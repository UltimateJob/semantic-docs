---
title: "Chapter 9: Full Product Gate"
linkTitle: "Chapter 9: Product Gate"
weight: 29
description: "Run a complete Fake, MuJoCo, or real-model product Gate, and keep reproducible acceptance evidence."
aliases:
  - /developer/quickstart/chapter_05_execution_chain/
---

**Goal of this chapter**: string the components verified in the first eight chapters into one real product chain, and give pass criteria and failure localization for each layer.

## What a product Gate is

A product Gate is not "every process started". It proves a user goal crossed the full chain and left traceable evidence:

```text
Conversation
→ Plan Proposal
→ Workflow
→ Task / SubTask
→ Robot Execution
→ Environment State
→ Studio Result / Artifact
```

## Preconditions

After the first eight chapters you should already have:

- Semantic Server and Studio;
- At least one Runtime or real device;
- Agent Profile, Model, and Skill;
- An approved Workflow;
- A joined Robot;
- Installed Robot Skills;
- Running Abilities.

## Minimal Fake product Gate

The Fake Gate verifies the full product state machine and does not require real physics:

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-real-gate
```

This Gate starts:

- A real Server;
- A Web production build;
- Two Pilots;
- Two AbilityFrameworks;
- Fourteen Ability processes;
- Three Robot Skill Workers;
- Two isolated Fake Robots.

It is not allowed to skip missing dependencies and pretend success.

## Real MuJoCo product Gate

The MuJoCo Gate verifies real physical behavior:

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-mujoco-product
```

It verifies:

- Scene assets and Runtime Installation;
- Managed start of a virtual Robot;
- Ability and Skill desired/actual state;
- Actual physical motion, contact, and stop;
- Viewer, Sensor, and Execution in Studio.

## Real-model product Gate

A real model is used only to verify Agent decisions and collaboration. It does not replace physical verification:

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-mujoco-deepseek-single
```

This Gate needs a real model key and is enabled by Framework config. It may incur model-call cost and should be run manually under an explicit switch.

## Acceptance by layer

| Layer | What to verify | Pass criteria |
|---|---|---|
| 1 | Server / Studio | Login, Project, Snapshot, and WebSocket work |
| 2 | Runtime / Scene | Scene is running; Snapshot and Robot are valid |
| 3 | Agent | Profile, Model, Skill, and Tool are visible |
| 4 | Workflow | Plan approved; Task dependencies and resources are correct |
| 5 | Pilot / Worker | Skill version is correct; Stages and events are complete |
| 6 | Ability / SDK | Action, Feedback, and stop/hold work |
| 7 | Robot / Environment | Objects, tools, and final environment state are correct |
| 8 | Studio | Execution, Observation, and Artifact are visible |

## Acceptance evidence you must keep

A complete Gate at least keeps:

- User input and the approved Plan;
- Workflow, Task, and SubTask status;
- Pilot, Skill, Ability, SDK, and Runtime versions;
- Stage, Action, Feedback, Observation;
- Final environment state;
- Artifact;
- Studio screenshots or execution records;
- On failure, the log time range and recovery actions.

## Troubleshooting by layer

| Symptom | Check first |
|---|---|
| Agent cannot see a Skill | Skill Store, role allowlist, Server restart |
| Workflow does not advance | Dependencies, resources, Agent/Robot availability, Task wait reason |
| Robot does not execute | Pilot online, Skill version, required Action |
| Action failed | Ability heartbeat, Manifest, Schema, input model |
| Robot does not move | SDK Backend, Runtime health, device state |
| Studio does not update | Snapshot, WebSocket sequence, Store state |
| Stop did not finish | Pilot, Ability, SDK, hold evidence |
| Scene cannot start | Runtime Installation, asset path, failure_reason |
| Cannot reproduce | Check the version list and Gate artifacts. Do not rely on "the environment I just hand-edited" |

## Pass criteria

A Gate is not "I saw motion once". All of the following must hold:

1. The user goal can be traced to Task and Execution;
2. Workflow and Robot Execution status agree;
3. Key physical actions have Feedback and Observation;
4. Stop has hold evidence;
5. Studio display agrees with Server data;
6. Every component version is recorded;
7. It can be rerun in a clean environment.

## Series wrap-up

You have understood and verified Semantic along one continuous path:

```text
Server
→ Environment
→ Agent
→ Workflow
→ Robot Skill
→ Ability / SDK
→ Pilot / Device
→ Studio
→ Product Gate
```

For further development, go to:

- [Core modules](../core-modules/_index.en.md): learn the full extension contracts;
- [Cookbook](../cookbook/_index.en.md): find real examples;
- [Component integration](../integration/_index.en.md): connect a concrete implementation;
- [Reference](../reference/_index.en.md): build, test, protocols, and internals.
