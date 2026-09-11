---
title: "Robot SDK and New Model Onboarding"
weight: 80
description: "Onboard a new robot model: RobotBackend / Provider Protocol, Backend implementation, and Wheel delivery."
---

The Robot SDK gives Abilities typed interfaces for robot control, state, motion planning, and sensing. It sits at the bottom of the execution chain (see [Chapter 6: Ability, Handler, and Robot SDK](../../quickstart/chapter_06_ability_sdk.en.md)): Abilities depend on the SDK through Wheels, and the SDK Backend connects a device controller or simulation Runtime.

Repository: `semantic-robotsdk/robot-sdk/`, managed with a **uv workspace** (`[tool.uv.workspace]`; this is the only workspace mechanism in the whole workspace).

## Package layout

| Package | Location | Responsibility |
|---|---|---|
| `semantic-robot-sdk-core` | `packages/core` | Config, Backend / Provider Protocol, kinematics, sensing, coordinate transforms, and shared models |
| `semantic-robot-sdk-r1pro` | `packages/r1pro` | R1 Pro Profile, SDK assembly, and Providers |
| `semantic-robot-sdk-franka` | `packages/franka` | Franka arm integration |
| New model package | `packages/<model>` | Onboard a different device with the same layering |

Model-package entry example: `sdk.py` in `packages/r1pro` assembles modules / backends / providers.

## Core SDK interfaces

### RobotBackend Protocol

`packages/core/src/semantic_robot_sdk_core/backend.py` defines the protocol every device integration must implement:

- `capabilities`: declare robot capabilities (joints, base, end effector, tools, sensors);
- `state` / `sensors`: state and sensor reads;
- `execute_plan` / `command`: execute joint trajectories, base trajectories, gripper commands, and so on;
- `feedback`: execution feedback stream;
- `stop` / `hold`: safe stop and hold.

Framework-side `RobotCommandType` (`joint_trajectory/base_trajectory/gripper_command/stop/hold`, `internal/robotruntime/types.go`) maps one-to-one to Backend commands.

### Provider Protocol

`packages/core/src/semantic_robot_sdk_core/providers.py` defines the reusable algorithm layer:

- `KinematicsProvider`: forward and inverse kinematics;
- `MotionProvider`: trajectory generation and motion planning;
- `NavigationProvider`: navigation data sources and planning.

Providers implement algorithms at the SDK layer. The Backend transports commands and state to a device or simulation Runtime. The two can be replaced independently.

### Configuration models

`config.py` parses RobotDeployment. A Profile provides frames, tools, collision groups, named postures, motion limits, and backend options. `fake_backend.py` / `shared_fake_backend.py` provide device-free fakes for development.

## SDK responsibility boundary

The SDK keeps robot capability expression and **does not store** Workflow, Task, Semantic Map, or Robot Skill business state — those belong upstream on the chain (see the execution chain). A Skill also must not import the SDK directly (see [Robot Skill](robot-skill.en.md)). All physical calls must go through an Ability.

## Getting started: onboard a new Robot model

The main line is adding `packages/<model>`:

### 1. Define the Robot Profile

On the core models, declare this model's frames, joints, end effectors, tools, collision groups, named postures, and motion limits.

### 2. Implement the Backend

Implement `RobotBackend` Protocol connect, command, state, and stop. Choose by target environment:

- `fake`: in-memory fake for device-free development and tests;
- `mujoco`: connect a simulation Runtime (over HTTP/WS);
- `real`: connect a real device controller;
- `isaac`: explicitly not implemented today.

### 3. Implement required Providers

Implement the parts of `KinematicsProvider` (local IK), `MotionProvider` (trajectory generation), and `NavigationProvider` (navigation data source) that Abilities depend on for this model.

### 4. Provide a RobotDeployment example

Give a deployment config sample that a `semantic-robot-deployment` type package can consume.

### 5. Build and verify

```bash
# 构建所有包（uv workspace）
uv build --all-packages

# 在干净虚拟环境验证安装和导入
uv venv /tmp/verify-sdk
/tmp/verify-sdk/bin/pip install dist/semantic_robot_sdk_<model>-*.whl
/tmp/verify-sdk/bin/python -c "import semantic_robot_sdk_<model>"
```

### 6. End-to-end test

Complete end-to-end verification through Ability calls: Action inputs declared in the Ability Manifest land on a fake or mujoco environment through the SDK Backend, and state and feedback travel back up the chain.

## Tests

```bash
make lint             # ruff
make test             # pytest（PYTEST_DISABLE_PLUGIN_AUTOLOAD=1）
make test-contracts   # 契约测试：型号包与 core Protocol 的一致性
make build
```

Test focus:

- Coordinate frames and units;
- Joint, tool, and sensor state decoding;
- Kinematics and collision;
- Trajectory timing and motion limits;
- stop/hold covering all active commands;
- Backend disconnect, timeout, and reconnect;
- Type consistency between simulation and real robot.

## Delivery

A model package is delivered as a Wheel. Abilities reference it as an artifact-level dependency in `pyproject.toml` (for example `semantic-robot-sdk-core`, `semantic-robot-sdk-r1pro`) and it enters a `semantic-robot-deployment` type package (`bundle.yaml` + `python-requirements.lock`). New packages must be added to the uv workspace members.
