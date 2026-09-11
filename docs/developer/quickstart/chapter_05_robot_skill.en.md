---
title: "Chapter 5: Robot Skill, Stage, and Action"
linkTitle: "Chapter 5: Robot Skill"
weight: 25
description: "Let a Robot SubTask in a Workflow enter a Robot Skill, and observe Stage, Action, Feedback, and results."
aliases:
  - /developer/quickstart/chapter_04_robot_skill/
---

**Goal of this chapter**: understand and verify how a Robot Skill splits a Robot SubTask into Stages, calls Abilities through Actions, and produces recoverable, observable execution results.

## What a Robot Skill is

A Robot Skill is the task-orchestration unit on the robot side. It is responsible only for:

- Reading Robot SubTask input;
- Advancing by Stage;
- Calling declared Actions;
- Reporting Feedback and Observation;
- Saving checkpoints;
- Handling stop and recovery.

It **must not** import Robot SDK, ROS, MuJoCo, Isaac, or a model library directly. Device details must be implemented through Ability and Robot SDK.

## Code locations

- Skill source: `semantic-skill/robot-skill/semantic_robot_skills/skills/`;
- Worker Runtime SDK: `semantic-skill/robot-skill/semantic_robot_skill_sdk/`;
- Built-in Skills: `grasp-object`, `place-object`, `semantic-navigation`;
- Pilot: `semantic-framework/cmd/semantic-pilot`;
- Local debug example: `semantic-framework/examples/mujoco-skill-debug/`.

## Inspect a real Skill

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"
sed -n '1,220p' semantic_robot_skills/skills/grasp_object/SKILL.md
```

You should see:

- `name` / `version`;
- `entrypoint` / `stop_entrypoint`;
- `input_model` / `state_model` / `result_model`;
- `required_actions`;
- `stop_actions`;
- `debug_input`.

All Actions currently must use `schema_version: 2`.

## Understand the Stage entry

```bash
sed -n '1,220p' semantic_robot_skills/skills/semantic_navigation/scripts/skill.py
```

The entry dispatches on the current state's `stage`:

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

`SkillContext` is the only runtime interface a Skill may use. It includes `input()`, `load_state()`, `checkpoint()`, `execute()`, `report()`, `request_agent()`, `execute_stop()`, and more.

## Preconditions

- The Chapter 4 Workflow exists and has a Robot SubTask;
- The Chapter 2 Runtime or a Runtime Installation is available;
- AbilityFramework and the required Abilities are started;
- The current Robot is not occupied by both a resident Pilot and a local debug command.

## Path A: observe Robot Execution through the product chain

If your Robot already joined the Server through Chapter 7, the recommended path is to observe from Studio:

1. Open the Project Workflow panel;
2. Find the Robot Task;
3. Inspect the SubTask;
4. Open Robot Execution;
5. Observe Stage, Action, Feedback, Observation, and Artifact.

This path does not require running a Worker by hand. Pilot starts the desired Skill version sent by the Server.

## Path B: run a Skill locally (development debug)

To verify only the Skill–Ability contract, you can bypass Workflow and Agent and use Pilot locally:

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

Notes:

- `--skill` must be exact `name@version`;
- Local mode does not assemble an Agent. `agent.request` fails;
- The same Robot cannot be controlled by a resident Pilot and a local command at the same time.

## Verify the Worker protocol (optional)

You can start a Worker directly to debug Stage logic:

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"

python -m semantic_robot_skill_sdk.worker \
  --skill-dir semantic_robot_skills/skills/semantic_navigation
```

Worker stdin/stdout allow only the JSON-RPC 2.0 line protocol. Do not print ordinary logs or `print()`.

## Expected output

In a local run, `events.jsonl` should contain:

```text
stage.running
action.started
feedback
stage.completed
```

`result.json` should contain the Skill's final result, for example `HeldObjectState` or a navigation arrival verification result.

On the product chain, the Studio Robot Execution panel should show:

```text
Current Stage
Current Action
Feedback sequence
Observation
Artifact
Terminal state
```

## Tests

```bash
cd "$SEMANTIC/semantic-skill/robot-skill"

make check
make test
```

`make test` covers:

- JSON-RPC Worker;
- Skill package contract;
- Action schema;
- checkpoint;
- stop;
- the three built-in Skills.

## Common failures

- **Version mismatch**: confirm `--skill` is exact `name@version` and exists in the Registry or catalog;
- **Action cannot match**: check the Skill's `required_actions` against the Ability Manifest `actionType@schemaVersion`;
- **Worker has no output**: a Worker can only output JSON-RPC. Business logs must not go to stdout;
- **Skill cannot import a device library**: this is a design constraint. Device calls must go through Ability and SDK;
- **Local direct run failed**: confirm AbilityFramework is started and the matching Ability heartbeat is running.

## Chapter summary

- A Robot Skill owns staged task orchestration;
- Stage, checkpoint, and events make a physical task recoverable;
- `required_actions` is the exact Skill–Ability contract;
- The Worker runs in an isolated process and talks to Pilot over JSON-RPC.

## Next chapter

Continue to [Chapter 6: Ability, Handler, and Robot SDK](chapter_06_ability_sdk.en.md) and connect Actions to a real device implementation.
