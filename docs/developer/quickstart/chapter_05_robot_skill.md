---
title: "第五章：Robot Skill、Stage 与 Action"
linkTitle: "第 5 章：Robot Skill"
weight: 25
description: "让 Workflow 中的 Robot SubTask 进入 Robot Skill，并观察 Stage、Action、Feedback 和结果。"
aliases:
  - /developer/quickstart/chapter_04_robot_skill/
---

**本章目标**：理解并验证 Robot Skill 如何把一个 Robot SubTask 拆成 Stage，通过 Action 调用 Ability，并产生可恢复、可观察的执行结果。

## Robot Skill 是什么

Robot Skill 是机器人侧的任务编排单元。它只负责：

- 读取 Robot SubTask 输入；
- 按 Stage 推进；
- 调用已声明的 Action；
- 上报 Feedback 和 Observation；
- 保存 checkpoint；
- 处理停止和恢复。

它**不允许**直接 import Robot SDK、ROS、MuJoCo、Isaac 或模型库。设备细节必须通过 Ability 和 Robot SDK 实现。

## 代码位置

- Skill 源码：`semantic-skill/robot-skill/semantic_robot_skills/skills/`；
- Worker Runtime SDK：`semantic-skill/robot-skill/semantic_robot_skill_sdk/`；
- 内置 Skill：`grasp-object`、`place-object`、`semantic-navigation`；
- Pilot：`semantic-framework/cmd/semantic-pilot`；
- 本地调试示例：`semantic-framework/examples/mujoco-skill-debug/`。

## 查看一个真实 Skill

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"
sed -n '1,220p' semantic_robot_skills/skills/grasp_object/SKILL.md
```

你应看到：

- `name` / `version`；
- `entrypoint` / `stop_entrypoint`；
- `input_model` / `state_model` / `result_model`；
- `required_actions`；
- `stop_actions`；
- `debug_input`。

所有 Action 当前必须使用 `schema_version: 2`。

## 理解 Stage 入口

```bash
sed -n '1,220p' semantic_robot_skills/skills/semantic_navigation/scripts/skill.py
```

入口按当前 state 的 `stage` 分发：

```python
async def run(ctx: SkillContext) -> None:
    ctx.check_cancelled()
    skill_input = ctx.input(SemanticNavigationInput)
    state = ctx.load_state(
        SemanticNavigationState,
        default=SemanticNavigationState(),
    )

    if state.stage == "validate_target":
        await _validate_target(ctx, skill_input, state)
        return
    if state.stage == "plan_route":
        await _plan_route(ctx, skill_input, state)
        return
```

`SkillContext` 是 Skill 唯一能使用的运行时接口，包含 `input()`、`load_state()`、`checkpoint()`、`execute()`、`report()`、`request_agent()`、`execute_stop()` 等方法。

## 前置条件

- 第 4 章的 Workflow 已创建，且存在 Robot SubTask；
- 第 2 章的 Runtime 或 Runtime Installation 可用；
- AbilityFramework 和所需 Ability 已启动；
- 当前 Robot 没有同时被常驻 Pilot 和本地调试命令占用。

## 方式 A：通过产品链观察 Robot Execution

如果你的 Robot 已经通过第 7 章加入 Server，最推荐的方式是从 Studio 观察：

1. 打开 Project 的 Workflow 面板；
2. 找到 Robot Task；
3. 查看 SubTask；
4. 打开 Robot Execution；
5. 观察 Stage、Action、Feedback、Observation 和 Artifact。

这条路径不需要手动运行 Worker，Pilot 会按 Server 下发的 desired Skill 版本启动。

## 方式 B：本地直跑一个 Skill（开发调试）

如果只需要验证 Skill 与 Ability 的契约，可以绕过 Workflow 和 Agent，本地使用 Pilot：

```bash
cd "$SEMANTIC/semantic-framework"

go build -o .output/bin/semantic-pilot ./cmd/semantic-pilot

.output/bin/semantic-pilot skill run \
  --profile "$SEMANTIC/semantic-robotsdk/robot-sdk/examples/robot-deployment.mujoco.yaml" \
  --skill grasp-object@0.4.17 \
  --input "$SEMANTIC/semantic-framework/examples/mujoco-skill-debug/grasp-object.json" \
  --skill-catalog "$SEMANTIC/semantic-skill/robot-skill/semantic_robot_skills/skills" \
  --python <venv>/bin/python \
  --events events.jsonl \
  --result result.json \
  --timeout 10m
```

注意：

- `--skill` 必须精确到 `name@version`；
- 本地模式不会装配 Agent，`agent.request` 会失败；
- 同一 Robot 不能同时被常驻 Pilot 和本地命令控制。

## 验证 Worker 协议（可选）

你可以直接启动 Worker 调试 Stage 逻辑：

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"

python -m semantic_robot_skill_sdk.worker \
  --skill-dir semantic_robot_skills/skills/semantic_navigation
```

Worker 的 stdin/stdout 只允许 JSON-RPC 2.0 行协议，不要输出普通日志或 `print()`。

## 预期输出

本地运行时，`events.jsonl` 应包含：

```text
stage.running
action.started
feedback
stage.completed
```

`result.json` 应包含 Skill 的最终结果，例如 `HeldObjectState` 或导航到达验证结果。

产品链运行时，Studio 的 Robot Execution 面板应显示：

```text
当前 Stage
当前 Action
Feedback 序列
Observation
Artifact
终态
```

## 测试

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"

make check
make test
```

其中 `make test` 会覆盖：

- JSON-RPC Worker；
- Skill package 契约；
- Action schema；
- checkpoint；
- 停止；
- 内置三个 Skill。

## 常见失败

- **版本不匹配**：确认 `--skill` 是精确 `name@version`，且 Registry 或 catalog 中存在；
- **Action 无法匹配**：检查 Skill 的 `required_actions` 与 Ability Manifest 的 `actionType@schemaVersion`；
- **Worker 没有输出**：Worker 只能输出 JSON-RPC，业务日志不能写 stdout；
- **Skill 无法 import 设备库**：这是设计约束，设备调用必须经 Ability 和 SDK；
- **本地直跑失败**：确认 AbilityFramework 已启动，并且对应 Ability heartbeat 为 running。

## 本章小结

- Robot Skill 负责阶段化任务编排；
- Stage、checkpoint 和事件让物理任务可恢复；
- `required_actions` 是 Skill 与 Ability 的精确契约；
- Worker 运行在隔离进程中，通过 JSON-RPC 与 Pilot 通信。

## 下一章

进入[第六章：Ability、Handler 与 Robot SDK](/developer/quickstart/chapter_06_ability_sdk/)，把 Action 连接到真实设备实现。
