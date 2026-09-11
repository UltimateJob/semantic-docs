---
title: "Robot Capabilities"
linkTitle: "Robot Capabilities"
weight: 30
description: "Use Robot Skill, Ability, and Robot SDK to orchestrate a task into actions and land those actions on a concrete device."
---

**Robot capabilities** answers one question: **how a task is orchestrated into actions, and how those actions land on a device**.

This is Semantic's physical execution. Workflow hands business intent to a Robot Task. A Robot Skill splits the task into Stages. An Ability executes an atomic Action. The Robot SDK connects the concrete device.

## Module composition

| Module | Problem it solves | Typical artifacts |
|---|---|---|
| [Robot Skill](robot-skill.en.md) | How one class of physical task is executed in stages | `SKILL.md`, Stage, Input/State/Result |
| [Ability](ability.en.md) | How one atomic action is executed | Manifest, Task Model, Handler |
| [Robot SDK](robot-sdk.en.md) | How to connect a new device or Backend | Backend, Provider, model package |

## Call chain

```text
Workflow Robot SubTask
→ Pilot
→ Robot Skill Worker
→ required_actions
→ AbilityFramework
→ Ability Handler
→ Robot SDK Backend
→ Fake / MuJoCo / physical device
```

Key constraints:

- A Skill does not import device details;
- An Action matches exactly as `type@schema_version`;
- An Ability owns action semantics;
- The SDK does not store Workflow, Skill, or Ability business state;
- Pilot manages Worker lifecycle and stop.

## Code locations

- Robot Skill: `semantic-skill/robot-skill/`;
- Skill Worker SDK: `semantic-skill/robot-skill/semantic_robot_skill_sdk/`;
- Ability: `semantic-ability/r1pro-ability/`;
- AbilityFramework: `semantic-ability/ability-runtime/`;
- Robot SDK: `semantic-robotsdk/robot-sdk/packages/`;
- Pilot: `semantic-framework/cmd/semantic-pilot/`.

## What a Robot Skill looks like

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

`SKILL.md` declares:

- `name` and `version`;
- `entrypoint` and `stop_entrypoint`;
- `input_model`, `state_model`, `result_model`;
- `required_actions`;
- `stop_actions`.

A Skill uses runtime capabilities only through `SkillContext`. It must not write `print()`. stdout may only output JSON-RPC.

## What an Ability looks like

```text
abilities/<ability_dir>/
├── ability.manifest.yaml
├── main.py
├── package.yaml
├── requirements.txt
├── bin/ability
└── crs/<ability>.yaml
```

The Manifest declares:

- `abilityName`;
- `actionType`;
- `schemaVersion`;
- `physical`;
- `inputModel`;
- `inputFields`;
- `returns`.

Pilot routes a Skill Action to an Ability with `actionType + schemaVersion`.

## What the Robot SDK does

The Robot SDK gives Abilities typed interfaces for:

- robot state and capabilities;
- motion planning;
- end-effector control;
- sensors;
- commands, Feedback, and stop;
- Fake / MuJoCo / physical-device Backends.

It does not need to know Workflow, Skill, or Ability business state.

## Minimal development path

### 1. Add a Robot Skill

1. Create a directory under `semantic_robot_skills/skills/`;
2. Write `SKILL.md`;
3. Define Input/State/Result in `scripts/models.py`;
4. Implement `run` and `on_stop` in `scripts/skill.py`;
5. Declare `required_actions` and `stop_actions`;
6. Verify with `make check && make test`;
7. Debug with local `semantic-pilot skill run`;
8. Publish to the Server Registry.

### 2. Add an Ability

1. Decide the Action type and schema version;
2. Define the input model in `r1pro_abilities/task_models.py`;
3. Implement the action in the Handler;
4. Write `ability.manifest.yaml`;
5. Run `make check && make test`;
6. Verify heartbeat and Action with AbilityFramework;
7. Verify `required_actions` through a Robot Skill;
8. Package the Ability Zip.

### 3. Connect a new device

1. Add a model package in the SDK;
2. Implement `RobotBackend`;
3. Provide Kinematics, Motion, and Navigation Providers;
4. Write a RobotDeployment;
5. Finish contract tests with a Fake Backend;
6. Verify actions, stop, and hold with MuJoCo or a physical device;
7. Add the Wheel to the Robot Bundle.

## Testing

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

## Boundaries

- Need a new task: write a Robot Skill;
- Need a new atomic action: write an Ability;
- Need to connect a new device: write a Robot SDK;
- A Skill must not bypass Ability and access the device directly;
- Stop must go through Pilot, Ability, and SDK stop/hold evidence;
- A real model does not replace Fake or MuJoCo physical tests.

## Further reading

- [Robot Skill](robot-skill.en.md);
- [Ability](ability.en.md);
- [Robot SDK and new models](robot-sdk.en.md);
- [Chapter 5: Robot Skill, Stage, and Action](../../quickstart/chapter_05_robot_skill.en.md);
- [Chapter 6: Ability, Handler, and Robot SDK](../../quickstart/chapter_06_ability_sdk.en.md).
