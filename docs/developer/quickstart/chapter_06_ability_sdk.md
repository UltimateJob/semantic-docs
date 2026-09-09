---
title: "第六章：Ability、Handler 与 Robot SDK"
linkTitle: "第 6 章：Ability 与 SDK"
weight: 26
description: "让 Skill 声明的 Action 由 Ability Handler 执行，并通过 Robot SDK 连接 Fake、MuJoCo 或真实设备。"
---

**本章目标**：把一个 `type@schema_version` 的 Action 路由到 Ability，再由 Robot SDK 落到具体 Backend。

## Ability 是什么

Ability 是原子机器人能力。它把 Skill 发出的 Action 变成具体设备行为，例如路线规划、末端移动、夹爪控制、物体定位或工具负载验证。

Robot Skill 声明依赖：

```yaml
required_actions:
  - { type: perception.locate_object, schema_version: 2 }
  - { type: gripper.close, schema_version: 2 }
```

Ability 的 Manifest 必须提供相同 `actionType` 和 `schemaVersion`，否则 Pilot 不会路由。

## 代码位置

- Ability：`semantic-ability/r1pro-ability/abilities/`；
- 共享业务包：`semantic-ability/r1pro-ability/r1pro_abilities/`；
- AbilityFramework：`semantic-ability/ability-runtime/`；
- Robot SDK：`semantic-robotsdk/robot-sdk/packages/`；
- 示例配置：`semantic-robotsdk/robot-sdk/examples/`。

## 七类 Ability

| 角色 | 典型 Task |
|---|---|
| `navigation` | PlanRoute、FollowRoute、VerifyArrival |
| `manipulator_motion` | MoveEndEffector、FollowWaypoints、LiftHeldObject、MoveToPosture |
| `end_effector` | SetOpening、CloseUntilContact、Release、HoldObject |
| `robot_state` | GetRobotState、VerifyToolLoad |
| `sensor_capture` | CaptureRGBD |
| `object_perception` | LocateObject、VerifyPregrasp、VerifyGrasp、ObservePlacementTarget、VerifyPlacement |
| `grasp_planning` | GenerateCandidates、PlanTransportPosture |

所有 Ability 还会提供 `GetExecution` 和 `StopExecution` 两个公共 Task。

## 查看真实 Manifest

```bash
cd "$SEMANTIC/semantic-ability/r1pro-ability"
sed -n '1,240p' abilities/r1pro-grasp-planning/ability.manifest.yaml
```

你应看到：

```yaml
abilityName: R1ProGraspPlanning.V2
kind: AtomAbility
tasks:
  - taskName: GenerateCandidates
    abilityRole: grasp_planning
    actionType: grasp.generate_candidates
    schemaVersion: 2
    physical: false
    inputModel: r1pro_abilities.task_models:GenerateCandidatesInput
```

`physical` 表示该 Task 是否会产生物理影响。Manifest 是 Pilot 路由和 UI 展示的唯一元数据来源。

## Robot SDK 是什么

Robot SDK 是 Ability 与设备之间的类型化接口。它提供：

- 机器人状态；
- 能力描述；
- 运动规划；
- 末端控制；
- 传感器；
- 命令、Feedback 和停止；
- Fake、MuJoCo、真实设备 Backend。

SDK 不保存 Workflow、Robot Skill 或 Ability 业务状态。

## 查看 SDK 配置

```bash
cd "$SEMANTIC/semantic-robotsdk/robot-sdk"
sed -n '1,260p' examples/robot-deployment.mujoco.yaml
```

关键字段包括：

- `robot.id`；
- `robot.model`；
- `robot.backend`；
- `sdk.endpoint`；
- `frames`；
- `tools`；
- `safety`；
- `ability_framework.endpoint`；
- `pilot.robot_skill_directory`。

你可以通过环境变量覆盖 Endpoint：

```bash
export SEMANTIC_ROBOT_CONFIG="$PWD/examples/robot-deployment.mujoco.yaml"
export SEMANTIC_ROBOT_SDK_ENDPOINT="http://127.0.0.1:18090"
```

## 构建 Robot SDK

```bash
cd "$SEMANTIC/semantic-robotsdk/robot-sdk"

make lock
make lint
make test
make test-contracts
make build
```

产物是三个 Wheel：

```text
semantic-robot-sdk-core
semantic-robot-sdk-r1pro
semantic-robot-sdk-franka
```

真实模型专项测试需要对应资产：

```bash
make test-r1pro
make test-franka
```

这些测试需要 `R1PRO_ASSET_ROOT`、`FRANKA_MODEL_ROOT` 等环境变量，不能用 skip 代替通过。

## 构建和测试 Ability

```bash
cd "$SEMANTIC/semantic-ability/r1pro-ability"

make check
make test
make build
```

`make build` 构建共享业务 Wheel：

```text
semantic-r1pro-abilities-<version>.whl
```

七个 Ability 的 Zip 需要按仓库 README 使用 `ability-scaffold pack` 单独打包。

## 启动 AbilityFramework

AbilityFramework 由 `semantic-ability/ability-runtime` 提供。开发环境通常从 Robot Bundle 启动；最小验证可以直接使用 `debug-stack`：

```bash
cd "$SEMANTIC/semantic-robot-deployment"

semantic-robot-instance debug-stack \
  --instance <实例目录>
```

这会启动 AbilityFramework 和七类 Ability，但不启动 Pilot、不连接 Server。

## 验证 Ability 可用

1. AbilityFramework 能启动；
2. 七个 Ability 能激活；
3. heartbeat 报告 `running`；
4. 目标 Action 在 Manifest 中存在；
5. Skill 的 `required_actions` 可以精确匹配。

如果使用 Studio 或设备中心，可以在设备详情页查看 Ability 状态。

## 与第 5 章的连接

在 AbilityFramework 和所需 Ability running 后，重新运行第 5 章的本地 Skill：

```bash
cd "$SEMANTIC/semantic-framework"
.output/bin/semantic-pilot skill run ...
```

你应看到 Action 被路由，而不是在 Pilot 处失败。

## 测试边界

- Fake Backend：用于契约、状态和停止测试；
- MuJoCo Backend：用于物理行为测试；
- 真实设备：只能在批准的安全环境测试；
- 真实模型：用于 Agent 决策，不代替 Robot 物理链测试。

## 常见失败

- **Action 未找到**：检查 Skill `required_actions` 与 Ability Manifest 的 `actionType`；
- **Schema 不匹配**：确认两边都是 `schema_version: 2`；
- **Ability 不启动**：检查 `robotDeploymentPath`、`executionStorePath` 和模型配置；
- **SDK Endpoint 不通**：检查 `SEMANTIC_ROBOT_SDK_ENDPOINT` 和 Runtime 端口；
- **停止没有完成**：检查 Pilot、Ability 和 SDK 的 stop/hold 证据，不能只看进程退出。

## 本章小结

- Ability 是 Action 的实现边界；
- Manifest 是 Pilot 路由的元数据；
- Handler 负责动作语义，Robot SDK 负责设备抽象；
- SDK、Ability、Skill 的版本必须精确匹配。

## 下一章

进入[第七章：Pilot、Robot Deployment 与设备加入](/developer/quickstart/chapter_07_device/)，把 Ability 和 SDK 装配为设备实例。
