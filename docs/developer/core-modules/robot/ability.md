---
title: "Ability"
weight: 70
description: "新增一种机器人原子动作：Ability Manifest、Task Model、Handler 与 Provider。"
---

Ability 执行 Robot Skill 发起的 Action。AbilityFramework 根据 Action 类型、Schema 版本、Robot 和 Ability 实例选择可运行实例，并管理调用、Feedback、停止和结果。在执行链上，它位于 Robot Skill 之下、Robot SDK 之上（见[第六章：Ability、Handler 与 Robot SDK](/developer/quickstart/chapter_06_ability_sdk/)）。

**什么时候写一个新 Ability**：机器人缺一种原子能力（如一种新的感知原语、一种新的运动原语）时。如果只是组合已有动作完成任务，写 Robot Skill 就够了；如果要接入一整台新机器人，去 [Robot SDK](/developer/core-modules/robot/robot-sdk/)。

## Ability 包结构

现有 R1 Pro Ability 采用（位于 `semantic-ability/r1pro-ability/abilities/`）：

```text
r1pro-navigation/
├── ability.manifest.yaml    必需，能力声明（Action 类型、Task、输入模型）
├── main.py                  必需，入口：run_ability(AbilityRole.NAVIGATION, "R1ProNavigation.V2")
├── package.yaml             打包配置（包名、版本、架构）
├── requirements.txt         Python 依赖
├── bin/ability              AbilityFramework 使用的启动脚本
├── r1pro_abilities/         Python 包：task_models、Handler 实现
│   ├── __init__.py
│   ├── task_models.py       Task 输入模型（Pydantic）
│   └── ...
└── crs/                     内容资源
```

## Ability Manifest

Manifest 是 Ability 的对外契约，Robot Skill 的 `required_actions` 按这里的 `actionType` + `schemaVersion` 匹配。以导航 Ability 为例（节选自真实文件）：

```yaml
abilityName: R1ProNavigation.V2
kind: AtomAbility
schema:
  config:
    openAPIV3Schema:
      properties:
        robotDeploymentPath: { type: string, description: 当前 Robot 的统一部署配置路径 }
        executionStorePath: { type: string, description: Ability Execution SQLite 路径 }
tasks:
  - taskType: 0
    taskName: PlanRoute
    abilityRole: navigation
    actionType: navigation.plan_route        # ← Skill 依赖的 Action 类型
    schemaVersion: 2                        # ← Skill 声明的 schema_version 必须精确匹配
    physical: false                          # 非物理动作（规划），不产生物理影响
    inputModel: r1pro_abilities.task_models:PlanRouteInput
    inputFields:
      - { name: target, type: ResolvedNavigationTarget, required: true, description: Robot Agent 已解析的目标引用和位姿 }
      - { name: navigation_purpose, type: enum, required: true, description: 接近抓取、携物放置或普通通行 }
      - { name: maximum_speed_mps, type: number, required: true, description: 路径允许的最大速度，单位 m/s }
    returns: [{ name: execution, type: object }]
  - taskType: 1
    taskName: FollowRoute
    abilityRole: navigation
    actionType: navigation.follow_route
    schemaVersion: 2
    physical: true                           # 物理动作，产生实际运动
    inputModel: r1pro_abilities.task_models:FollowRouteInput
    # ...
```

关键字段语义：

| 字段 | 说明 |
|---|---|
| `abilityName` | 全局唯一，带主版本号（如 `R1ProNavigation.V2`） |
| `abilityRole` | 语义角色（见下表），决定 AbilityFramework 的启动分组 |
| `actionType` / `schemaVersion` | Skill 侧 `required_actions` 的匹配键 |
| `physical` | 是否产生物理影响——影响停止与审批语义 |
| `inputModel` | Task 输入的 Pydantic 模型引用（`module:path:Class`） |
| `inputFields` | 输入字段的开放描述（类型、必填、语义） |

## 七类语义角色

