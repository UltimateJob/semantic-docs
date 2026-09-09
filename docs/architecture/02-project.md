---
title: "02 Project：具身应用工作空间"
weight: 20
mermaid: true
---

Project 是一项具身应用持续开发、协作和运行的工作空间。应用内容、环境、参与者和运行过程在 Project 中建立联系，让用户、Agent 和 Robot 围绕同一个目标持续工作。

Semantic Studio 是使用 Project 的集成工具。用户通过 Studio 了解 Project、维护应用、与 Agent 协作、观察环境和 Robot 行动。

~~~mermaid
flowchart LR
    User["用户"] --> Studio["Semantic Studio"]
    Studio --> Project["Project<br/>具身应用工作空间"]

    Project --> Application["应用"]
    Project --> Environment["环境"]
    Project --> Collaboration["协作"]
    Project --> Work["工作与运行"]
~~~

## Project 围绕具身应用建立共同上下文

具身应用将用户目标落实到真实或仿真环境中的行动。这个过程会持续经历环境理解、任务组织、Robot 执行和结果反馈。

Project 为这些活动提供共同上下文：

- 用户讨论的是当前 Project 中的业务目标；
- Agent 结合当前 Project 的应用知识和环境信息理解任务；
- Workflow 组织当前 Project 需要推进的工作；
- Robot 在当前 Project 关联的环境中执行行动；
- 环境变化和运行结果继续回到当前 Project。

例如，在拆码垛 Project 中，“顶部周转箱”“目标托盘”和“可用 Robot”都来自同一项应用。用户、Agent 和 Robot 围绕这些对象建立目标、执行行动，并继续使用行动后的环境状态。

## Project 中的应用

应用定义了 Project 要解决的问题，以及完成这些问题可以使用的知识和能力。

它可以包括：

- 业务目标和应用逻辑；
- Agent Skill；
- Robot Skill；
- Scene 和 Layout；
- 面向应用的代码、测试和文档。

Agent Skill 帮助 Agent 理解领域知识和工作方法。Robot Skill 表达导航、抓取和放置等具身操作。Scene 和 Layout 为仿真应用描述 Robot 行动所处的环境。

Project 可以维护应用专用内容，也可以选用 Semantic 中已经发布的能力和环境资源。二者共同组成当前应用。

## Project 中的环境

环境是具身应用发生的空间。它可以是仿真 Scene，也可以是真实 Robot 所在的工作现场。

Project 通过环境理解当前世界中的：

- Robot；
- 物体；
- 区域；
- 对象之间的空间关系；
- Robot 行动带来的变化。

Semantic Map 表达环境中的对象、区域和空间关系。Feedback 表达 Robot 行动的连续进展，Observation 提供对当前状态的主动观察，Artifact 保存图像、深度、点云、视频、模型、报告和日志等资源。

这些信息共同支持 Agent 理解目标，也让用户了解 Robot 行动对环境产生的影响。

~~~text
环境对象与空间关系
→ Agent 理解目标
→ Robot 在环境中行动
→ Feedback 与 Observation 返回
→ Project 获得新的环境信息
~~~

## Project 中的参与者

用户、多个 Agent 和 Robot 共同参与一项具身应用。

### 用户

用户提出目标、补充业务信息、审阅计划，并在需要选择或授权时继续参与。用户也可以查看应用内容、环境和运行结果。

### Agent

Leader 与用户协作并组织整体工作。其他专业 Agent 根据自己的角色处理环境、开发、运行监测或 Robot 任务。

Agent 使用 Project 提供的应用知识、环境信息和协作上下文工作。它们通过 Conversation、Task 和运行结果交换与当前目标有关的信息。

### Robot

Robot 将任务落实为环境中的实际行动。Robot Agent 理解当前 Robot Task 并选择合适的 Robot Skill，Robot Skill 通过 Ability 和 Robot SDK 驱动 Robot 完成操作。

Project 将 Robot 的能力和运行结果纳入当前应用，使 Agent 的任务决定始终与实际 Robot 联系在一起。

## Project 中的协作

Conversation 是用户与多个 Agent 协作的主要空间。用户可以在 Conversation 中说明目标、引用环境中的对象、回答 Interaction，并查看 Agent 返回的计划、问题和结果。

一个 Project 可以承载多条 Conversation。每条 Conversation 围绕自己的主题持续发展，同时共享当前 Project 的应用和环境背景。

Agent 之间的协作也发生在 Project 上下文中。Leader 可以将不同工作交给适合的 Agent，Agent 可以使用前置 Task 结果或请求短时咨询。重要问题和结果回到 Conversation，使用户能够理解当前工作如何推进。

## Project 中的工作与运行

用户目标通过 Plan、Workflow 和 Robot 执行逐步落实。

Plan 表达 Agent 对目标和主要工作的理解。Workflow 组织已经确认的工作，让不同 Task 可以根据依赖、资源和运行结果持续推进。

Robot Task 进入执行后，Robot Agent 选择 Robot Skill，Robot 通过执行链完成行动。行动产生的 Feedback、Observation、Artifact 和结果继续进入 Workflow 和 Conversation。

