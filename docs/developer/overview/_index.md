---
title: "概述"
linkTitle: "概述"
weight: 10
description: "Semantic 是什么、解决什么问题、如何工作，以及开发者应该从哪里开始。"
aliases:
  - /developer/overview/
---

**Semantic 是什么？**

Semantic 是面向具身应用的开发框架：让 Agent 理解目标、Workflow 组织工作，并通过 Robot Skill、Ability 和 Robot SDK 驱动仿真或真实机器人完成物理任务。

**Semantic 解决什么问题？**

具身任务同时包含语义决策和物理执行。Semantic 用明确的对象、协议和状态边界把两者连接起来，使开发者可以分别扩展、测试和替换每一部分。

```text
Agent → Workflow → Pilot → Robot Skill → Ability → Robot SDK
      → Runtime / Scene / 真实设备
```

## Semantic 提供什么

- **Agent 能力**：Agent Skill、Tool、MCP、Model Provider、角色与 Team；
- **任务编排**：Plan Proposal、Workflow、Task、SubTask、暂停、恢复和停止；
- **机器人执行**：Robot Skill、Stage、Action、Ability 和 Robot SDK；
- **环境抽象**：Scene Package、Runtime、Virtual Robot 和真实设备；
- **产品工作台**：Semantic Studio、事件流、Execution、Artifact 和 Interaction；
- **开发工具链**：quick-start、Runtime Pack、Robot Bundle 和产品 Gate。

## 开发者阅读路径

| 目标 | 推荐入口 |
|---|---|
| 想从零构建一个可运行系统 | [快速开始](/developer/quickstart/) |
| 想理解抽象和扩展点 | [核心模块](/developer/core-modules/) |
| 想找真实代码和配置 | [Cookbook](/developer/cookbook/) |
| 想接入具体模型、设备或 Runtime | [组件集成](/developer/integration/) |
| 想查命令、协议或内部机制 | [参考](/developer/reference/) |
| 想升级版本或处理迁移 | [发布记录与迁移](/developer/releases/) |
| 遇到具体报错 | [FAQ](/developer/faq/) |

## 继续阅读

- [Semantic 的核心对象与关系](/developer/overview/concepts/)；
- [系统架构与一次任务的生命周期](/developer/overview/architecture/)；
- [仓库、制品与版本边界](/developer/overview/repositories/)；
- [快速开始](/developer/quickstart/)。
