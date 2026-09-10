---
title: "Glossary"
linkTitle: "Glossary"
weight: 25
description: "Chinese–English counterparts and one-sentence definitions for Semantic core terms. Definitions follow the architecture docs and core-module docs."
---

This page unifies Chinese–English counterparts for site-wide terms. Each definition is one sentence. Meaning follows the full wording in the [Architecture](../../architecture/_index.en.md) docs and [Core Modules](../core-modules/_index.en.md). Use the "See also" column when you need protocol details.

## Collaboration and work organization

| Term | English | One-sentence definition | See also |
|---|---|---|---|
| Project | Project | A workspace for one embodied application that keeps users, Agents, the environment, Robots, and the run process in the same lasting context. | [Architecture 01](../../architecture/01-system-overview.en.md) |
| Conversation | Conversation | The space where a user and multiple Agents communicate, exchanging goals, questions, and results. | [Architecture 04](../../architecture/04-agent-and-collaboration.en.md) |
| Agent | Agent | A collaborator with a role (Profile) that handles work requiring semantic understanding, such as understanding goals, planning, and deciding. | [Agent roles and Team](../core-modules/intelligent/agent-profile.en.md) |
| Agent Run | Agent Run | A model run an Agent starts to finish one act of understanding, planning, deciding, or summarizing. | [Architecture 04](../../architecture/04-agent-and-collaboration.en.md) |
| Agent Skill | Agent Skill | Domain knowledge and working methods written for an Agent: a directory that contains `SKILL.md` and is read on demand during a Run after authorization. | [Agent Skill](../core-modules/intelligent/agent-skill.en.md) |
| Tool | Tool | A capability an Agent can call, with the full name `<namespace>.<action>`. The Agent uses it during a Run to perform allowed operations. | [Tools and MCP](../core-modules/intelligent/tool-and-mcp.en.md) |
| MCP | Model Context Protocol | A protocol for connecting external tool services by configuration only, without changing Framework code. | [Tools and MCP](../core-modules/intelligent/tool-and-mcp.en.md) |
| Model Provider | Model Provider | The adapter that connects an Agent Run to a concrete model service. It handles request format, streaming responses, Tool Call, and usage accounting. | [Model Provider](../core-modules/intelligent/model-provider.en.md) |
| Execution Scope | Execution Scope | The execution context of an Agent Run. Tools obtain Project, Conversation, Task, Agent, and approval scope from it. | [Tools and MCP](../core-modules/intelligent/tool-and-mcp.en.md) |
| Plan Proposal | Plan Proposal | The Leader's structured understanding of the user goal and main work, for user review. Approval forms a Workflow. | [Architecture 05](../../architecture/05-planning-and-workflow.en.md) |
| Workflow | Workflow | The user-confirmed body of work that can keep progressing. It keeps the goal, Task relationships, and progress. | [Architecture 05](../../architecture/05-planning-and-workflow.en.md) |
| Task | Task | A work unit in a Workflow that one Agent is responsible for completing. It expresses a clear result responsibility. | [Architecture 05](../../architecture/05-planning-and-workflow.en.md) |
| SubTask | SubTask | A local step needed to complete a Task result. A Robot SubTask corresponds to one embodied step. | [Architecture 05](../../architecture/05-planning-and-workflow.en.md) |
| Robot Agent | Robot Agent | An Agent role for embodied execution. It represents one concrete Robot in the work and chooses a Robot Skill. It does not handle motion-control details. | [Architecture 01](../../architecture/01-system-overview.en.md) |

## Robot execution chain

