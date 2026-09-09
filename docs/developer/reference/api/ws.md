---
title: "WebSocket 事件"
linkTitle: "WebSocket 事件"
weight: 12
description: "Semantic Server 的 WebSocket 通道参考：/ws/studio、/ws/chat、/ws/agent-events、/ws/devices、/ws/pilot 与 /ws/simulation-stream 的握手、帧协议、事件类型与 sequence 续传语义。"
---

本文是 Semantic Server WebSocket 协议的参考。全部消息类型与事件类型提取自 semantic-framework 源码：网关实现在 `internal/server/ws/`（浏览器通道）与 `internal/robot/gateway.go`（Pilot 通道），事件类型常量与发布点分布在 `internal/agent/runtime/`、`internal/workflow/`、`internal/interaction/`、`internal/robot/` 及 handlers 中。与代码不一致时以代码为准。

HTTP REST 端点见 [HTTP API](/developer/reference/api/http/)；协议总览见[组件接口与事件](/developer/reference/api/protocols/)。

## 通道总览

WebSocket 网关监听 `server.ws_addr`（默认 `:8081`），路由注册在 `internal/bootstrap/wire_access.go`：

| 路径 | 网关 | 订阅粒度 | 用途 |
|---|---|---|---|
| `/ws/studio` | `ws.StudioGateway`（`internal/server/ws/studio.go`） | Project（`project_id` query） | Studio 主通道：上行消息/取消/交互应答，下行 Project 级增量事件 |
| `/ws/chat` | `ws.ChatGateway`（`internal/server/ws/chat.go`） | Conversation（`session_id` query） | 迁移期对话通道：CLI 与旧页面使用 |
| `/ws/agent-events` | `ws.Gateway`（`internal/server/ws/gateway.go`） | Conversation（`session_id` query） | 纯下行事件通道，上行仅支持 `sync` |
| `/ws/devices` | `ws.DeviceGateway`（`internal/server/ws/devices.go`） | 全局设备增量 | 浏览器设备中心：Pilot/Robot/Skill/Ability/Execution 增量 |
| `/ws/pilot` | `robot.PilotGateway`（`internal/robot/gateway.go`） | 单 Pilot 连接 | 设备侧控制通道（Pilot credential 鉴权），见下文独立章节 |
| `/ws/simulation-stream` | `ws.SimulationStreamGateway`（`internal/server/ws/simulation.go`） | 单一仿真流 | 把 Plugin 的 Pose/传感器帧流转发给 Studio（`kind=pose\|sensor`），浏览器不直连 Plugin |

## 握手与连接维护

除 `/ws/pilot` 外，所有通道共用同一套握手约定（源码 `internal/server/ws/gateway.go` 的 `extractToken`）：

- **token 携带**：优先 query 参数 `?token=<token>`；浏览器无法自定义请求头时，用子协议 `Sec-WebSocket-Protocol: bearer.<token>`，服务端握手时原样回选该子协议；
- **订阅声明**：`/ws/studio` 用 `?project_id=`，`/ws/chat` 与 `/ws/agent-events` 用 `?session_id=`（可空，空则只收广播）；鉴权失败返回 `401` 与统一 JSON 错误（`{"error":{"code","message"}}`）；
- **心跳**：服务端每 30s 发送 ping，90s 未收到 pong 判定连接死亡并主动断开（`pingInterval`/`pongTimeout`，`internal/server/ws/gateway.go`）；
- **上行限制**：单条上行消息上限 1 MiB（`readLimit`）；超限连接被关闭；
- **下行背压**：每连接下行缓冲 64 条；`trace` 频道缓冲满时丢弃，其余频道不丢（阻塞等待）。

## 下行信封（Envelope）

所有浏览器通道的下行事件使用统一信封（源码 `internal/server/ws/envelope.go`；协议字段，禁止改名）：

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

