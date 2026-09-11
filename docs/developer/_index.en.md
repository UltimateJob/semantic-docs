---
title: "Semantic"
linkTitle: "Semantic"
weight: 30
description: "Semantic developer guide: understand the framework, then build, extend, integrate, and publish."
cascade:
  type: docs
---

# Semantic Developer Guide

Semantic is a development framework for embodied applications. Developers can build Agents, Workflows, Robot Skills, Abilities, Robot SDKs, simulation environments, and Semantic Studio in one system.

This guide is organized by how developers work, not by source repository. Pick a goal, then open the matching module.

## What Semantic can do

```text
Agent understands the goal
→ Workflow organizes work
→ Robot Skill orchestrates the task
→ Ability executes atomic actions
→ Robot SDK connects devices
→ Runtime / Scene provides the environment
→ Studio observes and intervenes
```

## Where to start

| Goal | Open | Result |
|---|---|---|
| Understand Semantic | [Overview](overview/_index.en.md) | Framework position, execution chain, and repository boundaries |
| Build an example from scratch | [Quick start](quickstart/_index.en.md) | From workspace setup to product-chain verification |
| Find runnable code | [Cookbook](cookbook/_index.en.md) | Real examples by development scenario |
| Learn core abstractions | [Core modules](core-modules/_index.en.md) | Agent, Workflow, Robot, and Runtime |
| Integrate an implementation | [Integration](integration/_index.en.md) | Models, tools, devices, and environments |
| Upgrade or publish | [Releases](../releases/_index.en.md) | Compatibility matrix and migration steps |
| Fix a specific error | [FAQ](faq/_index.en.md) | Root cause and handling by symptom |

## Core modules

1. **Agents and intelligence**: give Agents knowledge, tools, models, and roles;
2. **Workflow and task orchestration**: turn a plan into work that can keep progressing;
3. **Robot capabilities**: turn work into Skills, Actions, and device behavior;
4. **Environment and Runtime**: provide Scenes, simulation, and physical devices;
5. **Studio and interaction**: observe state, handle Interactions, and intervene;
6. **Developer toolchain**: build, test, Bundle, Runtime Pack, and product Gate.

## Contribution

Implementation, tests, build, and release rules are in [Reference](reference/_index.en.md). Read [Contributing and release](reference/contributing/_index.en.md) before cross-repository changes.

## GitHub / GitLab reading

Documentation links use relative `.md` paths so they work on GitHub and GitLab source pages. The Hugo build converts them to deployed URLs.
