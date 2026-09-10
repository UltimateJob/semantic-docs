---
title: "Quick Start"
linkTitle: "Quick Start"
weight: 20
description: "Build from a minimal Server to the Semantic product chain through one continuous development project."
---

This series is the main tutorial for Semantic developers. It does not list commands by repository. It follows the capability growth of one real task and builds a runnable Semantic system chapter by chapter.

## What this is

The final artifact is a verifiable embodied application chain:

```text
Workspace and Server
→ Runtime, Scene, and Virtual Robot
→ Agent Profile, Model, and Agent Skill
→ Plan Proposal, Workflow, Task
→ Robot Skill, Stage, and Action
→ Ability, Robot SDK, and Pilot
→ Studio observation and intervention
→ Full product Gate
```

Each chapter builds on resources already verified in the previous chapter and introduces only one new core object. Code locations, prerequisites, and completion criteria in each chapter must be explicit. Unexplained placeholders must not be the main path.

## Shortest path: get it running first

If you only want to confirm the environment works:

1. Prepare the multi-repo workspace with `quick-start/semantic_installer.py`;
2. Start `semantic-framework` and Semantic Studio;
3. Install a verified Runtime Pack and Robot Bundle;
4. Create a Project in Studio and start a Scene.

The full manual development path starts at [Chapter 1](chapter_01_environment.en.md).

## Learning path

| Chapter | Topic | Capability added | Artifact |
|---|---|---|---|
| [Chapter 1](chapter_01_environment.en.md) | Workspace and minimal Server | Multi-repo, config copies, Server | Runnable Framework |
| [Chapter 2](chapter_02_simulation.en.md) | Runtime, Scene, and Virtual Robot | Environment and virtual device | running Scene |
| [Chapter 3](chapter_03_agent_skill.en.md) | Agent Profile, Model, and Skill | Agent identity, model, and knowledge | Visible Agent Skill |
| [Chapter 4](chapter_04_workflow.en.md) | Plan Proposal and Workflow | Approval, tasks, dependencies, and resources | Approved Workflow |
| [Chapter 5](chapter_05_robot_skill.en.md) | Robot Skill, Stage, and Action | Staged physical task | Skill execution events |
| [Chapter 6](chapter_06_ability_sdk.en.md) | Ability, Handler, and Robot SDK | Atomic actions and device abstraction | Callable Ability |
| [Chapter 7](chapter_07_device.en.md) | Pilot, Deployment, and device join | Device assembly and connection | online Robot |
| [Chapter 8](chapter_08_studio.en.md) | Studio, event streams, and Execution | Observation, interaction, and artifacts | Observable execution |
| [Chapter 9](chapter_09_product_gate.en.md) | Full product Gate | End-to-end acceptance and troubleshooting | Reproducible product chain |

The nine chapters form one continuous end-to-end path: start from an empty workspace, add one capability per chapter, and finish with a reproducible, acceptable product chain. Each chapter builds on the previous chapter's artifact. Follow them in order.

## Boundaries of this tutorial

- The tutorial only walks you through one stable main path;
- Full extension contracts are in [Core Modules](../core-modules/_index.en.md);
- Concrete implementations and existing examples are in the [Cookbook](../cookbook/_index.en.md);
- Cross-component verification is in [Component Integration](../integration/_index.en.md);
- Build, test, and release facts are in [Reference](../reference/_index.en.md).

## Next step

Start with [Chapter 1: Environment and workspace](chapter_01_environment.en.md).