| 字段 | 说明 |
|---|---|
| `id` | 事件唯一标识（`evt-` 前缀），时间近似有序，是 `/ws/chat`、`/ws/agent-events` 断连续传的游标 |
| `project_id` / `session_id` | 投递目标；Hub 按二者投递，同为空时全局广播（`internal/server/ws/hub.go`） |
| `resource_type` / `resource_id` / `revision` | 变化资源标识；`revision` 用于客户端忽略旧事件 |
| `sequence` | Project 内连续序号，由 Aggregator 落库时分配，用于发现增量缺口 |
| `channel` | 分发通道（下表） |
| `type` | 事件类型（下文事件表） |
| `importance` | `critical` / `normal` / `low`；由 Aggregator 分级规则表 v1 判定（`internal/server/aggregate/rules.go`）：interaction 一律 critical，alert 按 `payload.level`，trace 一律 low |

`channel` 取值：`dialogue`（主对话）、`alert`（告警）、`trace`（可丢明细）、`artifact`（产物引用）、`interaction`（交互）、`simulation`（仿真状态）。<!-- TODO(实跑): 当前发布代码实际只使用 dialogue / interaction / simulation 三个频道；alert、trace、artifact 为协议保留值，未见发布方，确认是否有计划内用途。 -->

## 上行消息（uplinkMessage）

`/ws/chat` 与 `/ws/studio` 共用同一上行协议结构（源码 `internal/server/ws/chat.go` 的 `uplinkMessage`；`/ws/agent-events` 只接受其中的 `sync`）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `type` | string | 消息类型，见下表 |
| `session_id` | string | 目标 Conversation（`chat.message` 必填） |
| `run_id` | string | Studio 精确取消的目标 Run |
| `after_sequence` | int64 | `sync` 用：Project Snapshot 后的事件位置 |
| `text` | string | 消息文本（`chat.message` 必填，或提供 attachments） |
| `attachments` | []string | 已上传图片的 artifact ID |
| `interrupt_current` | bool | 发送前先中断当前 Run（运行中纠偏） |
| `reasoning_effort` | string | 本轮推理强度覆盖：`inherit/auto/low/medium/high` |
| `reasoning_visibility` | string | 本轮思考展示覆盖：`inherit/auto/show/hide` |
| `send_scope` | object | `{"type":"conversation","intent":"plan"}` 时本轮为 plan 模式，其余按 collaboration |
| `interaction_id` | string | 目标交互（`interaction.reply` 必填） |
| `approved` | bool | 旧 confirm 客户端的兼容字段 |
| `response` | any | v0.3 通用结构化应答内容 |
| `expected_state_revision` | int64 | 应答时所见的状态 revision（防止对过期交互应答） |
| `source_revision` | int64 | 显式来源 revision；缺省时服务端取 `expected_state_revision` |
| `last_event_id` | string | `sync` 用：事件 ID 游标 |

按通道的上行类型：

| type | /ws/chat | /ws/studio | /ws/agent-events | 处理逻辑 |
|---|---|---|---|---|
| `chat.message` | 支持 | 支持（校验 Conversation 归属与 Project 可写） | 拒绝 | 独立 goroutine 执行，读泵保持可读 |
| `chat.cancel` | 支持 | 支持（要求 `run_id`） | 拒绝 | 取消会话/Run |
| `run.cancel` | 拒绝 | 支持（同 `chat.cancel`，按 `run_id`） | 拒绝 | Studio 精确取消 |
| `interaction.reply` | 支持（旧 confirm 协议） | 支持（结构化应答） | 拒绝 | 先落库再唤醒等待中的 Run |
| `interaction.cancel` | 拒绝 | 支持 | 拒绝 | 取消结构化交互 |
| `sync` | 支持 | 支持 | 支持 | 断连续传，见下文 |

## 协议应答与错误码

上行消息的直接应答不是 Envelope，而是独立协议应答（`internal/server/ws/chat.go`）：

