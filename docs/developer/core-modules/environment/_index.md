---
title: "Environment 与 Runtime"
linkTitle: "Environment 与 Runtime"
weight: 40
description: "管理 Scene 资产、仿真 Runtime、Runtime Installation 和虚拟 Robot，让任务有可运行、可观察的环境。"
---

**Environment 与 Runtime**回答一个问题：**机器人在哪个世界运行，以及这个世界如何被启动、观察和替换**。

这组模块提供具身任务的环境。它可以是 MuJoCo 仿真、robosuite / LIBERO、真实设备现场，也可以是一个受管 Runtime 实例。

## 模块组成

| 模块 | 解决的问题 | 典型产物 |
|---|---|---|
| [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/) | Scene、Layout、Runtime 和虚拟 Robot | Scene 资产、Runtime Pack、Runtime Installation |

## 代码位置

- Runtime：`semantic-simulation/mujoco-runtime/`；
- Scene 资产：`semantic-scene/mujoco-asset/`；
- Runtime 配置：`semantic-framework/configs/runtimes.d/`；
- Scene 配置：`semantic-framework/configs/scenes.d/`；
- Studio 仿真：`semantic-web/src/stores/simulation.js`、Simulation 面板。

## Runtime 与 Scene 的关系

Runtime 是代码，Scene 是资产：

```text
Scene Package（场景、Mesh、Layout）
→ plugin-mujoco
→ Scene Instance
→ Snapshot
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

新增一个仓库布局或物体摆放，通常只需要新增资产目录，不需要修改 Runtime 源码。

## 一个 Scene Package 长什么样

```text
scene/<scene_key>/
├── asset-manifest.yaml
├── scene_info.yaml
├── layout001.yaml
├── layout002.yaml
├── layout_smoke.yaml
└── authoring/
```

- `asset-manifest.yaml`：稳定 ID、版本、Layout、能力和 authoring 约束；
- `scene_info.yaml`：Robot、传感器、物理参数；
- `layout*.yaml`：对象实例和初始布置；
- `authoring/`：编辑模板。

## 启动源码开发 Runtime

```bash
cd "$SEMANTIC/semantic-simulation/mujoco-runtime"

uv sync --frozen --extra dev
export MUJOCO_ASSET_ROOT="$SEMANTIC/semantic-scene/mujoco-asset"
export MUJOCO_GL=egl
uv run plugin-mujoco
```

验证：

```bash
curl http://127.0.0.1:8090/healthz
curl http://127.0.0.1:8090/api/v1/scenes
```

启动 Scene：

```bash
curl -X POST \
  http://127.0.0.1:8090/api/v1/scenes/palletizing_depalletizing_tote_v1/instances \
  -H 'Content-Type: application/json' \
  -d '{"request_id":"dev-1","layout":"layout_smoke","seed":7,"headless":true}'
```

## Runtime 提供什么

- Scene 目录；
- 实例生命周期；
- Snapshot；
- Virtual Robot；
- Viewer GLB；
- RGB / Depth / Contact / Holding；
- 低层命令；
- stop / hold / reset；
- Runtime Profile。

Runtime 不负责 IK、路径规划、抓取策略、Agent、Workflow 或 Robot Skill。

## 正式运行方式

正式产品不由源码目录直接启动 Runtime，而由 Framework 管理 Runtime Installation：

```bash
semantic runtime install native-mujoco@0.4.0 \
  --asset-root <资产目录>

semantic runtime doctor --all
semantic-server
```

源码开发模式会标记为 `development`，不能作为 RC 或发布验收。

## 什么时候扩展这组模块

- 新增测试场景或布局：新增 Scene Package；
- 修改 Runtime 行为：修改 Runtime 代码和契约测试；
- 接入新的 Runtime Profile：新增 profile 和安装入口；
- 接入真机设备：进入 [Robot SDK](/developer/core-modules/robot/robot-sdk/) 和 [设备集成](/developer/integration/device/)；
- 在 Studio 中观察环境：进入 [Studio 与交互](/developer/core-modules/interface/)。

## 测试

```bash
cd "$SEMANTIC/semantic-simulation/mujoco-runtime"

make lint
make test
make test-contracts
make test-native
```

真实资产测试需要 `MUJOCO_ASSET_ROOT`，不能用 skip 代替通过。

## 边界

- Scene 是纯资产，不包含 Agent 或 Ability 代码；
- Runtime 只负责物理世界和底层轨迹；
- `VirtualRobotDescriptor` 是上层接入设备的唯一描述；
- 没有批准的公共资产不能直接分发；
- Fake Backend 不能代替真实 MuJoCo 或真机验收。

## 深入阅读

- [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/)；
- [第二章：Runtime、Scene 与 Virtual Robot](/developer/quickstart/chapter_02_simulation/)；
- [仿真集成](/developer/integration/simulation/)。