~~~mermaid
flowchart LR
    Conversation["Conversation"] --> Plan["Plan"]
    Plan --> Workflow["Workflow"]
    Workflow --> Task["Task"]
    Task --> Robot["Robot 行动"]
    Robot --> Result["环境变化与运行结果"]
    Result --> Workflow
    Result --> Conversation
~~~

这条过程把用户协作、Agent 判断和 Robot 行动连接在一起。Project 保存它们之间的关系，使每一轮工作都能从已有目标和环境状态继续。

## Project 的持续性

一项具身应用会经历多轮开发、多次运行和持续的环境变化。Project 贯穿整个演进过程：

~~~text
开发应用
→ 准备环境
→ 与 Agent 协作
→ Robot 执行
→ 查看环境与运行结果
→ 继续调整应用
~~~

应用知识可以随开发持续完善，Conversation 可以继续讨论新的目标，Semantic Map 可以表达新的环境状态，运行结果和 Artifact 也可以进入后续工作。

Workflow 完成后，Project 继续承载这项具身应用。用户可以基于当前环境开始新的工作，也可以根据 Robot 运行结果调整 Skill、Scene 或应用逻辑。

## Project 与可复用能力

Semantic 提供可复用的 Agent Skill、Robot Skill、Scene、Model 和 Robot 支持能力。Project 从这些能力中选择适合当前应用的内容，并与应用专用内容一起使用。

例如，拆码垛 Project 可以使用：

- 面向拆码垛规划的 Agent Skill；
- 语义导航、抓取和放置 Robot Skill；
- R1 Pro Robot 能力；
- 拆码垛仿真 Scene；
- 当前应用选择的 Model。

可复用能力使 Project 能够组合已有成果，应用专用内容则表达当前业务的目标、环境和工作方式。

## Semantic Studio 如何使用 Project

Semantic Studio 从多个工作视角呈现同一个 Project。

~~~mermaid
flowchart LR
    Studio["Semantic Studio"]
    Project["Project"]

    Application["应用"]
    Environment["环境"]
    Collaboration["协作"]
    Work["工作"]
    Runtime["运行"]

    Studio --> Application
    Studio --> Environment
    Studio --> Collaboration
    Studio --> Work
    Studio --> Runtime

    Application --> Project
    Environment --> Project
    Collaboration --> Project
    Work --> Project
    Runtime --> Project
~~~

### 应用视角

用户查看和维护应用逻辑、Agent Skill、Robot Skill、Scene、测试和文档。

### 环境视角

用户查看 Scene、Viewer 和 Semantic Map，理解 Robot 行动所处的空间及其中的对象和区域。

### 协作视角

用户通过 Conversation 与 Agent 交流，处理 Interaction，并查看 Agent 返回的计划和结果。

### 工作视角

用户查看 Plan、Workflow 和 Task，理解当前目标如何被组织和推进。

### 运行视角

用户查看 Robot、Robot Execution、Observation 和 Artifact，理解 Robot 正在进行的行动以及环境发生的变化。

这些视角通过 Project 中的对象相互连接。用户可以从 Conversation 查看其中提到的环境对象，从 Task 进入对应 Robot Execution，从 Observation 打开 Artifact，再回到应用内容继续开发。

Studio 的页面结构与具体操作在 Studio 设计和用户指南中进一步展开。

## 一个完整的 Project 使用过程

以拆码垛 Project 为例：

1. Project 汇集拆码垛应用、Agent Skill、Robot Skill 和 Scene。
2. 用户通过 Studio 打开 Project 并查看当前环境。
3. 用户在 Semantic Map 中查看箱体和托盘，在 Conversation 中提出搬运目标。
4. Agent 结合应用知识和环境信息形成 Plan。
5. Workflow 组织任务，Robot 完成导航、抓取、搬运和放置。
6. 环境变化、Observation 和 Artifact 返回 Project。
7. 用户查看结果，并继续调整 Skill、Scene 或应用逻辑。
8. 后续工作从更新后的 Project 和环境状态继续。

Project 在整个过程中保持应用、环境、协作和运行的连续关系。Semantic Studio 为用户提供理解和操作这些内容的统一工具。

## 与后续章节的关系

本章介绍了 Project 作为具身应用工作空间的核心设计。后续章节继续展开：

- **环境、感知与 Semantic Map**：环境信息如何形成和使用；
- **Agent 与协作**：多个 Agent 如何围绕 Conversation 和 Task 工作；
- **任务规划与 Workflow**：Plan 和 Task 如何形成并持续推进；
- **Robot 执行与具身闭环**：Robot Skill、Ability 和 Robot SDK 如何完成行动；
- **Semantic 扩展模型**：开发者如何扩展 Agent、Skill、Robot 和 Scene；
- **仿真、真机与部署**：具身应用如何进入不同运行环境。

## 相关层次

- 设计契约与扩展指引：[核心模块 · Studio 面板与交互渲染器](/developer/core-modules/interface/studio-panel/)
- 服务端/前端实现细节：[内部实现 · Studio 前端架构](/developer/reference/internals/semantic-studio/)
