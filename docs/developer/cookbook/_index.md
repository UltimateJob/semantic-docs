---
title: "Cookbook"
linkTitle: "Cookbook"
weight: 30
description: "按开发场景查找 Semantic 的真实示例、配置模板、最小命令和验证方式。"
aliases:
  - /developer/cookbook.md
---

Cookbook 是真实代码和示例索引，不重复解释核心抽象。每个条目都给出：仓库、入口、运行方式和通过标准。想理解设计，请回到[核心模块](/developer/core-modules/)；想连续构建产品链，请使用[快速开始](/developer/quickstart/)。

## Agent 与智能能力

### 最小 Agent Skill

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `configs/skills/` |
| 目标 | 用一份 `SKILL.md` 扩展 Agent 领域知识 |
| 命令 | `go test ./internal/skill/... -count=1` |
| 通过标准 | `GET /api/v1/skills` 能看到新 Skill，目标角色 `skill_names` 包含它 |
| 相关教程 | [第三章](/developer/quickstart/chapter_03_agent_skill/) |

### Agent Profile 与 Team

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `configs/agents/`、`configs/agents/teams/default.yaml` |
| 目标 | 修改角色权限、工具、Skill 和协作关系 |
| 命令 | `go test ./internal/agent/... -count=1` |
| 通过标准 | `GET /api/v1/agents` 中模型、工具、Skill 与角色配置一致 |
| 相关教程 | [第三章](/developer/quickstart/chapter_03_agent_skill/) |

### Model Provider

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `configs/semantic-server.yaml` 的 `llm.providers` |
| 目标 | 配置 mock 或真实模型 |
| 命令 | `semantic doctor` |
| 通过标准 | doctor 无模型密钥错误，Agent Run 能启动 |
| 相关教程 | [第三章](/developer/quickstart/chapter_03_agent_skill/) |

## Workflow 与任务

### 拆码垛 Workflow

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `configs/skills/workflow/depalletizing-workflow-planning/`、`internal/workflow/` |
| 目标 | 从用户目标生成 Plan Proposal 并批准为 Workflow |
| 命令 | `go test ./tests/integration/ -run TestV030Workflow -count=1` |
| 通过标准 | Plan、Workflow、Task 和 SubTask 能在 Studio 中显示 |
| 相关教程 | [第四章](/developer/quickstart/chapter_04_workflow/) |

### 状态恢复

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `internal/store/` |
| 目标 | 验证 Server 重启后的 Workflow 状态恢复 |
| 命令 | `go test ./internal/store/... -count=1` |
| 通过标准 | 状态、revision 和迁移不会丢失或重复执行 |

## Robot 能力

### 最小 Robot Skill

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-skill/robot-skill` |
| 入口 | `tests/test_skill/` |
| 目标 | 使用只读 Action 创建最小 Skill |
| 命令 | `make check && make test` |
| 通过标准 | 包契约、frontmatter、入口和 required_actions 校验通过 |
| 相关教程 | [第五章](/developer/quickstart/chapter_05_robot_skill/) |

### Navigation Skill

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-skill/robot-skill` |
| 入口 | `semantic_robot_skills/skills/semantic_navigation/` |
| 目标 | 将导航任务拆成 validate、plan、navigate、verify 四个 Stage |
| 命令 | `python -m pytest -p no:cacheprovider -q semantic_robot_skills/skills/semantic_navigation/tests` |
| 通过标准 | Stage、checkpoint、Action 和恢复逻辑全部通过 |
| 相关教程 | [第五章](/developer/quickstart/chapter_05_robot_skill/) |

### Grasp Skill

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-skill/robot-skill` |
| 入口 | `semantic_robot_skills/skills/grasp_object/` |
| 目标 | 执行一次抓取并产生 HeldObjectState |
| 命令 | `make test` |
| 通过标准 | 输入、状态、结果和停止路径验证通过 |
| 相关教程 | [第五章](/developer/quickstart/chapter_05_robot_skill/) |

### Ability Manifest

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-ability/r1pro-ability` |
| 入口 | `abilities/r1pro-grasp-planning/` |
| 目标 | 声明 Action、schema、输入模型和 Handler |
| 命令 | `make check && make test` |
| 通过标准 | Manifest 与 Pydantic 模型一致，heartbeat 可进入 running |
| 相关教程 | [第六章](/developer/quickstart/chapter_06_ability_sdk/) |

