---
title: "Server, Agent, and Workflow"
weight: 10
description: "Framework server core: HTTP/WS gateways, Agent Runtime, Workflow scheduling, and persistence."
---

Semantic Server stores Project run data, organizes Agent Runs, and advances continuing work through Workflow. All implementation lives in `semantic-framework`:

- Entry and assembly: `cmd/semantic-server/main.go`, `internal/bootstrap/`
- HTTP routes: `internal/server/http/router.go`; WebSocket: `internal/server/ws/`
- Agent kernel and Run: `internal/agent/kernel/`, `internal/agent/runtime/`
- Workflow: `internal/workflow/`; storage: `internal/store/`

## Local start

```bash
cd semantic-framework
cp .env.example .env        # set SEMANTIC_ADMIN_PASSWORD and model keys as needed
make doctor                 # build + semantic init + config/port/key checks
make run                    # start Server (HTTP :8080 / WS :8081)
make logs                   # tail .output/logs/semantic-server.jsonl
```

- `semantic init` installs the config template compiled into the binary into `.output/` (existing files are kept). Runtime always uses the installed copy;
- Storage is SQLite (pure Go driver, no CGO, single writer), path `.output/data/semantic.db`;
- First start seeds user `admin`. When `SEMANTIC_ADMIN_PASSWORD` is unset the default password is `admin123` and a WARN is logged;
- Without a model key only the mock endpoint is available. The service still starts.

## Service ports and connections

| Service | Default address |
|---|---|
| Semantic Server HTTP | `:8080` |
| Semantic Server WebSocket | `:8081` (separate port) |

HTTP APIs all live under `/api/v1` (except the Pilot download channel `/pilot/v1/transfers/*`). WebSocket endpoints:

| Endpoint | Purpose |
|---|---|
| `/ws/agent-events` | Event channel (conversation messages, Run activity) |
| `/ws/chat` | Conversation uplink |
| `/ws/studio?project_id=...&token=...` | Project-level business events |
| `/ws/devices` | Device state |
| `/ws/pilot` | Pilot connection (dedicated credential) |
| `/ws/simulation-stream` | Simulation stream |

Downlink messages use a unified envelope (`internal/server/ws/envelope.go`):

```json
{
  "id": "evt-<millis>-<16hex>",
  "project_id": "...", "session_id": "...",
  "resource_type": "...", "resource_id": "...",
  "revision": 0, "sequence": 0, "ts": "...",
  "agent": {"id": "...", "role": "...", "name": "..."},
  "channel": "dialogue|alert|trace|artifact|interaction|simulation",
  "type": "agent.message|tool.completed|run.started|...",
  "importance": "critical|normal|low",
  "parent": {"run_id": "...", "trace_id": "..."},
  "payload": {}
}
```

Uplink messages (`type`): `chat.message / chat.cancel / run.cancel / interaction.reply / interaction.cancel / sync`. After disconnect, replay with `last_event_id` (Chat) or `after_sequence` (Studio). Error replies are `{type:"error", code, message}`.

Auth: login (`POST /api/v1/auth/login`) returns an opaque random token (stored in SQLite, not JWT, TTL 24h). After expiry, `POST /api/v1/auth/refresh` issues a new token (no separate refresh_token).

## Agent Run

An Agent Run is one model execution that can be traced, cancelled, and has a terminal state:

```text
run.started → [model generation → tool.call → tool.result → generate again]… → run.completed / failed / cancelled
```

Run event kinds (`kernel/run.go`): `EventTextDelta / EventReasoningDelta / EventToolCall / EventToolResult / EventDone / EventError / EventInterrupted / EventSubAgentDelta / EventSubAgentResult`. Runtime converts them to `message.delta / reasoning.delta / message.done / tool.call / tool.result` and Run status events.

Key semantics:

- **Run is decoupled from the connection**: a Run uses an independent context. A frontend disconnect does not stop execution. After a model Run ends, state is advanced by events;
- The user's next message, an Interaction reply, Task execution, and Recovery each create a new Run;
- **Persist the user message before starting the Run**. Assistant messages persist turns/usage/reasoning/tools/delegations so REST can fully restore history;
- Session history is fully replayed to build context (no cross-Run memory, except approval-breakpoint checkpoints);
- Interrupt-resume: when risk hits `interrupt.approval_required`, the Run enters `waiting_input`, starts an Interaction at each interrupt point, and Resume starts a new stream after the reply is persisted.

## Team and Agent directory

`configs/agents/teams/default.yaml` assembles the default Team: leader (coordinator) + query-1 (service, on-demand SubAgent) + developer-1 / map-1 / monitor-1 (worker). Robot Workers get identities generated dynamically from actual Robots (for example `robot:r1_pro_tote_gripper-1`).

- Agent state machine (roster): `starting → idle ⇄ running → stopped`, plus `offline` (the logical Agent exists but Pilot is unreachable);
- `GET /api/v1/agents` returns each Agent's role/mode/status/model/tool_namespaces/skill_names/max_turns, and so on;
- Service-mode members are assembled as agent-as-tool. **Delegation tool names use the member instance ID (query-1), not the role name**, aligned with event attribution.

## Proposal and Workflow

```text
Leader calls plan.suggest in Plan Mode (strict scope check)
→ Plan Proposal is stored and plan_proposal.ready is published
→ User approves the exact revision (REST approve)
→ Workflow / Task / dependencies are created atomically (global IDs reassigned)
→ workflow.approved is published and scheduling starts
```

