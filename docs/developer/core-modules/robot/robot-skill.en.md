---
title: "Robot Skill"
weight: 60
description: "Develop a staged physical task: Stage orchestration, Action calls, Worker protocol, and local debugging."
---

A Robot Skill organizes a robot task into Stages that can be observed, stopped, and recovered. It uses Abilities through Actions and advances execution from Feedback and Observation. On the execution chain it sits below Pilot and above Ability (see [Chapter 5: Robot Skill, Stage, and Action](../../quickstart/chapter_05_robot_skill.en.md)).

Related repositories:

- Worker Runtime SDK and Skill source: `semantic-skill/robot-skill`
- Discovery, install, Worker startup, and execution orchestration: `internal/pilot/` in `semantic-framework` (skillcatalog.go, skillmanager.go, supervisor.go, runtime.go, runner.go)
- Local debug command: `cmd/semantic-pilot/local_skill.go` in `semantic-framework`

## Directory layout

### Repository layout

`semantic-skill/robot-skill` has two parts:

```text
robot-skill/
├── semantic_robot_skill_sdk/       # Worker Runtime SDK（wheel 唯一内容）
│   ├── models.py                   # 协议公共类型（Pydantic v2）
│   ├── context.py                  # SkillContext / ActionHandle 协议
│   ├── rpc_context.py              # RpcSkillContext：Context 方法 → JSON-RPC
│   ├── protocol.py                 # 一行一个 JSON 的 JSON-RPC 2.0 协议
│   ├── worker.py                   # Worker 主入口
│   └── mock.py                     # MockSkillContext（单测用内存 Runtime）
├── semantic_robot_skills/          # 具体 Skill 源码（不进 wheel，由 Registry 单独打包下发）
│   └── skills/
│       ├── grasp_object/           # grasp-object（含 controllers）
│       ├── place_object/           # place-object
│       └── semantic_navigation/    # semantic-navigation（无 controllers，最简）
└── tests/                          # 仓库级跨进程/契约测试
```

### Structure of a single Skill

```text
semantic_navigation/
├── SKILL.md                唯一清单（Pilot 校验入口）
├── requirements.lock       依赖锁定（必须存在，如 pydantic==2.13.4）
├── scripts/
│   ├── __init__.py
│   ├── models.py           Pydantic 输入/状态/结果模型
│   ├── skill.py            run / on_stop 入口
│   └── controller.py       可选：确定性 Controller，组装 Action
├── references/             可选
└── tests/                  Skill 单元测试（MockSkillContext）
```

## SKILL.md frontmatter

SKILL.md is the only manifest (there is no separate `robot-skill.yaml`). Pilot enforces validation on load (`loadSkillDefinition` in `internal/pilot/skillcatalog.go`):

```yaml
---
name: semantic-navigation        # 必填
description: 导航到业务目标...     # 必填
category: robot_skill            # 必须是 robot_skill
version: 0.4.4                   # 必填
runtime:
  api_version: 1                 # 必须为 1
  python: ">=3.11"
  entrypoint: scripts.skill:run                # 必填，文件必须真实存在
  stop_entrypoint: scripts.skill:on_stop       # 必填
  input_model: scripts.models:SemanticNavigationInput      # 三模型必填
  state_model: scripts.models:SemanticNavigationState
  result_model: scripts.models:SemanticNavigationResult
  controllers: {}                # 可选
required_actions:                # 必填非空，每项需 type + schema_version
  - { type: robot.get_state, schema_version: 2 }
  - { type: navigation.plan_route, schema_version: 2 }
  - { type: navigation.follow_route, schema_version: 2 }
  - { type: navigation.verify_arrival, schema_version: 2 }
stop_actions:                    # 必填非空
  - { type: navigation.follow_route, schema_version: 2 }
debug_input: {}                  # 可选：本地调试样例输入。Pilot 不解析它，
---                              # 实际输入必须经 --input 提供
```

Validation rules: every `module:attr` reference is checked so the corresponding `.py` file actually exists; `requirements.lock` must exist; every item in `required_actions` and `stop_actions` must have `type` and `schema_version >= 1`.

### Frontmatter field contract

The table below maps field-by-field to `loadSkillDefinition` in `semantic-framework/internal/pilot/skillcatalog.go` (Go struct yaml tags + validation branches). It is the complete set of reasons Pilot rejects a Skill package:

