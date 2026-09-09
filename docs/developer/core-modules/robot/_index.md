---
title: "Robot 能力"
linkTitle: "Robot 能力"
weight: 30
description: "通过 Robot Skill、Ability 和 Robot SDK，把任务编排成动作并落到具体设备。"
---

**Robot 能力**回答一个问题：**任务怎么编排成动作，动作怎么落到设备**。

它承载 Semantic 的物理执行。业务意图由 Workflow 交给 Robot Task，Robot Skill 将任务拆成 Stage，Ability 执行原子 Action，Robot SDK 连接具体设备。

## 模块组成

| 模块 | 解决的问题 | 典型产物 |
|---|---|---|
| [Robot Skill](/developer/core-modules/robot/robot-skill/) | 一类物理任务怎么分阶段执行 | `SKILL.md`、Stage、Input/State/Result |
| [Ability](/developer/core-modules/robot/ability/) | 一个原子动作怎么执行 | Manifest、Task Model、Handler |
| [Robot SDK](/developer/core-modules/robot/robot-sdk/) | 怎么接入新设备或新 Backend | Backend、Provider、型号包 |

## 调用链

```text
Workflow Robot SubTask
→ Pilot
→ Robot Skill Worker
→ required_actions
→ AbilityFramework
→ Ability Handler
→ Robot SDK Backend
→ Fake / MuJoCo / 真实设备
```

关键约束：

- Skill 不 import 设备细节；
- Action 使用 `type@schema_version` 精确匹配；
- Ability 负责动作语义；
- SDK 不保存 Workflow、Skill 或 Ability 业务状态；
- Pilot 管理 Worker 生命周期和停止。

## 代码位置

- Robot Skill：`semantic-skill/robot-skill/`；
- Skill Worker SDK：`semantic-skill/robot-skill/semantic_robot_skill_sdk/`；
- Ability：`semantic-ability/r1pro-ability/`；
- AbilityFramework：`semantic-ability/ability-runtime/`；
- Robot SDK：`semantic-robotsdk/robot-sdk/packages/`；
- Pilot：`semantic-framework/cmd/semantic-pilot/`。

## 一个 Robot Skill 长什么样

```text
semantic_robot_skills/skills/<skill_dir>/
├── SKILL.md
├── scripts/
│   ├── skill.py
│   ├── controller.py
│   └── models.py
├── references/
├── tests/
└── requirements.lock
```

`SKILL.md` 声明：

- `name` 和 `version`；
- `entrypoint` 和 `stop_entrypoint`；
- `input_model`、`state_model`、`result_model`；
- `required_actions`；
- `stop_actions`。

Skill 只通过 `SkillContext` 使用运行时能力，不能写 `print()`，stdout 只能输出 JSON-RPC。

## 一个 Ability 长什么样

```text
abilities/<ability_dir>/
├── ability.manifest.yaml
├── main.py
├── package.yaml
├── requirements.txt
├── bin/ability
└── crs/<ability>.yaml
```

Manifest 声明：

- `abilityName`；
- `actionType`；
- `schemaVersion`；
- `physical`；
- `inputModel`；
- `inputFields`；
- `returns`。

Pilot 使用 `actionType + schemaVersion` 将 Skill 的 Action 路由到 Ability。

## Robot SDK 做什么

Robot SDK 向 Ability 提供类型化接口：

- 机器人状态和能力；
- 运动规划；
- 末端控制；
- 传感器；
- 命令、Feedback、停止；
- Fake / MuJoCo / 真实设备 Backend。

它不要求知道 Workflow、Skill 或 Ability 的业务状态。

## 最小开发路径

### 1. 新增一个 Robot Skill

1. 在 `semantic_robot_skills/skills/` 中创建目录；
2. 写 `SKILL.md`；
3. 在 `scripts/models.py` 中定义 Input/State/Result；
4. 在 `scripts/skill.py` 中实现 `run` 和 `on_stop`；
5. 声明 `required_actions` 和 `stop_actions`；
6. 使用 `make check && make test` 验证；
7. 使用本地 `semantic-pilot skill run` 调试；
8. 发布到 Server Registry。

### 2. 新增一个 Ability

1. 确定 Action 类型和 schema 版本；
2. 在 `r1pro_abilities/task_models.py` 定义输入模型；
3. 在 Handler 中实现动作；
4. 编写 `ability.manifest.yaml`；
5. 使用 `make check && make test`；
6. 使用 AbilityFramework 验证心跳和 Action；
7. 通过 Robot Skill 验证 `required_actions`；
8. 打包 Ability Zip。

### 3. 接入新设备

1. 在 SDK 中新增型号包；
2. 实现 `RobotBackend`；
3. 提供 Kinematics、Motion 和 Navigation Provider；
4. 编写 RobotDeployment；
5. 使用 Fake Backend 完成契约测试；
6. 使用 MuJoCo 或真实设备验证动作、stop 和 hold；
7. 将 Wheel 加入 Robot Bundle。

## 测试

```bash
# Robot Skill
cd "$SEMANTIC/semantic-skill/robot-skill"
make check
make test

# Ability
cd "$SEMANTIC/semantic-ability/r1pro-ability"
make check
make test
make build

# Robot SDK
cd "$SEMANTIC/semantic-robotsdk/robot-sdk"
make lint
make test
make test-contracts
make build
```

## 边界

- 需要新增任务：写 Robot Skill；
- 需要新增原子动作：写 Ability；
- 需要接入新设备：写 Robot SDK；
- Skill 不能绕过 Ability 直接访问设备；
- 停止必须通过 Pilot、Ability 和 SDK 的 stop/hold 证据；
- 真实模型不代替 Fake 或 MuJoCo 物理测试。

## 深入阅读

- [Robot Skill](/developer/core-modules/robot/robot-skill/)；
- [Ability](/developer/core-modules/robot/ability/)；
- [Robot SDK 与新型号接入](/developer/core-modules/robot/robot-sdk/)；
- [第五章：Robot Skill、Stage 与 Action](/developer/quickstart/chapter_05_robot_skill/)；
- [第六章：Ability、Handler 与 Robot SDK](/developer/quickstart/chapter_06_ability_sdk/)。
