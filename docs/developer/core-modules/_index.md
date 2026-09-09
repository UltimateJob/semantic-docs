---
title: "核心模块"
linkTitle: "核心模块"
weight: 40
description: "Semantic 的核心抽象：智能能力、任务编排、机器人能力、环境运行、Studio 和开发工具链。"
---

核心模块说明 Semantic 提供了哪些可复用抽象，以及这些抽象如何组合成具身应用。这里讲**框架能力和设计边界**，具体型号、具体制品和现成项目进入[组件集成](/developer/integration/)或[Cookbook](/developer/cookbook/)。

## 核心模块地图

```text
智能能力
  提供知识、模型、工具和 Agent 身份
        ↓
任务编排
  把目标变成 Plan、Workflow、Task 和 SubTask
        ↓
机器人能力
  把 SubTask 变成 Robot Skill、Action 和设备行为
        ↓
环境运行
  提供 Scene、Runtime、Virtual Robot 或真实设备

Studio 与开发工具链横向服务以上所有模块
```

## 模块目录

### 智能能力

Agent 如何理解目标、获得知识并使用外部能力。

- [Agent Skill](/developer/core-modules/intelligent/agent-skill/)：用 `SKILL.md` 提供领域知识和工作方法；
- [Tool 与 MCP 接入](/developer/core-modules/intelligent/tool-and-mcp/)：让 Agent 查询或操作外部系统；
- [Model Provider](/developer/core-modules/intelligent/model-provider/)：配置模型服务和运行参数；
- [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/)：定义角色、权限和协作关系。

### Workflow 与任务编排

已经理解的目标如何变成可持续推进的工作。

- [Workflow 与任务编排](/developer/core-modules/orchestration/)：Plan Proposal、Workflow、Task、SubTask、依赖、资源、暂停、恢复和停止。

### Robot 能力

任务如何变成阶段化动作，并最终落到设备。

- [Robot Skill](/developer/core-modules/robot/robot-skill/)：编排 Stage、checkpoint、Action、Feedback 和 Observation；
- [Ability](/developer/core-modules/robot/ability/)：通过 Manifest 和 Handler 实现原子 Action；
- [Robot SDK 与新型号接入](/developer/core-modules/robot/robot-sdk/)：通过 Backend 和 Protocol 接入设备。

### Environment 与 Runtime

机器人在哪个世界运行，以及仿真与真实设备如何保持同构。

- [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/)：Scene、Layout、Runtime Profile 和 Virtual Robot。

### Studio 与交互

人如何观察状态、处理 Interaction 并介入长时间执行。

- [Studio 面板与交互渲染器](/developer/core-modules/interface/studio-panel/)：Panel、Renderer、Store、Dock 和事件订阅；
- [Studio 前端架构](/developer/reference/internals/semantic-studio/)：前端状态来源、REST、WebSocket 和重连。

### 开发工具链

如何构建、测试、装配和验证 Semantic，而不是运行时执行链的一部分。

- [开发工具链](/developer/core-modules/toolchain/)：quick-start、构建测试、Runtime Pack、Robot Bundle 和 Product Gate；
- [构建与测试](/developer/reference/build/)：各仓库命令和测试范围。

## 怎么选择模块

| 你的目标 | 选择 |
|---|---|
| 教 Agent 领域知识 | Agent Skill |
| 让 Agent 调用外部系统 | Tool / MCP |
| 更换模型或配置 Agent 身份 | Model Provider / Agent Profile |
| 修改计划、依赖或调度 | Workflow 与任务编排 |
| 使用已有动作完成新任务 | Robot Skill |
| 增加一种原子机器人动作 | Ability |
| 接入新机器人型号 | Robot SDK |
| 增加仿真场景或 Runtime | Scene Package / Runtime |
| 增加 Studio 观察或交互能力 | Studio Panel / Renderer |
| 构建和验收整个产品 | 开发工具链 / 集成指南 |

## 共同设计原则

1. **抽象先于实现**：上层依赖公开接口，不依赖具体型号或进程内部实现；
2. **状态可追踪**：长任务必须有明确状态、事件、恢复和停止语义；
3. **边界可测试**：每个模块先做单元和契约测试，再进入跨模块产品验证；
4. **制品可交付**：组件通过 Wheel、Zip、二进制、Runtime Pack 或 Robot Bundle 交付；
5. **仿真先行**：能在仿真或 Fake 环境验证的行为，不直接依赖真机或真实模型。

## 推荐学习顺序

先读[快速开始](/developer/quickstart/)，再按目标进入对应模块。若需要理解整体对象关系，阅读[概述中的核心对象](/developer/overview/concepts/)；若需要修改跨模块行为，阅读[端到端集成](/developer/integration/end-to-end/)。