| Term | English | One-sentence definition | See also |
|---|---|---|---|
| Pilot | Pilot | The execution runtime for one Robot. It maintains the capability catalog, manages Robot Skills, and starts and tracks Robot Execution. | [Architecture 06](../../architecture/06-robot-execution.en.md) |
| Robot Skill | Robot Skill | The task-orchestration unit on the robot side. It organizes one operation as observable, stoppable, recoverable Stage progress. | [Robot Skill](../core-modules/robot/robot-skill.en.md) |
| Stage | Stage | One execution phase inside a Robot Skill. Action, Feedback, and Observation unfold inside a Stage. | [Architecture 06](../../architecture/06-robot-execution.en.md) |
| Action | Action | One call a Robot Skill makes to an Ability, matched exactly to an Ability Manifest as `actionType@schemaVersion`. | [Ability](../core-modules/robot/ability.en.md) |
| Feedback | Feedback | Information the execution layer actively returns while acting, such as motion progress, control error, and sensor readings. | [Architecture 01](../../architecture/01-system-overview.en.md) |
| Observation | Observation | An observation an Agent or Robot Skill actively starts to judge the current situation and answer "what is actually happening now". | [Architecture 01](../../architecture/01-system-overview.en.md) |
| Ability | Ability | An atomic robot capability that executes an Action started by a Robot Skill, such as path planning, end-effector motion, gripper control, and object localization. | [Ability](../core-modules/robot/ability.en.md) |
| AbilityFramework | AbilityFramework | The runtime that selects a runnable instance from Action type, Schema version, Robot, and Ability instance, and manages the call, Feedback, stop, and result. | [Ability](../core-modules/robot/ability.en.md) |
| Robot SDK | Robot SDK | Consistent control, state, and sensing interfaces for one Robot model. It connects a physical Robot or simulation Runtime through a Backend. | [Robot SDK](../core-modules/robot/robot-sdk.en.md) |
| Backend | Backend | The Robot SDK implementation that connects a concrete device controller or simulation Runtime and provides execution, feedback, and safety interfaces such as stop/hold. | [Robot SDK](../core-modules/robot/robot-sdk.en.md) |
| Provider | Provider | A reusable algorithm layer in the Robot SDK, such as forward and inverse kinematics. | [Robot SDK](../core-modules/robot/robot-sdk.en.md) |
| hold | hold | The command and evidence that keep the Robot in its current state after a safe stop. The stop flow must obtain hold evidence before reporting `stopped`. | [Robot SDK](../core-modules/robot/robot-sdk.en.md) |

## Environment and simulation

| Term | English | One-sentence definition | See also |
|---|---|---|---|
| Scene | Scene | A runnable environment that describes the Robot, objects, regions, sensors, and spatial layout in simulation. A Scene Package is its asset form. | [Scene Package and simulation Runtime](../core-modules/environment/scene-and-runtime.en.md) |
| Layout | Layout | One concrete environment arrangement of the same Scene. | [Scene Package and simulation Runtime](../core-modules/environment/scene-and-runtime.en.md) |
| Semantic Map | Semantic Map | A semantic layer that expresses objects, regions, and their spatial relations in the environment so an Agent can understand goals and choose objects. | [Architecture 01](../../architecture/01-system-overview.en.md) |
| Artifact | Artifact | A data resource or run product stored, viewed, referenced, and reused in a Project, such as images, point clouds, reports, and logs. | [Architecture 01](../../architecture/01-system-overview.en.md) |
| Runtime Profile | Runtime Profile | A Project's requirements and preferences for the simulation runtime, so the same application keeps a consistent run intent across development environments. | [Architecture 08](../../architecture/08-simulation-real-robot-and-deployment.en.md) |
| Runtime Installation | Runtime Installation | A concrete Runtime already installed and startable in a deployment environment, including the software, resource locations, and connection capability needed to run a Scene. | [Architecture 08](../../architecture/08-simulation-real-robot-and-deployment.en.md) |

## Deployment and artifacts

| Term | English | One-sentence definition | See also |
|---|---|---|---|
| RobotDeployment | RobotDeployment | The one configuration each device must maintain. It declares Robot identity, SDK, AbilityFramework, and the Server connection. | [Chapter 7: Device join](../quickstart/chapter_07_device.en.md) |
| Bundle | Robot Bundle | A version-pinned shared read-only artifact that assembles Pilot, AbilityFramework, Ability, Wheel, and a Python environment. It does not contain device data such as Robot ID or credentials. | [Chapter 7: Device join](../quickstart/chapter_07_device.en.md) |
| Runtime Pack | Runtime Pack | A release package that pins a Runtime and offline dependencies. A formal Runtime Installation is installed from it. | [Scene Package and simulation Runtime](../core-modules/environment/scene-and-runtime.en.md) |

## Usage conventions

- When writing site-wide docs, give the English term at first mention and then use the English term consistently. A meaning change must update this page and the authoritative docs first, then other pages;
- The full contract of a term (fields, state machine, version boundaries) lives on the page in the "See also" column. This page does not copy it.
