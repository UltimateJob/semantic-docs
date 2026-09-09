---
title: "HTTP API"
linkTitle: "HTTP API"
weight: 11
description: "Semantic Server 的 REST 端点清单：认证、Project、Conversation、Plan Proposal、Workflow、仿真、设备与观测域，全部从路由与处理器源码提取。"
---

本文是 Semantic Server HTTP API 的参考清单。全部端点提取自路由注册源码 `internal/server/http/router.go`（semantic-framework 仓库，下同），请求/响应字段提取自 `internal/server/http/handlers/` 与 `internal/store/` 中的结构体。端点清单与代码不一致时，以代码为准并请反馈。

协议边界与组件分工的概述见[组件接口与事件](/developer/reference/api/protocols/)；WebSocket 事件通道见 [WebSocket 事件](/developer/reference/api/ws/)。

## 网关与端口

- HTTP 网关监听 `server.http_addr`（默认 `:8080`），承载本文全部 REST 端点与 Pilot 传输入口 `/pilot/v1/transfers/*`；
- WebSocket 网关监听 `server.ws_addr`（默认 `:8081`），承载 `/ws/*` 通道（见 WebSocket 事件页）；
- 中间件链：RequestID（注入 trace_id）→ Recovery → Logging → auth 鉴权中间件。
- 源码：`internal/server/http/router.go`（路由装配）、`internal/server/http/middleware.go`（HTTP 中间件）、`pkg/config/config.go`（端口默认值）。

## 认证方式

源码：`internal/server/auth/service.go`、`internal/server/auth/handlers.go`、`internal/server/auth/middleware.go`。

- 认证模型：本地账号 + opaque token（32 字节随机数的十六进制串），token 存储在 SQLite 的 tokens 表中，**不是 JWT**；
- 调用方式：除白名单端点外，全部端点要求请求头 `Authorization: Bearer <token>`；
- token TTL：24 小时（`tokenTTL = 24 * time.Hour`）；过期 token 会被惰性剔除并返回 `AUTH_TOKEN_EXPIRED`；
- 种子账号：首次启动自动创建 `admin` 用户；初始密码取环境变量 `SEMANTIC_ADMIN_PASSWORD`，未设置时为 `admin123` 并 WARN 提示修改；
- 错误码（HTTP 401，与 `error.code` 一致）：`AUTH_INVALID_CREDENTIALS`、`AUTH_TOKEN_INVALID`、`AUTH_TOKEN_EXPIRED`、`AUTH_TOKEN_REQUIRED`；
- Pilot 设备使用与 Pilot 实例绑定的专用 credential（经 Pilot Enrollment 换取），不复用用户 token；credential 仅用于 `/ws/pilot` 与 `/pilot/v1/transfers/*`（见 [WebSocket 事件](/developer/reference/api/ws/)的 Pilot 一节）。

鉴权白名单（精确匹配，源码 `internal/server/auth/middleware.go` 的 `publicPaths`）：

| 路径 | 说明 |
|---|---|
| `/api/v1/auth/login` | 登录 |
| `/api/v1/pilot-enrollments/claim` | Pilot 凭加入码认领 credential |
| `/api/v1/system/healthz` | 健康检查 |
| `/api/v1/system/version` | 版本查询 |

### POST /api/v1/auth/login

登录并签发 token。源码：`internal/server/auth/handlers.go`（`HandleLogin`）。

请求体（`loginRequest`）：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `username` | string | 是 | 用户名；用户不存在与密码错误返回同一错误码 |
| `password` | string | 是 | 密码（服务端只存 bcrypt 哈希） |

响应 200（`tokenResponse`）：

```json
{
  "token": "<opaque token>",
  "expires_at": "<RFC3339 时间>"
}
```

错误：`400 BAD_REQUEST`（缺字段/非 JSON）、`401 AUTH_INVALID_CREDENTIALS`。

### POST /api/v1/auth/refresh

用当前 Bearer token 换发新 token。旧 token 立即作废（同一时刻一个旧 token 只能换一次）。该端点在受保护组内，请求需携带即将过期的 token。源码：`internal/server/auth/handlers.go`（`HandleRefresh`）、`internal/server/auth/service.go`（`Refresh`）。

请求体：无。

响应 200：同 `tokenResponse`（新 `token` 与 `expires_at`）。

### POST /api/v1/auth/logout

注销当前 Bearer token；token 不存在时同样返回成功（登出幂等）。源码：`internal/server/auth/handlers.go`（`HandleLogout`）。

请求体：无。响应 200：`{"ok": true}`。

## 通用约定