| Field | Level | Required | Validation (source behavior) |
|---|---|---|---|
| `name` | top-level | Yes | Non-empty; together with `version` forms the `name@version` reference key |
| `category` | top-level | Yes | Must equal `robot_skill` |
| `version` | top-level | Yes | Non-empty |
| `runtime.api_version` | runtime | Yes | Must equal `1` (the Worker side also accepts only 1, `_initialize` in `worker.py`) |
| `runtime.python` | runtime | No | Pilot parses it but does not enforce it; declares Worker runtime requirements |
| `runtime.entrypoint` | runtime | Yes | `module:attr` format; `module` is mapped segment by segment to a `.py` file next to `SKILL.md` and checked with `os.Stat` |
| `runtime.stop_entrypoint` | runtime | Yes | Same as above |
| `runtime.input_model` / `runtime.state_model` / `runtime.result_model` | runtime | Yes (all three required) | Same as above; Pilot checks each file exists |
| `runtime.controllers` | runtime | No | `name → module:attr` map; each reference is likewise checked for a `.py` file |
| `required_actions[]` | top-level | Yes (non-empty) | Each item must have non-empty `type` and `schema_version >= 1` |
| `stop_actions[]` | top-level | Yes (non-empty) | Same as above; when `action.start` carries `stop_action: true`, only Actions on this list may be used |
| `debug_input` | top-level | No | Pilot does not parse it; documentation sample input only. Actual input must come from `--input` |
| (file) `requirements.lock` | package root | Yes | Missing rejects install; existing Skill content is fixed as `pydantic==2.13.4` |

Additional semantics (same function): `required_actions` and `stop_actions` are merged and de-duplicated for validation, so the same `type@schema_version` may appear on both lists (for example `navigation.follow_route` appears on both lists in semantic-navigation). `SKILL.md` must start with `---\n` and the frontmatter must close correctly. `tests/test_skill_package_contract.py` mirrors these rules on the Python side and additionally asserts the exact version numbers of the three built-in Skills.

## SkillContext API

The minimal interface Skill scripts depend on (`semantic_robot_skill_sdk/context.py`):

| Method | Purpose |
|---|---|
| `input(Model)` | Validate and return typed input |
| `load_state(Model, default)` | Restore Stage state from a checkpoint |
| `checkpoint(state)` | Persist state (re-enter the current Stage after a process restart) |
| `execute(key, action)` | Execute one Action synchronously and return ActionResult |
| `start_action(key, action)` | Start an Action and return a Handle (`feedback()` / `result()` / `stop()`) |
| `observation(ref)` / `latest_observation(...)` | Read Observation |
| `request_agent(ResponseModel, ...)` | Request a Robot Agent decision (automatically carries the response_model JSON Schema) |
| `resolve_artifact(ref)` / `publish_artifact(...)` | Read and publish artifacts (pass references only) |
| `check_cancelled()` | Check for a stop request |
| `report(kind, ...)` | Report Stage / event progress |
| `execute_stop(key, action)` / `stop_outcome(...)` | Stop-path only |
| `complete(result)` / `fail(code, msg)` / `log(...)` / `now()` | Terminal state and utilities |

An Action envelope is constructed with `Action.from_model(action_type=..., parameters=<Pydantic model>, timeout_seconds=..., feedback=FeedbackRequest(...))`. A Controller only produces these envelopes; it does not connect to a device.

### Full public SkillContext method signatures

The source of truth is the `SkillContext` Protocol in `semantic_robot_skill_sdk/context.py` (the table also records actual `RpcSkillContext` behavior in `rpc_context.py`). Methods are synchronous unless marked `async`. `ModelT` is constrained to `type[BaseModel]`:

| Method (real signature) | Returns | Purpose and behavior |
|---|---|---|
| Attribute `robot_ref: str` | — | Robot reference bound to the current Execution. The Worker injects it in `skill.run` params |
| `input(model)` | `ModelT` | Re-validate runtime input with the Skill-declared model and return a typed instance |
| `load_state(model, default)` | `ModelT` | Return `default.model_copy(deep=True)` when there is no checkpoint; otherwise restore from the checkpoint |
| `checkpoint(state)` | `None` | Deep-copy and save state, then send a `checkpoint` notification; re-enter the current Stage after a process restart |
| `observation(observation_ref)` | `Observation \| None` | Return from the local cache on hit; otherwise pull from Pilot via `observation.get` |
| `latest_observation(kind, *, subject_ref=None, max_age_ms=None)` | `Observation \| None` | Read the latest observation that matches kind + subject + freshness via `observation.latest` |
| `controller(name)` | `Any` | Get a Controller instance declared in `runtime.controllers`; unregistered names raise `KeyError` |
| `async execute(key, action)` | `ActionResult` | Convenience wrapper for `start_action(...).result()`; stable keys are idempotent |
| `async start_action(key, action)` | `ActionHandle` | Start an Action via `action.start` (`stop_action: False`); call `check_cancelled()` first |
| `async request_agent(key, reason, context, response_model)` | `ModelT` | Request a decision via `agent.request`; params automatically carry `response_model.__name__` and `model_json_schema()` |
| `recent_evidence()` | `list[str]` | Collect cached observations' `evidence_refs` + `artifact_refs`, de-duplicated in order |
| `resolve_artifact(ref)` | `ResolvedArtifact` | Have Pilot download a Server Artifact into this Execution's read-only directory via `artifact.resolve` |
| `publish_artifact(path, media_type, summary)` | `PublishedArtifact` | Register a file in the workspace via `artifact.publish`; file content does not enter JSON-RPC |
| `check_cancelled()` | `None` | Raise `SkillCancelled` when a stop is latched. The script must not produce ordinary Actions after that |
| `report(event, *, summary, evidence_refs=None, stage=None, stage_status=None, expectation=None, observation_summary=None, deviation=None, progress=None, next_step=None)` | `None` | Send an `event.report` notification. Stage summaries are judged by the Skill; Pilot does not infer them from Action names |
| `async execute_stop(key, action)` | `ActionResult` | Execute a stop-only Action via `action.start` with `stop_action: True` (must be declared on the `stop_actions` list) |
| `stop_outcome(*, safe, summary, physical_state, requires_intervention=False, evidence_refs=None)` | `StopOutcome` | Build a structured stop conclusion; the return value of `on_stop` |
| `complete(result)` | `None` | Send a `complete` notification and enter the `completed` terminal state |
| `fail(code, message, evidence=None)` | `None` | Send a `fail` notification and enter the `failed` terminal state without raising a meaningless exception |
| `log(level, message, **fields)` | `None` | Send a `log` notification and automatically merge `log_fields` issued at Worker startup |
| `now()` | `datetime` | Read Pilot-side UTC time via `runtime.now` so it stays aligned with the event timeline |

