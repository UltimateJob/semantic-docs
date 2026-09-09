---
title: "仿真环境"
weight: 10
---

Semantic 将仿真 Scene 作为 Project 可连接的具身环境。Scene 提供空间、对象、传感数据和虚拟 Robot，虚拟 Robot 通过与真机一致的 Pilot、Ability 和 Robot Skill 链路执行任务。

## Scene、Layout 与 Runtime

- **Scene** 描述可运行的环境类型和资源。
- **Layout** 描述一次场景中的对象、Robot 初始状态和空间布置。
- **Runtime Profile** 描述场景需要的 Runtime 能力。
- **Runtime Installation** 是当前 Server 可以连接或启动的实际 Runtime。

启动面板会根据 Profile 列出兼容的 Runtime Installation。只有一个候选时系统直接使用；有多个候选时用户选择并可保存 Project 偏好。

## 启动 Scene

在 Project 环境资源中：

1. 选择 Scene 和 Layout。
2. 确认 Runtime Installation。
3. 点击“启动此 Layout”。
4. 查看 Scene Instance、Runtime 和虚拟 Robot 启动状态。

Scene 首次状态同步完成后，Framework 会启动其虚拟 Robot 实例，包括 Pilot、所需 Ability 和 Robot Skill。Robot 满足运行条件后显示为空闲。

## Viewer 与 Semantic Map

Viewer 展示 Runtime 中的真实仿真状态。Semantic Map 表达环境中的对象、区域和空间关系，供 Agent 理解和查询。

从 Viewer 或 Map 选择实体时，Web 将实体身份提交给 Server。Agent 可以据此规划，Robot Skill 会通过 Ability 在执行时重新观察对象和 Robot 状态。

## Reset、切换和停止

- **Reset**：Robot 先进入 hold，随后场景恢复 Layout 初始状态并更新环境信息。
- **切换 Layout**：安全停止相关 Robot 执行，停止当前 Scene Instance，再启动新 Layout。
- **停止 Scene**：停止活动执行和受管 Robot 实例，然后结束 Scene Instance。

外部共享 Runtime 由其运维方管理；停止 Project Scene 只结束由 Project 创建的场景和受管实例。

## 查看启动问题

启动面板分别显示 Scene Runtime、Robot Runtime、Pilot、Ability 和 Robot Skill 状态。某台虚拟 Robot 启动失败时，Scene 仍可查看，该 Robot 显示为 degraded 并附带错误信息。