- 错误：`{"type": "error", "code": "<错误码>", "message": "<描述>"}`；
- 补发完成：`{"type": "sync.done", "count": <条数>}`（`/ws/studio` 版本多一个 `"last_sequence": <补发后序号>`）。

| 错误码 | 含义 |
|---|---|
| `WS_UNKNOWN_TYPE` | 上行消息类型未知 |
| `WS_BAD_MESSAGE` | 消息格式或参数非法 |
| `CHAT_MESSAGE_FAILED` | 对话消息处理失败（运行时错误） |
| `INTERACTION_REPLY_FAILED` | 交互应答失败（不存在/已终结/非法/未装配） |
| `SYNC_FAILED` | 断连续传补发失败（含缺口） |
| `PROJECT_INACTIVE` | Project 当前不可写，需先激活（仅 /ws/studio） |

## 事件类型清单

事件由各域模块发布到事件总线，经 Aggregator 归一化、分配 sequence、落库后下发（`internal/server/aggregate/aggregator.go`）。以下按 channel 分组，`payload` 键名来自发布点代码。

### dialogue 频道：Run 与消息（internal/agent/runtime/events.go）

| type | payload | 说明 |
|---|---|---|
| `run.started` | `{"run": <RunSession>}` | Run 已启动 |
| `run.waiting_input` | `{"run": ...}` | 等待用户输入/交互应答 |
| `run.running` | `{"run": ...}` | 继续执行 |
| `run.cancelling` | `{"run": ...}` | 取消中 |
| `run.completed` | `{"run": ...}` | 成功结束 |
| `run.failed` | `{"run": ...}` | 失败结束 |
| `run.cancelled` | `{"run": ...}` | 已取消 |
| `message.delta` | 文本增量 | 模型文本增量 |
| `reasoning.delta` | 推理增量 | 模型显式返回的推理内容增量 |
| `message.done` | `{"run_id","trace_id","text","metadata",...}` | 本轮回复完成（成功或失败均以此收尾），metadata 携带 token 用量 |
| `tool.call` | 工具调用参数 | 模型发起工具调用（携带 call_id 与原始参数） |
| `tool.result` | 工具执行结果 | 普通工具执行完成 |
| `subagent.delta` | 文本增量 | SubAgent 委派执行冒泡（agent 归因到成员实例） |
| `subagent.result` | 任务与结果全文 | SubAgent 委派完成 |

### dialogue 频道：Plan Proposal 与 Workflow（internal/workflow/events.go、proposal.go、scheduler.go、service.go、robot_execution.go）

payload 键：Workflow 视图事件为 `{"workflow": <Workflow>, "workflow_view": <WorkflowView>}`；Plan Proposal 事件为 `{"plan_proposal": <PlanProposal>}`。

| type | 说明 |
|---|---|
| `plan_proposal.ready` | 计划提案就绪，等待用户批准 |
| `plan_proposal.approved` | 提案已批准（approve 端点联动） |
| `plan_proposal.discarded` | 提案已丢弃 |
| `workflow.approved` | 批准后创建 Workflow |
| `workflow.paused` / `workflow.resumed` | 暂停/恢复 |
| `workflow.stopping` / `workflow.stopped` | 停止请求/已停止（幂等停止链路） |
| `workflow.stop_confirmed_by_operator` | 操作者现场确认停止 |
| `workflow.robot_decision_retried` | Robot Agent 决策重试 |
| `workflow.completed` / `workflow.failed` | 终态 |
| `workflow.recovered` | 从中断中恢复 |
| `workflow.map_reference_stale` | 引用的语义地图已过期 |
| `task.started` / `task.waiting` / `task.waiting_input` | Task 调度状态 |
| `task.planning_subtasks` / `task.subtasks_planned` | 子任务规划 |
| `task.completed` / `task.failed` | Task 终态 |
| `task.paused` / `task.recovery_revised` / `task.recovery_running` / `task.interaction_failed` | 停靠与恢复过程 |
| `subtask.started` / `subtask.completed` / `subtask.stopped` | SubTask 生命周期 |

