---
title: "组件集成"
linkTitle: "组件集成"
weight: 50
description: "接入 Semantic 的具体实现：模型、工具、Robot Skill、Ability、Robot SDK、Runtime、Scene 和 Studio。"
---

组件集成说明**具体实现怎么接入**，不重复解释核心抽象。核心抽象和设计边界见[核心模块](/developer/core-modules/)；现成可运行例子见[Cookbook](/developer/cookbook/)。

## 集成目录

### Agent / Model

让 Agent 使用具体模型服务。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| mock | `semantic-framework` | `configs/semantic-server.yaml` | `semantic doctor` |
| OpenAI-compatible | `semantic-framework` | `llm.providers.<name>` | Agent Run |
| Agent Skill | `semantic-framework` | `configs/skills/` | `/api/v1/skills` |
| Tool / MCP | `semantic-framework` | `configs/semantic-server.yaml` | `/api/v1/tools` |

### Workflow / Robot Skill

把 Agent 计划变成可执行 Robot 任务。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| Workflow | `semantic-framework` | `internal/workflow/` | `go test ./tests/integration/` |
| semantic-navigation | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/semantic_navigation/` | `make test` |
| grasp-object | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/grasp_object/` | `make test` |
| place-object | `semantic-skill/robot-skill` | `semantic_robot_skills/skills/place_object/` | `make test` |

### Ability

实现具体原子动作。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| navigation | `semantic-ability/r1pro-ability` | `abilities/r1pro-navigation/` | `make check && make test` |
| manipulator_motion | `semantic-ability/r1pro-ability` | `abilities/r1pro-manipulator-motion/` | `make check && make test` |
| end_effector | `semantic-ability/r1pro-ability` | `abilities/r1pro-end-effector/` | `make check && make test` |
| robot_state | `semantic-ability/r1pro-ability` | `abilities/r1pro-robot-state/` | `make check && make test` |
| sensor_capture | `semantic-ability/r1pro-ability` | `abilities/r1pro-sensor-capture/` | `make check && make test` |
| object_perception | `semantic-ability/r1pro-ability` | `abilities/r1pro-object-perception/` | `make check && make test` |
| grasp_planning | `semantic-ability/r1pro-ability` | `abilities/r1pro-grasp-planning/` | `make check && make test` |

### Robot SDK / Backend

连接具体设备或仿真。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| Fake | `semantic-robotsdk/robot-sdk` | `packages/core/`、`packages/r1pro/backends/fake.py` | `make test` |
| MuJoCo | `semantic-robotsdk/robot-sdk` | `packages/r1pro/backends/mujoco.py` | `make test-r1pro` |
| Franka | `semantic-robotsdk/robot-sdk` | `packages/franka/` | `make test-franka` |
| Robot Bundle | `semantic-robot-deployment` | `type-packages/` | `make verify` |

### Runtime / Scene

提供环境。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| native-mujoco | `semantic-simulation/mujoco-runtime` | `plugin_mujoco.main:run` | `make test-native` |
| robosuite | `semantic-simulation/mujoco-runtime` | `profiles/robosuite/` | `make test-robosuite-real` |
| LIBERO | `semantic-simulation/mujoco-runtime` | `profiles/libero/` | `make test-libero-real` |
| Scene Package | `semantic-scene/mujoco-asset` | `scene/` | `python -m json.tool asset-catalog.v1.json` |

### Studio / Event

观察和介入。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| Studio | `semantic-web` | `src/views/StudioView.vue` | `npm run test:e2e` |
| Panel | `semantic-web` | `src/studio/panelRegistry.js` | `npm run test` |
| Interaction | `semantic-web` | `src/components/interaction/` | `npm run test -- v030-interaction-renderers` |
| WebSocket | `semantic-web` | `src/ws/`、`src/studio/subscription.js` | `npm run test:e2e` |

### 产品链

把上述实现组合成可验收系统。

| 实现 | 仓库 | 入口 | 验证 |
|---|---|---|---|
| Fake 产品链 | `semantic-framework` | `tests/gate/v050_real_gate.py` | `make test-v050-real-gate` |
| MuJoCo 产品链 | `semantic-framework` | `tests/gate/v050_mujoco_product.py` | `make test-v050-mujoco-product` |
| 真实模型产品链 | `semantic-framework` | `tests/gate/v050_mujoco_deepseek.py` | `make test-v050-mujoco-deepseek-single` |

## 集成顺序

1. 先在组件本地验证；
2. 再验证相邻接口；
3. 用 Fake 验证完整状态机；
4. 用 MuJoCo 验证真实物理；
5. 最后用真实模型验证 Agent 决策。

不要在缺少真实设备、真实资产或真实模型时，把跳过当作通过。

## 相关文档

- [设备集成](/developer/integration/device/)：Pilot、Ability、SDK、Deployment；
- [仿真集成](/developer/integration/simulation/)：Runtime、Scene、Runtime Installation；
- [端到端集成](/developer/integration/end-to-end/)：完整产品链验证；
- [组件接口与事件](/developer/reference/api/protocols/)：协议边界；
- [Cookbook](/developer/cookbook/)：真实可运行示例。
