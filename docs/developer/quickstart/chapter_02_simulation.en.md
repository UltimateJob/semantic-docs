---
title: "Chapter 2: Runtime, Scene, and Virtual Robot"
linkTitle: "Chapter 2: Runtime and Scene"
weight: 22
description: "Start MuJoCo Runtime, load real Scene assets, and confirm a virtual Robot is runnable through the HTTP API."
---

**Goal of this chapter**: start a standalone MuJoCo Runtime, load a Scene Package from `semantic-scene`, and verify the instance, Snapshot, and Virtual Robot.

## What a Runtime is

`plugin-mujoco` is a FastAPI Runtime that starts physics simulation per scene. It owns only the physics lifecycle, low-level trajectories, Scene Snapshot, Virtual Robot, sensor data, and stop/hold/reset. It does not own IK, navigation planning, grasp strategy, Agent, Workflow, or Robot Skill.

## Why Runtime and Scene are separate

Runtime is code. Scene is assets. When you add a warehouse layout, object placement, or robot configuration, developers usually only add an asset directory and do not change Runtime source.

```text
Scene Package（资产）
→ plugin-mujoco（Runtime 引擎）
→ Scene Instance
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

## Code locations

- Runtime: `semantic-simulation/mujoco-runtime/`;
- Scene assets: `semantic-scene/mujoco-asset/`;
- Scene catalog: `semantic-scene/mujoco-asset/scene/`;
- Main example scene: `palletizing_depalletizing_tote_v1/`.

## Preconditions

- The Chapter 1 workspace already exists;
- `semantic-scene` is cloned and `git lfs pull` has been run;
- Machines without a display need EGL or OSMesa.

## Start the Runtime

```bash
cd "$SEMANTIC/semantic-simulation/mujoco-runtime"

# 安装锁定依赖
uv sync --frozen --extra dev

# 指向 Scene 资产仓
export MUJOCO_ASSET_ROOT="$SEMANTIC/semantic-scene/mujoco-asset"

# 无头服务器使用 EGL；本地桌面可省略
export MUJOCO_GL=egl

# 启动 Runtime（源码开发默认 127.0.0.1:8090）
uv run plugin-mujoco
```

If 8090 is in use, set the port explicitly:

```bash
export PLUGIN_MUJOCO_PORT=18090
uv run plugin-mujoco
```

## Verify the Runtime is up

```bash
curl http://127.0.0.1:8090/healthz
```

Expected output:

```json
{"status":"ok","version":"0.4.0.dev0"}
```

If you use port 18090, replace 8090 in every command with 18090.

## List available Scenes

```bash
curl http://127.0.0.1:8090/api/v1/scenes
```

You should see at least one scene, for example:

```text
palletizing_depalletizing_tote_v1
```

The scene key matches a directory in the asset repository:

```text
$SEMANTIC/semantic-scene/mujoco-asset/scene/palletizing_depalletizing_tote_v1/
```

## Start a Scene instance

```bash
curl -X POST \
  http://127.0.0.1:8090/api/v1/scenes/palletizing_depalletizing_tote_v1/instances \
  -H 'Content-Type: application/json' \
  -d '{
    "request_id": "quickstart-scene-001",
    "layout": "layout_smoke",
    "seed": 7,
    "headless": true
  }'
```

Expected output includes:

```json
{
  "instance_id": "<实例ID>",
  "state": "starting"
}
```

Save the instance ID:

```bash
SCENE_INSTANCE_ID=<实例ID>
```

## Wait until the instance is running

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID"
```

Poll until:

```json
{
  "state": "running"
}
```

If the instance enters `failed`, read `failure_reason`. Common causes are a wrong `MUJOCO_ASSET_ROOT`, Git LFS assets not pulled, or EGL unavailable.

## Read the Snapshot

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/snapshot"
```

The Snapshot returns the current physical world: scene objects, positions, orientations, and version information. Upper-layer Abilities use this data for perception and verification.

## Read the Virtual Robot

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/robots"
```

You should get a non-empty `VirtualRobotDescriptor` list. The descriptor includes:

- Robot identity;
- Coordinate frames;
- Tool descriptions;
- Sensors;
- Available low-level control entries.

Robot SDK later binds a Robot from this descriptor. The Framework does not need to know MuJoCo internals.

## Stop the instance

```bash
curl -X POST \
  "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/stop"
```

To stop the Runtime process, interrupt the terminal running `uv run plugin-mujoco`.

## Relationship to the Framework

The Runtime in this chapter is **source development mode**, for developers verifying Scenes and low-level APIs. In formal product runs, the Framework hosts the Runtime through a Runtime Installation:

```bash
semantic runtime install native-mujoco@0.4.0 --asset-root <资产目录>
semantic runtime doctor --all
semantic-server
```

Source development mode is marked development and cannot be used as a formal RC or release acceptance.

## Expected result

After this chapter you should have:

```text
plugin-mujoco 已启动
→ /healthz 返回 ok
→ /api/v1/scenes 有场景
→ Scene Instance 达到 running
→ Snapshot 返回对象状态
→ /robots 返回 VirtualRobotDescriptor
```

## Common failures

- **Runtime failed to start**: check that `MUJOCO_ASSET_ROOT` is an absolute path and assets have been pulled with `git lfs pull`;
- **Empty scene list**: confirm a valid Scene Package exists under `scene/` in the asset repository;
- **Instance failed**: read the instance `failure_reason`, focusing on Mesh files, URDF, and EGL;
- **Port unreachable**: check `PLUGIN_MUJOCO_HOST` / `PLUGIN_MUJOCO_PORT`. Do not mix production managed ports with source-development ports;
- **Snapshot has no objects**: confirm the layout is correct, for example `layout_smoke`.

## Chapter summary

- Runtime owns only the physical world, not Agent or business orchestration;
- Scene is pure assets. Runtime consumes it through `MUJOCO_ASSET_ROOT`;
- `VirtualRobotDescriptor` is the key description for upper layers to attach a Robot;
- Source mode is for development verification. Formal runs are hosted by the Framework.

## Next chapter

Continue to [Chapter 3: Agent Profile, Model, and Agent Skill](chapter_03_agent_skill.en.md) so an Agent has identity, a model, and authorizable knowledge.
