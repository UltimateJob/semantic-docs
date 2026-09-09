---
title: "计划与 Workflow"
weight: 10
---

Plan Proposal 将自然语言目标整理为可审阅的主要 Task 和依赖。用户批准后，系统创建 Workflow 并开始分配 Agent 与 Robot。

## 生成 Plan Proposal

Leader 根据 Conversation、Project 资源和工具查询结果生成计划。计划卡包含：

- 目标和摘要；
- 主要 Task；
- Task 依赖；
- 所需角色、Robot 能力和资源范围；
- 约束与完成条件；
- Proposal revision。

继续讨论时，Leader 可以提交新的 revision。卡片会更新为最新内容，旧 revision 保留在历史中。

## 批准并执行

点击“批准并执行”会以卡片上的精确 revision 创建 Workflow。批准前可以继续讨论或放弃 Proposal。

Workflow 创建后：

1. 依赖已满足的 Task 进入可分配状态。
2. 系统选择兼容且可用的 Agent 和 Robot。
3. 负责 Task 的 Agent 规划 SubTask。
4. SubTask 根据实际结果依次推进。
5. 所有 Task 收敛后，Leader 汇总 Workflow 结果。

多个无依赖 Task 可以并行执行。单个 Task 内的 Robot SubTask 按执行结果逐项推进。

## 观察 Task

Task 卡展示：

- 当前状态和依赖；
- 所需角色与能力；
- 实际 Agent 和 Robot；
- 等待或暂停原因；
- SubTask 完成进度。

点击 Task 后，Inspector 展示输入、完成条件、SubTask、最近 Agent Run、Robot Execution、结果和 Artifact。

## 暂停与恢复

暂停表示当前工作正在等待明确条件。界面会说明：

- 暂停原因；
- 当前处理者；
- 正在等待的输入或运行状态；
- 可执行操作。

典型情况包括用户 Interaction、Recovery 分析、Robot 状态确认、环境变化和人工暂停。每种情况由对应入口恢复：回答问题、等待 Agent 决策、恢复设备连接、重新确认环境或点击继续执行。

## 停止 Workflow

在 Studio 的 **Run & Debug → Workflows** 中可以查看当前和历史 Workflow。点击任意记录会按 Workflow ID 重新打开完整运行视图，因此刷新页面、关闭面板或重启 Server 后仍能继续查看和处理原 Workflow。

运行面板提供“停止 Workflow”。停止操作会：

1. 阻止新的 Task 和 SubTask 启动；
2. 取消相关 Agent Run；
3. 对活动 Robot Execution 请求安全停止；
4. 等待 Robot 返回停止和 hold 状态；
5. 收敛 Task 与 Workflow 状态。

`stopping` 状态显示“重试停止”。重复请求会继续对账同一个停止目标，不会创建新的 Workflow 或 Robot Execution。

Robot 离线、Runtime 消失或执行记录不完整时，Workflow 显示“执行状态未知”。系统会保留 Robot、Task 和原 Execution 引用，禁止自动重放。此时有两种操作：

1. Robot/Pilot 可以恢复时，先恢复连接，再点击“重试停止”，等待正常 hold 证据。
2. 无法恢复连接但现场已经检查时，点击“确认现场安全并终结”，核对弹窗列出的 Robot 和 Execution，填写原因后提交。

人工终结只适用于现场已经确认机器人停止并处于安全保持状态的情况。系统会保存确认人、时间、原因和原错误，然后统一停止 Workflow、Task、SubTask 与关联 Execution，并释放调度占用。正常运行中的 Workflow 不能使用该入口，Task 和 SubTask 也没有独立停止按钮。

`completed`、`failed` 和 `stopped` 等终态 Workflow 只读展示，不再显示停止操作；历史记录不会被删除。
