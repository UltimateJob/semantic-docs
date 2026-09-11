---
title: "Component Integration"
linkTitle: "Component Integration"
weight: 50
description: "Connect Semantic's concrete implementations: models, tools, Robot Skills, Abilities, Robot SDK, Runtime, Scene, and Studio."
---

Component Integration explains **how a concrete implementation is connected**. It does not re-explain core abstractions. Core abstractions and design boundaries are in [Core Modules](../core-modules/_index.en.md). Ready-to-run examples are in the [Cookbook](../cookbook/_index.en.md).

## Integration catalog

### Agent / Model

Let an Agent use a concrete model service.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| mock | `semantic-framework` | `configs/semantic-server.yaml` | `semantic doctor` |
| OpenAI-compatible | `semantic-framework` | `llm.providers.<name>` | Agent Run |
| Agent Skill | `semantic-framework` | `configs/skills/` | `/api/v1/skills` |
| Tool / MCP | `semantic-framework` | `configs/semantic-server.yaml` | `/api/v1/tools` |

### Workflow / Robot Skill

Turn an Agent plan into an executable Robot task.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| Workflow | `semantic-framework` | `internal/workflow/` | `go test ./tests/integration/` |
| semantic-navigation | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/semantic_navigation/` | `make test` |
| grasp-object | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/grasp_object/` | `make test` |
| place-object | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/place_object/` | `make test` |

### Ability

Implement concrete atomic actions.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| navigation | `semantic-ability/r1pro-ability` | `abilities/r1pro-navigation/` | `make check && make test` |
| manipulator_motion | `semantic-ability/r1pro-ability` | `abilities/r1pro-manipulator-motion/` | `make check && make test` |
| end_effector | `semantic-ability/r1pro-ability` | `abilities/r1pro-end-effector/` | `make check && make test` |
| robot_state | `semantic-ability/r1pro-ability` | `abilities/r1pro-robot-state/` | `make check && make test` |
| sensor_capture | `semantic-ability/r1pro-ability` | `abilities/r1pro-sensor-capture/` | `make check && make test` |
| object_perception | `semantic-ability/r1pro-ability` | `abilities/r1pro-object-perception/` | `make check && make test` |
| grasp_planning | `semantic-ability/r1pro-ability` | `abilities/r1pro-grasp-planning/` | `make check && make test` |

### Robot SDK / Backend

Connect a concrete device or simulation.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| Fake | `semantic-robotsdk/robot-sdk` | `packages/core/`, `packages/r1pro/backends/fake.py` | `make test` |
| MuJoCo | `semantic-robotsdk/robot-sdk` | `packages/r1pro/backends/mujoco.py` | `make test-r1pro` |
| Franka | `semantic-robotsdk/robot-sdk` | `packages/franka/` | `make test-franka` |
| Robot Bundle | `semantic-robot-deployment` | `type-packages/` | `make verify` |

### Runtime / Scene

Provide the environment.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| native-mujoco | `semantic-simulation/mujoco-runtime` | `plugin_mujoco.main:run` | `make test-native` |
| robosuite | `semantic-simulation/mujoco-runtime` | `profiles/robosuite/` | `make test-robosuite-real` |
| LIBERO | `semantic-simulation/mujoco-runtime` | `profiles/libero/` | `make test-libero-real` |
| Scene Package | `semantic-scene/mujoco-asset` | `scene/` | `python -m json.tool asset-catalog.v1.json` |

### Studio / Event

Observe and intervene.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| Studio | `semantic-web` | `src/views/StudioView.vue` | `npm run test:e2e` |
| Panel | `semantic-web` | `src/studio/panelRegistry.js` | `npm run test` |
| Interaction | `semantic-web` | `src/components/interaction/` | `npm run test -- v030-interaction-renderers` |
| WebSocket | `semantic-web` | `src/ws/`, `src/studio/subscription.js` | `npm run test:e2e` |

### Product chain

Combine the implementations above into an acceptable system.

| Implementation | Repository | Entry | Verification |
|---|---|---|---|
| Fake product chain | `semantic-framework` | `tests/gate/v050_real_gate.py` | `make test-v050-real-gate` |
| MuJoCo product chain | `semantic-framework` | `tests/gate/v050_mujoco_product.py` | `make test-v050-mujoco-product` |
| Real-model product chain | `semantic-framework` | `tests/gate/v050_mujoco_deepseek.py` | `make test-v050-mujoco-deepseek-single` |

## Integration order

1. Verify locally in the component first;
2. Then verify adjacent interfaces;
3. Use Fake to verify the full state machine;
4. Use MuJoCo to verify real physics;
5. Finally use a real model to verify Agent decisions.

Do not treat a skip as a pass when a real device, real assets, or a real model is missing.

## Related docs

- [Device Integration](device/_index.en.md): Pilot, Ability, SDK, Deployment;
- [Simulation Integration](simulation/_index.en.md): Runtime, Scene, Runtime Installation;
- [End-to-End Integration](end-to-end/_index.en.md): full product-chain verification;
- [Component interfaces and events](../reference/api/protocols.en.md): protocol boundaries;
- [Cookbook](../cookbook/_index.en.md): real runnable examples.
