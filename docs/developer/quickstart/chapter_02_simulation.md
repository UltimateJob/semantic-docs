---
title: "第二章：Runtime、Scene 与 Virtual Robot"
linkTitle: "第 2 章：Runtime 与 Scene"
weight: 22
description: "启动 MuJoCo Runtime，加载真实 Scene 资产，并通过 HTTP API 确认虚拟 Robot 可运行。"
---

**本章目标**：启动一个独立的 MuJoCo Runtime，加载 `semantic-scene` 中的 Scene Package，并验证实例、Snapshot 和 Virtual Robot。

## Runtime 是什么

`plugin-mujoco` 是一个按场景启动物理仿真的 FastAPI Runtime。它只负责物理生命周期、低层轨迹、Scene Snapshot、Virtual Robot、传感器数据和 stop/hold/reset；不负责 IK、导航规划、抓取策略、Agent、Workflow 或 Robot Skill。

## 为什么要分离 Runtime 和 Scene

Runtime 是代码，Scene 是资产。新增一个仓库布局、物体摆放或机器人配置时，开发者通常只需要新增资产目录，不需要修改 Runtime 源码。

```text
Scene Package（资产）
→ plugin-mujoco（Runtime 引擎）
→ Scene Instance
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

## 代码位置

- Runtime：`semantic-simulation/mujoco-runtime/`；
- Scene 资产：`semantic-scene/mujoco-asset/`；
- 场景目录：`semantic-scene/mujoco-asset/scene/`；
- 主要示例场景：`palletizing_depalletizing_tote_v1/`。

## 前置条件

- 第 1 章工作区已经存在；
- `semantic-scene` 已克隆，并已执行 `git lfs pull`；
- 无显示器机器需要 EGL 或 OSMesa。

## 启动 Runtime

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

如果 8090 被占用，可以显式指定端口：

```bash
export PLUGIN_MUJOCO_PORT=18090
uv run plugin-mujoco
```

## 验证 Runtime 已启动

```bash
curl http://127.0.0.1:8090/healthz
```

预期输出：

```json
{"status":"ok","version":"0.4.0.dev0"}
```

如果你使用的是 18090 端口，请把所有命令中的 8090 替换为 18090。

## 查看可用 Scene

```bash
curl http://127.0.0.1:8090/api/v1/scenes
```

应看到至少一个场景，例如：

```text
palletizing_depalletizing_tote_v1
```

场景 key 对应资产仓中的目录：

```text
$SEMANTIC/semantic-scene/mujoco-asset/scene/palletizing_depalletizing_tote_v1/
```

## 启动一个 Scene 实例

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

预期输出包含：

```json
{
  "instance_id": "<实例ID>",
  "state": "starting"
}
```

保存实例 ID：

```bash
SCENE_INSTANCE_ID=<实例ID>
```

## 等待实例进入 running

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID"
```

反复查询，直到：

```json
{
  "state": "running"
}
```

如果实例进入 `failed`，查看返回的 `failure_reason`。常见原因是 `MUJOCO_ASSET_ROOT` 指向错误、Git LFS 资产未拉取或 EGL 不可用。

## 查看 Snapshot

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/snapshot"
```

Snapshot 返回当前物理世界的状态，包括场景对象、位置、方向和版本信息。上层 Ability 会使用这些数据做感知和验证。

## 查看 Virtual Robot

```bash
curl "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/robots"
```

应返回非空的 `VirtualRobotDescriptor` 列表。描述中包含：

- Robot 标识；
- 坐标系；
- 工具描述；
- 传感器；
- 可使用的底层控制入口。

Robot SDK 后续会用这个描述符绑定 Robot，Framework 不需要知道 MuJoCo 的具体实现。

## 停止实例

```bash
curl -X POST \
  "http://127.0.0.1:8090/api/v1/scene-instances/$SCENE_INSTANCE_ID/stop"
```

停止 Runtime 进程时，直接中断 `uv run plugin-mujoco` 所在终端。

## 与 Framework 的关系

本章的 Runtime 是**源码开发模式**，用于开发者验证 Scene 和底层 API。正式产品运行时，Framework 会通过 Runtime Installation 托管 Runtime：

```bash
semantic runtime install native-mujoco@0.4.0 --asset-root <资产目录>
semantic runtime doctor --all
semantic-server
```

源码开发模式标记为 development，不能作为正式 RC 或发布验收。

## 预期结果

本章完成后，你应得到：

```text
plugin-mujoco 已启动
→ /healthz 返回 ok
→ /api/v1/scenes 有场景
→ Scene Instance 达到 running
→ Snapshot 返回对象状态
→ /robots 返回 VirtualRobotDescriptor
```

## 常见失败

- **Runtime 启动失败**：检查 `MUJOCO_ASSET_ROOT` 是否是绝对路径，且资产已执行 `git lfs pull`；
- **Scene 列表为空**：确认资产仓中 `scene/` 存在合法 Scene Package；
- **实例失败**：读取实例 `failure_reason`，重点检查 Mesh 文件、URDF 和 EGL；
- **端口不通**：检查 `PLUGIN_MUJOCO_HOST` / `PLUGIN_MUJOCO_PORT`，不要把生产受管端口与源码开发端口混用；
- **Snapshot 无对象**：确认使用的 layout 是否正确，例如 `layout_smoke`。

## 本章小结

- Runtime 只负责物理世界，不负责 Agent 或业务编排；
- Scene 是纯资产，Runtime 通过 `MUJOCO_ASSET_ROOT` 消费；
- `VirtualRobotDescriptor` 是上层接入 Robot 的关键描述；
- 源码模式用于开发验证，正式运行由 Framework 托管。

## 下一章

进入[第 3 章：Agent Profile、Model 与 Agent Skill](/developer/quickstart/chapter_03_agent_skill/)，让 Agent 有身份、模型和可授权的知识。
