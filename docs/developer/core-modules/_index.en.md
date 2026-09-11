---
title: "Core Modules"
linkTitle: "Core Modules"
weight: 40
description: "Semantic's core abstractions: intelligence, task orchestration, robot capabilities, environment runtime, Studio, and the developer toolchain."
---

Core modules explain which reusable abstractions Semantic provides and how those abstractions combine into embodied applications. This section covers **framework capabilities and design boundaries**. Specific robot models, artifacts, and ready-made projects belong in [Component Integration](../integration/_index.en.md) or the [Cookbook](../cookbook/_index.en.md).

## Core module map

```text
Intelligence
  Provides knowledge, models, tools, and Agent identity
        ↓
Task orchestration
  Turns a goal into a Plan, Workflow, Task, and SubTask
        ↓
Robot capabilities
  Turns a SubTask into a Robot Skill, Action, and device behavior
        ↓
Environment runtime
  Provides a Scene, Runtime, Virtual Robot, or physical device

Studio and the developer toolchain serve all of the modules above
```

## Module catalog

### Intelligence

How an Agent understands a goal, obtains knowledge, and uses external capabilities.

- [Agent Skill](intelligent/agent-skill.en.md): provide domain knowledge and working methods with `SKILL.md`;
- [Tools and MCP](intelligent/tool-and-mcp.en.md): let an Agent query or operate external systems;
- [Model Provider](intelligent/model-provider.en.md): configure model services and runtime parameters;
- [Agent roles and Team](intelligent/agent-profile.en.md): define roles, permissions, and collaboration.

### Workflow and task orchestration

How an understood goal becomes work that can keep progressing.

- [Workflow and task orchestration](orchestration/_index.en.md): Plan Proposal, Workflow, Task, SubTask, dependencies, resources, pause, resume, and stop.

### Robot capabilities

How a task becomes staged actions and finally reaches a device.

- [Robot Skill](robot/robot-skill.en.md): orchestrate Stage, checkpoint, Action, Feedback, and Observation;
- [Ability](robot/ability.en.md): implement atomic Actions with a Manifest and Handler;
- [Robot SDK and new models](robot/robot-sdk.en.md): connect devices through a Backend and Protocol.

### Environment and Runtime

Which world the robot runs in, and how simulation and physical devices stay isomorphic.

- [Scene Package and simulation Runtime](environment/scene-and-runtime.en.md): Scene, Layout, Runtime Profile, and Virtual Robot.

### Studio and interaction

How people observe state, handle Interactions, and intervene in long-running execution.

- [Studio panels and interaction renderers](interface/studio-panel.en.md): Panel, Renderer, Store, Dock, and event subscription;
- [Studio frontend architecture](../reference/internals/semantic-studio.en.md): frontend state sources, REST, WebSocket, and reconnection.

### Developer toolchain

How to build, test, assemble, and verify Semantic. This is not part of the runtime execution chain.

- [Developer toolchain](toolchain/_index.en.md): quick-start, build and test, Runtime Pack, Robot Bundle, and Product Gate;
- [Build and test](../reference/build/_index.en.md): commands and test scope for each repository.

## How to choose a module

| Your goal | Choose |
|---|---|
| Teach an Agent domain knowledge | Agent Skill |
| Let an Agent call an external system | Tool / MCP |
| Change the model or configure Agent identity | Model Provider / Agent Profile |
| Change plans, dependencies, or scheduling | Workflow and task orchestration |
| Complete a new task with existing actions | Robot Skill |
| Add an atomic robot action | Ability |
| Connect a new robot model | Robot SDK |
| Add a simulation Scene or Runtime | Scene Package / Runtime |
| Add Studio observation or interaction | Studio Panel / Renderer |
| Build and accept the whole product | Developer toolchain / integration guides |

## Shared design principles

1. **Abstraction before implementation**: upper layers depend on public interfaces, not on a specific model or in-process internals;
2. **State must be traceable**: long-running work must have explicit state, events, resume, and stop semantics;
3. **Boundaries must be testable**: unit-test and contract-test each module before cross-module product verification;
4. **Artifacts must be deliverable**: components ship as Wheels, Zips, binaries, Runtime Packs, or Robot Bundles;
5. **Simulation first**: behavior that can be verified in simulation or a Fake environment must not depend on a physical robot or a real model.

## Recommended reading order

Start with the [Quick Start](../quickstart/_index.en.md), then open the module that matches your goal. To understand the overall object relationships, read [core objects in the Overview](../overview/concepts.en.md). To change cross-module behavior, read [End-to-End Integration](../integration/end-to-end/_index.en.md).
