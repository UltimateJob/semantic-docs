---
title: "第一个 Project"
weight: 20
description: "在仿真中完成从打开 Project、批准计划到观察 Robot 执行结果的第一条完整流程。"
---

本章用默认的 R1 Pro 拆码垛场景走完一条完整产品链路。完成后，你将看到 Conversation、Plan、Workflow、Robot Task 和 Robot Execution 如何连接起来。

> **无需真机**：全部步骤在 MuJoCo 仿真中完成，不需要真实机器人和真实模型密钥。仿真 Robot 与真实 Robot 走同一条执行链；先在仿真中跑通，再考虑接入真机（见[连接真实 Robot](../environments/real-robot.md)）。逐步点击和界面截图见[最佳实践：从 Project 到规划](best-practice.md)。

如尚未安装或登录，先阅读[安装与启动](install-and-start.md)。

## 1. 创建或打开 Project

登录后进入 Project Hub。推荐打开 **Default Project**；若要隔离实验，也可以新建 Project，并在创建时选择已就绪的 MuJoCo Runtime Profile。

![Project Hub](../../../static/images/user/getting-started/01-project-hub.png)

进入 Project 后，Semantic Studio 会恢复该 Project 的对话、布局和运行状态。左侧是项目资源，中央是工作区，右侧是 Conversation 或 Inspector，底部可以展开过程和日志。

![Default Project Studio](../../../static/images/user/getting-started/03-default-project-studio.png)

## 2. 启动仿真环境

先在系统设置中选择并连接模型服务（推荐 DeepSeek），再在 Project 的场景资源中：

- 浏览并添加默认 **R1 Pro 拆码垛** 场景；
- Layout 选择 **布局 001**；
- Runtime 确认为已就绪的 Native MuJoCo。

![添加 R1 Pro 拆码垛场景](../../../static/images/user/getting-started/04-add-r1pro-scene.png)

点击“启动此 Layout”。等待 Scene、Robot Runtime 和 Robot 都进入可用状态。设备面板中的项目 Robot 应在线且空闲。

![仿真场景运行中](../../../static/images/user/getting-started/06-simulation-running.png)

如果提示 Runtime 已被另一个 Project 使用，先到占用它的 Project 停止场景，或直接使用已经占用 Runtime 的 Project。

## 3. 描述任务

在右侧打开对话功能，新建对话，将模式切换为 **规划**，然后发送：

```text
把pallet-a区域顶层4个箱子放在对应的pallet-b区域的指定位置
```

![发送规划请求](../../../static/images/user/getting-started/08-planning-request-sent.png)

Leader 会结合 Project、环境和可用 Robot 理解目标。信息明确时，它直接生成 Plan Proposal；存在会影响任务结果的选择时，它会通过 Interaction 提问。

## 4. 审阅计划

计划卡显示目标、主要 Task、依赖、Robot Skill 范围和完成条件。点击“查看计划”阅读完整内容。批准前检查来源、目标、Robot 和完成条件是否符合预期。

![Plan Proposal 已生成](../../../static/images/user/getting-started/09-plan-proposal-ready.png)

确认后点击“批准并执行”。批准会按卡片上的精确 revision 创建 Workflow。后续执行自动推进，无需再发送“继续”。

## 5. 观察执行

Workflow 面板中应看到 Robot Task。一次典型的拆码垛 Task 会分解为导航、抓取、携物移动和放置等 SubTask；具体分解以当前 Plan 为准。

![Workflow 执行过程](../../../static/images/user/getting-started/wf-execution-inspector.png)

打开 Robot Execution 可以查看 Stage、Action、Feedback、Observation 和 Artifact。中央 Physics Viewer 展示 Robot 和箱体的真实运动；底部“过程”页显示当前运行状态，日志页显示模型、工具和 Execution 事件。

![底部过程面板](../../../static/images/user/getting-started/10-bottom-process-panel.png)

更细的批准、暂停与恢复见[计划与 Workflow](../workflow/planning-and-execution.md)；Stage 与证据见[Robot 执行与观察](../robot/execute-and-observe.md)。

## 6. 查看结果

Workflow 完成后，Leader 在原 Conversation 汇总：

- 箱体最终位置与稳定状态；
- Robot 工具和行走姿态；
- Task 与 Robot Execution 结果；
- 可查看的图片、深度数据或其他 Artifact。

若执行暂停，Task 卡和 Conversation 会显示原因、当前处理者和可执行操作。

下一步可以阅读[Project 与 Semantic Studio](../workspace/project-and-studio.md)，了解每个页面和面板的作用。