`plan.suggest` server-side checks: only an explicit Plan Mode Leader Run may call it; a Robot Task's `required_capabilities` must be inside the approved scope's `allowed_skills`; the approve transaction **clears SubTasks output by Leader** — only a Task Agent can plan SubTasks.

### State machines

Workflow / Task / SubTask share states: `pending / running / paused / stopping / completed / failed / stopped` (transition table in `internal/store/workflow.go`):

```text
Workflow: running → {paused, stopping, completed, failed}
          paused  → {running, stopping}
          stopping → {stopped, paused}
Task/SubTask: pending → {running, paused, stopping, stopped}
          running → {paused, stopping, completed, failed}
          paused  → {running, stopping, failed}
          stopping → {stopped, paused}
```

Notes:

- Every transition carries a revision optimistic lock plus `confirmed_revision` check;
- `stopping → paused` is only for a Robot SubTask whose physical stop cannot be confirmed (keeps execution_ref and the Robot lock);
- `ConfirmWorkflowStop` is the only human terminal entry for `execution_state_unknown`;
- A SubTask has only two kinds: `robot_skill` or `agent_step`;
- Robot reservation: a partial unique index on `assigned_robot_id` guarantees exclusivity while a Task is active. A Robot is bound only when the Task is ready.

### Scheduling

The scheduler has **no polling**. It is event-driven:

- Workflow approve / resume / Task terminal → `schedule()`: pick pending Tasks whose dependencies are done, validate Map bindings, pass in-process gates, then start asynchronously;
- Robot resource edge events (`OnRobotAvailabilityChanged`) → re-evaluate `waiting_resource` Tasks;
- Robot occupancy uses a database unique constraint. In-process only a workspace write lock is kept.

`robot.run` accepted only records execution_ref (`AttachSubTaskExecution`) and **does not advance state — completion must be driven by a Robot Execution terminal state**:

| Robot Execution terminal | SubTask convergence |
|---|---|
| completed | Complete the SubTask, `continueOrFinishTask` |
| failed | Physics already started → `execution_state_unknown` (replay forbidden); not started → `robot_execution_failed` + Recovery |
| waiting_agent | Start one Robot Agent Decision; the reply returns to the original Worker |
| interrupted | paused / execution_state_unknown |
| stopped / cancelled | Converge stop |

## Pause and resume

Pause reasons form a wait view from the current state of Task, Interaction, Agent Run, and Robot Execution. When you implement a new pause path, also provide:

- A clear reason (`waiting_reason`);
- The current owner;
- What is being waited for;
- The only valid resume operation;
- State recovery after a Server restart (all state lands in SQLite; Run breakpoint checkpoints persist with run_sessions).

## Stop

Workflow stop is an idempotent converge: block new work → cancel Agent Runs → request stop from the real state of active Robot Executions and wait for hold evidence. Late results from a model or Worker re-check Workflow and Task state before writing the Store.

## Storage

- SQLite (`modernc.org/sqlite`, no CGO), `SetMaxOpenConns(1)` single writer;
- Versioned migrations v1→v31 (`internal/store/migrate.go`), executed in version order inside transactions. **Do not modify a published migration**;
- Main domain tables: users/tokens, trace/metering, chat/run_sessions, artifacts/interactions, events, settings/keys, projects, workflow/plan_proposal, semantic_map, simulation, robot/robot_runtime, pilot_enrollment.

## Common REST APIs

Full routes are in `internal/server/http/router.go`. Common domains:

| Domain | APIs |
|---|---|
| Auth | `POST /auth/login`, `/auth/refresh`, `/auth/logout` |
| Agent | `GET /agents`, `PUT /agents/{id}/models` |
| Skill/Tool | `GET /skills(/{name}/resources/*)`, `GET /tools` |
| Project | `GET/POST /projects`, `POST /projects/{id}/activate`, `GET/PUT /{id}/bindings`, `/{id}/conversations` |
| Conversation | Messages related to `GET /projects/{id}/conversations/{cid}` go through `/chat/sessions/{id}/messages` |
| Plan/Workflow | `GET /{id}/plan-proposals/active`, `POST .../{approve\|discard}`, `POST /{id}/workflows/{wid}/{pause\|resume\|stop}` |
| Run | `GET /runs/{id}`, `POST /runs/{id}/cancel` |
| Robot | `/devices/*`, `/robot-executions/{id}(/stop\|/agent-reply)` |
| Simulation | `/projects/{id}/simulation/**` (instances/snapshot/viewer-scene/operations/scene-documents) |
| Observation | `GET /traces`, `GET /metering/summary`, `GET /interactions` |
| Settings | `GET/PATCH /settings`, `GET/PUT/DELETE /settings/keys/{name}` |

Errors are unified as `{"error": {"code", "message", "details"}}`.

## Tests

```bash
# all integration tests: real bootstrap.Wire + mock model + real HTTP/WS (no external deps)
go test ./tests/integration/ -count=1

# per-domain unit tests
go test ./internal/workflow/... ./internal/store/... ./internal/agent/... -count=1
```

Test coverage: normal completion, Interaction, Recovery, Pilot offline, Server restart, and repeat stop. State consistency requires Workflow, Task, SubTask, Robot Execution, Pilot, and Web to reflect the same run fact.

## Related layers

- Conceptual model: [Architecture · Planning and Workflow](../../../architecture/05-planning-and-workflow.en.md), [Architecture · Agents and collaboration](../../../architecture/04-agent-and-collaboration.en.md)
- Design contracts: [Core modules · Workflow and task orchestration](../../core-modules/orchestration/_index.en.md), [Core modules · Agent Roles and Teams](../../core-modules/intelligent/agent-profile.en.md)