The streaming Action `ActionHandle` Protocol (`context.py`) has three methods: `feedback() -> AsyncIterator[ActionFeedback]` (incremental continue-read by cursor; no re-consumption after recovery), `async result() -> ActionResult` (read the unique terminal state), and `async stop(reason: str) -> ActionResult` (actively request a stop for that Action).

### MockSkillContext for unit tests

`semantic_robot_skill_sdk/mock.py` provides an in-memory implementation with the same signatures as `SkillContext`, plus test-orchestration methods (signatures follow `mock.py`):

| Method | Signature | Purpose |
|---|---|---|
| Constructor | `MockSkillContext(skill_input: BaseModel, *, robot_ref="robot://demo-1", workspace=None)` | `workspace` is the artifact workspace root; a temp directory is used when omitted |
| `queue_action` | `(action_type: str, result: ActionResult, *, feedback: list[ActionFeedback] \| None = None, stop_result: ActionResult \| None = None) -> None` | Prefill a response by Action type; `feedback` simulates streaming feedback |
| `queue_agent_reply` | `(reply: dict \| BaseModel) -> None` | Prefill the next typed Agent reply |
| `add_observation` | `(observation: Observation) -> None` | Inject a known observation |
| `add_artifact` | `(ref: str, *, content: bytes, media_type: str, summary: str = "", filename: str = "input.bin") -> ResolvedArtifact` | Place a Server Artifact into the workspace |
| `request_stop` | `() -> None` | Simulate Runtime latching a stop; later `check_cancelled()` raises `SkillCancelled` |
| `register_controller` | `(name: str, controller: Any) -> None` | Register the Controller returned by `ctx.controller(name)` |
| `run_skill` | `(run, context, *, max_turns: int = 64) -> None` (module-level function) | Simulate Runtime re-entering `run(ctx)` until a terminal state; 64 turns without convergence fails the assertion |
| Assertion helpers | `state` (latest checkpoint), `status`, `result`, `failure`, `events`, `logs`, `checkpoint_count` attributes | Read the execution trail directly |

## Getting started: a minimal Robot Skill

The following skeleton matches the structure of the three existing Skills, Pilot validation, and contract tests.

### 1. Directory and dependencies

```text
my_skill/
├── SKILL.md
├── requirements.lock          # 内容：pydantic==2.13.4
└── scripts/
    ├── __init__.py
    ├── models.py
    └── skill.py
```

### 2. models.py

```python
from pydantic import BaseModel, ConfigDict, Field

class MySkillInput(BaseModel):
    """Robot Agent 已解析完成的输入。"""
    model_config = ConfigDict(extra="forbid")
    target_ref: str = Field(min_length=1)

class MySkillState(BaseModel):
    """可跨进程恢复的轻量 Stage 状态。"""
    stage: str = "observe"

class MySkillResult(BaseModel):
    reached: bool
    final_pose_ref: str
```

Notes:

- The three lifecycle models Input / State / Result are all required;
- The input model uses `extra="forbid"` to reject unknown fields;
- **Pydantic models are the only source of input and result structure.** JSON Schema has three real exits: `input_schema` in the `worker.initialize` response (for Registry / Agent / Web forms), the response_model Schema carried by `agent.request`, and the normalized return of `skill.validate_input`.

### 3. skill.py

```python
from semantic_robot_skill_sdk import SkillContext, StopOutcome, StopRequest
from .models import MySkillInput, MySkillResult, MySkillState

async def run(ctx: SkillContext) -> None:
    """每次从持久化检查点重新进入当前 Stage。"""
    ctx.check_cancelled()
    skill_input = ctx.input(MySkillInput)
    state = ctx.load_state(MySkillState, default=MySkillState())

    if state.stage == "observe":
        state.stage = "finish"
        ctx.checkpoint(state)          # 先落检查点再做不可逆操作
        # result = await ctx.execute("observe-1",
        #     Action.from_model(action_type="my.observe", parameters=..., ...))
        ctx.report("stage.completed", stage="observe", stage_status="completed",
                   summary="已完成观察")

    ctx.complete(MySkillResult(reached=True, final_pose_ref="pose://world/here"))

async def on_stop(ctx: SkillContext, request: StopRequest) -> StopOutcome:
    return ctx.stop_outcome(safe=True, summary="无活动动作", physical_state="idle")
```

