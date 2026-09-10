---
title: "Cookbook"
linkTitle: "Cookbook"
weight: 30
description: "Find real Semantic examples, configuration templates, minimal commands, and pass criteria by development scenario."
aliases:
  - /developer/cookbook.md
---

The Cookbook is an index of real code and examples. It does not re-explain core abstractions. Every entry gives: repository, entry point, how to run it, and the pass criteria. To understand the design, go back to [Core Modules](../core-modules/_index.en.md). To build the product chain continuously, use the [Quick Start](../quickstart/_index.en.md).

## Agents and intelligence

### Minimal Agent Skill

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `configs/skills/` |
| Goal | Extend Agent domain knowledge with one `SKILL.md` |
| Command | `go test ./internal/skill/... -count=1` |
| Pass criteria | `GET /api/v1/skills` shows the new Skill, and the target role `skill_names` includes it |
| Related tutorial | [Chapter 3](../quickstart/chapter_03_agent_skill.en.md) |

### Agent Profile and Team

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `configs/agents/`, `configs/agents/teams/default.yaml` |
| Goal | Change role permissions, tools, Skills, and collaboration |
| Command | `go test ./internal/agent/... -count=1` |
| Pass criteria | Model, tools, and Skills in `GET /api/v1/agents` match the role configuration |
| Related tutorial | [Chapter 3](../quickstart/chapter_03_agent_skill.en.md) |

### Model Provider

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `llm.providers` in `configs/semantic-server.yaml` |
| Goal | Configure a mock or real model |
| Command | `semantic doctor` |
| Pass criteria | doctor reports no model-key errors, and an Agent Run can start |
| Related tutorial | [Chapter 3](../quickstart/chapter_03_agent_skill.en.md) |

## Workflow and tasks

### Depalletizing Workflow

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `configs/skills/workflow/depalletizing-workflow-planning/`, `internal/workflow/` |
| Goal | Generate a Plan Proposal from a user goal and approve it as a Workflow |
| Command | `go test ./tests/integration/ -run TestV030Workflow -count=1` |
| Pass criteria | Plan, Workflow, Task, and SubTask are visible in Studio |
| Related tutorial | [Chapter 4](../quickstart/chapter_04_workflow.en.md) |

### State recovery

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `internal/store/` |
| Goal | Verify Workflow state recovery after a Server restart |
| Command | `go test ./internal/store/... -count=1` |
| Pass criteria | State, revision, and migrations are not lost or executed twice |

## Robot capabilities

### Minimal Robot Skill

| Item | Content |
|---|---|
| Repository | `semantic-skill/robot-skill` |
| Entry | `tests/test_skill/` |
| Goal | Create a minimal Skill that uses read-only Actions |
| Command | `make check && make test` |
| Pass criteria | Package contract, frontmatter, entry points, and required_actions all pass |
| Related tutorial | [Chapter 5](../quickstart/chapter_05_robot_skill.en.md) |

### Navigation Skill

| Item | Content |
|---|---|
| Repository | `semantic-skill/robot-skill` |
| Entry | `semantic_robot_skills/skills/semantic_navigation/` |
| Goal | Split a navigation task into four Stages: validate, plan, navigate, verify |
| Command | `python -m pytest -p no:cacheprovider -q semantic_robot_skills/skills/semantic_navigation/tests` |
| Pass criteria | Stage, checkpoint, Action, and recovery logic all pass |
| Related tutorial | [Chapter 5](../quickstart/chapter_05_robot_skill.en.md) |

### Grasp Skill

| Item | Content |
|---|---|
| Repository | `semantic-skill/robot-skill` |
| Entry | `semantic_robot_skills/skills/grasp_object/` |
| Goal | Execute one grasp and produce a HeldObjectState |
| Command | `make test` |
| Pass criteria | Input, state, result, and stop paths all pass |
| Related tutorial | [Chapter 5](../quickstart/chapter_05_robot_skill.en.md) |

### Ability Manifest

| Item | Content |
|---|---|
| Repository | `semantic-ability/r1pro-ability` |
| Entry | `abilities/r1pro-grasp-planning/` |
| Goal | Declare Action, schema, input model, and Handler |
| Command | `make check && make test` |
| Pass criteria | Manifest matches the Pydantic model, and heartbeat can enter running |
| Related tutorial | [Chapter 6](../quickstart/chapter_06_ability_sdk.en.md) |

