---
title: "Ability"
weight: 70
description: "Add an atomic robot action: Ability Manifest, Task Model, Handler, and Provider."
---

An Ability executes an Action started by a Robot Skill. AbilityFramework selects a runnable instance from Action type, Schema version, Robot, and Ability instance, and manages the call, Feedback, stop, and result. On the execution chain it sits below Robot Skill and above Robot SDK (see [Chapter 6: Ability, Handler, and Robot SDK](../../quickstart/chapter_06_ability_sdk.en.md)).

**When to write a new Ability**: the robot is missing an atomic capability (for example a new perception primitive or a new motion primitive). If you only need to compose existing actions into a task, write a Robot Skill. If you need to onboard a whole new robot, go to [Robot SDK](robot-sdk.en.md).

## Ability package layout

Existing R1 Pro Abilities use this layout (under `semantic-ability/r1pro-ability/abilities/`):

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

The Manifest is the Ability's public contract. A Robot Skill's `required_actions` match on `actionType` + `schemaVersion` here. Navigation Ability excerpt (from the real file):

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

Key field semantics:

| Field | Description |
|---|---|
| `abilityName` | Globally unique, with a major version (for example `R1ProNavigation.V2`) |
| `abilityRole` | Semantic role (see the table below). Determines AbilityFramework startup grouping |
| `actionType` / `schemaVersion` | Match key for Skill-side `required_actions` |
| `physical` | Whether the action has a physical effect — affects stop and approval semantics |
| `inputModel` | Pydantic model reference for Task input (`module:path:Class`) |
| `inputFields` | Open description of input fields (type, required, semantics) |

## Seven semantic roles

All R1 Pro capabilities sit on seven semantic roles. A new Robot can reuse this split:

| Role | Typical Actions | Responsibility |
|---|---|---|
| Navigation | `navigation.plan_route` / `follow_route` / `verify_arrival` | Route planning, following, arrival verification |
| Manipulator Motion | `motion.move_end_effector` / `lift_held_object` | Arm motion |
| End Effector | `gripper.set_opening` / `close` / `hold_object` | End-effector control |
| Robot State | `robot.get_state` / `verify_tool_load` | Robot state and self-check |
| Sensor Capture | Perception data capture | Raw observation acquisition |
| Object Perception | `perception.locate_object` / `verify_pregrasp` / `verify_grasp` | Object localization and verification |
| Grasp Planning | `grasp.generate_candidates` / `plan_transport_posture` | Grasp planning |

One Ability package can contain multiple Tasks under the same role (the navigation Ability provides PlanRoute / FollowRoute / VerifyArrival / GetExecution / StopExecution).

## Handler and Provider

A **Handler** receives typed Task input, calls a Provider or Robot SDK, and forms an Action result:

- Each Task has one Handler;
- During a physical action, Feedback is sent at a limited rate (state changes, errors, and terminal states are reported promptly);
- Stop handling covers all active SDK commands so the Robot enters hold.

A **Provider** implements the algorithm or data source for a concrete backend. The same Handler adapts to different environments through different Providers: local motion planning, MuJoCo ground-truth perception, or a real-robot navigation stack. This split keeps "navigation logic" from caring whether it is in simulation or on a real robot.

State judgments inside an Ability use real time and sensor data. Robot Runtime provides raw state; the Ability observes and judges against the current Action's goal.

## Getting started: add an Ability

### 1. Choose a semantic role and Action type

Look up the seven-role table first. Name Action types as `<role>.<verb>` (for example `gripper.hold_object`). If none of the existing roles fit, discuss a new role with maintainers.

### 2. Define the Task Model and Manifest

Add a Pydantic model in the package and write `ability.manifest.yaml` (follow the example above). Make sure:

- `actionType` is unique and semantically clear;
- `inputFields` descriptions are written for Skill developers — they construct inputs from those descriptions;
- `physical` is labeled honestly.

### 3. Implement the Handler and required Providers

One-line entry in `main.py`:

```python
from semantic_ability_sdk import run_ability, AbilityRole

run_ability(AbilityRole.NAVIGATION, "R1ProNavigation.V2")
```

Inside the Handler: parse Task input → call Provider / Robot SDK → return the result. Physical actions implement Feedback, timeout, and stop.

### 4. Pack and verify in AbilityFramework

`package.yaml` declares package name and version. After you build the Ability Zip, verify in AbilityFramework:

- **Discovery**: after upload, `/api/instance` activates and polling reaches Running;
- **Health**: `/api/ability-heartbeat` reports the expected abilityName with state running;
- **Call**: start the matching Action through Pilot and check input-model match and return structure.

The Robot-side startup order is fixed as `AbilityFramework → seven Abilities → semantic-pilot` (guaranteed by the `semantic-robot-deployment` runner), so Pilot does not come online while Abilities are not ready — that is the first place to look when something is wrong.

## Related references

- How the Skill side declares Action dependencies: `required_actions` in [Robot Skill](robot-skill.en.md);
- The interface a Handler uses to reach a device: [Robot SDK](robot-sdk.en.md);
- Local joint-debug environment: the MuJoCo Skill debug example in [Cookbook](../../cookbook/_index.en.md).