### 4. SKILL.md

Fill frontmatter from the template above: `entrypoint: scripts.skill:run`, `stop_entrypoint: scripts.skill:on_stop`, and the three `*_model` fields pointing at the classes from step 2. The body describes Stages, observation and completion judgments, the local recovery budget, cases that need a Robot Agent decision, and safe-stop behavior (follow `semantic_navigation/SKILL.md`).

### 5. Unit tests (no Pilot)

Drive with `MockSkillContext` + `run_skill`. See `tests/test_runtime.py` and `grasp_object/tests/`:

```python
from semantic_robot_skill_sdk import ActionResult, MockSkillContext, run_skill
from my_skill.scripts.skill import run
from my_skill.scripts.models import MySkillInput

def test_run_completes():
    ctx = MockSkillContext(input=MySkillInput(target_ref="obj-1"))
    # ctx.queue_action("my.observe", ActionResult(status="completed", ...))
    run_skill(run, ctx)
    assert ctx.status.value == "completed"
```

`MockSkillContext` supports `queue_action` (prefill Action responses), `queue_agent_reply`, `add_observation`, `request_stop` (verify stop semantics), and more.

## Complete example: a read-only survey Skill

The skeleton above shows structure. Here is a **full, runnable** Skill: `object-survey` (object survey) uses only two `physical: false` read-only Actions (`robot.get_state`, `perception.locate_object`; see the Ability Manifests of `r1pro-robot-state` and `r1pro-object-perception`). It has no physical effect and is a good starting template for a new Skill. The writing style matches `semantic_navigation`: Stages dispatch on `state.stage`, `checkpoint` takes effect before state advances, and Stage and terminal state converge separately.

### Directory and SKILL.md

```text
object_survey/
├── SKILL.md
├── requirements.lock          # 内容：pydantic==2.13.4
└── scripts/
    ├── __init__.py
    ├── models.py
    └── skill.py
```

`SKILL.md` frontmatter (body style follows `semantic_navigation/SKILL.md`):

```yaml
---
name: object-survey
description: 读取机器人状态并定位指定物体，返回带证据的巡检结果
category: robot_skill
version: 0.1.0
runtime:
  api_version: 1
  python: ">=3.11"
  entrypoint: scripts.skill:run
  stop_entrypoint: scripts.skill:on_stop
  input_model: scripts.models:ObjectSurveyInput
  state_model: scripts.models:ObjectSurveyState
  result_model: scripts.models:ObjectSurveyResult
  controllers: {}
required_actions:
  - { type: robot.get_state, schema_version: 2 }
  - { type: perception.locate_object, schema_version: 2 }
stop_actions:
  - { type: robot.get_state, schema_version: 2 }
debug_input:
  object_ref: tote-large-smoke
---
```

`stop_actions` must be non-empty (Pilot enforces this). A read-only Skill declares a harmless read-only Action to satisfy the contract. `on_stop` itself does not start a new physical action.

### models.py (full)

```python
"""对象巡检 Skill 的输入、状态和结果模型。"""

from pydantic import BaseModel, ConfigDict, Field

from semantic_robot_skill_sdk import Pose3D


class ObjectSurveyInput(BaseModel):
    """Robot Agent 已解析完成的巡检输入。"""

    model_config = ConfigDict(extra="forbid")

    object_ref: str = Field(min_length=1)
    minimum_confidence: float = Field(default=0.65, ge=0.0, le=1.0)


class ObjectSurveyState(BaseModel):
    """可跨进程恢复的轻量 Stage 状态。"""

    stage: str = "read_robot_state"
    robot_state_generation: int = Field(default=0, ge=0)
    object_pose: Pose3D | None = None


class RobotStateValue(BaseModel):
    """robot.state Observation 中与本 Skill 相关的字段。"""

    model_config = ConfigDict(extra="ignore")

    robot_id: str
    generation: int = Field(ge=0)


class TargetPoseValue(BaseModel):
    """target_pose Observation 中与本 Skill 相关的字段。"""

    model_config = ConfigDict(extra="ignore")

    object_ref: str
    pose: Pose3D
    identity_confidence: float = Field(ge=0.0, le=1.0)


class ObjectSurveyResult(BaseModel):
    robot_ref: str
    robot_state_generation: int
    object_pose: Pose3D
    confidence: float


class GetRobotStateParameters(BaseModel):
    """robot.get_state 无业务参数。"""

    pass


class LocateObjectParameters(BaseModel):
    """perception.locate_object 的类型化参数。"""

    object_ref: str
    minimum_confidence: float = Field(default=0.65, ge=0.0, le=1.0)
```