## Environment 与 Runtime

### MuJoCo Runtime

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-simulation/mujoco-runtime` |
| 入口 | `plugin_mujoco.main:run` |
| 目标 | 启动一个源码开发 Runtime |
| 命令 | `uv run plugin-mujoco` |
| 通过标准 | `/healthz` 返回 ok，`/api/v1/scenes` 有场景 |
| 相关教程 | [第二章](/developer/quickstart/chapter_02_simulation/) |

### Scene Package

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-scene/mujoco-asset` |
| 入口 | `scene/palletizing_depalletizing_tote_v1/` |
| 目标 | 提供一个包含周转箱和 Layout 的 Scene |
| 命令 | `python -m json.tool asset-catalog.v1.json >/dev/null` |
| 通过标准 | `asset-manifest.yaml`、`scene_info.yaml` 和 Layout 可加载 |
| 相关教程 | [第二章](/developer/quickstart/chapter_02_simulation/) |

## Studio 与观察

### Studio 面板

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-web` |
| 入口 | `src/studio/panelRegistry.js` |
| 目标 | 新增一个观察面板 |
| 命令 | `npm run test && npm run test:e2e` |
| 通过标准 | 面板能打开、刷新恢复、布局持久化 |
| 相关教程 | [第八章](/developer/quickstart/chapter_08_studio/) |

### Interaction Renderer

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-web` |
| 入口 | `src/components/interaction/rendererRegistry.js` |
| 目标 | 支持新的 `uiKind` |
| 命令 | `npm run test -- v030-interaction-renderers` |
| 通过标准 | 提交载荷、取消、跳过和恢复行为精确通过 |
| 相关教程 | [第八章](/developer/quickstart/chapter_08_studio/) |

## Product Gate

### MuJoCo Skill 调试

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `examples/mujoco-skill-debug/` |
| 目标 | 本地验证 Runtime、Ability、Pilot 和 Skill |
| 命令 | `semantic-pilot skill run ...` |
| 通过标准 | events 和 result 文件完整，Ability heartbeat running |
| 相关教程 | [第五章](/developer/quickstart/chapter_05_robot_skill/) |

### Fake 产品 Gate

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `tests/gate/v050_real_gate.py` |
| 目标 | 验证完整产品状态机 |
| 命令 | `make test-v050-real-gate` |
| 通过标准 | Server、Web、两个 Robot、七类 Ability、三个 Skill 全部收敛 |
| 相关教程 | [第九章](/developer/quickstart/chapter_09_product_gate/) |

### MuJoCo 产品 Gate

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `tests/gate/v050_mujoco_product.py` |
| 目标 | 验证真实物理环境产品链 |
| 命令 | `make test-v050-mujoco-product` |
| 通过标准 | Scene、Runtime、物理运动、停止和 Studio 展示一致 |
| 相关教程 | [第九章](/developer/quickstart/chapter_09_product_gate/) |

### 真实模型 Gate

| 项目 | 内容 |
|---|---|
| 仓库 | `semantic-framework` |
| 入口 | `tests/gate/v050_mujoco_deepseek.py` |
| 目标 | 验证真实模型的 Conversation、Plan 和 Workflow |
| 命令 | `make test-v050-mujoco-deepseek-single` |
| 通过标准 | 真实模型能完成一次完整产品链 |
| 相关教程 | [第九章](/developer/quickstart/chapter_09_product_gate/) |

## 使用建议

- 学习抽象：先读[核心模块](/developer/core-modules/)；
- 复制运行：先满足[快速开始](/developer/quickstart/)的前置条件；
- 跨仓联调：使用[端到端集成](/developer/integration/end-to-end/)；
- 发布前验证：使用 [第九章：完整产品 Gate](/developer/quickstart/chapter_09_product_gate/)；
- 某个入口不存在：以对应仓库当前分支的 README、Makefile 和测试入口为准。