### dialogue 频道：Project 资源（internal/server/http/handlers/projects.go、project_bindings.go、chat.go）

| type | payload | 发布时机 |
|---|---|---|
| `project.created` / `project.updated` / `project.archived` | `{"project": <Project>}` | 对应 REST 写操作 |
| `project.activated` / `project.deactivated` | `{"project": ...}` | activate / 归档活动 Project |
| `project.bindings.updated` | `{"project": ..., "bindings": <ProjectBindings>}` | PUT bindings |
| `memory.updated` | `{"memory": <ProjectMemory>}` | PUT memory |
| `conversation.created` / `conversation.archived` | `{"conversation": <sessionView>}` | 创建/归档 Conversation（Project 域与迁移期 /chat 域同形） |

### dialogue 频道：Robot Execution（internal/robot/service.go、internal/bootstrap/wire_robot.go）

Robot Execution 状态变化同时走两条链路：按 Project 发布到 dialogue 频道（订阅该 Project 的 Studio 连接可见），并发布到 `/ws/devices`（见下文设备事件表）。payload 键：`{"execution": <RobotExecution>}`（或事件原始 payload）。

| type | 说明 |
|---|---|
| `robot.execution.queued` | 已排队（`request_key` 幂等命中也由此可查） |
| `robot.execution.stopping` / `robot.execution.stopped` | 停止中/已停止（幂等停止） |
| `robot.execution.failed` / `robot.execution.interrupted` | 失败/被打断（重连对账） |
| `robot.execution.stop_confirmed_by_operator` | 操作者确认停止 |
| `robot.execution.reconciled` | Pilot 重连后对账恢复 |
| `robot.artifact.synced` | Artifact 回传完成 |
| `artifact.summary.announced` / `artifact.summary.failed` | Skill 产物摘要生成成功/失败（`internal/pilot/runtime.go` 上报） |

此外，Pilot 上报的执行过程事件（`stage.*`、`action.*`、`observation.recorded`、`feedback.emitted`、`skill.started`、`skill.log`、`agent.requested`、`agent.resolved`、`stop.outcome` 等）原样进入 Execution 事件流，在 Project 有归属时同样按 Project 发布到 dialogue 频道。

### interaction 频道（internal/interaction/service.go、structured.go）

| type | payload | 说明 |
|---|---|---|
| `interaction.request` | 交互请求负载（`interaction_id`、question/risk/timeout、response_schema 等） | 审批/表单请求；importance 恒为 critical |
| `interaction.resolved` | `{"interaction_id","status","reply","revision"}` | 已应答/过期/取消；唤醒等待中的 Run |

### simulation 频道（internal/server/http/handlers/simulation*.go）

所有仿真事件的 envelope 不带 `session_id`，按 `project_id` 投递。

| type | resource_type | 发布时机 |
|---|---|---|
| `simulation.runtime.ready` | runtime | Project Runtime 就绪（runtime/ensure） |
| `simulation.runtime.recovered` | runtime | 恢复被打断的 Runtime |
| `simulation.runtime.preference_updated` | project | PUT runtime-preference |
| `simulation.project.released` | runtime | 退出 Project 并回收 Runtime |
| `simulation.project_scene.added` | project_scene | 添加场景引用 |
| `simulation.layout_draft.created` | scene_document | 创建布局草稿 |
| `simulation.scene.started` | scene_instance | 从场景/Project 场景启动实例 |
| `simulation.scene.<operation>` | scene_instance | pause/resume/step/reset/stop 操作 |
| `simulation.scene.variant_switched` | scene_instance | 切换变体 |
| `simulation.scene.built` | runtime_bundle | 场景包构建完成 |
| `simulation.map.synced` | semantic_map | 实例地图同步 |
| `simulation.robot.command.accepted` | robot_command | 虚拟 Robot 命令受理 |
| `simulation.robot.command.stopped` | robot_command | 命令停止 |
| `simulation.robot.hold` | robot_command | 急停/保持 |
| `simulation.scene.document.created` / `.updated` / `.published` / `.forked` | scene_document | 场景文档生命周期 |
| `simulation.scene.layout.created` / `.renamed` / `.deleted` | scene_document | 布局生命周期 |
| `simulation.scene.package.imported` | scene_document | 场景包导入（每份文档一条） |