### skill.py (full)

```python
"""对象巡检 Skill：两个只读 Action 组成的最小 Stage 流。"""

from semantic_robot_skill_sdk import (
    ActionResult,
    Action,
    Observation,
    SkillContext,
    StopOutcome,
    StopRequest,
)

from .models import (
    GetRobotStateParameters,
    LocateObjectParameters,
    ObjectSurveyInput,
    ObjectSurveyResult,
    ObjectSurveyState,
    RobotStateValue,
    TargetPoseValue,
)


def _last(result: ActionResult, kind: str) -> Observation | None:
    """取 Action 结果中最后一帧指定类型的 Observation。"""

    return next(
        (item for item in reversed(result.observations) if item.kind == kind), None
    )


async def run(ctx: SkillContext) -> None:
    """每次从持久化检查点重新进入当前 Stage。"""

    ctx.check_cancelled()
    skill_input = ctx.input(ObjectSurveyInput)
    state = ctx.load_state(ObjectSurveyState, default=ObjectSurveyState())
    ctx.report(
        "stage.running",
        summary=f"正在执行对象巡检阶段：{state.stage}",
        stage=state.stage,
        stage_status="running",
        evidence_refs=ctx.recent_evidence(),
    )

    if state.stage == "read_robot_state":
        result = await ctx.execute(
            key="survey:get-state",
            action=Action.from_model(
                action_type="robot.get_state",
                parameters=GetRobotStateParameters(),
                timeout_seconds=5,
                label="读取机器人状态",
            ),
        )
        observation = _last(result, "robot.state")
        if result.status != "succeeded" or observation is None:
            ctx.fail("ROBOT_STATE_READ_FAILED", "无法读取当前 Robot 状态",
                     result.evidence_refs)
            return
        robot_state = RobotStateValue.model_validate(observation.value or {})
        if robot_state.robot_id != ctx.robot_ref:
            ctx.fail("ROBOT_STATE_MISMATCH", "RobotState 不属于当前 Execution 绑定的 Robot")
            return
        state.robot_state_generation = robot_state.generation
        state.stage = "locate_object"
        ctx.checkpoint(state)              # 先落检查点，再进入下一 Stage
        ctx.report(
            "stage.completed",
            stage="read_robot_state",
            stage_status="completed",
            summary="已读取 Robot 状态",
            evidence_refs=result.evidence_refs,
        )
        return

    if state.stage == "locate_object":
        result = await ctx.execute(
            key="survey:locate-object",
            action=Action.from_model(
                action_type="perception.locate_object",
                parameters=LocateObjectParameters(
                    object_ref=skill_input.object_ref,
                    minimum_confidence=skill_input.minimum_confidence,
                ),
                timeout_seconds=10,
                label="定位巡检对象",
            ),
        )
        observation = _last(result, "target_pose")
        target = (
            TargetPoseValue.model_validate(observation.value or {})
            if observation is not None
            else None
        )
        if (
            result.status != "succeeded"
            or target is None
            or target.object_ref != skill_input.object_ref
        ):
            ctx.fail("OBJECT_NOT_OBSERVED", "无法定位巡检对象", result.evidence_refs)
            return
        state.object_pose = target.pose
        # 先关闭当前 Stage，再写 Skill 终态，避免“Execution 已完成而 Stage 仍 running”。
        ctx.report(
            "stage.completed",
            stage="locate_object",
            stage_status="completed",
            summary="已定位巡检对象",
            evidence_refs=result.evidence_refs,
        )
        ctx.complete(
            ObjectSurveyResult(
                robot_ref=ctx.robot_ref,
                robot_state_generation=state.robot_state_generation,
                object_pose=target.pose,
                confidence=target.identity_confidence,
            )
        )
        return

    ctx.fail("INVALID_STAGE", f"未知对象巡检 Stage：{state.stage}")


async def on_stop(ctx: SkillContext, request: StopRequest) -> StopOutcome:
    # 两个 Stage 都不产生物理影响（Ability Manifest 中 physical: false），
    # 停止路径不需要 execute_stop，直接给出可审计的安全结论。
    return ctx.stop_outcome(
        safe=True,
        summary="对象巡检为只读任务，无需物理停止",
        physical_state="idle",
    )
```

`GetRobotStateParameters` and `LocateObjectParameters` match the same-named parameter models in `semantic_navigation/scripts/models.py`. Those models have long been used by the three built-in Skills to construct these two Actions. A custom Skill should define equivalent models from the target Ability Manifest's `inputFields`. Unit-test style is in step 5 above: `MockSkillContext(ObjectSurveyInput(object_ref="tote-large-smoke"))` + `queue_action("robot.get_state", ActionResult(status="succeeded", observations=[...]))`, then assert the terminal state with `run_skill(run, ctx)`.

## Worker runtime

The Worker is the Skill host process, started by Pilot:

```bash
python -m semantic_robot_skill_sdk.worker --skill-dir <skill目录>
```

