---
title: "Pilot and Robot Execution"
weight: 20
description: "Pilot and Robot Execution: device connection, Skill delivery, Action routing, and environment runtime."
---

Robot Execution connects a Robot Task in the Framework to a Robot Skill Worker in Pilot. Environment runtime connects Scene Runtime, Semantic Map, and virtual Robots. The full execution chain is in [Chapter 9: Full Product Gate](../../quickstart/chapter_09_product_gate.en.md).

Implementation locations: `internal/pilot/` (Pilot process and Server-side orchestration), `internal/robot/` (devices and enrollment), `internal/simulation/` (Scene and virtual Robot lifecycle).

## Robot Execution path

```text
Robot Agent robot.run (validate Robot, Skill version, and complete input)
→ Server creates Robot Execution
→ Pilot starts the Robot Skill Worker (python -m semantic_robot_skill_sdk.worker)
→ Worker runs Stages and Actions (JSON-RPC)
→ AbilityFramework runs Abilities
→ Robot SDK controls the Robot
→ Events update Execution, SubTask, and Task
```

- `robot.run` accepted only records execution_ref and **does not advance Task/SubTask state** — completion must be driven by a Robot Execution terminal event;
- After Pilot accepts, it returns an Execution ID. The model Run can end; later state is advanced by events.

## Pilot and Robot

Pilot connects to the Server with a dedicated credential (`/ws/pilot`, issued by enrollment) and binds a Robot identity. It is responsible for:

- Reporting actual Robot, Ability, and Robot Skill state;
- Installing and enabling desired Robot Skills (ZIP validation + `packages/<name>/<version>` + atomic `active/` symlink switch; see [Robot Skill](../../core-modules/robot/robot-skill.en.md));
- Starting, stopping, and observing Workers;
- Forwarding Action, Feedback, Observation, and Artifact;
- After disconnect recovery, reporting current execution and event-sequence position.

Action routing (`internal/pilot/runner.go`):

- Action keys are idempotent: same key and same content reuse the result; different content reports `ErrActionKeyConflict`. interrupted forbids replay;
- Physical Actions have a Robot-level mutex (`ErrRobotBusy`). StartTask failure is not retried automatically.

The Server decides whether a Robot can be assigned from Pilot, Ability, Skill, Robot state, and Task occupancy.

## Execution events

Events update Stage, Action, and Execution, and drive SubTasks:

- completed: complete the SubTask after validating the result;
- failed: if physics already started → `execution_state_unknown` (replay forbidden); if not started → Recovery;
- waiting_agent: start a Robot Agent Decision; the reply returns to the original Worker;
- interrupted: keep Robot occupancy and wait for state confirmation;
- stopped: converge from stop and hold state (record `stopped` only after `stop.outcome` safety evidence; otherwise `interrupted`).

Event replay and query-by-Execution-ID are used to sync state after a reconnect (Pilot-side journal + event-sequence position).

## Scene and virtual Robot

The Framework starts a Scene Instance through a Runtime Installation (startup chain: [Scene Package and Simulation Runtime](../../core-modules/environment/scene-and-runtime.en.md)). After the initial Snapshot is synced to the Semantic Map, the Runtime provides virtual Robot descriptors. The Robot Runtime Orchestrator generates a deployment config for each virtual Robot and starts a managed instance (AbilityFramework, Ability, Pilot) so it enters the unified Robot Execution path.

- Virtual Robot launch runs asynchronously after the scene is running and the first Map generation is written (the Launcher finishes reconcile in about 2 minutes);
- A Robot Skill reads Runtime live state through Ability. Semantic Map serves Agent queries and environment understanding.

## Lifecycle

- Reset: hold the Robot, reset the Scene, and sync the new environment state;
- Scene stop: first HoldRobot each robot on the Runtime and confirm success (physical safety boundary), then converge Pilot/Ability, then stop the Scene Instance;
- Layout switch: write a layout_switch checkpoint first, fully end the current instance, then start the new Layout;
- Robot start failure: the Scene stays viewable, the Robot is marked degraded, and the scene is not destroyed.

Lifecycle tests check process, Store, Web state, and the actual Robot safety state together.

## Local debugging

- Debug a single Robot Skill without an Agent: `semantic-pilot skill run` (usage: [Robot Skill](../../core-modules/robot/robot-skill.en.md));
- Debug the Ability physical chain: `semantic-pilot debug-stack` (see `semantic-framework/examples/mujoco-skill-debug/README.md`);
- Verify a Scene independently: start `plugin-mujoco` directly and call its HTTP API.

## Tests

```bash
cd semantic-framework
go test ./internal/pilot/... ./internal/robot/... ./internal/simulation/... -count=1
go test ./tests/integration/ -count=1
```

## Related layers

- Conceptual model: [Architecture · Robot execution and the embodied loop](../../../architecture/06-robot-execution.en.md)
