---
title: "Workflow 与任务编排"
linkTitle: "Workflow 与任务编排"
weight: 20
description: "把 Agent 提出的计划转化为可持续推进、可观察、可恢复、可停止的 Workflow、Task 和 SubTask。"
---

**Workflow 与任务编排**回答一个问题：**已经理解的目标，如何变成可持续、可观察、可恢复的工作**。

它位于 Agent 的语义决策和 Robot 的物理执行之间。Agent 负责形成计划，Workflow 负责保存已批准的工作、管理依赖和资源、启动执行，并根据事件继续推进。

## 核心对象

```text
Conversation
└── Plan Proposal       用户审阅前的计划
    └── Workflow        已批准、可持续推进的工作整体
        ├── Task        一个 Agent 负责的业务结果
        │   └── SubTask 一个局部执行步骤
        └── Task
```

| 对象 | 职责 | 不负责 |
|---|---|---|
| Plan Proposal | 表达目标、范围、Task、关系和约束，等待用户批准 | 直接启动物理动作 |
| Workflow | 保存已批准工作，按事件评估依赖和资源 | 代替 Agent 做语义决策 |
| Task | 表达一个 Agent 的结果责任和业务输入 | 描述 Robot Skill 内部 Stage |
| SubTask | 表达 Task 内部的 Agent 步骤或 Robot 步骤 | 取代具体 Skill / Ability |
| Robot Execution | 记录 Robot Skill 的真实 Stage、Action、Feedback、Observation | 决定整体业务计划 |

## 代码位置

- Workflow 服务：`semantic-framework/internal/workflow/`；
- Store 模型：`semantic-framework/internal/store/workflow.go`；
- Store 迁移：`semantic-framework/internal/store/migrate.go`；
- Agent：`semantic-framework/internal/agent/`；
- Pilot 连接：`semantic-framework/internal/pilot/`；
- HTTP / WS：`semantic-framework/internal/server/http/`、`internal/server/ws/`；
- Studio：`semantic-web/src/stores/workflow.js`、Workflow 面板。

## 一次任务如何运行

```text
用户目标
→ Leader 形成 Plan Proposal
→ 用户批准精确 revision
→ 原子创建 Workflow / Task / 依赖
→ 事件驱动调度
→ Agent Step 或 Robot Execution
→ 结果回写
→ Workflow 重新评估
→ 完成、暂停、恢复或停止
```

调度器不由固定轮询推进，而由以下事件触发重新评估：

- Plan 获批；
- 前置 Task 完成；
- Agent 或 Robot 可用；
- SubTask 完成；
- Interaction 回复；
- Execution 终态；
- 暂停或停止请求。

## 状态机

Workflow、Task、SubTask 共用状态：

```text
pending
running
paused
stopping
completed
failed
stopped
```

状态转移必须使用 revision 乐观锁。Robot 占用使用数据库唯一约束，不能只依赖进程内状态。物理停止无法确认时保留 `execution_state_unknown`，需要人工确认，不能伪报成功或停止。

## Task 与 SubTask

Task 描述业务结果，例如：

```text
把来源托盘顶层的一个周转箱搬运到目标托盘。
```

Task Input 包含：

- 来源对象；
- 目标位置；
- 用户确认的约束；
- 需要的 Robot 能力；
- 前置结果；
- 完成条件。

Robot Task 可形成 SubTask：

```text
来源导航
抓取
携物导航
放置
```

每个 SubTask 只是当前 Task 的内部步骤，不表达 Robot Skill 内部的 Stage。

## 最小操作：在 Studio 中验证 Workflow

1. 启动 Server 和 Studio；
2. 创建 Project；
3. 在 Conversation 中输入明确机器人目标；
4. 在 Plan Document 面板审阅 Plan Proposal；
5. 批准当前 revision；
6. 在 Workflow 面板查看 Task DAG 和状态；
7. 等待 Robot Task 生成 SubTask。

预期 Workflow 进入 `running`，未满足资源或依赖时显示明确等待原因。

## 修改 Workflow 时应该做什么

1. 确认你修改的是 Plan、Workflow、Task、SubTask 还是调度器；
2. 更新 `internal/store/workflow.go` 的状态和迁移；
3. 更新 `internal/workflow/` 的调度和恢复逻辑；
4. 更新 HTTP / WS 事件和 Studio store；
5. 覆盖完成、失败、暂停、停止、Server 重启和重复操作；
6. 使用完整集成测试，而不是只测单个状态。

## 测试

```bash
cd "$SEMANTIC/semantic-framework"

# Workflow 和 Store
go test ./internal/workflow/... ./internal/store/... -count=1

# Agent 与交互
go test ./internal/agent/... -count=1

# 真实集成：mock 模型 + HTTP/WS + Store
go test ./tests/integration/ -count=1

# 产品链
make test-v050-real-gate
```

## 边界

- Workflow 不负责生成新的业务计划，只保存和推进已批准工作；
- Task 不知道 Robot Skill 内部 Stage；
- SubTask 不是 Ability，也不保存设备状态；
- Workflow 停止不能只根据按钮响应显示 `stopped`；
- `execution_state_unknown` 必须通过安全确认路径结束。

## 深入阅读

- [任务规划与 Workflow](/architecture/05-planning-and-workflow/)；
- [Server、Agent 与 Workflow](/developer/reference/internals/server-agent-and-workflow/)；
- [第四章：Plan Proposal、Workflow 与 Task](/developer/quickstart/chapter_04_workflow/)；
- [端到端集成](/developer/integration/end-to-end/)。