- **统一错误格式**：所有非 2xx 响应为 `{"error": {"code": "<机器可读错误码>", "message": "<人类可读描述>"}}`。源码：`internal/server/http/errors.go`（`WriteError`）。
- **revision 乐观锁**：Project、Memory、Plan Proposal、Workflow、Semantic Map 等可变对象带 `revision` 字段。写请求必须携带客户端最近一次读到的 revision（字段名 `revision` 或 `expected_revision`，两者都提供时 `expected_revision` 优先），服务端不匹配时返回 `409 REVISION_CONFLICT`。
- **幂等停止**：停止类操作（Run cancel、Robot Execution stop、Workflow stop/pause）重复请求返回当前进度或终态，不重复执行。Robot Skill 启动另有 `request_key` 幂等键：同一 Project 内 `request_key` 命中既有 Execution 时直接返回该 Execution（源码 `internal/robot/service.go` 的 `Run`）。
- **事件联动**：写操作提交后发布对应 WS 事件（如 `project.updated`、`plan_proposal.approved`），事件由 Aggregator 统一分配 Project 内 sequence 并下发；HTTP 响应成功不代表订阅端已收到事件，订阅端按 sequence 发现缺口时应重新读取快照（Studio Snapshot / Device Snapshot）。
- **归档语义**：Project 与 Conversation 的 DELETE 是归档而非物理删除，消息、Run、Interaction 与 Trace 保留。

## 系统端点

源码：`internal/server/http/router.go`（`healthzHandler`、`versionHandler`、`pingHandler`）。

| Method | Path | 用途 | 备注 |
|---|---|---|---|
| GET | `/api/v1/system/healthz` | 进程存活探活 | 公开；响应 `{"status":"ok"}`；依赖探活在 TODO(B3) 中 |
| GET | `/api/v1/system/version` | 查询版本号 | 公开；响应 `{"version":"..."}`，版本由 `pkg/version` 提供 |
| GET | `/api/v1/system/ping` | 鉴权链路验证 | 受保护；响应 `{"pong":true,"user_id":"..."}`，`user_id` 来自 Bearer token |

## Project 域

源码：`internal/server/http/handlers/projects.go`（CRUD/activate/memory/runs）、`project_bindings.go`（bindings）、`projects_v030_snapshot.go`（Studio Snapshot）、`robots.go`（Project Robot 时间线）。Project 响应体统一使用 `store.Project`（`internal/store/project.go`）。

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| GET | `/api/v1/projects` | 当前用户的 Project 列表 | query：`include_archived` | — |
| POST | `/api/v1/projects` | 创建 Project | `name`、`runtime_profile_id?`、`preferred_runtime_installation_id?` | 事件 `project.created` |
| GET | `/api/v1/projects/{id}` | Project 详情 | — | 归档后 `410 PROJECT_ARCHIVED` |
| PATCH | `/api/v1/projects/{id}` | 改名 | `name`、`revision` | 乐观锁；事件 `project.updated` |
| DELETE | `/api/v1/projects/{id}` | 归档 Project | `revision`（body 或 query） | 归档幂等补齐 Default Project；事件 `project.archived` |
| POST | `/api/v1/projects/{id}/activate` | 激活 Project | — | 同时释放上一活动 Project 的仿真；事件 `project.activated` / `project.deactivated` |
| GET | `/api/v1/projects/{id}/bindings` | 查询 Agent/Skill 绑定 | — | — |
| PUT | `/api/v1/projects/{id}/bindings` | 原子替换绑定 | `agent_ids`、`skill_names` | 运行中的 Project 拒绝（需激活且可写）；事件 `project.bindings.updated` |
| GET | `/api/v1/projects/{id}/memory` | 读取 Project Memory | — | 未创建时 content 为空、revision=0 |
| PUT | `/api/v1/projects/{id}/memory` | 保存 Memory | `content`、`revision` | 上限 1MB；乐观锁；事件 `memory.updated` |
| GET | `/api/v1/projects/{id}/conversations` | Conversation 列表 | query：`include_archived` | 见 Conversation 域 |
| POST | `/api/v1/projects/{id}/conversations` | 创建 Conversation | `title` | 需活动 Project；事件 `conversation.created` |
| DELETE | `/api/v1/projects/{id}/conversations/{conversation_id}` | 归档 Conversation | — | 有未结束 Run/待应答 Interaction 时 `409`；事件 `conversation.archived` |
| GET | `/api/v1/projects/{id}/runs` | Run 列表 | query：`status`、`conversation_id`、分页 | — |
| GET | `/api/v1/projects/{id}/studio/snapshot` | Studio 全量快照 | — | 事件缺口时由此恢复（见 WebSocket 事件页） |
| GET | `/api/v1/projects/{id}/robot-executions` | Project 的 Robot Execution 列表 | — | 上限 200 条 |

