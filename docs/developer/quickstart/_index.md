---
title: "快速开始"
linkTitle: "快速开始"
weight: 20
description: "通过一个连续的开发项目，从最小 Server 逐步构建到 Semantic 产品链。"
---

本系列是 Semantic 开发者的主教程。它不按仓库罗列命令，而是沿着一个真实任务的能力增长过程，逐章构建可运行的 Semantic 系统。

## 这是什么

最终产物是一条可验证的具身应用链路：

```text
工作区与 Server
→ Runtime、Scene 与 Virtual Robot
→ Agent Profile、Model 与 Agent Skill
→ Plan Proposal、Workflow、Task
→ Robot Skill、Stage 与 Action
→ Ability、Robot SDK 与 Pilot
→ Studio 观察与介入
→ 完整产品 Gate
```

每章都建立在前一章已经验证的资源上，并只引入一个新的核心对象。章节中的代码位置、前置条件和完成标准必须明确，不能使用未解释的占位符作为主路径。

## 最短路径：先跑起来

如果只想确认环境可用：

1. 使用 `quick-start/semantic_installer.py` 准备多仓工作区；
2. 启动 `semantic-framework` 和 Semantic Studio；
3. 安装一个已验证的 Runtime Pack 和 Robot Bundle；
4. 在 Studio 创建 Project 并启动一个 Scene。

完整的手动开发路径从[第 1 章](chapter_01_environment.md)开始。

## 学习路线

| 章节 | 主题 | 本章新增能力 | 产物 |
|---|---|---|---|
| [第 1 章](chapter_01_environment.md) | 工作区与最小 Server | 多仓、配置副本、Server | 可运行的 Framework |
| [第 2 章](chapter_02_simulation.md) | Runtime、Scene 与 Virtual Robot | 环境和虚拟设备 | running Scene |
| [第 3 章](chapter_03_agent_skill.md) | Agent Profile、Model 与 Skill | Agent 身份、模型和知识 | 可见的 Agent Skill |
| [第 4 章](chapter_04_workflow.md) | Plan Proposal 与 Workflow | 审批、任务、依赖和资源 | 已批准 Workflow |
| [第 5 章](chapter_05_robot_skill.md) | Robot Skill、Stage 与 Action | 阶段化物理任务 | Skill 执行事件 |
| [第 6 章](chapter_06_ability_sdk.md) | Ability、Handler 与 Robot SDK | 原子动作和设备抽象 | 可调用 Ability |
| [第 7 章](chapter_07_device.md) | Pilot、Deployment 与设备加入 | 设备装配和连接 | online Robot |
| [第 8 章](chapter_08_studio.md) | Studio、事件流与 Execution | 观察、交互和产物 | 可观察执行 |
| [第 9 章](chapter_09_product_gate.md) | 完整产品 Gate | 端到端验收和排障 | 可复现产品链 |

九章构成一条连续的端到端路径：从空工作区起步，逐章叠加能力，最终形成一条可复现、可验收的产品链。每章都建立在前一章的产物之上，建议按顺序执行。

## 本教程的边界

- 教程只负责带你完成一条稳定主路径；
- 完整扩展契约见[核心模块](../core-modules/_index.md)；
- 具体实现和现有示例见[Cookbook](../cookbook/_index.md)；
- 跨组件验证见[组件集成](../integration/_index.md)；
- 构建、测试和发布事实见[参考](../reference/_index.md)。

## 下一步

从[第 1 章：环境准备与工作区](chapter_01_environment.md)开始。
