---
title: "Server、Agent 与 Workflow"
weight: 10
description: "Framework 服务端核心：HTTP/WS 网关、Agent Runtime、Workflow 调度与持久化。"
---

Semantic Server 保存 Project 运行数据，组织 Agent Run，并通过 Workflow 推进持续任务。全部实现位于 `semantic-framework`：

- 入口与装配：`cmd/semantic-server/main.go`、`internal/bootstrap/`
- HTTP 路由：`internal/server/http/router.go`；WebSocket：`internal/server/ws/`
- Agent kernel 与 Run：`internal/agent/kernel/`、`internal/agent/runtime/`
- Workflow：`internal/workflow/`；存储：`internal/store/`

## 本地启动

```bash
cd semantic-framework
cp .env.example .env        # 按需填写 SEMANTIC_ADMIN_PASSWORD 与模型密钥
make doctor                 # build + semantic init + 配置/端口/密钥检查
make run                    # 启动 Server（HTTP :8080 / WS :8081）
make logs                   # tail .output/logs/semantic-server.jsonl
```

- `semantic init` 把编译进二进制的配置模板安装到 `.output/`（已有文件保持不变），运行期永远使用安装副本；
- 存储为 SQLite（纯 Go 驱动，无 CGO，单写者），路径 `.output/data/semantic.db`；
- 首次启动种子用户 `admin`；未设置 `SEMANTIC_ADMIN_PASSWORD` 时默认密码 `admin123` 并 WARN；
- 无模型密钥时仅 mock 端点可用，服务照常启动。

## 服务端口与连接

| 服务 | 默认地址 |
|---|---|
| Semantic Server HTTP | `:8080` |
| Semantic Server WebSocket | `:8081`（独立端口） |

HTTP API 全部在 `/api/v1` 下（Pilot 下载通道 `/pilot/v1/transfers/*` 除外）。WebSocket 端点：

| 端点 | 用途 |
|---|---|
| `/ws/agent-events` | 事件通道（对话消息、Run 活动） |
| `/ws/chat` | 对话上行 |
| `/ws/studio?project_id=...&token=...` | Project 级业务事件 |
| `/ws/devices` | 设备状态 |
| `/ws/pilot` | Pilot 连接（专用 credential） |
| `/ws/simulation-stream` | 仿真流 |

下行消息统一信封（`internal/server/ws/envelope.go`）：

```json
{
  "id": "evt-<毫秒>-<16hex>",
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

上行消息（`type`）：`chat.message / chat.cancel / run.cancel / interaction.reply / interaction.cancel / sync`。断线重连后用 `last_event_id`（Chat）或 `after_sequence`（Studio）补发；错误应答为 `{type:"error", code, message}`。

认证：登录（`POST /api/v1/auth/login`）返回 opaque 随机 token（存 SQLite，非 JWT，TTL 24h）；过期后 `POST /api/v1/auth/refresh` 换新 token（无独立 refresh_token）。

## Agent Run

一次 Agent Run 是一次可追踪、可取消、有终态的模型执行：

```text
run.started → [模型生成 → tool.call → tool.result → 再次生成]… → run.completed / failed / cancelled
```

Run 事件种类（`kernel/run.go`）：`EventTextDelta / EventReasoningDelta / EventToolCall / EventToolResult / EventDone / EventError / EventInterrupted / EventSubAgentDelta / EventSubAgentResult`，经 Runtime 转换为 `message.delta / reasoning.delta / message.done / tool.call / tool.result` 与 Run 状态事件发布。

关键语义：

- **Run 与连接解耦**：Run 使用独立 context，前端断线不影响执行；模型 Run 结束后状态由事件推进；
- 用户下一轮消息、Interaction 回答、Task 执行和 Recovery 各自创建新的 Run；
- **先落库用户消息再启动 Run**；助手消息持久化 turns/usage/reasoning/tools/delegations，REST 可完整恢复历史；
- 会话历史全量重放构建上下文（无跨 Run 记忆；审批断点 checkpoint 除外）；
- 中断-恢复：risk 命中 `interrupt.approval_required` 时 Run 进入 `waiting_input`，逐中断点发起 Interaction，应答落库后 Resume 新流。

## Team 与 Agent 目录

`configs/agents/teams/default.yaml` 装配默认 Team：leader（coordinator）+ query-1（service，请求式 SubAgent）+ developer-1 / map-1 / monitor-1（worker）。Robot Worker 按实际 Robot 动态生成身份（如 `robot:r1_pro_tote_gripper-1`）。

- Agent 状态机（roster）：`starting → idle ⇄ running → stopped`，另有 `offline`（逻辑 Agent 存在但 Pilot 不可达）；
- `GET /api/v1/agents` 返回每个 Agent 的 role/mode/status/model/tool_namespaces/skill_names/max_turns 等；
- service 模式成员装配为 agent-as-tool，**委派工具名使用成员实例 ID（query-1）而非角色名**，与事件归因对齐。

## Proposal 与 Workflow

```text
Leader 在 Plan Mode 调用 plan.suggest（作用域强校验）
→ Plan Proposal 落库并发布 plan_proposal.ready
→ 用户批准精确 revision（REST approve）
→ 事务中原子创建 Workflow / Task / 依赖（全局 ID 重分配）
→ 发布 workflow.approved，调度开始
```

`plan.suggest` 服务端校验：只能由显式 Plan Mode 的 Leader Run 调用；Robot Task 的 `required_capabilities` 必须在批准范围的 `allowed_skills` 内；批准事务会**清空 Leader 输出的 SubTask**——只有 Task Agent 能规划 SubTask。

### 状态机

Workflow / Task / SubTask 共用状态：`pending / running / paused / stopping / completed / failed / stopped`（`internal/store/workflow.go` 转移表）：

```text
Workflow: running → {paused, stopping, completed, failed}
          paused  → {running, stopping}
          stopping → {stopped, paused}
