---
title: "发布记录 & 迁移指引"
linkTitle: "发布记录"
weight: 80
description: "Semantic 产品和各组件的版本变化、兼容矩阵与迁移说明。"
---

本节独立记录版本变化，不把迁移信息埋在参考或 FAQ 中。Semantic 是多仓系统，产品版本、Framework、Web、Robot SDK、Ability、Robot Skill、Runtime Pack 和 Robot Bundle 可以有独立版本。

## 版本阅读顺序

1. 先确认产品版本和目标组件版本；
2. 阅读对应版本的新增能力和破坏性变化；
3. 查看配置、Action Schema 和制品升级顺序；
4. 按迁移步骤在 Fake 或仿真环境验证；
5. 最后进入真实设备或真实模型链路。

## 发布记录

- [v0.5.0（开发中）](/releases/v0.5.0/)：受管 MuJoCo Robot 生命周期、Robot Skill 人工调试、拆码垛产品链与 v050 Gate 工具链。
- [v0.4.0](/releases/v0.4.0/)：MuJoCo 仿真工作台、Runtime Pack 与 Scene 资产体系。
- [v0.3.0](/releases/v0.3.0/)：显式 Plan Mode、Workflow/Task/SubTask 计划域与内置 Semantic Map。
- [v0.2.0](/releases/v0.2.0/)：首个公开基座。

> v0.3.0 及更早版本有 Framework/Web tag 可考；v0.4.0 与 v0.5.0 的版本边界基于 git 历史与版本元数据提交重建，发布前需负责人确认。

后续版本记录应包含：

- 新增能力；
- 破坏性变化；
- 配置迁移；
- Action Schema 变化；
- 组件兼容矩阵；
- 制品升级顺序；
- 回滚方式；
- 已知限制和弃用计划。

## 兼容矩阵

矩阵基于各仓 git 历史、版本元数据提交与 `type-packages/*/bundle.yaml` 推断。v0.2.0/v0.3.0 有 tag 可考；v0.4.0/v0.5.0 组合为推断值，不确定处已标注 TODO(确认)。

| 产品版本 | Framework | Web | Robot SDK（core / r1pro） | AbilityFramework（ability_py） | Ability 包（r1pro-abilities） | Robot Skill SDK | Robot Skill（r1pro-mujoco） | Runtime Pack（plugin-mujoco） | Robot Bundle |
|---|---|---|---|---|---|---|---|---|---|
| v0.2.0（2026-08-08） | 0.2.0 | 0.2.0 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 |
| v0.3.0（2026-08-09） | 0.3.0 | 0.3.0 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 |
| v0.4.0（2026-08-12，TODO(确认)：无 tag） | 0.4.0-dev | 0.4.0-dev | 基座开发中 | 不适用 | 开发中 | 开发中 | 开发中 | v0.4 重构版（TODO(确认)：0.4.0.dev0 边界） | 不适用 |
| v0.5.0-dev（2026-08-15 起，未发布） | 0.5.0-dev | 0.5.0-dev | 0.5.0.dev0 / 0.5.0.dev0 | 0.4.0 | 0.4.0.dev0 | 0.1.0.dev0 | grasp-object、semantic-navigation、place-object（示例引用 0.4.17，TODO(确认)：当前精确版本） | 0.4.0.dev0 | r1pro-mujoco 0.5.0-dev、r1pro-fake 0.5.0-dev |

依据与备注：

- v0.2.0/v0.3.0 机器人链路组件"不适用"：semantic-framework/CHANGELOG.md 与 semantic-web/CHANGELOG.md 明确 Simulation、Pilot、Robot Skill、AbilityFramework 和 Robot 执行不进入这两个版本。
- v0.5.0-dev 组件版本取自 `semantic-robot-deployment/type-packages/r1pro-mujoco/bundle.yaml` 与 `type-packages/r1pro-fake/bundle.yaml` 的 `artifacts.pythonWheels` 锁定清单，以及 semantic-simulation/mujoco-runtime 的 `pyproject.toml`（`semantic-plugin-mujoco 0.4.0.dev0`）。
- Scene 资产仓（semantic-scene/mujoco-asset）无独立版本号，按版本分段：v0.4.0 起提供拆码垛场景与 Layout 模板（@4027725），v0.5.0-dev 期对齐周转箱侧槽与拆码垛布局（@e11d6dc）。使用前需 `git lfs pull`。
- Bundle 激活要求 Framework 版本与 Bundle 版本配套（`refresh-v050-mujoco-bundle` 流程），跨大版本混用 Bundle 与 Server 需重新走制品升级顺序。

## 版本边界

- Robot Skill 使用精确 `name@version`；
- Ability 使用 `actionType@schemaVersion`；
- Python 包遵循 PEP 440，Go/Node 包使用各自版本格式；
- Runtime Pack 和 Robot Bundle 必须记录内部包含的精确组件版本和校验值。
