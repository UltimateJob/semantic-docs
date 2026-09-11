---
title: "Environment and Runtime"
linkTitle: "Environment and Runtime"
weight: 40
description: "Manage Scene assets, simulation Runtimes, Runtime Installations, and virtual Robots so a task has a runnable, observable environment."
---

**Environment and Runtime** answers one question: **which world the robot runs in, and how that world is started, observed, and replaced**.

These modules provide the environment for embodied tasks. It can be MuJoCo simulation, robosuite / LIBERO, a physical device site, or a managed Runtime instance.

## Module composition

| Module | Problem it solves | Typical artifacts |
|---|---|---|
| [Scene Package and simulation Runtime](scene-and-runtime.en.md) | Scene, Layout, Runtime, and virtual Robot | Scene assets, Runtime Pack, Runtime Installation |

## Code locations

- Runtime: `semantic-simulation/mujoco-runtime/`;
- Scene assets: `semantic-scene/mujoco-asset/`;
- Runtime configuration: `semantic-framework/configs/runtimes.d/`;
- Scene configuration: `semantic-framework/configs/scenes.d/`;
- Studio simulation: `semantic-web/src/stores/simulation.js`, Simulation panel.

## Relationship between Runtime and Scene

Runtime is code. Scene is assets:

```text
Scene Package (scene, Mesh, Layout)
→ plugin-mujoco
→ Scene Instance
→ Snapshot
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

Adding a warehouse layout or object placement usually requires only a new asset directory. You do not need to change Runtime source code.

## What a Scene Package looks like

```text
scene/<scene_key>/
├── asset-manifest.yaml
├── scene_info.yaml
├── layout001.yaml
├── layout002.yaml
├── layout_smoke.yaml
└── authoring/
```

- `asset-manifest.yaml`: stable IDs, version, Layouts, capabilities, and authoring constraints;
- `scene_info.yaml`: Robot, sensors, and physics parameters;
- `layout*.yaml`: object instances and the initial arrangement;
- `authoring/`: editing templates.

## Start a source-development Runtime

```bash
cd "$SEMANTIC/semantic-simulation/mujoco-runtime"

uv sync --frozen --extra dev
export MUJOCO_ASSET_ROOT="$SEMANTIC/semantic-scene/mujoco-asset"
export MUJOCO_GL=egl
uv run plugin-mujoco
```

Verify:

```bash
curl http://127.0.0.1:8090/healthz
curl http://127.0.0.1:8090/api/v1/scenes
```

Start a Scene:

```bash
curl -X POST \
  http://127.0.0.1:8090/api/v1/scenes/palletizing_depalletizing_tote_v1/instances \
  -H 'Content-Type: application/json' \
  -d '{"request_id":"dev-1","layout":"layout_smoke","seed":7,"headless":true}'
```

## What a Runtime provides

- Scene catalog;
- instance lifecycle;
- Snapshot;
- Virtual Robot;
- Viewer GLB;
- RGB / Depth / Contact / Holding;
- low-level commands;
- stop / hold / reset;
- Runtime Profile.

A Runtime is not responsible for IK, path planning, grasp strategy, Agents, Workflow, or Robot Skills.

## Production run mode

A production product does not start the Runtime from a source directory. The Framework manages a Runtime Installation:

```bash
semantic runtime install native-mujoco@0.4.0 \
  --asset-root <asset directory>

semantic runtime doctor --all
semantic-server
```

Source-development mode is marked `development` and cannot be used as RC or release acceptance.

## When to extend these modules

- Add a test Scene or layout: add a Scene Package;
- Change Runtime behavior: change Runtime code and contract tests;
- Connect a new Runtime Profile: add the profile and an install entry;
- Connect a physical device: go to [Robot SDK](../robot/robot-sdk.en.md) and [Device Integration](../../integration/device/_index.en.md);
- Observe the environment in Studio: go to [Studio and Interaction](../interface/_index.en.md).

## Testing

```bash
cd "$SEMANTIC/semantic-simulation/mujoco-runtime"

make lint
make test
make test-contracts
make test-native
```

Real-asset tests require `MUJOCO_ASSET_ROOT`. A skip is not a pass.

## Boundaries

- A Scene is pure assets and contains no Agent or Ability code;
- A Runtime is responsible only for the physical world and low-level trajectories;
- `VirtualRobotDescriptor` is the only description upper layers use to attach a device;
- Unapproved public assets must not be distributed directly;
- A Fake Backend cannot replace real MuJoCo or physical-device acceptance.

## Further reading

- [Scene Package and simulation Runtime](scene-and-runtime.en.md);
- [Chapter 2: Runtime, Scene, and Virtual Robot](../../quickstart/chapter_02_simulation.en.md);
- [Simulation Integration](../../integration/simulation/_index.en.md).
