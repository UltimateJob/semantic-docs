---
title: "Simulation Integration"
linkTitle: "Simulation Integration"
weight: 20
description: "Connect a Scene Package and simulation Runtime, and produce an executable virtual Robot."
---

This section is for simulation-environment developers. Simulation integration has three boundaries: Scene assets, the Runtime engine, and the Framework's Runtime Installation.

## Integration boundary

```text
Scene Package (scene assets)
→ MuJoCo Runtime (physics lifecycle)
→ Runtime Installation (version and asset registration)
→ Framework Scene Instance
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

## Recommended order

1. Confirm the source and distribution license of the scene, Robot model, Mesh, and Layout;
2. Write `asset-manifest.yaml`, `scene_info.yaml`, and Layouts;
3. Load the Scene in a standalone Runtime and verify health, instance state, snapshot, and Robot descriptor;
4. Generate a frozen scene directory;
5. Register the Runtime Installation and Scene Catalog in the Framework;
6. Start the Scene in Studio and confirm the virtual Robot can be managed and deployed;
7. Continue verifying Ability, Pilot, and Robot Skill with [Device Integration](../device/_index.en.md).

## Key boundaries

A Runtime is responsible only for the physics lifecycle, low-level trajectories, Snapshot, Virtual Robot, sensor data, and reset/stop/hold. It is not responsible for IK, path planning, grasp strategy, Ability, Robot Skill, or Agent. Adding a Scene usually does not require Runtime source changes.

## Reading path

- Scene assets and Runtime contracts: [Scene Package and simulation Runtime](../../core-modules/environment/scene-and-runtime.en.md);
- Five-minute start: [Chapter 2: Simulation environment](../../quickstart/chapter_02_simulation.en.md);
- Cross-component verification: [End-to-End Integration](../end-to-end/_index.en.md).

## Acceptance criteria

- Runtime `/healthz` is healthy;
- the Scene can load from a directory and create an instance;
- the instance reaches `running`;
- Snapshot and `/robots` return valid data;
- the Framework can register and host the Runtime;
- the virtual Robot can enter the same Robot Execution chain as a physical robot.