### GET/POST /api/v1/projects 请求/响应骨架

请求体（`createProjectRequest`，`internal/server/http/handlers/projects.go`）：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `name` | string | 是 | Project 名称，空白视为缺省 |
| `runtime_profile_id` | string | 否 | 可移植的运行能力偏好（引用 Runtime Profile） |
| `preferred_runtime_installation_id` | string | 否 | 当前 Server 上的 Runtime 安装偏好 |

响应 201：`{"project": <store.Project>}`。`store.Project`（`internal/store/project.go`）：

```json
{
  "id": "", "owner_id": "", "name": "", "workspace_root": "",
  "is_default": false, "mode": "", "is_active": false,
  "runtime_profile_id": "", "preferred_runtime_installation_id": "",
  "archived_at": null, "revision": 0,
  "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

PATCH 请求体（`updateProjectRequest`）：`{"name": "", "revision": 0}`。DELETE 请求体（`archiveProjectRequest`）：`{"revision": 0}`（也可用 query `?revision=`）。两者响应均为 `{"project": <store.Project>}`。

Memory 请求体（`saveMemoryRequest`）：`{"content": "", "revision": 0}`；响应 `{"memory": {"project_id":"","content":"","revision":0,"updated_at":"<RFC3339>"}}`（`store.ProjectMemory`，`internal/store/context.go`）。

常见错误：`409 REVISION_CONFLICT`、`409 PROJECT_INACTIVE`、`410 PROJECT_ARCHIVED`、`409 DEFAULT_PROJECT`（Default Project 不能归档）、`409 PROJECT_HAS_ACTIVE_WORK`（仍有未结束 Run 或待应答 Interaction）。

## Conversation 与 Run 域

源码：`internal/server/http/handlers/projects.go`（Project 侧）、`internal/server/http/handlers/chat.go`（会话视图 `sessionView`、消息视图 `messageView`）。消息发送不在 REST：走 `/ws/studio`（或迁移期 `/ws/chat`）的 `chat.message` 上行。

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| POST | `/api/v1/runs/{id}/cancel` | 取消指定 Run | — | 幂等停止；精确按 Run ID，不误伤新 Run；202 返回取消中状态 |
| GET | `/api/v1/runs/{id}` | Run 详情 | — | — |

### POST /api/v1/projects/{id}/conversations 请求/响应骨架

请求体（`createSessionRequest`，title 可选，默认"新会话"）：`{"title": ""}`。

响应 201：`{"conversation": <sessionView>}`。`sessionView`（`internal/server/http/handlers/chat.go`）：

```json
{
  "id": "", "project_id": "", "title": "", "archived_at": null,
  "revision": 0, "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

### GET /api/v1/runs/{id} 响应骨架

`{"run": <store.RunSession>}`。`store.RunSession`（`internal/store/chat.go`）：

```json
{
  "id": "", "project_id": "", "conversation_id": "", "workflow_id": "", "task_id": "",
  "kind": "", "context_id": "", "agent_id": "", "agent_name": "",
  "provider": "", "endpoint": "", "model": "", "trace_id": "",
  "status": "", "error": "", "revision": 0,
  "started_at": "<RFC3339>", "updated_at": "<RFC3339>", "ended_at": null
}
```

POST `/api/v1/runs/{id}/cancel` 响应 202：`{"run": <store.RunSession>}`（status 已进入取消流程）。错误：`503 RUN_CONTROL_UNAVAILABLE`（取消服务未装配）、`409 RUN_CANCEL_FAILED`。

## Plan Proposal 域

源码：`internal/server/http/handlers/projects_plan_proposal.go`。Plan Proposal 由 Planning Run 产生，用户只能 approve（批准）或 discard（丢弃）；批准前的修订只发生在 Conversation 中。响应体使用 `store.PlanProposal`（`internal/store/plan_proposal.go`）。

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/plan-proposals/active` | 当前未结束的 Proposal | — | 无活动 Proposal 时返回 `{"plan_proposal": null}`，不用 404 区分 |
| GET | `/api/v1/projects/{id}/plan-proposals/{proposal_id}` | Proposal 详情 | — | — |
| POST | `/api/v1/projects/{id}/plan-proposals/{proposal_id}/approve` | 批准计划，创建 Workflow | `revision` / `expected_revision` | 乐观锁；事件 `plan_proposal.approved`、`workflow.approved` |
| POST | `/api/v1/projects/{id}/plan-proposals/{proposal_id}/discard` | 丢弃计划 | `revision` / `expected_revision` | 事件 `plan_proposal.discarded` |

### 请求骨架（approve 与 discard 共用）

请求体（`planProposalActionRequest`，`internal/server/http/handlers/projects_plan_proposal.go`）：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `revision` | int64 | 二选一 | 旧字段名；客户端最近一次读到的 Proposal revision |
| `expected_revision` | int64 | 二选一 | 新字段名；非 0 时优先于 `revision` |

服务端取两者之一作为期望 revision；`<=0` 返回 `422 INVALID_REVISION`。revision 不匹配返回 `409 REVISION_CONFLICT`。

### POST .../approve 响应骨架

响应 200：`{"workflow_view": <store.WorkflowView>}`。`store.WorkflowView`（`internal/store/workflow.go`）：

```json
{
  "workflow": {
    "id": "", "project_id": "", "conversation_id": "", "goal": "",
    "approved_scope": {}, "constraints": {}, "completion_criteria": {}, "map_scope": {},
    "status": "", "reason": "", "revision": 0, "confirmed_revision": 0,
    "created_at": "<RFC3339>", "started_at": null, "updated_at": "<RFC3339>", "ended_at": null
  },
  "tasks": [], "subtasks": [], "dependencies": [], "subtask_dependencies": []
}
```

`tasks`/`subtasks` 为 `store.Task`/`store.SubTask` 数组，`dependencies`/`subtask_dependencies` 为对应依赖数组（字段见 `internal/store/workflow.go`）。

### POST .../discard 响应骨架

响应 200：`{"plan_proposal": <store.PlanProposal>}`：

```json
{
  "id": "", "project_id": "", "conversation_id": "", "revision": 0,
  "status": "", "goal": "", "summary": "",
  "approved_scope": {}, "structured_plan": {}, "document_markdown": "",
  "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

错误：`503 PLAN_SERVICE_UNAVAILABLE`（Plan 服务未装配）、`409 REVISION_CONFLICT`、`422 INVALID_REVISION`、`404 RESOURCE_NOT_FOUND`。

## Workflow 域

源码：`internal/server/http/handlers/projects_v030.go`（`WorkflowApplication` 接口、`workflowRevisionRequest`）。Workflow 创建后只暴露运行控制；旧的直接 PATCH/feedback/confirm 入口已下线。

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/workflows` | Workflow 列表 | query：`include_ended` | — |
| GET | `/api/v1/projects/{id}/workflows/active` | 当前未结束 Workflow | — | 无则返回 `{"workflow_view": null}` |
| GET | `/api/v1/projects/{id}/workflows/{workflow_id}/view` | 计划/Task/依赖完整视图 | — | — |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/pause` | 暂停 | `revision`/`expected_revision` | 事件 `workflow.paused` |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/resume` | 恢复 | 同上 | 事件 `workflow.resumed` |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/stop` | 请求停止 | 同上 | 事件 `workflow.stopping`；幂等停止 |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/retry-decision` | 重试 Robot Agent 决策 | 同上 | 事件 `workflow.robot_decision_retried` |

请求体（`workflowRevisionRequest`）：`{"revision": 0, "expected_revision": 0, "physical_state_confirmed": false, "reason": ""}`。路由 `:action` 取值为 `pause|resume|stop|retry-decision`；运行时亦支持 `confirm-stop`（现场确认停止，要求 `physical_state_confirmed=true` 且 `reason` 非空，否则 `422 PHYSICAL_CONFIRMATION_REQUIRED`），但未在路由白名单中注册，属于内部语义。<!-- TODO(实跑): confirm-stop 未出现在 chi 路由 :action 枚举中，确认运行时实际可达性。 -->

响应 200：`{"workflow_view": <store.WorkflowView>}`（结构同 Plan Proposal approve）。错误：`503 WORKFLOW_SERVICE_UNAVAILABLE`、`409 ACTIVE_WORKFLOW_EXISTS`、`409 PROJECT_INACTIVE`、`422 INVALID_STATE`、`422 INVALID_REVISION`。

## Semantic Map 域

源码：`internal/server/http/handlers/projects_v030_map.go`。

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/maps/{map_id}` | 读取语义地图 | — | — |
| POST | `/api/v1/projects/{id}/maps/{map_id}/query` | 结构化查询 | `generation`、`entity_id`、`entity_ids`、`entity_type`、`type`、`status`、`region_id`、`predicate`、`subject_id`、`object_id` | 只读 |
| POST | `/api/v1/projects/{id}/maps/{map_id}/generations` | 创建新地图 generation | `revision`/`expected_revision`、`reason` | 乐观锁 |
| POST | `/api/v1/projects/{id}/maps/{map_id}/updates` | 提交地图变更 | `generation`、`revision`/`expected_revision`、`source`、`operations[]`（或 `entities`/`remove_entity_ids`/`relations`/`remove_relation_ids`） | generation 已变化返回 `409 MAP_GENERATION_CONFLICT` |

`mapOperation`：`{"op": "", "entity": {}, "entity_id": "", "relation": {}, "relation_id": ""}`。

## Robot Skill 包与设备域

源码：`internal/server/http/handlers/robots.go`；领域逻辑与错误码在 `internal/robot/service.go`。浏览器只访问 Server，不直连 Pilot；Pilot 离线返回 `503 PILOT_OFFLINE`。

### Pilot Enrollment（设备接入）

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| POST | `/api/v1/pilot-enrollments` | 创建加入码 | — | 受保护；响应 `{"enrollment": ...}` |
| POST | `/api/v1/pilot-enrollments/claim` | Pilot 用加入码换取 credential | `join_code`、`pilot_id` | 公开；一次性，重复使用返回 `409 PILOT_ENROLLMENT_INVALID`；响应含 `credential` 与 `websocket_path: "/ws/pilot"` |
| DELETE | `/api/v1/pilot-enrollments/{id}` | 吊销加入码 | — | 204 |

### Robot Skill 包

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| GET | `/api/v1/robot-skills` | 已发布 Skill 包列表 | — | — |
| POST | `/api/v1/robot-skills` | 发布 Skill 包（zip） | body：包归档 | `400 ROBOT_SKILL_INVALID` |
| GET | `/api/v1/robot-skills/{name}/{version}` | 包详情（SKILL.md 与目录） | — | 精确 `name@version` |
| GET | `/api/v1/robot-skills/{name}/{version}/resources/*` | 读取包内文本资源 | — | — |

### 设备中心

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| GET | `/api/v1/devices` | 设备列表 | query：`status`、`model`、`backend` | — |
| GET | `/api/v1/devices/snapshot` | 设备全量快照 | — | 含 `event_sequence`，供 `/ws/devices` 续传 |
| GET | `/api/v1/devices/{robot_id}` | 设备详情 + 最近 Execution + Skill 包 | — | — |
| GET | `/api/v1/devices/{robot_id}/executions` | 设备 Execution 列表 | query：`project_id`、`limit` | — |
| POST | `/api/v1/devices/{robot_id}/stop` | 停止设备当前 Execution | `execution_id`、`reason` | 幂等停止；事件 `robot.execution.stopping` |
| POST | `/api/v1/devices/{robot_id}/skills/{name}/{version}/install` | 安装 Skill 到设备 | — | 写入 desired 状态，Pilot 经 WS 收 `skill.install`；事件 `skill.status` |
| POST | `/api/v1/devices/{robot_id}/skills/{name}/{version}/{action}` | enable/disable/uninstall | `:action` ∈ `enable\|disable\|uninstall` | 事件 `skill.status` |
| DELETE | `/api/v1/devices/{robot_id}/skills/{name}/{version}` | 移除 desired Skill | — | 等价 uninstall |
| POST | `/api/v1/devices/{robot_id}/abilities/debug` | 启动 Ability 调试 | `ability_instance_id`、`task_name`、`input` | Pilot 下行 `ability.debug.start`；事件 `ability_debug.started` |
| POST | `/api/v1/devices/{robot_id}/abilities/debug/{debug_id}/stop` | 停止 Ability 调试 | — | 事件 `ability_debug.stopping` |

### Robot Execution（人工调试与运行控制）

| Method | Path | 用途 | 关键请求字段 | 备注（幂等/事件） |
|---|---|---|---|---|
| POST | `/api/v1/projects/{id}/robots/{robot_id}/skill-executions` | 人工调试启动 Skill | `skill_name`、`skill_version`、`input`、`request_key` | `request_key` 幂等（`409 ROBOT_REQUEST_CONFLICT` 表示同 key 不同请求）；202 返回 queued |
| GET | `/api/v1/robot-executions/{execution_id}` | Execution 详情 + 事件分页 | query：`after_sequence` | 事件按 sequence 升序，单页最多 500 条，`has_more`+`next_sequence` 提示续读 |
| POST | `/api/v1/robot-executions/{execution_id}/stop` | 停止 Execution | `reason` | 幂等停止；事件 `robot.execution.stopping` |
| POST | `/api/v1/robot-executions/{execution_id}/agent-reply` | 应答 Agent 请求 | body：任意 JSON（原样转发给 Worker） | Pilot 下行 `agent.reply`；202 |

Execution 响应体为 `store.RobotExecution`（`internal/store/robot.go`）：`id`、`project_id`、`workflow_id`、`task_id`、`subtask_id`、`run_id`、`robot_id`、`pilot_instance_id`、`skill_name`、`skill_version`、`request_key`、`status`、`stage`、`progress`、`input`、`artifact_refs`、`artifact_sync`、`result`、`error`、`revision`、`created_at`、`updated_at`。

常见错误：`404 ROBOT_NOT_FOUND` / `ROBOT_EXECUTION_NOT_FOUND`、`409 ROBOT_BUSY`（调试锁被占用）、`409 ROBOT_SKILL_UNAVAILABLE`、`409 ROBOT_EXECUTION_NOT_ACTIVE`、`503 PILOT_OFFLINE`。

### 传输入口（内部）

| Method | Path | 用途 | 备注 |
|---|---|---|---|
| GET | `/pilot/v1/transfers/*` | Pilot 流式下载 Skill 包与 Artifact | 内部端点：使用 Pilot credential 鉴权（非用户 token），由 Server 把 URL 下发给 Pilot（`skill.install` 的 `package_url`、`artifact.upload` 的 `upload_url`）。源码：`internal/server/http/router.go`、`internal/server/auth/middleware.go`、`internal/robot/skillpackage.go` |

## 仿真域

源码：`internal/server/http/handlers/simulation.go`、`simulation_resources.go`、`simulation_scene_packages.go`、`simulation_visual_assets.go`；事件发布同文件。仿真服务未装配时整组路由不注册（`simulationH == nil`）。

### 全局 Runtime 安装与场景目录

| Method | Path | 用途 |
|---|---|---|
| GET | `/api/v1/simulation/runtime-installations` | Runtime 安装列表 |
| GET | `/api/v1/simulation/scene-catalog` | 场景目录 |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/probe` | 探测安装可用性 |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/start-test` | 启动测试实例 |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/stop` | 停止测试实例 |
| PUT | `/api/v1/simulation/runtime-installations/{installation_id}/enabled` | 启用/停用安装 |

### Project 仿真生命周期

| Method | Path | 用途 | 备注（事件） |
|---|---|---|---|
| POST | `/api/v1/projects/{id}/simulation/runtime/ensure` | 确保 Project Runtime 就绪 | 事件 `simulation.runtime.ready` |
| POST | `/api/v1/projects/{id}/simulation/runtime/recover-interrupted` | 恢复被打断的 Runtime | 事件 `simulation.runtime.recovered` |
| GET/PUT | `/api/v1/projects/{id}/simulation/runtime-preference` | 查询/设置 Runtime 偏好 | PUT 事件 `simulation.runtime.preference_updated` |
| POST | `/api/v1/projects/{id}/simulation/runtime/release` | 退出 Project 并回收 Runtime | 事件 `simulation.project.released` |

### Project 场景与实例

| Method | Path | 用途 | 备注（事件） |
|---|---|---|---|
| GET/POST | `/api/v1/projects/{id}/simulation/project-scenes` | 场景引用列表/添加 | POST 事件 `simulation.project_scene.added` |
| POST | `.../project-scenes/{project_scene_id}/layout-drafts` | 创建布局草稿 | 事件 `simulation.layout_draft.created` |
| POST | `.../project-scenes/{project_scene_id}/instances` | 从 Project 场景启动实例 | 事件 `simulation.scene.started` |
| POST | `.../instances/{instance_id}/switch-variant` | 切换场景变体 | 事件 `simulation.scene.variant_switched` |
| GET | `.../runtime-profiles` | Runtime Profile 列表 | — |
| GET | `.../snapshot` | 仿真全局快照 | — |
| GET | `.../scenes` | 场景目录 | — |
| POST | `.../scenes/{scene_key}/instances` | 从场景 key 启动实例 | 事件 `simulation.scene.started` |
| GET | `.../instances/{instance_id}` | 实例详情 | — |
| GET | `.../instances/{instance_id}/snapshot` | 实例状态快照 | — |
| GET | `.../instances/{instance_id}/viewer-scene` | Viewer 场景描述 | 另含 `pose_stream_url`（指向 `/ws/simulation-stream`） |
| GET | `.../instances/{instance_id}/viewer-scene/content` | Viewer 场景内容 | — |
| POST | `.../instances/{instance_id}/sync-map` | 同步实例地图 | 事件 `simulation.map.synced` |
| GET | `.../instances/{instance_id}/source-links` | 场景来源链接 | — |
| GET | `.../instances/{instance_id}/evaluation` | 实例评估结果 | — |
| GET | `.../instances/{instance_id}/robots` | 实例内虚拟 Robot 列表 | — |
| POST | `.../instances/{instance_id}/{operation}` | 场景操作 | `:operation` ∈ `pause\|resume\|step\|reset\|stop`；`step` 请求体 `{"steps": 1..1000}`；事件 `simulation.scene.<operation>` |
| GET | `.../instances/{instance_id}/robots/{robot_id}/state` | 虚拟 Robot 状态 | — |
| GET | `.../instances/{instance_id}/robots/{robot_id}/sensors` | 传感器读数 | — |
| POST | `.../robots/{robot_id}/commands` | 下发 Robot 命令 | 事件 `simulation.robot.command.accepted` |
| GET | `.../robots/{robot_id}/commands/{command_id}` | 查询命令状态 | — |
| POST | `.../robots/{robot_id}/commands/{command_id}/stop` | 停止命令 | 事件 `simulation.robot.command.stopped` |
| POST | `.../robots/{robot_id}/hold` | 急停/保持 | 事件 `simulation.robot.hold` |
| GET | `.../scene-assets` | 场景资产列表 | — |
| GET | `.../visual-assets/{visual_id}/{version}.glb` | 下载视觉资产（glb） | — |

### 场景文档（Scene Document）

| Method | Path | 用途 | 备注（事件） |
|---|---|---|---|
| GET/POST | `.../scene-documents` | 文档列表/创建 | POST 事件 `simulation.scene.document.created` |
| GET/PUT | `.../scene-documents/{document_id}` | 读取/更新文档 | PUT 事件 `simulation.scene.document.updated` |
| POST | `.../scene-documents/{document_id}/operations` | 提交文档操作 | 事件 `simulation.scene.document.updated` |
| POST | `.../scene-documents/{document_id}/validate` | 校验文档 | — |
| POST | `.../scene-documents/{document_id}/build` | 构建场景包 | 事件 `simulation.scene.built` |
| POST | `.../scene-documents/{document_id}/publish` | 发布 | 事件 `simulation.scene.document.published` |
| POST | `.../scene-documents/{document_id}/fork` | 复刻 | 事件 `simulation.scene.document.forked` |
| GET/POST | `.../scene-documents/{document_id}/layouts` | 布局列表/新建 | POST 事件 `simulation.scene.layout.created` |
| PATCH | `.../scene-documents/{document_id}/layout` | 重命名布局 | 事件 `simulation.scene.layout.renamed` |
| DELETE | `.../scene-documents/{document_id}/layout` | 删除布局 | 事件 `simulation.scene.layout.deleted` |
| GET | `.../scenes/{scene_id}/package` | 导出场景包 | — |
| POST | `.../scene-packages/import` | 导入场景包 | 事件 `simulation.scene.package.imported`（每份文档一条） |

## Agent 目录、技能库与工具目录

源码：`internal/server/http/handlers/agents.go`、`skills.go`、`tools.go`。

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| GET | `/api/v1/agents` | Team 成员目录（只读 roster） | — | 未配置 Team 时返回空清单 |
| PUT | `/api/v1/agents/{id}/models` | 更新角色的模型策略 | `model`、`reasoning_effort`、`reasoning_visibility` | — |
| GET | `/api/v1/skills` | Agent Skill 清单（SKILL.md frontmatter 摘要） | — | 无技能形态返回 `[]` |
| GET | `/api/v1/skills/{name}` | Skill 详情（含正文与扩展字段） | — | 404 `SKILL_NOT_FOUND` |
| GET | `/api/v1/skills/{name}/resources/*` | 按需读取 Skill 文本资源 | — | 大文件/二进制拒绝（`SKILL_RESOURCE_TOO_LARGE` / `SKILL_RESOURCE_NOT_TEXT`） |
| GET | `/api/v1/tools` | 工具目录（内置 + MCP，含健康状态） | — | 按来源分组 |

## 观测域（只读）

源码：`internal/server/http/handlers/traces.go`、`metering.go`、`interactions.go`。

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| GET | `/api/v1/traces` | 链路追踪列表 | 分页参数 | `traceView`：`trace_id`、`name`、`kind`、`started_at`、`duration_ms`、`span_count` |
| GET | `/api/v1/traces/{trace_id}/spans` | Span 明细 | — | `spanView`：`id`、`parent_id`、`name`、`kind`、`started_at`、`duration_ms`、`attrs` |
| GET | `/api/v1/metering/summary` | 模型调用计量汇总 | 分页参数 | `meteringSummaryView`：`model`、`agent`、`purpose`、`calls`、`prompt_tokens`、`completion_tokens`、`total_tokens` |
| GET | `/api/v1/metering/traces/{id}` | 单条 Trace 的计量明细 | — | — |
| GET | `/api/v1/interactions` | 交互记录列表 | query：`status`（`pending` 供审批卡恢复）、分页 | `interactionView`：`id`、`project_id`、`session_id`、`revision`、`agent`、`type`、`status`、`payload`、`reply` 等 |

## 对话域（迁移期 /chat）

源码：`internal/server/http/handlers/chat.go`。保留给旧 CLI 与迁移期页面；新集成方请使用 Project 域 + `/ws/studio`。

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| POST | `/api/v1/chat/attachments` | 上传对话图片 | multipart 字段 `file` | ≤20MB，仅 JPEG/PNG/GIF/WebP；内容入 artifact store，消息只存引用 |
| GET | `/api/v1/chat/attachments/{id}` | 取回图片本体 | — | 返回二进制（本人附件） |
| POST | `/api/v1/chat/artifacts/register` | 登记工作区文件为 Artifact | `project_id`、`path`、`media_type?`、`summary?` | ≤100MB；path 必须在工作区内 |
| GET | `/api/v1/chat/artifacts` | Artifact 列表 | — | — |
| GET | `/api/v1/chat/artifacts/{id}` | Artifact 元数据 | — | 复用附件处理器 |
| DELETE | `/api/v1/chat/artifacts/{id}` | 删除 Artifact | — | — |
| POST | `/api/v1/chat/sessions` | 创建会话 | `title?`、`project_id?`（缺省用当前活动 Project） | 事件 `conversation.created` |
| GET | `/api/v1/chat/sessions` | 本人会话列表 | — | 按最近活跃倒序 |
| GET | `/api/v1/chat/sessions/{id}/agents` | 会话内各 Agent 模型快照 | — | — |
| GET | `/api/v1/chat/sessions/{id}/agents/{agent_id}/tools` | 会话 Agent 的有效工具集 | — | 按 Profile/Project/权限计算 |
| PUT | `/api/v1/chat/sessions/{id}/agents/{agent_id}/model` | 会话级模型覆盖 | `endpoint_id`、`reasoning_effort?` | 活动 Run 时 `409 SESSION_BUSY` |
| GET | `/api/v1/chat/sessions/{id}/messages` | 消息分页查询 | query：`page`、`page_size`（默认 50，上限 200） | — |
| GET/PUT | `/api/v1/chat/sessions/{id}/host-execution` | 查询/设置会话执行策略 | PUT：`mode`、`enabled` | 活动 Run 时 `409 SESSION_BUSY` |
| DELETE | `/api/v1/chat/sessions/{id}` | 归档会话 | — | 运行中 `409`；事件 `conversation.archived`；204 |

## 设置域

源码：`internal/server/http/handlers/settings.go`。

| Method | Path | 用途 | 关键请求字段 | 备注 |
|---|---|---|---|---|
| GET | `/api/v1/settings` | 生效配置快照 | — | 敏感值掩码 |
| PATCH | `/api/v1/settings` | 修改配置 | `base_hash`、`patch` | `base_hash` 乐观锁 + merge patch + 白名单热应用；冲突返回 `409` |
| GET | `/api/v1/settings/keys` | 托管密钥列表 | — | 值掩码 |
| PUT | `/api/v1/settings/keys/{name}` | 写入密钥 | `key_value` | 审计只记键名，不记值 |
| DELETE | `/api/v1/settings/keys/{name}` | 删除密钥 | — | — |

## 端点覆盖说明

本文总表覆盖 `internal/server/http/router.go` 注册的全部 140 条路由（含 1 条内部传输入口 `/pilot/v1/transfers/*`；`/api/v1/simulation/*` 与 Project 仿真子路由在仿真服务未装配时不注册）。设备域的 `{action}` 为单一注册路由（枚举 `enable|disable|uninstall`），Plan Proposal 的 `{action}` 枚举 `approve|discard`，Workflow 的 `{action}` 枚举 `pause|resume|stop|retry-decision`，场景操作 `{operation}` 枚举 `pause|resume|step|reset|stop`。

## 相关参考

- WebSocket 事件通道与 sequence 续传：[WebSocket 事件](/developer/reference/api/ws/)；
- 协议总览与版本边界：[接口与配置](/developer/reference/api/)、[组件接口与事件](/developer/reference/api/protocols/)。
