---
title: "第四章：Plan Proposal、Workflow 与 Task"
linkTitle: "第 4 章：Workflow"
weight: 24
description: "在 Studio 中创建 Project、Conversation 和 Plan Proposal，并把批准后的计划转化为 Workflow。"
---

**本章目标**：从第 3 章已经配置好的 Agent 出发，通过 Studio 界面或 REST/WebSocket API 走通执行链的业务入口：用户目标 → Plan Proposal → 批准 → Workflow → Task。完成后，你应能得到一个已批准的 Workflow 和它的 Task DAG。

## Workflow 是什么

Plan Proposal 是 Agent 提出的待审阅计划；Workflow 是用户批准后的持续工作整体；Task 是一个 Agent 负责的业务结果；SubTask 是 Task 内部的局部步骤。

```text
Conversation
└── Plan Proposal
    └── Workflow
        └── Task
            └── SubTask
```

Agent Run 是一次模型执行，而具身任务会跨越用户批准、资源等待、多个 Run 和物理执行。Workflow 持久化计划、依赖、资源、执行引用和结果，使任务可以在 Run 结束后继续推进。Plan Proposal 是审批边界：批准之前数据库中绝不出现可执行 Workflow（`semantic-framework/internal/workflow/proposal.go`、`semantic-framework/internal/store/plan_proposal.go`）。

## 代码位置

- Workflow 应用服务：`semantic-framework/internal/workflow/`（`proposal.go` 是提交与批准入口）；
- Store：`semantic-framework/internal/store/plan_proposal.go`、`semantic-framework/internal/store/workflow.go`；
- HTTP 路由：`semantic-framework/internal/server/http/router.go`；
- Plan 工具：`semantic-framework/internal/tool/builtin/plan_suggest.go`；
- Studio：`semantic-web/src/components/studio/`（`ConversationPlanSummary.vue`、`panels/PlanDocumentPanel.vue`、`panels/WorkflowRunPanel.vue`）。

## 前置条件

- 第 1 章的 Server 已启动并可登录：

  ```bash
  curl -s http://127.0.0.1:8080/api/v1/system/healthz
  ```

  预期输出：

  ```json
  {"status":"ok"}
  ```

- 第 3 章的 Agent Profile、Model 和 Skill 已配置。确认 leader 的 Skill 授权包含内置的拆码垛规划 Skill：

  ```bash
  curl -s http://127.0.0.1:8080/api/v1/agents \
    -H "Authorization: Bearer $TOKEN"
  ```

  预期返回中 `leader` 的 `skill_names` 应包含 `"depalletizing-workflow-planning"`。它是默认配置的内置示例（模板在 `semantic-framework/configs/skills/workflow/depalletizing-workflow-planning/`，默认授权在 `semantic-framework/configs/agents/leader/role.yaml` 的 `skills.allowlist`）。

