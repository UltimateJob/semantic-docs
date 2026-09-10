---
title: "Chapter 4: Plan Proposal, Workflow, and Task"
linkTitle: "Chapter 4: Workflow"
weight: 24
description: "Create a Project, Conversation, and Plan Proposal in Studio, then turn the approved plan into a Workflow."
---

**Goal of this chapter**: starting from the Agent configured in Chapter 3, walk the business entry of the execution chain through the Studio UI or REST/WebSocket APIs: user goal → Plan Proposal → approve → Workflow → Task. When you are done, you should have an approved Workflow and its Task DAG.

## What a Workflow is

A Plan Proposal is a plan an Agent submitted for review. A Workflow is the continuing body of work after the user approves it. A Task is a business result owned by one Agent. A SubTask is a local step inside a Task.

```text
Conversation
└── Plan Proposal
    └── Workflow
        └── Task
            └── SubTask
```

An Agent Run is one model execution. An embodied task spans user approval, resource waits, multiple Runs, and physical execution. Workflow persists the plan, dependencies, resources, execution references, and results so work can continue after a Run ends. Plan Proposal is the approval boundary: a runnable Workflow never appears in the database before approval (`semantic-framework/internal/workflow/proposal.go`, `semantic-framework/internal/store/plan_proposal.go`).

## Code locations

- Workflow application service: `semantic-framework/internal/workflow/` (`proposal.go` is the submit-and-approve entry);
- Store: `semantic-framework/internal/store/plan_proposal.go`, `semantic-framework/internal/store/workflow.go`;
- HTTP routes: `semantic-framework/internal/server/http/router.go`;
- Plan tool: `semantic-framework/internal/tool/builtin/plan_suggest.go`;
- Studio: `semantic-web/src/components/studio/` (`ConversationPlanSummary.vue`, `panels/PlanDocumentPanel.vue`, `panels/WorkflowRunPanel.vue`).

## Preconditions

- The Chapter 1 Server is running and you can log in:

  ```bash
  curl -s http://127.0.0.1:8080/api/v1/system/healthz
  ```

  Expected output:

  ```json
  {"status":"ok"}
  ```

- Chapter 3 Agent Profile, Model, and Skill are configured. Confirm the leader Skill authorization includes the built-in depalletizing planning Skill:

  ```bash
  curl -s http://127.0.0.1:8080/api/v1/agents \
    -H "Authorization: Bearer $TOKEN"
  ```

  In the expected response, `leader`'s `skill_names` should include `"depalletizing-workflow-planning"`. It is the built-in example in the default config (template at `semantic-framework/configs/skills/workflow/depalletizing-workflow-planning/`, default authorization in `skills.allowlist` of `semantic-framework/configs/agents/leader/role.yaml`).