- After startup it first sends a `ready` notification to stdout. After that, **stdout carries only JSON-RPC** (the worker internally redirects stdout to stderr so third-party print cannot pollute the protocol channel);
- Pilot calls `worker.initialize` (carrying entrypoint/stop_entrypoint/input_model/controllers). The Worker imports the entry and returns `input_schema`;
- `skill.validate_input` only validates input and does not execute;
- `skill.run` carries `execution_id / robot_ref / input / checkpoint / feedback_cursors`. The Worker guarantees a single Execution. `run(ctx)` re-enters at most 64 times until a terminal state;
- `skill.stop` first calls `context.request_stop()` and then runs `on_stop`. It sends a `stop.outcome` notification before returning;
- While a Skill is running, Pilot can still concurrently issue `skill.stop` (`ConcurrentJsonRpcPeer` background read thread dispatches by id).

Skill → Pilot reverse calls (`RpcSkillContext`): `action.start / action.feedback / action.result / action.stop / observation.get / observation.latest / agent.request / artifact.resolve / artifact.publish / runtime.now`, plus one-way notifications `checkpoint / complete / fail / log / event.report`. All automatically carry `execution_id`.

### JSON-RPC message list

The transport is a **JSON-RPC 2.0 line protocol with one JSON object per line** (`LineJsonRpcPeer` / `ConcurrentJsonRpcPeer` in `semantic_robot_skill_sdk/protocol.py`). Binary data can only be expressed as Artifact references. The table below summarizes every method name in `worker.py` and `rpc_context.py`:

**Pilot → Worker (`serve()` dispatch on the Worker)**

| Method | Key params | Return / behavior |
|---|---|---|
| `worker.initialize` | `name`, `version`, `runtime` (including `api_version`, `entrypoint`, `stop_entrypoint`, `input_model`, `controllers`) | Returns `{status: "initialized", name, version, input_schema}`. An already-initialized Worker refuses to switch Skill or version (error code -32000) |
| `skill.validate_input` | `input` | Validate only, do not execute. Returns `{valid: true, input}` or `{valid: false, error}` |
| `skill.run` | `execution_id`, `robot_ref`, `input`, `checkpoint`, `log_fields`, `feedback_cursors` | Runs on a background thread. One Worker guarantees a single Execution (-32001). Terminal return is `{status, result, error}` |
| `skill.stop` | `request` (`StopRequest`: `id/source/reason/mode/requested_at`) | Latch stop first, then run `on_stop`. After sending `stop.outcome`, return StopOutcome (-32002 = no active Execution) |
| `worker.shutdown` | none | Return `{status: "shutting_down"}` and exit the main loop |
| (unknown method) | — | Error code -32601 |

**Worker → Pilot (synchronous requests from `RpcSkillContext`)**

| Method | Key params | Return |
|---|---|---|
| `action.start` | `key`, `action` (Action envelope), `stop_action` | `{action_id}`. When `stop_action: true`, only Actions on the `stop_actions` list are accepted |
| `action.feedback` | `action_id`, `after_sequence` | `{feedback: [...], terminal: bool}`, incremental continue-read by sequence cursor |
| `action.result` | `action_id` | `ActionResult` |
| `action.stop` | `action_id`, `reason` | `ActionResult` (status is usually `stopped`) |
| `observation.get` | `observation_ref` | `Observation` or `null` |
| `observation.latest` | `kind`, `subject_ref`, `max_age_ms` | `Observation` or `null` |
| `agent.request` | `key`, `reason`, `context`, `response_model`, `response_schema` | Typed decision after validation against `response_schema` |
| `artifact.resolve` | `ref` | `{ref, local_path, media_type, size_bytes, summary}` |
| `artifact.publish` | `path`, `media_type`, `summary` | `{local_ref, server_ref, sync_status}` |
| `runtime.now` | none | RFC3339 UTC time string |

**Worker → Pilot one-way notifications**: `ready` (first message after Worker startup, carries `skill_dir`), `checkpoint` (`execution_id` + `state`), `event.report`, `log`, `complete`, `fail`, `stop.outcome`. `checkpoint / complete / fail` are consumed inside Pilot (`complete/fail` are not forwarded to the Server, to avoid overwriting a formal terminal state with a stale running state). `stage.running` from `event.report` also writes `stage` into the recovery checkpoint before forwarding.

### Event name list

The `event` field of `event.report` is defined by the Skill and forwarded as-is onto the event channel (`runtime.go` does not enumerate-validate it). The three built-in Skills actually use:

| Event | Semantics | Typical fields |
|---|---|---|
| `stage.running` | Enter a Stage (Pilot uses this to write the Stage into the checkpoint) | `stage`, `stage_status: "running"`, `expectation`, `next_step` |
| `stage.progress` | Progress or deviation inside a Stage | `stage`, `progress`, `observation_summary`, `deviation` |
| `stage.completed` | A Stage has converged | `stage`, `stage_status: "completed"`, `summary` |
| `decision.required` | Timeline mark before requesting an Agent decision | `stage`, `stage_status: "waiting_agent"`, `deviation` |