## Environment and Runtime

### MuJoCo Runtime

| Item | Content |
|---|---|
| Repository | `semantic-simulation/mujoco-runtime` |
| Entry | `plugin_mujoco.main:run` |
| Goal | Start a source-development Runtime |
| Command | `uv run plugin-mujoco` |
| Pass criteria | `/healthz` returns ok, and `/api/v1/scenes` lists scenes |
| Related tutorial | [Chapter 2](../quickstart/chapter_02_simulation.en.md) |

### Scene Package

| Item | Content |
|---|---|
| Repository | `semantic-scene/mujoco-asset` |
| Entry | `scene/palletizing_depalletizing_tote_v1/` |
| Goal | Provide a Scene that includes totes and Layouts |
| Command | `python -m json.tool asset-catalog.v1.json >/dev/null` |
| Pass criteria | `asset-manifest.yaml`, `scene_info.yaml`, and Layouts can load |
| Related tutorial | [Chapter 2](../quickstart/chapter_02_simulation.en.md) |

## Studio and observation

### Studio panel

| Item | Content |
|---|---|
| Repository | `semantic-web` |
| Entry | `src/studio/panelRegistry.js` |
| Goal | Add an observation panel |
| Command | `npm run test && npm run test:e2e` |
| Pass criteria | The panel can open, survive refresh, and persist layout |
| Related tutorial | [Chapter 8](../quickstart/chapter_08_studio.en.md) |

### Interaction Renderer

| Item | Content |
|---|---|
| Repository | `semantic-web` |
| Entry | `src/components/interaction/rendererRegistry.js` |
| Goal | Support a new `uiKind` |
| Command | `npm run test -- v030-interaction-renderers` |
| Pass criteria | Submit payload, cancel, skip, and restore behavior pass exactly |
| Related tutorial | [Chapter 8](../quickstart/chapter_08_studio.en.md) |

## Product Gate

### MuJoCo Skill debug

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `examples/mujoco-skill-debug/` |
| Goal | Locally verify Runtime, Ability, Pilot, and Skill |
| Command | `semantic-pilot skill run ...` |
| Pass criteria | events and result files are complete, and Ability heartbeat is running |
| Related tutorial | [Chapter 5](../quickstart/chapter_05_robot_skill.en.md) |

### Fake product Gate

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `tests/gate/v050_real_gate.py` |
| Goal | Verify the full product state machine |
| Command | `make test-v050-real-gate` |
| Pass criteria | Server, Web, two Robots, seven Ability classes, and three Skills all converge |
| Related tutorial | [Chapter 9](../quickstart/chapter_09_product_gate.en.md) |

### MuJoCo product Gate

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `tests/gate/v050_mujoco_product.py` |
| Goal | Verify the product chain in a real physics environment |
| Command | `make test-v050-mujoco-product` |
| Pass criteria | Scene, Runtime, physical motion, stop, and Studio display stay consistent |
| Related tutorial | [Chapter 9](../quickstart/chapter_09_product_gate.en.md) |

### Real-model Gate

| Item | Content |
|---|---|
| Repository | `semantic-framework` |
| Entry | `tests/gate/v050_mujoco_deepseek.py` |
| Goal | Verify Conversation, Plan, and Workflow with a real model |
| Command | `make test-v050-mujoco-deepseek-single` |
| Pass criteria | A real model can complete one full product chain |
| Related tutorial | [Chapter 9](../quickstart/chapter_09_product_gate.en.md) |

## Usage notes

- Learn abstractions: start with [Core Modules](../core-modules/_index.en.md);
- Copy and run: first satisfy the [Quick Start](../quickstart/_index.en.md) prerequisites;
- Cross-repository integration: use [End-to-End Integration](../integration/end-to-end/_index.en.md);
- Verify before release: use [Chapter 9: Full product Gate](../quickstart/chapter_09_product_gate.en.md);
- If an entry is missing: follow the README, Makefile, and test entry on the corresponding repository's current branch.
