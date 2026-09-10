---
title: "Overview"
linkTitle: "Overview"
weight: 10
description: "What Semantic is, the problem it solves, how it works, and where developers should start."
---

**What is Semantic?**

Semantic is a development framework for embodied applications: Agents understand goals, Workflows organize work, and Robot Skills, Abilities, and the Robot SDK drive simulated or physical robots to complete physical tasks.

**What problem does it solve?**

An embodied task contains both semantic decisions and physical execution. Semantic connects the two with explicit objects, protocols, and state boundaries so developers can extend, test, and replace each part independently.

```text
Agent → Workflow → Pilot → Robot Skill → Ability → Robot SDK
      → Runtime / Scene / physical device
```

## What Semantic provides

- **Agent capabilities**: Agent Skills, Tools, MCP, Model Providers, roles, and Teams;
- **Task orchestration**: Plan Proposal, Workflow, Task, SubTask, pause, resume, and stop;
- **Robot execution**: Robot Skill, Stage, Action, Ability, and Robot SDK;
- **Environment abstraction**: Scene Package, Runtime, Virtual Robot, and physical devices;
- **Product workbench**: Semantic Studio, event streams, Execution, Artifact, and Interaction;
- **Developer toolchain**: quick-start, Runtime Pack, Robot Bundle, and product Gate.

## Reading path

| Goal | Start here |
|---|---|
| Build a runnable system from scratch | [Quick start](../quickstart/_index.en.md) |
| Understand abstractions and extension points | [Core modules](../core-modules/_index.en.md) |
| Find real code and configuration | [Cookbook](../cookbook/_index.en.md) |
| Integrate a model, device, or Runtime | [Integration](../integration/_index.en.md) |
| Look up commands, protocols, or internals | [Reference](../reference/_index.en.md) |
| Upgrade or migrate | [Releases](../../releases/_index.en.md) |
| Troubleshoot a specific error | [FAQ](../faq/_index.en.md) |

## Continue reading

- [Core objects and relationships](concepts.en.md);
- [System architecture and one task lifecycle](architecture.en.md);
- [Repositories, artifacts, and version boundaries](repositories.en.md);
- [Quick start](../quickstart/_index.en.md).