Pilot itself also emits system events (`events.Report` in `internal/pilot/runtime.go`): `skill.started`, `action.started`, `action.terminal`, `feedback.emitted`, `observation.recorded`, `agent.requested`, `agent.resolved`, `stop.outcome`, `skill.stop.finalized`, `worker.restarted`, `artifact.summary.announced` / `artifact.summary.failed`, `execution.terminal`. Skill-defined events and system events share one channel. Downstream distinguishes them by `event` name.

## Pilot-side lifecycle

| Phase | Implementation | Description |
|---|---|---|
| Discover | `ScanSkillCatalog` | Scan only first-level directories under root that contain SKILL.md (`active/<name>` symlinks are followed) |
| Install | `InstalledSkillManager.Install` | Unzip (reject symlinks / path traversal) → validate → atomically move to `packages/<name>/<version>` |
| Enable | `Enable(name, version)` | Atomically switch the `active/<name>` symlink. A Skill that is executing refuses Disable/Uninstall |
| Start | `supervisor.go` | `exec python -m semantic_robot_skill_sdk.worker --skill-dir ...`, append the skills directory to PYTHONPATH |
| Execute | `runtime.go` | Build `skill.run` params; route checkpoint / action / agent.request. A stop is recorded as `stopped` only after `stop.outcome` safety evidence; otherwise `interrupted` |
| Action routing | `runner.go` | Action keys are idempotent (same key and same content reuse the result; different content reports a conflict). Physical Actions have a Robot-level mutex |

## Local debugging

### Drive a Worker by hand

```bash
cd semantic-skill/robot-skill
python -m semantic_robot_skill_sdk.worker --skill-dir semantic_robot_skills/skills/semantic_navigation
# stdin/stdout 只能发 JSON-RPC（一行一个 JSON）
```

Manual cross-Skill import debugging requires you to set PYTHONPATH yourself (Pilot appends it automatically at startup; a manual start does not).

### Pilot local Skill Run

```bash
go build -o .output/bin/semantic-pilot ./cmd/semantic-pilot

.output/bin/semantic-pilot skill run \
  --profile <robot-deployment.yaml> \
  --skill grasp-object@0.4.17 \
  --input examples/mujoco-skill-debug/grasp-object.json \
  --skill-catalog /path/to/semantic_robot_skills/skills \
  --python <venv>/bin/python \
  --events events.jsonl --result result.json --timeout 10m
```

Notes:

- `--skill` must be exact to version (`name@version`);
- Local mode does not assemble an Agent: `agent.request` always fails, and entering `waiting_agent` makes the command error immediately;
- Preconditions: MuJoCo Scene + AbilityFramework are ready (see `examples/mujoco-skill-debug/README.md`). The same Robot cannot be controlled by a resident Pilot and a local command at the same time.

#### All command-line flags (cmd/semantic-pilot/local_skill.go)

| Flag | Default | Description |
|---|---|---|
| `--profile` | Environment variable `SEMANTIC_ROBOT_CONFIG`, then `SEMANTIC_ROBOT_DEPLOYMENT` | RobotDeployment YAML (required; must contain `ability_framework.endpoint` or startup fails) |
| `--skill` | none | `name@version`; both parts must be non-empty (required) |
| `--input` | none | Skill input JSON file; `-` means read from stdin. Content must be a JSON object (required) |
| `--skill-catalog` | Environment variable `SEMANTIC_ROBOT_SKILL_CATALOG_DIR` | Local Skill directory root. When omitted, fall back to deployment config `pilot.robot_skill_directory/active` |
| `--python` | Environment variable `SEMANTIC_ROBOT_SKILL_PYTHON`, then `python` | Python interpreter used to start the Worker process |
| `--python-path` | none (repeatable) | Append to the Worker process `PYTHONPATH` one by one (used for manual cross-Skill import debugging) |
| `--ability-framework` | none | Override `ability_framework.endpoint` in the deployment config |
| `--execution-id` | auto-generated | Specify a local execution ID |
| `--timeout` | `15m` | Maximum execution time. Timeout or Ctrl+C both take the formal `runtime.Stop(..., mode="safe")` path (30 second stop budget) and do not kill the process directly |
| `--events` | `-` (stderr) | JSONL event output path; `-` means stderr; empty string means off |
| `--result` | `-` (stdout) | Final result JSON output path; `-` means stdout |

Startup flow (same file): load and strictly validate the deployment config → refresh the AbilityFramework Action catalog with a 10 second timeout (fail if offline) → `ScanSkillCatalog` parses the version specified by `--skill` → start the Worker and wait for a terminal state. The command exits non-zero when the terminal state is not `completed`.

#### Expected contents of events.jsonl and result.json

Each line of the `--events` file is one JSON object (`localSkillEventWriter`), in two kinds:

```text
事件行：{"time": "<UTC>", "kind": "event", "event": "<事件名>", "execution_id": "...", "skill": "...", "status": "<执行状态>", "fields": {...}}
日志行：{"time": "<UTC>", "kind": "log", "level": "...", "message": "...", "execution_id": "...", "skill": "...", "fields": {...}}
```

