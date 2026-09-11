---
title: "WebSocket Events"
linkTitle: "WebSocket events"
weight: 12
description: "WebSocket channel reference for Semantic Server: handshake, frame protocol, event types, and sequence-resume semantics for /ws/studio, /ws/chat, /ws/agent-events, /ws/devices, /ws/pilot, and /ws/simulation-stream."
---

This page is the Semantic Server WebSocket protocol reference. Every message type and event type is extracted from semantic-framework source: gateway implementations are in `internal/server/ws/` (browser channels) and `internal/robot/gateway.go` (Pilot channel). Event-type constants and publish points are spread across `internal/agent/runtime/`, `internal/workflow/`, `internal/interaction/`, `internal/robot/`, and handlers. When this page disagrees with code, trust the code.

REST endpoints are in [HTTP API](http.en.md). Protocol overview is in [Component interfaces and events](protocols.en.md).

## Channel overview

The WebSocket gateway listens on `server.ws_addr` (default `:8081`). Routes are registered in `internal/bootstrap/wire_access.go`:

| Path | Gateway | Subscription grain | Purpose |
|---|---|---|---|
| `/ws/studio` | `ws.StudioGateway` (`internal/server/ws/studio.go`) | Project (`project_id` query) | Studio main channel: uplink messages/cancel/interaction reply, downlink Project-level incremental events |
| `/ws/chat` | `ws.ChatGateway` (`internal/server/ws/chat.go`) | Conversation (`session_id` query) | Migration conversation channel: used by CLI and old pages |
| `/ws/agent-events` | `ws.Gateway` (`internal/server/ws/gateway.go`) | Conversation (`session_id` query) | Downlink-only event channel. Uplink supports only `sync` |
| `/ws/devices` | `ws.DeviceGateway` (`internal/server/ws/devices.go`) | Global device increments | Browser device center: Pilot/Robot/Skill/Ability/Execution increments |
| `/ws/pilot` | `robot.PilotGateway` (`internal/robot/gateway.go`) | Single Pilot connection | Device-side control channel (Pilot credential auth). See the dedicated section below |
| `/ws/simulation-stream` | `ws.SimulationStreamGateway` (`internal/server/ws/simulation.go`) | Single simulation stream | Forwards Plugin Pose/sensor frame streams to Studio (`kind=pose\|sensor`). Browsers do not connect to Plugin |

## Handshake and connection keep-alive

Except `/ws/pilot`, every channel shares the same handshake convention (`extractToken` in `internal/server/ws/gateway.go`):

- **Carrying a token**: prefer query `?token=<token>`. When the browser cannot set a custom request header, use subprotocol `Sec-WebSocket-Protocol: bearer.<token>`; the server echoes that subprotocol on handshake;
- **Subscription declaration**: `/ws/studio` uses `?project_id=`, `/ws/chat` and `/ws/agent-events` use `?session_id=` (may be empty; empty receives only broadcasts). Auth failure returns `401` and a unified JSON error (`{"error":{"code","message"}}`);
- **Heartbeat**: the server sends ping every 30s and treats the connection as dead after 90s without pong (`pingInterval`/`pongTimeout`, `internal/server/ws/gateway.go`);
- **Uplink limit**: one uplink message is capped at 1 MiB (`readLimit`). Oversize closes the connection;
- **Downlink backpressure**: per-connection downlink buffer is 64. The `trace` channel drops when full; other channels do not drop (they block).

## Downlink envelope

Every browser-channel downlink event uses a unified envelope (source `internal/server/ws/envelope.go`; protocol fields, do not rename):

```json
{
  "id": "evt-<毫秒时间戳>-<随机hex>",
  "project_id": "", "session_id": "",
  "resource_type": "", "resource_id": "", "revision": 0, "sequence": 0,
  "ts": "<RFC3339>", 
  "agent": {"id": "", "role": "", "name": ""},
  "channel": "dialogue", "type": "", "importance": "normal",
  "parent": {"run_id": "", "trace_id": ""},
  "payload": {}
}
```

