---
title: "Robot SDK 与新型号接入"
weight: 80
description: "接入新机器人型号：RobotBackend / Provider Protocol、Backend 实现与 Wheel 交付。"
---

Robot SDK 向 Ability 提供类型化的机器人控制、状态、运动规划和传感接口。它位于执行链的最底端（见[第六章：Ability、Handler 与 Robot SDK](/developer/quickstart/chapter_06_ability_sdk/)）：Ability 通过 Wheel 依赖 SDK，SDK 的 Backend 连接设备控制器或仿真 Runtime。

仓库：`semantic-robotsdk/robot-sdk/`，使用 **uv workspace** 管理（`[tool.uv.workspace]`，这是整个工作区中唯一的 workspace 机制）。

## 包结构

| 包 | 位置 | 职责 |
|---|---|---|
| `semantic-robot-sdk-core` | `packages/core` | 配置、Backend / Provider Protocol、运动学、传感、坐标变换和通用模型 |
| `semantic-robot-sdk-r1pro` | `packages/r1pro` | R1 Pro Profile、SDK 装配和 Provider |
| `semantic-robot-sdk-franka` | `packages/franka` | Franka 机械臂接入 |
| 新型号包 | `packages/<model>` | 按相同分层接入不同设备 |

型号包入口示例：`packages/r1pro` 的 `sdk.py` 负责装配 modules / backends / providers。

## SDK 的核心接口

### RobotBackend Protocol

`packages/core/src/semantic_robot_sdk_core/backend.py` 定义了所有设备接入必须实现的协议：

- `capabilities`：声明机器人能力（关节、底盘、末端、工具、传感器）；
- `state` / `sensors`：状态与传感读取；
- `execute_plan` / `command`：关节轨迹、底盘轨迹、夹爪命令等执行；
- `feedback`：执行反馈流；
- `stop` / `hold`：安全停止与保持。

Framework 侧的 `RobotCommandType`（`joint_trajectory/base_trajectory/gripper_command/stop/hold`，`internal/robotruntime/types.go`）与 Backend 命令一一对应。

### Provider Protocol

`packages/core/src/semantic_robot_sdk_core/providers.py` 定义可复用算法层：

- `KinematicsProvider`：正逆运动学；
- `MotionProvider`：轨迹生成与运动规划；
- `NavigationProvider`：导航数据源与规划。

Provider 在 SDK 层实现算法，Backend 负责与设备或仿真 Runtime 传输命令和状态，两者可独立替换。

### 配置模型

`config.py` 解析 RobotDeployment；Profile 提供 frame、工具、碰撞组、命名姿态、运动限制和 backend 选项。`fake_backend.py` / `shared_fake_backend.py` 提供无设备开发用的假实现。

## SDK 的职责边界

SDK 保持机器人能力表达，**不保存** Workflow、Task、Semantic Map 或 Robot Skill 业务状态——那些属于链路上游（见执行链）。Skill 也不允许直接 import SDK（见 [Robot Skill](/developer/core-modules/robot/robot-skill/)），所有物理调用必须经过 Ability。

## 入门教程：接入新 Robot 型号

以新增 `packages/<model>` 为主线：

### 1. 定义 Robot Profile

在 core 模型上声明该型号的 frame、关节、末端、工具、碰撞组、命名姿态和运动限制。

### 2. 实现 Backend

实现 `RobotBackend` Protocol 的连接、命令、状态和停止。按目标环境选择：

- `fake`：纯内存假实现，用于无设备开发与测试；
- `mujoco`：连接仿真 Runtime（经 HTTP/WS）；
- `real`：连接真实设备控制器；
- `isaac`：当前明确未实现。

### 3. 实现所需 Provider

按型号能力实现 `KinematicsProvider`（本地 IK）、`MotionProvider`（轨迹生成）、`NavigationProvider`（导航数据源）中被 Ability 依赖的部分。

### 4. 提供 RobotDeployment 示例

给出可被 `semantic-robot-deployment` 类型包消费的部署配置样例。

### 5. 构建与验证

```bash
# 构建所有包（uv workspace）
uv build --all-packages

# 在干净虚拟环境验证安装和导入
uv venv /tmp/verify-sdk
/tmp/verify-sdk/bin/pip install dist/semantic_robot_sdk_<model>-*.whl
/tmp/verify-sdk/bin/python -c "import semantic_robot_sdk_<model>"
```

### 6. 端到端测试

通过 Ability 调用完成端到端验证：Ability Manifest 声明的 Action 输入经 SDK Backend 落到 fake 或 mujoco 环境，状态与反馈沿链路上行。

## 测试

```bash
make lint             # ruff
make test             # pytest（PYTEST_DISABLE_PLUGIN_AUTOLOAD=1）
make test-contracts   # 契约测试：型号包与 core Protocol 的一致性
make build
```

测试重点：

- 坐标系与单位；
- 关节、工具和传感状态解码；
- 运动学与碰撞；
- 轨迹时间参数和运动限制；
- stop/hold 覆盖所有活动命令；
- Backend 断线、超时和重连；
- 仿真与真机的类型一致性。

## 交付

型号包以 Wheel 交付，被 Ability 的 `pyproject.toml` 以制品级依赖引用（如 `semantic-robot-sdk-core`、`semantic-robot-sdk-r1pro`），并进入 `semantic-robot-deployment` 的类型包（`bundle.yaml` + `python-requirements.lock`）。新包需加入 uv workspace 的 members。