R1 Pro 的全部能力覆盖在七个语义角色上，新 Robot 可以复用这套角色划分：

| 角色 | 典型 Action | 职责 |
|---|---|---|
| Navigation | `navigation.plan_route` / `follow_route` / `verify_arrival` | 路线规划、跟随、到达验证 |
| Manipulator Motion | `motion.move_end_effector` / `lift_held_object` | 机械臂运动 |
| End Effector | `gripper.set_opening` / `close` / `hold_object` | 末端执行器控制 |
| Robot State | `robot.get_state` / `verify_tool_load` | 机器人状态与自检 |
| Sensor Capture | 感知数据采集 | 原始观测获取 |
| Object Perception | `perception.locate_object` / `verify_pregrasp` / `verify_grasp` | 物体定位与验证 |
| Grasp Planning | `grasp.generate_candidates` / `plan_transport_posture` | 抓取规划 |

一个 Ability 包可以包含同一角色下的多个 Task（如导航 Ability 同时提供 PlanRoute / FollowRoute / VerifyArrival / GetExecution / StopExecution 五个 Task）。

## Handler 与 Provider

**Handler** 接收类型化 Task 输入，调用 Provider 或 Robot SDK，形成 Action 结果：

- 每个 Task 对应一个 Handler；
- 物理动作执行期间按限频发送 Feedback（状态变化、错误、终态及时上报）；
- 停止处理覆盖所有活动 SDK 命令，让 Robot 进入 hold。

**Provider** 实现具体 backend 的算法或数据来源——同一 Handler 通过不同 Provider 适配不同环境：本地运动规划、MuJoCo ground-truth 感知、真机导航栈。这层分离让"导航逻辑"不必关心自己在仿真还是真机。

Ability 中的状态判断使用真实时间和传感数据。Robot Runtime 提供原始状态，Ability 根据当前 Action 的目标进行观察和判断。

## 入门教程：新增一个 Ability

### 1. 选择语义角色和 Action 类型

先查七类角色表确定归属，Action 类型采用 `<role>.<verb>` 命名（如 `gripper.hold_object`）。如果现有的角色都不合适，与维护者讨论是否引入新角色。

### 2. 定义 Task Model 与 Manifest

在包内新增 Pydantic 模型，编写 `ability.manifest.yaml`（对照上文示例），确保：

- `actionType` 唯一且语义清晰；
- `inputFields` 的描述写给 Skill 开发者看——他们按这些描述构造输入；
- `physical` 如实标注。

### 3. 实现 Handler 和所需 Provider

`main.py` 一行入口：

```python
from semantic_ability_sdk import run_ability, AbilityRole

run_ability(AbilityRole.NAVIGATION, "R1ProNavigation.V2")
```

Handler 内：解析 Task 输入 → 调用 Provider / Robot SDK → 返回结果；物理动作实现 Feedback、超时和停止。

### 4. 打包并在 AbilityFramework 中验证

`package.yaml` 声明包名与版本，构建 Ability Zip 后，在 AbilityFramework 中验证：

- **发现**：包上传后 `/api/instance` 激活，轮询进入 Running；
- **健康**：`/api/ability-heartbeat` 上报期望的 abilityName 且状态 running；
- **调用**：经 Pilot 发起一次对应 Action，检查输入模型匹配与返回结构。

Robot 侧启动顺序固定为 `AbilityFramework → 七类 Ability → semantic-pilot`（由 `semantic-robot-deployment` 的 runner 保证），所以 Ability 未就绪时 Pilot 不会上线——这是发现问题的第一排查点。

## 相关参考

- Skill 侧如何声明 Action 依赖：[Robot Skill](/developer/core-modules/robot/robot-skill/) 的 `required_actions`；
- Handler 落到设备的接口：[Robot SDK](/developer/core-modules/robot/robot-sdk/)；
- 本地联调环境：[Cookbook](/developer/cookbook/) 的 MuJoCo Skill 调试示例。
