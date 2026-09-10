---
title: "Chapter 6: Ability, Handler, and Robot SDK"
linkTitle: "Chapter 6: Ability and SDK"
weight: 26
description: "Have an Ability Handler execute the Action a Skill declared, and connect Fake, MuJoCo, or a real device through Robot SDK."
---

**Goal of this chapter**: route an Action of `type@schema_version` to an Ability, then let Robot SDK land it on a concrete Backend.

## What an Ability is

An Ability is an atomic robot capability. It turns an Action issued by a Skill into concrete device behavior, for example route planning, end-effector motion, gripper control, object localization, or tool-load verification.

A Robot Skill declares dependencies:

```yaml
required_actions:
  - { type: perception.locate_object, schema_version: 2 }
  - { type: gripper.close, schema_version: 2 }
```

The Ability Manifest must provide the same `actionType` and `schemaVersion`. Otherwise Pilot will not route.

## Code locations

- Ability: `semantic-ability/r1pro-ability/abilities/`;
- Shared business package: `semantic-ability/r1pro-ability/r1pro_abilities/`;
- AbilityFramework: `semantic-ability/ability-runtime/`;
- Robot SDK: `semantic-robotsdk/robot-sdk/packages/`;
- Example config: `semantic-robotsdk/robot-sdk/examples/`.

## Seven Ability roles

| Role | Typical Tasks |
|---|---|
| `navigation` | PlanRoute, FollowRoute, VerifyArrival |
| `manipulator_motion` | MoveEndEffector, FollowWaypoints, LiftHeldObject, MoveToPosture |
| `end_effector` | SetOpening, CloseUntilContact, Release, HoldObject |
| `robot_state` | GetRobotState, VerifyToolLoad |
| `sensor_capture` | CaptureRGBD |
| `object_perception` | LocateObject, VerifyPregrasp, VerifyGrasp, ObservePlacementTarget, VerifyPlacement |
| `grasp_planning` | GenerateCandidates, PlanTransportPosture |

Every Ability also provides the two common Tasks `GetExecution` and `StopExecution`.

## Inspect a real Manifest

```bash
cd "$SEMANTIC/semantic-ability/r1pro-ability"
sed -n '1,240p' abilities/r1pro-grasp-planning/ability.manifest.yaml
```

You should see:

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

`physical` says whether the Task has a physical effect. The Manifest is the only metadata source for Pilot routing and UI display.

## What Robot SDK is

Robot SDK is the typed interface between Ability and device. It provides:

- Robot state;
- Capability description;
- Motion planning;
- End-effector control;
- Sensors;
- Commands, Feedback, and stop;
- Fake, MuJoCo, and real-device Backends.

The SDK does not store Workflow, Robot Skill, or Ability business state.

## Inspect SDK config

```bash
cd "$SEMANTIC/semantic-robotsdk/robot-sdk"
sed -n '1,260p' examples/robot-deployment.mujoco.yaml
```

Key fields include:

- `robot.id`;
- `robot.model`;
- `robot.backend`;
- `sdk.endpoint`;
- `frames`;
- `tools`;
- `safety`;
- `ability_framework.endpoint`;
- `pilot.robot_skill_directory`.

You can override the Endpoint with environment variables:

```bash
export SEMANTIC_ROBOT_CONFIG="$PWD/examples/robot-deployment.mujoco.yaml"
export SEMANTIC_ROBOT_SDK_ENDPOINT="http://127.0.0.1:18090"
```

## Build Robot SDK

```bash
cd "$SEMANTIC/semantic-robotsdk/robot-sdk"

make lock
make lint
make test
make test-contracts
make build
```

The artifacts are three Wheels:

```text
semantic-robot-sdk-core
semantic-robot-sdk-r1pro
semantic-robot-sdk-franka
```

Real-model specialized tests need matching assets:

```bash
make test-r1pro
make test-franka
```

These tests need environment variables such as `R1PRO_ASSET_ROOT` and `FRANKA_MODEL_ROOT`. A skip cannot substitute for a pass.

## Build and test Ability

```bash
cd "$SEMANTIC/semantic-ability/r1pro-ability"

make check
make test
make build
```

`make build` builds the shared business Wheel:

```text
semantic-r1pro-abilities-<version>.whl
```

The seven Ability Zips must be packed separately with `ability-scaffold pack` following the repository README.

## Start AbilityFramework

AbilityFramework is provided by `semantic-ability/ability-runtime`. Development environments usually start it from a Robot Bundle. For a minimal verification you can use `debug-stack` directly:

```bash
cd "$SEMANTIC/semantic-robot-deployment"

semantic-robot-instance debug-stack \
  --instance <实例目录>
```

This starts AbilityFramework and the seven Abilities, but does not start Pilot and does not connect to the Server.

## Verify Abilities are available

1. AbilityFramework can start;
2. The seven Abilities can activate;
3. heartbeat reports `running`;
4. The target Action exists in the Manifest;
5. The Skill's `required_actions` can match exactly.

If you use Studio or the device center, you can inspect Ability status on the device detail page.

## Connection to Chapter 5

After AbilityFramework and the required Abilities are running, re-run the local Skill from Chapter 5:

```bash
cd "$SEMANTIC/semantic-framework"
.output/bin/semantic-pilot skill run ...
```

You should see the Action routed, not fail at Pilot.

## Test boundaries

- Fake Backend: contract, state, and stop tests;
- MuJoCo Backend: physical-behavior tests;
- Real device: only in an approved safe environment;
- Real model: Agent decisions. It does not replace Robot physical-chain tests.

## Common failures

- **Action not found**: check Skill `required_actions` against Ability Manifest `actionType`;
- **Schema mismatch**: confirm both sides use `schema_version: 2`;
- **Ability does not start**: check `robotDeploymentPath`, `executionStorePath`, and model config;
- **SDK Endpoint unreachable**: check `SEMANTIC_ROBOT_SDK_ENDPOINT` and the Runtime port;
- **Stop did not finish**: check stop/hold evidence from Pilot, Ability, and SDK. Do not look only at process exit.

## Chapter summary

- Ability is the implementation boundary of an Action;
- The Manifest is the metadata Pilot routes on;
- Handler owns action semantics. Robot SDK owns device abstraction;
- SDK, Ability, and Skill versions must match exactly.

## Next chapter

Continue to [Chapter 7: Pilot, Robot Deployment, and Device Join](chapter_07_device.en.md) and assemble Ability and SDK into a device instance.