| Field | Description |
|---|---|
| `id` | Unique event id (`evt-` prefix), approximately time-ordered. It is the resume cursor for `/ws/chat` and `/ws/agent-events` |
| `project_id` / `session_id` | Delivery target. Hub delivers by both. When both are empty it is a global broadcast (`internal/server/ws/hub.go`) |
| `resource_type` / `resource_id` / `revision` | Changed-resource identity. `revision` lets the client ignore stale events |
| `sequence` | Continuous Project-local sequence, assigned when Aggregator persists, used to find increment gaps |
| `channel` | Dispatch channel (table below) |
| `type` | Event type (event tables below) |
| `importance` | `critical` / `normal` / `low`. Decided by Aggregator grading-rules table v1 (`internal/server/aggregate/rules.go`): interaction is always critical, alert follows `payload.level`, trace is always low |

`channel` values: `dialogue` (main conversation), `alert` (alerts), `trace` (droppable detail), `artifact` (artifact references), `interaction` (interactions), `simulation` (simulation state). <!-- TODO(实跑): 当前发布代码实际只使用 dialogue / interaction / simulation 三个频道；alert、trace、artifact 为协议保留值，未见发布方，确认是否有计划内用途。 -->

## Uplink messages (uplinkMessage)

`/ws/chat` and `/ws/studio` share the same uplink protocol structure (`uplinkMessage` in `internal/server/ws/chat.go`; `/ws/agent-events` accepts only `sync` from it):

| Field | Type | Description |
|---|---|---|
| `type` | string | Message type, see the table below |
| `session_id` | string | Target Conversation (`chat.message` required) |
| `run_id` | string | Target Run for a precise Studio cancel |
| `after_sequence` | int64 | For `sync`: event position after a Project Snapshot |
| `text` | string | Message text (`chat.message` required, or provide attachments) |
| `attachments` | []string | Artifact IDs of already-uploaded images |
| `interrupt_current` | bool | Interrupt the current Run before send (mid-run correction) |
| `reasoning_effort` | string | This-turn reasoning-strength override: `inherit/auto/low/medium/high` |
| `reasoning_visibility` | string | This-turn thinking-display override: `inherit/auto/show/hide` |
| `send_scope` | object | When `{"type":"conversation","intent":"plan"}` this turn is plan mode; otherwise collaboration |
| `interaction_id` | string | Target interaction (`interaction.reply` required) |
| `approved` | bool | Compatibility field for old confirm clients |
| `response` | any | v0.3 generic structured reply content |
| `expected_state_revision` | int64 | State revision seen when replying (prevents replying to a stale interaction) |
| `source_revision` | int64 | Explicit source revision. When omitted the server takes `expected_state_revision` |
| `last_event_id` | string | For `sync`: event-id cursor |

Uplink types by channel:

| type | /ws/chat | /ws/studio | /ws/agent-events | Handling |
|---|---|---|---|---|
| `chat.message` | supported | supported (checks Conversation ownership and Project writability) | rejected | Runs on an independent goroutine; the read pump stays readable |
| `chat.cancel` | supported | supported (requires `run_id`) | rejected | Cancel a session/Run |
| `run.cancel` | rejected | supported (same as `chat.cancel`, by `run_id`) | rejected | Precise Studio cancel |
| `interaction.reply` | supported (old confirm protocol) | supported (structured reply) | rejected | Persist first, then wake the waiting Run |
| `interaction.cancel` | rejected | supported | rejected | Cancel a structured interaction |
| `sync` | supported | supported | supported | Disconnect resume, see below |

## Protocol replies and error codes

Direct replies to uplink messages are not Envelopes. They are independent protocol replies (`internal/server/ws/chat.go`):

- Error: `{"type": "error", "code": "<error code>", "message": "<description>"}`;
- Replay done: `{"type": "sync.done", "count": <count>}` (the `/ws/studio` version also has `"last_sequence": <sequence after replay>`).

| Error code | Meaning |
|---|---|
| `WS_UNKNOWN_TYPE` | Unknown uplink message type |
| `WS_BAD_MESSAGE` | Illegal message format or parameters |
| `CHAT_MESSAGE_FAILED` | Conversation-message handling failed (runtime error) |
| `INTERACTION_REPLY_FAILED` | Interaction reply failed (missing/already terminal/illegal/not assembled) |
| `SYNC_FAILED` | Disconnect-resume replay failed (including a gap) |
| `PROJECT_INACTIVE` | Project is not writable now and must be activated first (`/ws/studio` only) |

## Event-type inventory

Events are published by domain modules onto the event bus, then normalized, sequenced, persisted, and delivered by Aggregator (`internal/server/aggregate/aggregator.go`). Grouped by channel below. `payload` key names come from publish-point code.

### dialogue channel: Run and messages (internal/agent/runtime/events.go)

