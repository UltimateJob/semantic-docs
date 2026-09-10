---
title: "Semantic"
linkTitle: "Semantic"
weight: 30
description: "Semantic 开发者手册：从理解框架，到构建、扩展、集成和发布。"
cascade:
  type: docs
---

# Semantic 开发者手册

Semantic 是面向具身应用的开发框架。开发者可以在同一套系统中构建 Agent、Workflow、Robot Skill、Ability、Robot SDK、仿真环境和 Semantic Studio。

本手册按开发者的工作方式组织，而不是按代码仓库组织。先选择目标，再进入对应模块。

## Semantic 能做什么

```text
Agent 理解目标
→ Workflow 组织工作
→ Robot Skill 编排任务
→ Ability 执行原子动作
→ Robot SDK 连接设备
→ Runtime / Scene 提供运行环境
→ Studio 观察与介入
```

## 从哪里开始

| 我想做什么 | 进入 | 结果 |
|---|---|---|
| 了解 Semantic 是什么 | [概述](overview/_index.md) | 理解框架定位、执行链和仓库边界 |
| 从零运行一个示例 | [快速开始](quickstart/_index.md) | 从工作区逐步构建到产品链验证 |
| 找现成的可运行代码 | [Cookbook](cookbook/_index.md) | 按开发场景查找真实示例 |
| 学习框架核心抽象 | [核心模块](core-modules/_index.md) | 理解 Agent、Workflow、Robot 和 Runtime |
| 接入具体实现 | [组件集成](integration/_index.md) | 连接模型、工具、设备和环境 |
| 升级或发布版本 | [发布记录与迁移](../releases/_index.md) | 查看兼容矩阵和迁移步骤 |
| 解决具体错误 | [FAQ](faq/_index.md) | 按现象定位根因和处理方式 |

## 核心模块

Semantic 的核心模块按照开发者需要解决的问题划分：

1. **Agent 与智能能力**：让 Agent 获得知识、工具、模型和角色；
2. **Workflow 与任务编排**：把计划变成可持续推进的工作；
3. **Robot 能力**：把工作编排成 Skill、Action 和设备行为；
4. **Environment 与 Runtime**：提供 Scene、仿真和真实设备环境；
5. **Studio 与交互**：观察状态、处理 Interaction 和介入执行；
6. **开发工具链**：构建、测试、Bundle、Runtime Pack 和产品 Gate。

## 贡献入口

核心实现、测试、构建和发布规范见[参考](reference/_index.md)。跨仓修改前先阅读[贡献与发布](reference/contributing/_index.md)。

## GitHub / GitLab 阅读说明

仓库内的文档链接统一使用相对的 `.md` 文件路径，保证在 GitHub 和 GitLab 源码页可以直接跳转。Hugo 文档站构建时会通过链接渲染钩子自动转换为部署后的页面 URL。若源码页仍出现 404，请先确认当前分支是否已包含目标文件。