## /ws/devices：设备增量事件

设备中心通道（源码 `internal/server/ws/devices.go`、`internal/robot/devices.go`）。事件结构为独立的 `DeviceEvent`（非 Envelope）：

```json
{
  "id": "device-event-<UTC时间戳>-<sequence>",
  "sequence": 0,
  "resource_type": "robot", "resource_id": "", "resource_revision": 0,
  "type": "", "occurred_at": "<RFC3339>", "payload": {}
}
```

| resource_type | type | payload | 说明 |
|---|---|---|---|
| `robot` | `pilot.online` / `pilot.offline` / `pilot.status` | `{"robot": <设备视图>}` | Pilot 上线/下线/状态更新（`internal/robot/service.go`） |
| `robot` | `skill.<status>`（installed/failed/uninstalled）、`skill.enabled` | `{"robot": ...}` | Pilot 上报 `skill.status` 后联动 |
| `robot` | `robot.idle` / `robot.busy` / `robot.interrupted` | `{"robot": ...}` | 当前 Execution 变化与中断 |
| `robot_execution` | `robot.execution.*`（同上表）、Pilot 上报的执行事件 | `{"execution": <RobotExecution>}` | Execution 状态与过程事件 |
| `robot_runtime_instance` | `robot.runtime.starting/ready/stopping/stopped/failed/degraded/interrupted` | `{"runtime_instance": <RuntimeInstance>, "robot_id": ""}` | 受管 Runtime 生命周期（`internal/robotruntime/orchestrator.go`） |
| `ability_debug` | `ability_debug.<status>`（started/stopping/…） | `{"debug": <调试执行>}` | Ability 调试状态 |
| `artifact_sync` | `artifact_sync.announced` / `artifact_sync.synced` | `{"artifact_sync": <同步映射>}` | Artifact 回传登记/完成 |

设备视图字段（`deviceView`，`internal/robot/devices.go`）：`robot_id`、`display_name`、`model`、`backend`、`environment`（real/simulation）、`status`、`revision`、`pilot`、`ability_framework`、`skill_catalog_revision`、`ability_catalog_revision`、`installed_skills`、`desired_skills`、`abilities`、`sensors`、`configuration`、`runtime_instance`、`current_execution_id`、`progress`。离线时以当前 Gateway 会话为准，缓存能力状态标记为 offline。

## sequence 续传与重连语义

三条浏览器通道的续传游标不同，重连语义以各自网关为准：

### /ws/chat 与 /ws/agent-events：last_event_id 游标

源码：`internal/server/ws/sync.go`（`handleSync`）。重连后（同 `session_id` 重新握手）发送：

```json
{"type": "sync", "last_event_id": "evt-..."}
```

- 服务端按事件 `id` 升序补发该会话中晚于游标的缺失事件（持久化在事件表中）；
- `trace` 频道事件不补发（可丢不补，`internal/store/events.go`）；
- 补发完成后回 `sync.done`（`count` 为补发条数）；`last_event_id` 为空表示只要实时流，直接回 `sync.done`（count=0）；
- **at-least-once 边界**：重连窗口内到达的实时事件可能与补发重叠，客户端必须按事件 `id` 去重（源码注释明确该契约）。

### /ws/studio：after_sequence 游标

源码：`internal/server/ws/studio.go`（`handleProjectSync`）。重连后（同 `project_id` 重新握手）发送：

```json
{"type": "sync", "after_sequence": 0}
```

