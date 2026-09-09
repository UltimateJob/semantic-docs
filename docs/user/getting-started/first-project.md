---
title: "第一个 Project"
weight: 20
---

本章使用一个 MuJoCo 拆码垛场景说明完整流程。完成后，你将看到 Conversation、Plan、Workflow、Robot Task 和 Robot Execution 如何连接起来。

> **无需真机**：本章全部步骤在 MuJoCo 仿真环境中完成，不需要真实机器人和真实模型密钥。Semantic 的仿真 Robot 与真实 Robot 走同一条执行链，先在仿真中跑通，再考虑接入真机（见[连接真实 Robot](/user/environments/real-robot/)）。

## 1. 创建或打开 Project

在 Project 列表中创建 Project，填写名称和用途。进入 Project 后，Semantic Studio 会恢复该 Project 的对话、布局和运行状态。

## 2. 启动仿真环境

在 Project 的环境资源中选择：

- Scene：R1 Pro 拆码垛
- Layout：`layout_smoke`
- Runtime Profile：原生 MuJoCo

点击“启动此 Layout”。等待 Scene、Robot Runtime 和 Robot 都进入可用状态。设备面板应显示 `r1_pro_tote_gripper-1` 在线且空闲。

## 3. 描述任务

在 Conversation 输入：

```text
在当前 layout_smoke 场景中，使用可用的 R1 Pro Robot，
把周转箱 tote-large-smoke 搬到堆叠列 pallet-b-slot-r1-c1。

完成后确认箱体已稳定放置、双侧工具为空，Robot 恢复行走姿态。
```

Leader 会结合 Project、环境和可用 Robot 理解目标。信息明确时，它直接生成 Plan Proposal；存在会影响任务结果的选择时，它会通过 Interaction 提问。

## 4. 审阅计划

计划卡显示目标、主要 Task、依赖、Robot Skill 范围和完成条件。点击“查看计划”阅读完整内容，确认后点击“批准并执行”。

批准操作会创建 Workflow。后续执行自动推进，无需再发送“继续”。

## 5. 观察执行

Workflow 面板中应看到一个 Robot Task，Task 内包含：

```text
来源导航
→ 抓取并整理携物姿态
→ 携物导航
→ 放置并恢复行走姿态
```

打开 Robot Execution 可以查看 Stage、Action、Feedback、Observation 和 Artifact。仿真 Viewer 展示 Robot 和箱体的真实运动。

## 6. 查看结果

Workflow 完成后，Leader 在原 Conversation 汇总：

- 箱体最终位置与稳定状态；
- Robot 工具和行走姿态；
- Task 与 Robot Execution 结果；
- 可查看的图片、深度数据或其他 Artifact。

若执行暂停，Task 卡和 Conversation 会显示原因、当前处理者和可执行操作。参阅[计划与 Workflow](/user/workflow/planning-and-execution/)了解恢复和停止方式。