- A model is available: the real model from Chapter 3, or the default `mock` Provider (`llm.default: mock` in `semantic-framework/configs/semantic-server.yaml`). This chapter still works without a real model key; see [Common questions](#common-questions).
- Studio is started and you can log in (Path A); or you already have a login Token (Path B):

  ```bash
  TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"username":"admin","password":"admin123"}' \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
  ```

  The initial password comes from `SEMANTIC_ADMIN_PASSWORD`. When unset it is `admin123` (`semantic-framework/internal/server/auth/service.go`).

## Path A: Studio

Studio is the default entry for this chain. Every write eventually hits the same endpoints listed in Path B.

### 1. Create a Project

1. Log into Studio;
2. Open Projects;
3. Click New Project;
4. Enter a name, for example `quickstart-depalletizing`;
5. Save and enter the Project.

When the install has no active Project, the first Project you create is activated automatically (`activateIfNoneTx`, see `semantic-framework/internal/store/project.go`). Otherwise Studio asks you to activate first. If a Runtime Installation is registered, you can choose `native-mujoco` on the Project Simulation page. In source development mode you can keep using the standalone Runtime from Chapter 2.

### 2. Create a Conversation and enter a goal

In the Project, create a Conversation. In the input box switch the send mode to "Planning" (Plan Mode; protocol field `send_scope: {"type":"conversation","intent":"plan"}`, see `semantic-web/src/components/chat/PromptInput.vue`), then enter a clear goal:

```text
Plan a depalletizing task: move one top-layer tote from the source pallet to the target pallet.
```

After send, Leader enters a planning Run. It may ask clarifying questions first. When the goal, constraints, and completion criteria are enough, it calls the `plan.suggest` tool to submit a complete plan.

### 3. Wait for the Plan Proposal card

After `plan.suggest` succeeds, a plan card appears in Conversation (component `ConversationPlanSummary.vue`):

```text
PLAN PROPOSAL · REVISION 1
Plan a depalletizing task: …
N main Tasks · TODO: …
[View plan]  [Approve and execute]
```

The card shows the current revision and the number of main Tasks. revision is the optimistic lock for approval. Each time Leader resubmits a plan, it increments by 1.

<!-- TODO(实跑): 用 mock 默认 Provider 跑通「规划模式 → plan.suggest → 计划卡片出现」的完整界面路径并截图；mock 兜底剧本写法见常见问题。 -->

### 4. Review the plan detail

Click "View plan" to open the Plan Document panel (`panels/PlanDocumentPanel.vue`) and check:

- Goal and scope (`goal`, `approved_scope`);
- Main Task list (each Task's role, capabilities, resource scope, completion criteria);
- Task dependencies;
- Risks and items that need confirmation.

The plan body is Markdown (`document_markdown`) and is display-only. Execution always reads the structured plan `structured_plan`. The Framework never reverse-parses Markdown (see the `PlanProposal` comment in `semantic-framework/internal/store/plan_proposal.go`).

To adjust, go back to the original Conversation and say so. Leader calls `plan.suggest` again and produces a new complete revision.

### 5. Approve and create a Workflow

Click "Approve and run" on the plan card or Plan Document panel. The frontend calls the approve endpoint with the current revision (`approveProposal` in `semantic-web/src/stores/workflow.js`). If the revision was changed by a newer submit, the UI says the plan was updated and asks you to review again.

### 6. Inspect Workflow and Tasks

After a successful approve, the Workflow Run panel opens automatically (`panels/WorkflowRunPanel.vue`). It should show:

- The new Workflow (status `running`);
- The main Task list and dependency DAG;
- `required_capabilities` of Robot Tasks (if the plan locked Robot Skills).

Task status meanings:

- `pending`: waiting for a dependency or resource;
- `running`: an Agent or Robot has been assigned;
- `paused`: waiting for the user, an Interaction, or a resource;
- `stopping`: converging a stop;
- `completed`: a result has been formed.

(State machine definition: `semantic-framework/internal/store/workflow.go`.)

## Path B: API

The following commands match the call sequence `semantic-framework/tests/gate/v050_real_gate.py` runs against a real Server. All endpoints are in `semantic-framework/internal/server/http/router.go`. Assume `$SEMANTIC` is the multi-repo workspace root.

### 1. Log in

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
```

Response skeleton (fields: `tokenResponse` in `semantic-framework/internal/server/auth/handlers.go`):

```json
{
  "token": "<opaque token>",
  "expires_at": "<RFC3339 timestamp>"
}
```

### 2. Create a Project

```bash
PROJECT_ID=$(curl -s -X POST http://127.0.0.1:8080/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"quickstart-depalletizing"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["project"]["id"])')
```

Response is 201. Skeleton (request/response fields: `createProjectRequest` in `handlers/projects.go` and `Project` in `store/project.go`):

```json
{
  "project": {
    "id": "proj-<uuid>",
    "name": "quickstart-depalletizing",
    "mode": "development",
    "is_active": true,
    "revision": 1
  }
}
```

Note `is_active`: only an active Project is writable. When the current install has no active Project, a newly created Project activates automatically. Otherwise you must activate it explicitly, or later writes return 409 `PROJECT_INACTIVE`:

```bash
curl -s -X POST http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/activate \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Create a Conversation

```bash
CONVERSATION_ID=$(curl -s -X POST http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/conversations \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"quickstart depalletizing plan"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["conversation"]["id"])')
```

Response is 201. Skeleton (fields: `sessionView` in `handlers/chat.go`):

```json
{
  "conversation": {
    "id": "<conversation ID>",
    "project_id": "proj-<uuid>",
    "title": "quickstart depalletizing plan",
    "revision": 1
  }
}
```

### 4. Send a planning goal over WebSocket

Conversation messages have no HTTP entry. Send and incremental subscribe go over WebSocket (Server WS port 8081, see `server.ws_addr` in `configs/semantic-server.yaml`). The following script uses the Python standard library to send one Plan Mode message. The protocol matches the gate test (`_send_plan_message` in `tests/gate/v050_real_gate.py`; message structure is `uplinkMessage` in `internal/server/ws/chat.go`):

```bash
python3 - "$TOKEN" "$CONVERSATION_ID" <<'EOF'
import base64, json, os, socket, sys, urllib.parse

token, session_id = sys.argv[1], sys.argv[2]
query = urllib.parse.urlencode({"token": token, "session_id": session_id})
message = {
    "type": "chat.message",
    "session_id": session_id,
    "text": "Plan a depalletizing task: move one top-layer tote from the source pallet to the target pallet.",
    "send_scope": {"type": "conversation", "intent": "plan"},
}

sock = socket.create_connection(("127.0.0.1", 8081), timeout=3)
key = base64.b64encode(os.urandom(16)).decode("ascii")
sock.sendall((
    f"GET /ws/chat?{query} HTTP/1.1\r\nHost: 127.0.0.1:8081\r\n"
    f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
).encode("ascii"))
response = b""
while b"\r\n\r\n" not in response:
    response += sock.recv(4096)
assert b" 101 " in response.split(b"\r\n", 1)[0], response[:200]

payload = json.dumps(message, ensure_ascii=False).encode("utf-8")
mask = os.urandom(4)
header = bytearray([0x81])
if len(payload) < 126:
    header.append(0x80 | len(payload))
else:
    header.append(0x80 | 126)
    header.extend(len(payload).to_bytes(2, "big"))
sock.sendall(bytes(header) + mask +
             bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
sock.close()
print("Sent Plan Mode message")
EOF
```

Expected output:

```text
Sent Plan Mode message
```

`send_scope.intent=plan` is the switch that puts Leader into explicit Plan Mode (`conversationMode()` in `internal/server/ws/chat.go`). When omitted, the message is treated as ordinary collaboration and produces no Plan Proposal. The Studio frontend sends the same message type on `/ws/studio?token=...&project_id=...`. The uplink protocol is the same (`internal/server/ws/studio.go`).

<!-- TODO(实跑): 用 mock Provider 验证该脚本后补充服务端下行确认帧（gate 测试会等待首个下行帧再断开）。 -->

### 5. Poll the Plan Proposal

```bash
curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/active \
  -H "Authorization: Bearer $TOKEN"
```

Before Leader has submitted:

```json
{"plan_proposal": null}
```

After `plan.suggest` succeeds, the response is 200. Skeleton (fields: `PlanProposal` in `store/plan_proposal.go`):

```json
{
  "plan_proposal": {
    "id": "plan-<uuid>",
    "project_id": "proj-<uuid>",
    "conversation_id": "<conversation ID>",
    "revision": 1,
    "status": "ready",
    "goal": "<goal>",
    "summary": "<plan summary>",
    "approved_scope": {},
    "structured_plan": {},
    "document_markdown": "<Markdown plan body>"
  }
}
```

When `status` is `ready`, take `id` and `revision`:

```bash
read PROPOSAL_ID PROPOSAL_REVISION < <(
  curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/active \
    -H "Authorization: Bearer $TOKEN" \
    | python3 -c 'import sys,json; p=json.load(sys.stdin)["plan_proposal"]; print(p["id"], p["revision"])'
)
```

<!-- TODO(实跑): 记录 mock 模型下从发消息到 ready 的典型耗时区间。 -->

### 6. Approve the Plan Proposal

Approve must carry the current exact revision (`revision` and `expected_revision` are equivalent; see `planProposalActionRequest` in `handlers/projects_plan_proposal.go`):

```bash
curl -s -X POST "http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/$PROPOSAL_ID/approve" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"revision\": $PROPOSAL_REVISION}"
```

Response is 200. Skeleton (`workflow_view` structure: `WorkflowView` in `store/workflow.go`):

```json
{
  "workflow_view": {
    "workflow": {
      "id": "wf-<uuid>",
      "project_id": "proj-<uuid>",
      "conversation_id": "<conversation ID>",
      "goal": "<goal>",
      "status": "running",
      "revision": 1,
      "confirmed_revision": 1
    },
    "tasks": [
      {
        "id": "task-<uuid>",
        "workflow_id": "wf-<uuid>",
        "required_role": "robot",
        "required_capabilities": ["<Robot Skill name>"],
        "goal": "<Task goal>",
        "status": "pending",
        "revision": 1
      }
    ],
    "subtasks": [],
    "dependencies": [
      {"task_id": "task-<uuid>", "depends_on_task_id": "task-<uuid>"}
    ],
    "subtask_dependencies": []
  }
}
```

Actual Task goals, roles, and dependencies come from the model-generated plan. The skeleton only labels field sources. Approve is atomic: Workflow, Tasks, and dependencies are created in the same transaction before the response returns (`ApprovePlanProposal` in `store/plan_proposal.go`).

### 7. Read the Workflow view

```bash
curl -s "http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/workflows/<workflow_id>/view" \
  -H "Authorization: Bearer $TOKEN"
```

You can also read the current unfinished Workflow directly:

```bash
curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/workflows/active \
  -H "Authorization: Bearer $TOKEN"
```

Both return `workflow_view` (`HandleGetWorkflowView` / `HandleGetActiveWorkflow` in `handlers/projects_v030.go`). You can then keep watching Tasks move from `pending` to `running`.

## Verification checklist

UI (Path A):

- [ ] A `PLAN PROPOSAL · REVISION n` card appears in Conversation;
- [ ] The Plan Document panel opens and shows the goal, main Tasks, and dependencies;
- [ ] Clicking "Approve and run" automatically opens the Workflow Run panel;
- [ ] The Workflow Run panel shows a `running` Workflow and a Task DAG.

API (Path B):

- [ ] `GET /api/v1/projects/{id}/plan-proposals/active` returns a proposal with `status: "ready"`;
- [ ] `POST .../approve` returns 200 and `workflow_view.workflow.status` is `"running"`;
- [ ] `workflow_view.tasks` is non-empty and `dependencies` match the plan;
- [ ] `GET /api/v1/projects/{id}/workflows/{workflow_id}/view` keeps returning the same view;
- [ ] Conversation shows a Leader activity message: `Plan revision n 已批准，Workflow wf-... 已开始` (written by `ApprovePlanProposal` in `internal/workflow/proposal.go`).

## What happens after a run

In time order (source locations are under "Code locations"):

1. **A Plan Mode message enters**: the WebSocket uplink `chat.message` carries `send_scope.intent=plan`. The Server starts an explicit Plan Mode Leader Run. That Run's tools are hard-whitelisted to `system.*`, `artifact.get`, `artifact.list`, `map.query`, `plan.suggest`, and `interaction.ask` (`internal/agent/runtime/workflow_runtime.go`). It cannot execute commands, delegate Agents, or operate a Robot.
2. **plan.suggest submits**: Leader calls `plan.suggest` (model-side tool name `plan_suggest`, mapped by `SafeToolName` in `internal/agent/kernel/tools.go`). The tool validates parameters and hands them to the Workflow Service, which creates or revises a Proposal in a transaction. A repeat submit on the same Conversation increments `revision`. On success it publishes `plan_proposal.ready`, which refreshes the Studio plan card. If the model stream is cancelled or parameters are illegal, the previous revision stays as-is.
3. **User approve**: the approve request carries the exact revision. The Service compares revision once, then the Store checks `revision` and `status='ready'` again inside the transaction. Any mismatch returns `ErrRevisionConflict`, mapped by the HTTP layer to 409 `REVISION_CONFLICT`.
4. **Transactional create**: the same transaction creates the Workflow (`status='running'`, `revision=1`), main Tasks and dependencies (`replacePlanTx`), sets the Project to `running` mode, and sets the Proposal to `approved`. A half Workflow never appears in the database before success.
5. **Event-driven scheduling**: after commit, `workflow.approved` is published, a Leader activity message is written to Conversation, and the scheduler starts. Tasks advance by dependency and resource-wait conditions. Agent and Robot assignment happens after approve, so approve does not require preexisting SubTasks or a robot_id.
6. **Repeat approve is an idempotent reject**: after the first approve, the Proposal `status` is already `approved` and `revision` has incremented. Approving the same revision again only yields 409 `REVISION_CONFLICT` and does not create a second Workflow. Also, a Project allows only one unfinished Workflow at a time; otherwise submit and approve both return 409 `ACTIVE_WORKFLOW_EXISTS`.

## Common questions

- **You sent a message but never get a Plan Proposal**. Check in order:
  1. Is the send mode "Planning" / does the message carry `send_scope.intent=plan` — ordinary collaboration does not enter Plan Mode;
  2. Is a model available — for a real model, confirm `SEMANTIC_LLM_API_KEY_<endpoint name>` is set; without a key use the default `mock`;
  3. The mock model's default response is only placeholder text (`（mock 模型默认响应）`) and does not call `plan_suggest`. Provide a script with the `SEMANTIC_MOCK_SCRIPT` environment variable so mock returns one `plan_suggest` tool call (format: `MockScriptEnv` comment in `internal/agent/kernel/mock.go`; a complete script example is `_mock_script` in `tests/gate/v050_real_gate.py`);
  4. Does leader `skills.allowlist` include `depalletizing-workflow-planning` (the default config already does; see `configs/agents/leader/role.yaml`). Authorization cache needs a Server restart;
  5. Check Server logs for whether the Leader Run started and whether tool calls reported `BAD_ARGUMENTS`.
- **Approve returns 409 `REVISION_CONFLICT`**: the revision changed. Leader submitted a new revision while you were reviewing, or this revision was already approved. `GET .../plan-proposals/active` again for the latest `revision` and approve that. Do not retry an old revision.
- **Approve returns 409 `ACTIVE_WORKFLOW_EXISTS`**: the current Project already has an unfinished Workflow. Stop it in the Workflow panel first, or end it with `POST /api/v1/projects/{id}/workflows/{workflow_id}/stop` (carry the current Workflow revision) before submitting a new plan.
- **Creating a Conversation returns 409 `PROJECT_INACTIVE`**: the Project is not active. Call `POST /api/v1/projects/{id}/activate` and retry (activation semantics: `store/project.go`).
- **Workflow panel is empty**: check that the Studio WebSocket is online (`workflow.approved` is delivered on `/ws/studio`). If needed, refresh the page to reload the Snapshot (`GET /api/v1/projects/{id}/studio/snapshot`).

## Chapter summary

- Plan Proposal is the approval boundary. Workflow is the continuing-run boundary;
- A proposal is submitted by an explicit Plan Mode Leader through `plan.suggest`. Approve uses an exact revision so an old plan cannot run twice;
- Approve creates Workflow, Tasks, and dependencies in a single transaction, then event-driven scheduling advances them;
- A Project allows only one unfinished Workflow at a time. Repeat approve is rejected idempotently;
- A Task expresses a business result. A Robot Task's SubTask enters the next chapter's Robot Skill.

## Next chapter

Continue to [Chapter 5: Robot Skill, Stage, and Action](chapter_05_robot_skill.en.md) and let a Robot SubTask enter physical execution.