| type | payload | Description |
|---|---|---|
| `run.started` | `{"run": <RunSession>}` | Run has started |
| `run.waiting_input` | `{"run": ...}` | Waiting for user input / an interaction reply |
| `run.running` | `{"run": ...}` | Continue executing |
| `run.cancelling` | `{"run": ...}` | Cancelling |
| `run.completed` | `{"run": ...}` | Finished successfully |
| `run.failed` | `{"run": ...}` | Finished in failure |
| `run.cancelled` | `{"run": ...}` | Cancelled |
| `message.delta` | text delta | Model text increment |
| `reasoning.delta` | reasoning delta | Increment of reasoning content the model returned explicitly |
| `message.done` | `{"run_id","trace_id","text","metadata",...}` | This-turn reply finished (success or failure both close with this). metadata carries token usage |
| `tool.call` | tool-call arguments | Model started a tool call (carries call_id and raw arguments) |
| `tool.result` | tool-execution result | An ordinary tool finished |
| `subagent.delta` | text delta | SubAgent delegation execution bubble (agent attributed to the member instance) |
| `subagent.result` | task and full result | SubAgent delegation finished |

### dialogue channel: Plan Proposal and Workflow (internal/workflow/events.go, proposal.go, scheduler.go, service.go, robot_execution.go)

payload keys: Workflow view events are `{"workflow": <Workflow>, "workflow_view": <WorkflowView>}`; Plan Proposal events are `{"plan_proposal": <PlanProposal>}`.

| type | Description |
|---|---|
| `plan_proposal.ready` | Plan proposal is ready, waiting for user approve |
| `plan_proposal.approved` | Proposal approved (coupled with the approve endpoint) |
| `plan_proposal.discarded` | Proposal discarded |
| `workflow.approved` | Workflow created after approve |
| `workflow.paused` / `workflow.resumed` | Pause/resume |
| `workflow.stopping` / `workflow.stopped` | Stop requested / stopped (idempotent stop path) |
| `workflow.stop_confirmed_by_operator` | Operator confirmed stop on site |
| `workflow.robot_decision_retried` | Robot Agent decision retried |
| `workflow.completed` / `workflow.failed` | Terminal states |
| `workflow.recovered` | Recovered from an interrupt |
| `workflow.map_reference_stale` | Referenced semantic map is stale |
| `task.started` / `task.waiting` / `task.waiting_input` | Task scheduling states |
| `task.planning_subtasks` / `task.subtasks_planned` | Subtask planning |
| `task.completed` / `task.failed` | Task terminal states |
| `task.paused` / `task.recovery_revised` / `task.recovery_running` / `task.interaction_failed` | Hold and recovery process |
| `subtask.started` / `subtask.completed` / `subtask.stopped` | SubTask lifecycle |

### dialogue channel: Project resources (internal/server/http/handlers/projects.go, project_bindings.go, chat.go)

| type | payload | When published |
|---|---|---|
| `project.created` / `project.updated` / `project.archived` | `{"project": <Project>}` | Matching REST writes |
| `project.activated` / `project.deactivated` | `{"project": ...}` | activate / archive an active Project |
| `project.bindings.updated` | `{"project": ..., "bindings": <ProjectBindings>}` | PUT bindings |
| `memory.updated` | `{"memory": <ProjectMemory>}` | PUT memory |
| `conversation.created` / `conversation.archived` | `{"conversation": <sessionView>}` | Create/archive a Conversation (same shape in Project domain and migration /chat domain) |

### dialogue channel: Robot Execution (internal/robot/service.go, internal/bootstrap/wire_robot.go)