- 模型可用：第 3 章配置的真实模型，或默认的 `mock` Provider（`semantic-framework/configs/semantic-server.yaml` 的 `llm.default: mock`）。没有真实模型 key 时本章仍可跑通，见[常见问题](#常见问题)。
- Studio 已启动并可登录（方式 A）；或已有登录 Token（方式 B）：

  ```bash
  TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"username":"admin","password":"admin123"}' \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
  ```

  初始密码来自 `SEMANTIC_ADMIN_PASSWORD`，未设置时为 `admin123`（`semantic-framework/internal/server/auth/service.go`）。

## 方式 A：Studio 路径

Studio 是这条链的默认入口，所有写操作最终都走方式 B 列出的同一组端点。

### 1. 创建 Project

1. 登录 Studio；
2. 进入 Projects；
3. 点击新建 Project；
4. 输入名称，例如 `quickstart-depalletizing`；
5. 保存并进入该 Project。

安装环境没有活动 Project 时，第一个创建的 Project 会被自动激活（`activateIfNoneTx`，见 `semantic-framework/internal/store/project.go`）；否则 Studio 会提示先激活。如果 Runtime Installation 已登记，可以在 Project 的 Simulation 页面选择 `native-mujoco`；源码开发模式下可以继续使用第 2 章的独立 Runtime。

### 2. 创建 Conversation 并输入目标

在 Project 中新建一个 Conversation，在输入框把发送模式切换为「规划」（Plan Mode，对应协议字段 `send_scope: {"type":"conversation","intent":"plan"}`，见 `semantic-web/src/components/chat/PromptInput.vue`），然后输入一个明确目标：

```text
请规划一次拆码垛任务：把来源托盘顶层的一个周转箱搬运到目标托盘。
```

发送后 Leader 进入规划 Run。它可能先追问澄清问题；目标、约束和完成条件足够后，它会调用 `plan.suggest` 工具提交完整计划。

### 3. 等待 Plan Proposal 卡片

`plan.suggest` 成功后，Conversation 中会出现计划卡片（组件 `ConversationPlanSummary.vue`）：

```text
PLAN PROPOSAL · REVISION 1
请规划一次拆码垛任务：……
N 个主要 Task · TODO：……
[查看计划]  [批准并执行]
```

卡片显示当前 revision 和主要 Task 数量。revision 是批准的乐观锁，每次 Leader 重新提交计划都会加 1。

<!-- TODO(实跑): 用 mock 默认 Provider 跑通「规划模式 → plan.suggest → 计划卡片出现」的完整界面路径并截图；mock 兜底剧本写法见常见问题。 -->

### 4. 审阅计划详情

点击「查看计划」打开 Plan Document 面板（`panels/PlanDocumentPanel.vue`），检查：

- 目标和范围（`goal`、`approved_scope`）；
- 主要 Task 列表（每个 Task 的角色、能力、资源范围、完成条件）；
- Task 依赖；
- 风险和需要确认的内容。

计划正文是 Markdown（`document_markdown`），只负责展示；执行始终读取结构化计划 `structured_plan`，Framework 不会反向解析 Markdown（`semantic-framework/internal/store/plan_proposal.go` 的 `PlanProposal` 注释）。

需要调整时，回到原 Conversation 直接说明，Leader 会重新调用 `plan.suggest` 生成新的完整 revision。

### 5. 批准并创建 Workflow

在计划卡片或 Plan Document 面板点击「批准并执行」。前端会携带当前 revision 调用批准端点（`semantic-web/src/stores/workflow.js` 的 `approveProposal`）。如果 revision 已被新提交修改，界面会提示「计划已更新，请重新审阅」。

### 6. 查看 Workflow 与 Task

批准成功后自动打开 Workflow Run 面板（`panels/WorkflowRunPanel.vue`），应显示：

- 新 Workflow（状态 `running`）；
- 主要 Task 列表与依赖 DAG；
- Robot Task 的 `required_capabilities`（若计划锁定了 Robot Skill）。

Task 状态含义：

- `pending`：等待依赖或资源；
- `running`：已分配 Agent 或 Robot；
- `paused`：等待用户、Interaction 或资源；
- `stopping`：正在收敛停止；
- `completed`：已形成结果。

（状态机定义见 `semantic-framework/internal/store/workflow.go`。）

## 方式 B：API 路径

以下命令与 `semantic-framework/tests/gate/v050_real_gate.py` 在真实 Server 上执行的调用序列一致。所有端点见 `semantic-framework/internal/server/http/router.go`。假设 `$SEMANTIC` 是多仓工作区根目录。

### 1. 登录

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
```

响应骨架（字段见 `semantic-framework/internal/server/auth/handlers.go` 的 `tokenResponse`）：

```json
{
  "token": "<opaque token>",
  "expires_at": "<RFC3339 时间>"
}
```

### 2. 创建 Project

```bash
PROJECT_ID=$(curl -s -X POST http://127.0.0.1:8080/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"quickstart-depalletizing"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["project"]["id"])')
```

响应为 201，骨架（请求/响应字段见 `handlers/projects.go` 的 `createProjectRequest` 与 `store/project.go` 的 `Project`）：

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

注意 `is_active`：只有活动 Project 可写。当前安装环境没有活动 Project 时，新建 Project 自动激活；否则需要显式激活，否则后续写操作返回 409 `PROJECT_INACTIVE`：

```bash
curl -s -X POST http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/activate \
  -H "Authorization: Bearer $TOKEN"
```

### 3. 创建 Conversation

```bash
CONVERSATION_ID=$(curl -s -X POST http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/conversations \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"quickstart 拆码垛规划"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["conversation"]["id"])')
```

响应为 201，骨架（字段见 `handlers/chat.go` 的 `sessionView`）：

```json
{
  "conversation": {
    "id": "<会话 ID>",
    "project_id": "proj-<uuid>",
    "title": "quickstart 拆码垛规划",
    "revision": 1
  }
}
```

### 4. 通过 WebSocket 发送规划目标

对话消息没有 HTTP 入口，发送与增量订阅走 WebSocket（Server WS 端口 8081，见 `configs/semantic-server.yaml` 的 `server.ws_addr`）。以下脚本用 Python 标准库发送一条 Plan Mode 消息，协议与 gate 测试相同（`tests/gate/v050_real_gate.py` 的 `_send_plan_message`；消息结构见 `internal/server/ws/chat.go` 的 `uplinkMessage`）：

```bash
python3 - "$TOKEN" "$CONVERSATION_ID" <<'EOF'
import base64, json, os, socket, sys, urllib.parse

token, session_id = sys.argv[1], sys.argv[2]
query = urllib.parse.urlencode({"token": token, "session_id": session_id})
message = {
    "type": "chat.message",
    "session_id": session_id,
    "text": "请规划一次拆码垛任务：把来源托盘顶层的一个周转箱搬运到目标托盘。",
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
print("已发送 Plan Mode 消息")
EOF
```

预期输出：

```text
已发送 Plan Mode 消息
```

`send_scope.intent=plan` 是让 Leader 进入显式 Plan Mode 的开关（`internal/server/ws/chat.go` 的 `conversationMode()`）；缺省时按普通协作对话处理，不会产生 Plan Proposal。Studio 前端使用 `/ws/studio?token=...&project_id=...` 发送同一消息类型，二者上行协议一致（`internal/server/ws/studio.go`）。

<!-- TODO(实跑): 用 mock Provider 验证该脚本后补充服务端下行确认帧（gate 测试会等待首个下行帧再断开）。 -->

### 5. 轮询 Plan Proposal

```bash
curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/active \
  -H "Authorization: Bearer $TOKEN"
```

Leader 尚未提交时返回：

```json
{"plan_proposal": null}
```

`plan.suggest` 成功后返回 200，骨架（字段见 `store/plan_proposal.go` 的 `PlanProposal`）：

```json
{
  "plan_proposal": {
    "id": "plan-<uuid>",
    "project_id": "proj-<uuid>",
    "conversation_id": "<会话 ID>",
    "revision": 1,
    "status": "ready",
    "goal": "<目标>",
    "summary": "<计划摘要>",
    "approved_scope": {},
    "structured_plan": {},
    "document_markdown": "<Markdown 计划正文>"
  }
}
```

轮询到 `status` 为 `ready` 后，取出 `id` 和 `revision`：

```bash
read PROPOSAL_ID PROPOSAL_REVISION < <(
  curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/active \
    -H "Authorization: Bearer $TOKEN" \
    | python3 -c 'import sys,json; p=json.load(sys.stdin)["plan_proposal"]; print(p["id"], p["revision"])'
)
```

<!-- TODO(实跑): 记录 mock 模型下从发消息到 ready 的典型耗时区间。 -->

### 6. 批准 Plan Proposal

批准必须携带当前精确 revision（`revision` 与 `expected_revision` 等价，见 `handlers/projects_plan_proposal.go` 的 `planProposalActionRequest`）：

```bash
curl -s -X POST "http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/plan-proposals/$PROPOSAL_ID/approve" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"revision\": $PROPOSAL_REVISION}"
```

响应为 200，骨架（`workflow_view` 结构见 `store/workflow.go` 的 `WorkflowView`）：

```json
{
  "workflow_view": {
    "workflow": {
      "id": "wf-<uuid>",
      "project_id": "proj-<uuid>",
      "conversation_id": "<会话 ID>",
      "goal": "<目标>",
      "status": "running",
      "revision": 1,
      "confirmed_revision": 1
    },
    "tasks": [
      {
        "id": "task-<uuid>",
        "workflow_id": "wf-<uuid>",
        "required_role": "robot",
        "required_capabilities": ["<Robot Skill 名称>"],
        "goal": "<Task 目标>",
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

Task 的实际目标、角色与依赖由模型生成的计划决定，以上只标注字段来源。批准是原子的：响应返回前 Workflow、Task 和依赖已在同一事务中创建（`store/plan_proposal.go` 的 `ApprovePlanProposal`）。

### 7. 查看 Workflow 视图

```bash
curl -s "http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/workflows/<workflow_id>/view" \
  -H "Authorization: Bearer $TOKEN"
```

也可以直接读当前未结束的 Workflow：

```bash
curl -s http://127.0.0.1:8080/api/v1/projects/$PROJECT_ID/workflows/active \
  -H "Authorization: Bearer $TOKEN"
```

两者都返回 `workflow_view`（`handlers/projects_v030.go` 的 `HandleGetWorkflowView` / `HandleGetActiveWorkflow`），随后可以持续观察 Task 从 `pending` 进入 `running`。

## 验证清单

界面（方式 A）：

- [ ] Conversation 中出现 `PLAN PROPOSAL · REVISION n` 卡片；
- [ ] Plan Document 面板能打开，且显示目标、主要 Task、依赖；
- [ ] 点击「批准并执行」后自动打开 Workflow Run 面板；
- [ ] Workflow Run 面板显示状态为 `running` 的 Workflow 和 Task DAG。

API（方式 B）：

- [ ] `GET /api/v1/projects/{id}/plan-proposals/active` 返回 `status: "ready"` 的提案；
- [ ] `POST .../approve` 返回 200 且 `workflow_view.workflow.status` 为 `"running"`；
- [ ] `workflow_view.tasks` 非空，`dependencies` 与计划中声明的一致；
- [ ] `GET /api/v1/projects/{id}/workflows/{workflow_id}/view` 能持续读到同一视图；
- [ ] Conversation 中出现一条 Leader 发布的活动消息：`Plan revision n 已批准，Workflow wf-... 已开始`（由 `internal/workflow/proposal.go` 的 `ApprovePlanProposal` 写入）。

## 运行后发生了什么

按时间顺序（源码位置见「代码位置」）：

1. **Plan Mode 消息进入**：WebSocket 上行 `chat.message` 携带 `send_scope.intent=plan`，Server 启动一个显式 Plan Mode 的 Leader Run。该 Run 的工具被硬白名单收窄为 `system.*`、`artifact.get`、`artifact.list`、`map.query`、`plan.suggest`、`interaction.ask`（`internal/agent/runtime/workflow_runtime.go`），不能执行命令、委派 Agent 或操作 Robot。
2. **plan.suggest 提交**：Leader 调用 `plan.suggest`（模型侧工具名 `plan_suggest`，由 `internal/agent/kernel/tools.go` 的 `SafeToolName` 映射）。工具校验参数后交给 Workflow Service，在事务中创建或修订 Proposal：同一 Conversation 重复提交会让 `revision` 加 1，成功后发布 `plan_proposal.ready` 事件，Studio 计划卡片由此刷新。模型流取消或参数非法时，上一 revision 保持原样。
3. **用户批准**：批准请求携带精确 revision。Service 先比对一次 revision，Store 再在事务内二次校验 `revision` 与 `status='ready'`；任一不匹配返回 `ErrRevisionConflict`，HTTP 层映射为 409 `REVISION_CONFLICT`。
4. **事务创建**：同一事务中依次创建 Workflow（`status='running'`、`revision=1`）、主要 Task 与依赖（`replacePlanTx`）、把 Project 置为 `running` 模式、把 Proposal 置为 `approved`。成功前数据库不会出现半个 Workflow。
5. **事件驱动调度**：事务提交后发布 `workflow.approved` 事件，向 Conversation 写入 Leader 活动消息，然后启动调度器：Task 按依赖与资源等待条件推进，Agent 与 Robot 的分配发生在批准之后，因此批准时不要求预先存在 SubTask 或 robot_id。
6. **重复批准是幂等拒绝**：第一次批准后 Proposal 的 `status` 已是 `approved` 且 `revision` 已递增，用同一 revision 再批准只会得到 409 `REVISION_CONFLICT`，不会创建第二个 Workflow。另外，一个 Project 同时只允许一个未结束 Workflow，否则提交和批准都会返回 409 `ACTIVE_WORKFLOW_EXISTS`。

## 常见问题

- **发了消息但一直没有 Plan Proposal**：按序检查：
  1. 发送模式是否为「规划」/ 消息是否带 `send_scope.intent=plan`——普通协作对话不会进入 Plan Mode；
  2. 模型是否可用——真实模型确认 `SEMANTIC_LLM_API_KEY_<端点名>` 已设置；没有 key 时用默认 `mock`；
  3. mock 模型的默认响应只是占位文本（`（mock 模型默认响应）`），不会调用 `plan_suggest`。需要用 `SEMANTIC_MOCK_SCRIPT` 环境变量提供剧本，让 mock 返回一次 `plan_suggest` 工具调用（格式见 `internal/agent/kernel/mock.go` 的 `MockScriptEnv` 注释；完整剧本示例见 `tests/gate/v050_real_gate.py` 的 `_mock_script`）；
  4. leader 的 `skills.allowlist` 是否包含 `depalletizing-workflow-planning`（默认配置已含，见 `configs/agents/leader/role.yaml`）；授权缓存需重启 Server 生效；
  5. 查看 Server 日志确认 Leader Run 是否启动、工具调用是否报 `BAD_ARGUMENTS`。
- **批准返回 409 `REVISION_CONFLICT`**：revision 已变。Leader 在你审阅期间又提交了新 revision，或该 revision 已被批准过。重新 `GET .../plan-proposals/active` 取最新 `revision` 再批准；不要对旧 revision 重试。
- **批准返回 409 `ACTIVE_WORKFLOW_EXISTS`**：当前 Project 已有未结束 Workflow。先在 Workflow 面板停止它，或用 `POST /api/v1/projects/{id}/workflows/{workflow_id}/stop`（携带当前 Workflow revision）结束后再提交新计划。
- **创建 Conversation 返回 409 `PROJECT_INACTIVE`**：Project 未激活。调用 `POST /api/v1/projects/{id}/activate` 后再试（激活语义见 `store/project.go`）。
- **Workflow 面板为空**：检查 Studio WebSocket 是否在线（`workflow.approved` 事件经 `/ws/studio` 下发），必要时刷新页面重新加载 Snapshot（`GET /api/v1/projects/{id}/studio/snapshot`）。

## 本章小结

- Plan Proposal 是审批边界，Workflow 是持续运行边界；
- 提案由显式 Plan Mode 的 Leader 通过 `plan.suggest` 提交，批准使用精确 revision，防止旧计划重复执行；
- 批准在单个事务中创建 Workflow、Task 和依赖，随后由事件驱动调度推进；
- 同一 Project 同一时刻只允许一个未结束 Workflow；重复批准被幂等拒绝；
- Task 表达业务结果，Robot Task 的 SubTask 将进入下一章的 Robot Skill。

## 下一章

进入[第五章：Robot Skill、Stage 与 Action](/developer/quickstart/chapter_05_robot_skill/)，让一个 Robot SubTask 进入物理执行。
