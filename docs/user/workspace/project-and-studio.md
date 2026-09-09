---
title: "Project 与 Semantic Studio"
weight: 10
---

Project 是具身应用的工作空间。Semantic Studio 提供进入 Project、组织资源、与 Agent 协作以及观察运行过程的统一界面。

## Project 中包含什么

一个 Project 通常关联：

- Conversation 和 Agent 协作历史；
- Scene、Layout、Semantic Map 与环境资源；
- Agent Skill 和允许使用的 Robot Skill；
- Plan Proposal、Workflow、Task 与 SubTask；
- Robot Execution、Observation 和 Artifact；
- Project 运行所使用的配置与资源选择。

Project 保存业务目标和使用关系。Robot、Runtime Installation 和 Robot Skill Registry 可以服务多个 Project，Project 在实际运行时选择与当前任务兼容的资源。

## Studio 布局

Studio 围绕当前工作组织界面：

- **活动栏**：切换 Conversation、环境、Robot、技能和其他 Project 工具。
- **左侧区域**：浏览当前类别下的对象和资源。
- **中央 Dock**：打开 Conversation、Plan、Workflow、Scene Viewer、Execution 等主要内容。
- **Inspector**：显示当前选中对象的参数、状态和详细信息。
- **底部调试区**：查看 Run、Trace、Stage 时间线和运行日志。

点击 Task、Robot、Stage 或 Artifact 时，相关内容在当前 Project 内打开。Dock 布局和选中对象会随 Project 恢复。

## Project 资源

Project 资源按用途展示：

- **Agent Skill**：为 Agent 提供领域知识、操作方法和工具说明。
- **Robot Skill**：Robot 可以执行的阶段化能力，以及在各 Robot 上的安装状态。
- **Scene 与 Layout**：可运行环境和 Project 中维护的布局。
- **Runtime Profile**：描述场景所需的 Runtime 能力；启动时由系统匹配实际 Runtime Installation。
- **Artifact**：运行产生的图片、深度数据、文件和其他可查看内容。

资源详情通过 Dock 和 Inspector 展示。用户可以在资源视图中完成选择、调试、版本查看和运行关联。

## 全局与 Project 设备入口

全局设备中心用于管理 Server 下的所有 Pilot 和 Robot。Project 中的设备入口聚焦当前 Project 已连接或可使用的 Robot，并保持用户位于 Studio 中。

两处入口读取同一设备状态。全局入口负责设备管理，Project 入口负责当前任务和执行观察。
