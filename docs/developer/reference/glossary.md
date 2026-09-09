---
title: "术语表"
linkTitle: "术语表"
weight: 25
description: "Semantic 核心术语的中英对照与一句话定义，定义以架构文档与核心模块文档为准。"
---

本页统一全站术语的中英对照。每条定义只有一句话，语义以[架构文档](/architecture/)与[核心模块](/developer/core-modules/)的完整表述为准；查协议细节时使用"详见"列的入口。

## 协作与工作组织

| 术语 | 英文 | 一句话定义 | 详见 |
|---|---|---|---|
| Project | Project | 一项具身应用的工作空间，把用户、Agent、环境、Robot 和运行过程放在同一个持续上下文中。 | [架构 01](/architecture/01-system-overview/) |
| Conversation | Conversation | 用户与多个 Agent 共同交流的空间，目标、问题和结果在这里交换。 | [架构 04](/architecture/04-agent-and-collaboration/) |
| Agent | Agent | 具有角色（Profile）的协作者，负责理解目标、规划和决策等需要语义理解的工作。 | [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/) |
| Agent Run | Agent Run | Agent 为完成一次理解、规划、决策或总结而启动的模型运行。 | [架构 04](/architecture/04-agent-and-collaboration/) |
| Agent Skill | Agent Skill | 写给 Agent 的领域知识和工作方法，是一个含 `SKILL.md` 的目录，授权后在 Run 中按需读取。 | [Agent Skill](/developer/core-modules/intelligent/agent-skill/) |
| Tool | Tool | Agent 可调用的能力，全名为 `<命名空间>.<动作>`，Agent 在 Run 中通过它执行被允许的操作。 | [Tool 与 MCP](/developer/core-modules/intelligent/tool-and-mcp/) |
| MCP | Model Context Protocol | 以纯配置接入外部工具服务的协议，无需修改 Framework 代码。 | [Tool 与 MCP](/developer/core-modules/intelligent/tool-and-mcp/) |
| Model Provider | Model Provider | 将 Agent Run 连接到具体模型服务的适配层，负责请求格式、流式响应、Tool Call 与用量统计。 | [Model Provider](/developer/core-modules/intelligent/model-provider/) |
| Execution Scope | Execution Scope | Agent Run 的执行上下文，Tool 从中获得 Project、Conversation、Task、Agent 和批准范围。 | [Tool 与 MCP](/developer/core-modules/intelligent/tool-and-mcp/) |
| Plan Proposal | Plan Proposal | Leader 对用户目标和主要工作的结构化理解，供用户审阅，批准后形成 Workflow。 | [架构 05](/architecture/05-planning-and-workflow/) |
| Workflow | Workflow | 经过用户确认、可以持续推进的工作整体，保留目标、Task 关系和进展。 | [架构 05](/architecture/05-planning-and-workflow/) |
| Task | Task | Workflow 中由一个 Agent 负责完成的工作单元，表达明确的结果责任。 | [架构 05](/architecture/05-planning-and-workflow/) |
| SubTask | SubTask | 完成 Task 结果需要推进的局部步骤；Robot SubTask 对应一次具身步骤。 | [架构 05](/architecture/05-planning-and-workflow/) |
| Robot Agent | Robot Agent | 面向具身执行的 Agent 角色，代表一台具体 Robot 参与工作并选择 Robot Skill；不处理运动控制细节。 | [架构 01](/architecture/01-system-overview/) |

## Robot 执行链