- 服务端按 Project sequence 补发晚于该序号的增量事件，随后回 `{"type":"sync.done","count":N,"last_sequence":M}`；
- `after_sequence < 0` 回 `WS_BAD_MESSAGE`；游标过旧造成缺口时回 `SYNC_FAILED`（"增量存在缺口，请重新读取 Snapshot"）——客户端应重新读取 `GET /api/v1/projects/{id}/studio/snapshot` 再重新订阅。

### /ws/devices：首条消息必须 sync

源码：`internal/server/ws/devices.go`、`internal/robot/devices.go`（`SubscribeDevices`）。

- 连接建立后 10s 内必须发送 `{"type": "sync", "after_sequence": <DeviceSnapshot 的 event_sequence>}`，否则连接被关闭；
- 游标非法（`after < 0` 或 `after > current`）或存在缺口（`after < current`）时回 `{"type":"error","code":"SYNC_FAILED","message":"..."}`——Server 只缓存实时增量，客户端必须重新读取 `GET /api/v1/devices/snapshot`；
- `after_sequence=0` 表示只要实时增量；
- Robot Execution 的过程事件另有**按 Execution** 的 sequence（`RobotExecutionEvent.Sequence`），经 REST `GET /api/v1/robot-executions/{id}?after_sequence=` 分页续读（单页 500 条，`has_more` + `next_sequence`）。

## Pilot WebSocket（/ws/pilot）

Pilot 与 Server 的单一控制通道。控制事件走本通道，Skill 包与 Artifact 的二进制传输走 HTTP `/pilot/v1/transfers/*`。源码：服务端 `internal/robot/gateway.go`、客户端 `internal/pilot/remote.go`。

### 握手与注册

- 连接：`GET /ws/pilot`，请求头 `Authorization: Bearer <Pilot credential>`（credential 经 Pilot Enrollment 换取，与设备绑定）；
- **首条消息必须 `register`**，否则连接以 PolicyViolation 关闭；`register.pilot.pilot_instance_id` 必须与 credential 绑定的 Pilot ID 一致；
- 注册成功后 Server 立即下发 `reconcile.request` 要求对账；
- 上行消息上限 2 MiB（注册与心跳携带 Ability Manifest，心跳默认 2s 一次）；
- 断线后 Pilot 按 `ReconnectDelay` 自动重连并重新注册（注册消息携带完整 `packages`/`active` Skill 快照）。

### 上行消息（Pilot → Server）

上行统一结构（`pilotUplink`）：`{"type": "...", "pilot": {}, "skills": [], "event_type": "", "sequence": 0, "payload": {}, "executions": [], "command_id": "", "ok": false, "error": "", "result": {}}`。

| type | 字段 | 说明 |
|---|---|---|
| `register` | `pilot`、`skills` | 首条消息：Pilot 身份 + 已安装 Skill 全量快照 |
| `heartbeat` | `payload`（Pilot 快照） | 周期上报状态/Robot 状态/当前 Execution |
| `event` | `event_type`、`sequence`、`payload` | 领域事件，`event_type` 取值见下表 |
| `reconcile` | `executions` | 响应 `reconcile.request`：可恢复 Execution 快照（`execution_id/status/checkpoint/feedback_cursors`） |
| `command.ack` | `command_id`、`ok`、`error`、`result` | Server 下行命令的执行结果 |

`event` 的 `event_type` 取值（来自 `internal/pilot/remote.go`、`internal/pilot/runtime.go` 上报点与 Worker 透传）：