Task/SubTask: pending → {running, paused, stopping, stopped}
          running → {paused, stopping, completed, failed}
          paused  → {running, stopping, failed}
          stopping → {stopped, paused}
```

要点：

- 所有转移带 revision 乐观锁 + `confirmed_revision` 校验；
- `stopping → paused` 专用于物理停止无法确认的 Robot SubTask（保留 execution_ref 和 Robot 锁）；
- `ConfirmWorkflowStop` 是 `execution_state_unknown` 的唯一人工终结入口；
- SubTask 只有两种 kind：`robot_skill` 或 `agent_step`；
- Robot 保留：`assigned_robot_id` 部分唯一索引保证活动 Task 期间独占；Task ready 时才后绑定 Robot。

### 调度

调度器**无轮询**，由事件驱动：

- Workflow 批准 / 恢复 / Task 终态 → `schedule()`：选择依赖完成的 pending Task，校验 Map 绑定，进程内门禁后异步启动；
- Robot 资源边沿事件（`OnRobotAvailabilityChanged`）→ 重评 `waiting_resource` Task；
- Robot 占用走数据库唯一约束，进程内只保留 workspace 写锁。

`robot.run` accepted 只记录 execution_ref（`AttachSubTaskExecution`），**不推进状态——完成必须由 Robot Execution 终态驱动**：

| Robot Execution 终态 | SubTask 收敛 |
|---|---|
| completed | 完成 SubTask，`continueOrFinishTask` |
| failed | 物理已启动 → `execution_state_unknown`（禁止重放）；未启动 → `robot_execution_failed` + Recovery |
| waiting_agent | 启动一次 Robot Agent Decision，回复返回原 Worker |
| interrupted | paused / execution_state_unknown |
| stopped / cancelled | 收敛停止 |

## 暂停与恢复

暂停原因由 Task、Interaction、Agent Run 和 Robot Execution 当前状态形成等待视图。实现新的暂停路径时同时提供：

- 清晰原因（`waiting_reason`）；
- 当前处理者；
- 等待内容；
- 唯一有效的恢复操作；
- Server 重启后的状态恢复（所有状态落 SQLite，Run 断点 checkpoint 随 run_sessions 持久化）。

## 停止

Workflow 停止是幂等收敛操作：阻止新工作 → 取消 Agent Run → 按活动 Robot Execution 的真实状态请求停止并等待 hold 证据。模型或 Worker 的迟到结果在写入 Store 前重新检查 Workflow 与 Task 状态。

## 存储

- SQLite（`modernc.org/sqlite`，无 CGO），`SetMaxOpenConns(1)` 单写者；
- 版本化迁移 v1→v31（`internal/store/migrate.go`），按 version 升序在事务中执行，**禁止修改已发布迁移**；
- 主要域表：users/tokens、trace/metering、chat/run_sessions、artifacts/interactions、events、settings/keys、projects、workflow/plan_proposal、semantic_map、simulation、robot/robot_runtime、pilot_enrollment。

## 常用 REST 接口

完整路由见 `internal/server/http/router.go`，常用域：

| 域 | 接口 |
|---|---|
| 认证 | `POST /auth/login`、`/auth/refresh`、`/auth/logout` |
| Agent | `GET /agents`、`PUT /agents/{id}/models` |
| Skill/Tool | `GET /skills(/{name}/resources/*)`、`GET /tools` |
| Project | `GET/POST /projects`、`POST /projects/{id}/activate`、`GET/PUT /{id}/bindings`、`/{id}/conversations` |
| Conversation | `GET /projects/{id}/conversations/{cid}` 相关消息经 `/chat/sessions/{id}/messages` |
| Plan/Workflow | `GET /{id}/plan-proposals/active`、`POST .../{approve\|discard}`、`POST /{id}/workflows/{wid}/{pause\|resume\|stop}` |
| Run | `GET /runs/{id}`、`POST /runs/{id}/cancel` |
| Robot | `/devices/*`、`/robot-executions/{id}(/stop\|/agent-reply)` |
| 仿真 | `/projects/{id}/simulation/**`（instances/snapshot/viewer-scene/operations/scene-documents） |
| 观测 | `GET /traces`、`GET /metering/summary`、`GET /interactions` |
| 设置 | `GET/PATCH /settings`、`GET/PUT/DELETE /settings/keys/{name}` |

错误统一为 `{"error": {"code", "message", "details"}}`。

## 测试

```bash
# 全部集成测试：真实 bootstrap.Wire + mock 模型 + 真实 HTTP/WS（无外部依赖）
go test ./tests/integration/ -count=1

# 各域单测
go test ./internal/workflow/... ./internal/store/... ./internal/agent/... -count=1
```

测试覆盖：正常完成、Interaction、Recovery、Pilot 离线、Server 重启和重复停止；状态一致性要求 Workflow、Task、SubTask、Robot Execution、Pilot 和 Web 反映同一运行事实。

## 相关层次

- 概念模型：[架构 · 任务规划与 Workflow](/architecture/05-planning-and-workflow/)、[架构 · Agent 与协作](/architecture/04-agent-and-collaboration/)
- 设计契约：[核心模块 · Workflow 与任务编排](/developer/core-modules/orchestration/)、[核心模块 · Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/)