| 术语 | 英文 | 一句话定义 | 详见 |
|---|---|---|---|
| Pilot | Pilot | 面向一台 Robot 的执行运行时，维护能力目录、管理 Robot Skill，并启动和跟踪 Robot Execution。 | [架构 06](/architecture/06-robot-execution/) |
| Robot Skill | Robot Skill | 机器人侧的任务编排单元，把一次操作组织为可观察、可停止、可恢复的 Stage 推进。 | [Robot Skill](/developer/core-modules/robot/robot-skill/) |
| Stage | Stage | Robot Skill 内的一个执行阶段，Action、Feedback 和 Observation 在 Stage 中展开。 | [架构 06](/architecture/06-robot-execution/) |
| Action | Action | Robot Skill 对 Ability 能力的一次调用请求，以 `actionType@schemaVersion` 与 Ability Manifest 精确匹配。 | [Ability](/developer/core-modules/robot/ability/) |
| Feedback | Feedback | 执行层在行动过程中主动向上返回的信息，如运动进度、控制偏差和传感器读数。 | [架构 01](/architecture/01-system-overview/) |
| Observation | Observation | Agent 或 Robot Skill 为判断当前情况主动发起的观察，回答"现在实际发生了什么"。 | [架构 01](/architecture/01-system-overview/) |
| Ability | Ability | 执行 Robot Skill 发起的 Action 的原子机器人能力，如路线规划、末端移动、夹爪控制和物体定位。 | [Ability](/developer/core-modules/robot/ability/) |
| AbilityFramework | AbilityFramework | 根据 Action 类型、Schema 版本、Robot 和 Ability 实例选择可运行实例，并管理调用、Feedback、停止和结果的运行时。 | [Ability](/developer/core-modules/robot/ability/) |
| Robot SDK | Robot SDK | 面向一个 Robot 型号提供一致的控制、状态和传感接口，并通过 Backend 连接真实 Robot 或仿真 Runtime。 | [Robot SDK](/developer/core-modules/robot/robot-sdk/) |
| Backend | Backend | Robot SDK 中连接具体设备控制器或仿真 Runtime 的实现，提供执行、反馈和 stop/hold 等安全接口。 | [Robot SDK](/developer/core-modules/robot/robot-sdk/) |
| Provider | Provider | Robot SDK 中可复用的算法层，如正逆运动学。 | [Robot SDK](/developer/core-modules/robot/robot-sdk/) |
| hold | hold | 安全停止后保持 Robot 当前状态的命令与证据；停止流程必须取得 hold 证据才报告 `stopped`。 | [Robot SDK](/developer/core-modules/robot/robot-sdk/) |

## 环境与仿真

| 术语 | 英文 | 一句话定义 | 详见 |
|---|---|---|---|
| Scene | Scene | 描述仿真环境中 Robot、物体、区域、传感器和空间布置的可运行环境；Scene Package 是其资产形态。 | [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/) |
| Layout | Layout | 对同一 Scene 的一次具体环境布置。 | [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/) |
| Semantic Map | Semantic Map | 表达环境中对象、区域及其空间关系的语义层，供 Agent 理解目标和选择对象。 | [架构 01](/architecture/01-system-overview/) |
| Artifact | Artifact | Project 中保存、查看、引用和复用的数据资源或运行产物，如图像、点云、报告和日志。 | [架构 01](/architecture/01-system-overview/) |
| Runtime Profile | Runtime Profile | Project 对仿真运行环境的需求和偏好，使同一应用在不同开发环境中保持一致的运行意图。 | [架构 08](/architecture/08-simulation-real-robot-and-deployment/) |
| Runtime Installation | Runtime Installation | 部署环境中已安装并可启动的具体 Runtime，包含运行 Scene 所需的软件、资源位置和连接能力。 | [架构 08](/architecture/08-simulation-real-robot-and-deployment/) |

## 部署与制品

| 术语 | 英文 | 一句话定义 | 详见 |
|---|---|---|---|
| RobotDeployment | RobotDeployment | 每台设备唯一需要维护的配置，声明 Robot 身份、SDK、AbilityFramework 和 Server 连接。 | [第 7 章：设备加入](/developer/quickstart/chapter_07_device/) |
| Bundle | Robot Bundle | 固定版本的共享只读制品，组装 Pilot、AbilityFramework、Ability、Wheel 和 Python 环境；不包含 Robot ID 或 credential 等设备数据。 | [第 7 章：设备加入](/developer/quickstart/chapter_07_device/) |
| Runtime Pack | Runtime Pack | 固定 Runtime 和离线依赖的发布包，正式 Runtime Installation 由它安装。 | [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/) |

## 使用约定

- 全站写作时，术语首次出现给出英文，后续统一用中文；语义变化必须先更新本页与权威文档，再同步其他页面；
- 术语的完整契约（字段、状态机、版本边界）在"详见"列的页面中，本页不复制。