A successful read-only survey (the complete example above) is expected to emit these events in order (`event` field):

```text
skill.started            → Pilot 启动 Execution
stage.running            → Skill 上报进入 read_robot_state（stage 字段同时写入恢复 checkpoint）
action.started           → robot.get_state
action.terminal          → 该 Action 终态
stage.completed          → read_robot_state 收敛
stage.running            → locate_object
action.started           → perception.locate_object
action.terminal
stage.completed          → locate_object 收敛
execution.terminal       → status=completed
```

A physical Skill (for example grasp-object) will also see `feedback.emitted`, `observation.recorded`, `stop.outcome` / `skill.stop.finalized`. When an Agent decision is needed, the local command first emits `agent.requested` and then fails and exits. `fields` contains each event's raw params (including `stage`, `key`, `progress`, and so on, matching the event-name list above).

The `--result` file is indented final-result JSON (`writeLocalSkillResult`):

```json
{
  "execution_id": "...",
  "robot_id": "sim-r1pro-001",
  "skill_name": "object-survey",
  "skill_version": "0.1.0",
  "status": "completed",
  "result": { "…": "Skill 的 result_model 输出" },
  "error": null,
  "stop_outcome": null,
  "created_at": "...",
  "updated_at": "..."
}
```

On failure, `error` is `{code, message, evidence_refs}`. When a stop occurred, `stop_outcome` is the `{safe, summary, physical_state, requires_intervention, evidence_refs}` returned by `on_stop`.

## Tests

```bash
cd semantic-skill/robot-skill
make check   # compileall 语法检查
make test    # pytest：仓库级跨进程/契约测试 + 各 Skill 的 tests/
```

Note: the machine needs Python 3.11+ (if the system only has a `python` command, use `uv venv --python 3.11 .venv` and run inside the venv).

Test layers:

- Model and Stage unit tests (MockSkillContext);
- Repository-level JSON-RPC cross-process full flow (`tests/test_jsonrpc_worker.py`: ready → initialize → validate → run → terminal → shutdown);
- Package-structure contract tests (`test_skill_package_contract.py`; this test hard-codes exact version numbers of existing Skills, so update it when you add or upgrade a Skill);
- Pilot local Skill Run → real AbilityFramework and Robot SDK → full simulation / real-robot execution → Framework Task and Web debug entry.

### Test location list

| File / directory | Coverage |
|---|---|
| `tests/test_jsonrpc_worker.py` | Real subprocess + pipe JSON-RPC full flow: `ready → worker.initialize → skill.validate_input → skill.run` (answer `action.start/feedback/result`, `observation.latest`, `log` one by one) `→ terminal → worker.shutdown`; also asserts a clear failure when stdout is polluted |
| `tests/test_runtime.py` | MockSkillContext key recovery semantics: same-key Action result reuse, same key with different content rejected, feedback cursor continue-read, `latest_observation` filtering, Artifact workspace boundary, `agent.request` automatically carries Schema, `event.report` field pass-through |
| `tests/test_skill_package_contract.py` | Package-structure contract: SKILL.md is the only manifest (no `robot-skill.yaml`), five `module:attr` entry files exist, `requirements.lock` content, `schema_version: 2`, Skill scripts must not import device/model libraries or use `print()`, SDK Wheel contains only `semantic_robot_skill_sdk*`. Hard-codes exact version numbers of the three built-in Skills; update when adding or upgrading a Skill |
| `semantic_robot_skills/skills/*/tests/` | Per-Skill Stage unit tests (`test_semantic_navigation.py`, `test_navigation_carrying.py`, `test_grasp_object.py`, `test_place_object.py`), all based on MockSkillContext |
| Command actually run by `make test` | `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -p no:cacheprovider -q tests semantic_robot_skills/skills/*/tests` (after `make check` compileall syntax check) |

Note: the repository has no smoke Skill named `skills/test_skill` and no matching test file. The simplest runnable reference is the "Complete example: a read-only survey Skill" above, plus the semantic-navigation Worker drive sequence in `tests/test_jsonrpc_worker.py`.

## Design notes

- Stages express execution phases a user can understand. Write `checkpoint` before an irreversible operation;
- Express business goals through object and region identity (ref). Precise pose, contact, and load are re-observed at execution time;
- A Skill only describes Stages, Actions, feedback, and recovery. Device connection and low-level implementation belong to Ability and Robot SDK;
- The stop path uses dedicated `execute_stop` / `on_stop` and does not rely on ordinary Actions. Do not start the next Action when the stop result is unknown;
- When a business choice, a change in approval scope, or an unconfirmable execution state is needed, use `request_agent` to ask the Robot Agent. The Agent can only return a typed decision defined by the Skill.

## Related layers

- Conceptual model: [Architecture · Robot execution and the embodied loop](../../../architecture/06-robot-execution.en.md)
- Implementation details: [Internals · Pilot and Robot Execution](../../reference/internals/robot-execution-and-environment.en.md)