| event_type | payload 要点 | Server 处理 |
|---|---|---|
| `skill.status` | `name/version/enabled/status/error` | 更新 Pilot Skill 目录；联动设备事件 `skill.<status>`；触发 desired 对账 |
| `ability.debug.status` | `debug`（调试执行状态） | 透传为 `ability_debug.<status>` 设备事件 |
| `artifact.announce` | `execution_id/local_artifact_id/media_type/summary/size_bytes` | 登记回传任务，下发 `artifact.upload` |
| `agent.requested` | `execution_id/skill_name/stage/decision_key/decision_revision/reason/context/response_model/response_schema/status` | Execution 置 `waiting_agent`，Studio 收到 Agent 请求（`agent-reply` 端点应答） |
| `agent.resolved` | 决策结果 | Execution 恢复 running |
| `execution.accepted` | `execution_id/status` | Execution 已被 Pilot 受理 |
| `skill.started` / `skill.log` / `skill.stop.finalized` | 阶段与日志 | Execution 过程事件 |
| `execution.terminal` | 终态结果 | Execution 终态收敛 |
| `worker.restarted` | `reason/error` | Worker 进程重启记录 |
| `feedback.emitted` / `observation.recorded` / `action.started` / `action.terminal` / `stop.outcome` | Stage/Action/反馈/观测字段原样透传 | Execution 过程事件（携带 `skill_status`、`occurred_at`） |
| `stage.*`（如 `stage.running`） | Worker `event.report` 原样透传 | 过程事件；`stage.running` 同时写入恢复 checkpoint |

`sequence` 为 Execution 事件序号，Server 用于持久化排序；缺省时由 Server 按 `NextRobotExecutionEventSequence` 补齐。

### 下行消息（Server → Pilot）

下行统一结构（`serverCommand`）：`{"type": "...", "command_id": "...", "payload": {}}`。Pilot 对每条命令回 `command.ack`（`skill.validate_input` 直接在同消息内回 ack 携带 `result`）。

| type | payload | 用途 |
|---|---|---|
| `reconcile.request` | `requested_at` | 要求 Pilot 上报可恢复 Execution（Server 重连/启动后主动发起） |
| `reconcile.result` | `executions` | 对账结果回执（Server 按 Pilot 快照纠正状态） |
| `execution.start` | `execution`（`execution_id/project_id/task_id/subtask_id/robot_id/skill_name/skill_version/input`）、`artifact_downloads` | 启动 Robot Skill（Workflow 调度或人工调试） |
| `execution.stop` | `execution_id`、`reason` | 停止 Execution（幂等停止链路的设备侧环节） |
| `agent.reply` | Agent 决策应答（原样转发给 Skill Worker） | 应答 `agent.requested`（REST `agent-reply` 端点触发） |
| `skill.install` | `name`、`version`、`package_url`（指向 `/pilot/v1/transfers/*`） | 安装 Skill 包 |
| `skill.enable` / `skill.disable` | `name`、`version` | 启用/停用已安装 Skill |
| `skill.uninstall` | `name`、`version` | 卸载 |
| `skill.validate_input` | `name`、`version`、`input` | 启动前输入校验（按 Skill 的 Task Model） |
| `artifact.upload` | `execution_id`、`local_artifact_id`、`upload_url` | 回传 Artifact |
| `ability.debug.start` | 调试执行描述（`ability_instance_id` 等） | 启动 Ability 调试 |
| `ability.debug.stop` | `debug_id`、`reason` | 停止 Ability 调试 |

## /ws/simulation-stream（仿真画面流代理）

源码：`internal/server/ws/simulation.go`。Server 把 Plugin 的 Scene Pose/传感器二进制流转发给 Studio，浏览器不获知 Runtime 地址：

- 连接：`/ws/simulation-stream?project_id=&kind=pose|sensor&instance_id=&robot_id=&sensor_id=`；
- `kind=pose` 转发场景 Pose 流；`kind=sensor` 转发指定传感器帧流；
- 该通道是单向二进制代理（上游 16 MiB 帧上限），无 JSON 事件语义；上游连接失败返回 `502 SIMULATION_STREAM_OFFLINE`。

## 相关参考

- REST 端点与认证：[HTTP API](/developer/reference/api/http/)；
- Studio 前端如何消费这些事件（dispatcher、store、续传）：[Studio 前端架构](/developer/reference/internals/semantic-studio/)；
- Pilot 与 Worker 的进程内边界：[组件接口与事件](/developer/reference/api/protocols/)。