Robot Execution state changes travel two paths at once: published to the dialogue channel by Project (visible to Studio connections subscribed to that Project), and published to `/ws/devices` (see the device event table below). payload key: `{"execution": <RobotExecution>}` (or the event's raw payload).

| type | Description |
|---|---|
| `robot.execution.queued` | Queued (an idempotent `request_key` hit is also visible here) |
| `robot.execution.stopping` / `robot.execution.stopped` | Stopping / stopped (idempotent stop) |
| `robot.execution.failed` / `robot.execution.interrupted` | Failed / interrupted (reconnect reconcile) |
| `robot.execution.stop_confirmed_by_operator` | Operator confirmed stop |
| `robot.execution.reconciled` | Recovered by reconcile after Pilot reconnect |
| `robot.artifact.synced` | Artifact upload finished |
| `artifact.summary.announced` / `artifact.summary.failed` | Skill artifact-summary generation succeeded/failed (reported by `internal/pilot/runtime.go`) |

In addition, execution-process events reported by Pilot (`stage.*`, `action.*`, `observation.recorded`, `feedback.emitted`, `skill.started`, `skill.log`, `agent.requested`, `agent.resolved`, `stop.outcome`, and so on) enter the Execution event stream as-is. When the Execution belongs to a Project they are also published to the dialogue channel by Project.

### interaction channel (internal/interaction/service.go, structured.go)

| type | payload | Description |
|---|---|---|
| `interaction.request` | Interaction-request payload (`interaction_id`, question/risk/timeout, response_schema, and so on) | Approval/form request; importance is always critical |
| `interaction.resolved` | `{"interaction_id","status","reply","revision"}` | Replied/expired/cancelled; wakes a waiting Run |

### simulation channel (internal/server/http/handlers/simulation*.go)

Simulation-event envelopes have no `session_id` and are delivered by `project_id`.

| type | resource_type | When published |
|---|---|---|
| `simulation.runtime.ready` | runtime | Project Runtime ready (runtime/ensure) |
| `simulation.runtime.recovered` | runtime | Recovered an interrupted Runtime |
| `simulation.runtime.preference_updated` | project | PUT runtime-preference |
| `simulation.project.released` | runtime | Left the Project and reclaimed the Runtime |
| `simulation.project_scene.added` | project_scene | Added a scene reference |
| `simulation.layout_draft.created` | scene_document | Created a layout draft |
| `simulation.scene.started` | scene_instance | Started an instance from a scene / Project scene |
| `simulation.scene.<operation>` | scene_instance | pause/resume/step/reset/stop operations |
| `simulation.scene.variant_switched` | scene_instance | Switched a variant |
| `simulation.scene.built` | runtime_bundle | Scene package build finished |
| `simulation.map.synced` | semantic_map | Instance map synced |
| `simulation.robot.command.accepted` | robot_command | Virtual Robot command accepted |
| `simulation.robot.command.stopped` | robot_command | Command stopped |
| `simulation.robot.hold` | robot_command | E-stop / hold |
| `simulation.scene.document.created` / `.updated` / `.published` / `.forked` | scene_document | Scene-document lifecycle |
| `simulation.scene.layout.created` / `.renamed` / `.deleted` | scene_document | Layout lifecycle |
| `simulation.scene.package.imported` | scene_document | Scene package imported (one per document) |

## /ws/devices: device incremental events

Device-center channel (source `internal/server/ws/devices.go`, `internal/robot/devices.go`). Event structure is an independent `DeviceEvent` (not Envelope):

```json
{
  "id": "device-event-<UTC时间戳>-<sequence>",
  "sequence": 0,
  "resource_type": "robot", "resource_id": "", "resource_revision": 0,
  "type": "", "occurred_at": "<RFC3339>", "payload": {}
}
```

| resource_type | type | payload | Description |
|---|---|---|---|
| `robot` | `pilot.online` / `pilot.offline` / `pilot.status` | `{"robot": <device view>}` | Pilot online/offline/status update (`internal/robot/service.go`) |
| `robot` | `skill.<status>` (installed/failed/uninstalled), `skill.enabled` | `{"robot": ...}` | Coupled after Pilot reports `skill.status` |
| `robot` | `robot.idle` / `robot.busy` / `robot.interrupted` | `{"robot": ...}` | Current Execution change and interrupt |
| `robot_execution` | `robot.execution.*` (same table as above), Pilot-reported execution events | `{"execution": <RobotExecution>}` | Execution state and process events |
| `robot_runtime_instance` | `robot.runtime.starting/ready/stopping/stopped/failed/degraded/interrupted` | `{"runtime_instance": <RuntimeInstance>, "robot_id": ""}` | Managed Runtime lifecycle (`internal/robotruntime/orchestrator.go`) |
| `ability_debug` | `ability_debug.<status>` (started/stopping/…) | `{"debug": <debug execution>}` | Ability debug state |
| `artifact_sync` | `artifact_sync.announced` / `artifact_sync.synced` | `{"artifact_sync": <sync mapping>}` | Artifact upload registered/finished |

Device-view fields (`deviceView`, `internal/robot/devices.go`): `robot_id`, `display_name`, `model`, `backend`, `environment` (real/simulation), `status`, `revision`, `pilot`, `ability_framework`, `skill_catalog_revision`, `ability_catalog_revision`, `installed_skills`, `desired_skills`, `abilities`, `sensors`, `configuration`, `runtime_instance`, `current_execution_id`, `progress`. When offline, the current Gateway session is the source of truth and cached capability state is marked offline.

## Sequence resume and reconnect semantics

The three browser channels use different resume cursors. Reconnect semantics follow each gateway:

### /ws/chat and /ws/agent-events: last_event_id cursor

Source: `internal/server/ws/sync.go` (`handleSync`). After reconnect (re-handshake with the same `session_id`) send:

```json
{"type": "sync", "last_event_id": "evt-..."}
```

- The server replays missing events in that session later than the cursor, in ascending event `id` (persisted in the event table);
- `trace` channel events are not replayed (droppable, not backfilled; `internal/store/events.go`);
- After replay it replies `sync.done` (`count` is the replayed count). An empty `last_event_id` means live stream only and replies `sync.done` immediately (count=0);
- **at-least-once boundary**: live events that arrive in the reconnect window may overlap the replay. Clients must de-duplicate by event `id` (source comments state this contract).

### /ws/studio: after_sequence cursor

Source: `internal/server/ws/studio.go` (`handleProjectSync`). After reconnect (re-handshake with the same `project_id`) send:

```json
{"type": "sync", "after_sequence": 0}
```

- The server replays incremental events later than that sequence by Project sequence, then replies `{"type":"sync.done","count":N,"last_sequence":M}`;
- `after_sequence < 0` replies `WS_BAD_MESSAGE`. A cursor so old that there is a gap replies `SYNC_FAILED` ("增量存在缺口，请重新读取 Snapshot") — the client should re-read `GET /api/v1/projects/{id}/studio/snapshot` and resubscribe.

### /ws/devices: first message must be sync

Source: `internal/server/ws/devices.go`, `internal/robot/devices.go` (`SubscribeDevices`).

- Within 10s of connect you must send `{"type": "sync", "after_sequence": <DeviceSnapshot event_sequence>}`, otherwise the connection is closed;
- An illegal cursor (`after < 0` or `after > current`) or a gap (`after < current`) replies `{"type":"error","code":"SYNC_FAILED","message":"..."}` — the Server only caches live increments. The client must re-read `GET /api/v1/devices/snapshot`;
- `after_sequence=0` means live increments only;
- Robot Execution process events also have a **per-Execution** sequence (`RobotExecutionEvent.Sequence`), continued through REST `GET /api/v1/robot-executions/{id}?after_sequence=` (500 per page, `has_more` + `next_sequence`).

## Pilot WebSocket (/ws/pilot)

The single control channel between Pilot and Server. Control events travel this channel. Binary transfer of Skill packages and Artifacts travels HTTP `/pilot/v1/transfers/*`. Source: server `internal/robot/gateway.go`, client `internal/pilot/remote.go`.

### Handshake and register

- Connect: `GET /ws/pilot`, request header `Authorization: Bearer <Pilot credential>` (credential exchanged through Pilot Enrollment, bound to the device);
- **The first message must be `register`**, otherwise the connection is closed with PolicyViolation. `register.pilot.pilot_instance_id` must match the Pilot ID bound to the credential;
- After a successful register the Server immediately issues `reconcile.request`;
- Uplink messages are capped at 2 MiB (register and heartbeat carry Ability Manifests; heartbeat defaults to once every 2s);
- After disconnect, Pilot automatically reconnects by `ReconnectDelay` and registers again (the register message carries a full `packages`/`active` Skill snapshot).

### Uplink messages (Pilot → Server)

Unified uplink structure (`pilotUplink`): `{"type": "...", "pilot": {}, "skills": [], "event_type": "", "sequence": 0, "payload": {}, "executions": [], "command_id": "", "ok": false, "error": "", "result": {}}`.

| type | Fields | Description |
|---|---|---|
| `register` | `pilot`, `skills` | First message: Pilot identity + full snapshot of installed Skills |
| `heartbeat` | `payload` (Pilot snapshot) | Periodic report of status/Robot state/current Execution |
| `event` | `event_type`, `sequence`, `payload` | Domain event. `event_type` values are in the table below |
| `reconcile` | `executions` | Response to `reconcile.request`: recoverable Execution snapshot (`execution_id/status/checkpoint/feedback_cursors`) |
| `command.ack` | `command_id`, `ok`, `error`, `result` | Result of a Server downlink command |

`event` `event_type` values (from publish points in `internal/pilot/remote.go`, `internal/pilot/runtime.go`, and Worker pass-through):

| event_type | payload highlights | Server handling |
|---|---|---|
| `skill.status` | `name/version/enabled/status/error` | Update the Pilot Skill catalog; couple device event `skill.<status>`; trigger desired reconcile |
| `ability.debug.status` | `debug` (debug-execution state) | Pass through as `ability_debug.<status>` device event |
| `artifact.announce` | `execution_id/local_artifact_id/media_type/summary/size_bytes` | Register an upload task and issue `artifact.upload` |
| `agent.requested` | `execution_id/skill_name/stage/decision_key/decision_revision/reason/context/response_model/response_schema/status` | Execution enters `waiting_agent`. Studio receives the Agent request (reply via the `agent-reply` endpoint) |
| `agent.resolved` | decision result | Execution returns to running |
| `execution.accepted` | `execution_id/status` | Execution accepted by Pilot |
| `skill.started` / `skill.log` / `skill.stop.finalized` | stage and logs | Execution process events |
| `execution.terminal` | terminal result | Execution terminal converge |
| `worker.restarted` | `reason/error` | Worker process restart record |
| `feedback.emitted` / `observation.recorded` / `action.started` / `action.terminal` / `stop.outcome` | Stage/Action/feedback/observation fields passed through as-is | Execution process events (carry `skill_status`, `occurred_at`) |
| `stage.*` (for example `stage.running`) | Worker `event.report` passed through as-is | Process events; `stage.running` is also written into the recovery checkpoint |

`sequence` is the Execution event sequence. The Server uses it for persist ordering. When omitted the Server fills it with `NextRobotExecutionEventSequence`.

### Downlink messages (Server → Pilot)

Unified downlink structure (`serverCommand`): `{"type": "...", "command_id": "...", "payload": {}}`. Pilot replies `command.ack` to every command (`skill.validate_input` acks in the same message and carries `result`).

| type | payload | Purpose |
|---|---|---|
| `reconcile.request` | `requested_at` | Ask Pilot to report recoverable Executions (Server initiates after reconnect/startup) |
| `reconcile.result` | `executions` | Reconcile-result receipt (Server corrects state from the Pilot snapshot) |
| `execution.start` | `execution` (`execution_id/project_id/task_id/subtask_id/robot_id/skill_name/skill_version/input`), `artifact_downloads` | Start a Robot Skill (Workflow schedule or manual debug) |
| `execution.stop` | `execution_id`, `reason` | Stop an Execution (device-side step of the idempotent stop path) |
| `agent.reply` | Agent decision reply (forwarded as-is to the Skill Worker) | Reply to `agent.requested` (triggered by the REST `agent-reply` endpoint) |
| `skill.install` | `name`, `version`, `package_url` (points at `/pilot/v1/transfers/*`) | Install a Skill package |
| `skill.enable` / `skill.disable` | `name`, `version` | Enable/disable an installed Skill |
| `skill.uninstall` | `name`, `version` | Uninstall |
| `skill.validate_input` | `name`, `version`, `input` | Pre-start input validation (against the Skill Task Model) |
| `artifact.upload` | `execution_id`, `local_artifact_id`, `upload_url` | Upload an Artifact |
| `ability.debug.start` | debug-execution description (`ability_instance_id` and so on) | Start Ability debug |
| `ability.debug.stop` | `debug_id`, `reason` | Stop Ability debug |

## /ws/simulation-stream (simulation picture-stream proxy)

Source: `internal/server/ws/simulation.go`. The Server forwards Plugin Scene Pose/sensor binary streams to Studio. Browsers do not learn the Runtime address:

- Connect: `/ws/simulation-stream?project_id=&kind=pose|sensor&instance_id=&robot_id=&sensor_id=`;
- `kind=pose` forwards the scene Pose stream; `kind=sensor` forwards a specified sensor frame stream;
- This channel is a one-way binary proxy (upstream 16 MiB frame cap) with no JSON event semantics. Upstream connect failure returns `502 SIMULATION_STREAM_OFFLINE`.

## Related references

- REST endpoints and auth: [HTTP API](http.en.md);
- How the Studio frontend consumes these events (dispatcher, store, resume): [Studio frontend architecture](../internals/semantic-studio.en.md);
- In-process boundary between Pilot and Worker: [Component interfaces and events](protocols.en.md).
