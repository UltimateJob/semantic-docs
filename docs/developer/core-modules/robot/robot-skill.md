---
title: "Robot Skill"
weight: 60
description: "开发阶段化物理任务：Stage 编排、Action 调用、Worker 协议与本地调试。"
---

Robot Skill 将一个机器人任务组织为可观察、可停止、可恢复的 Stage。它通过 Action 使用 Ability，并根据 Feedback 和 Observation 推进执行。在执行链上，它位于 Pilot 之下、Ability 之上（见[第 5 章：Robot Skill、Stage 与 Action](/developer/quickstart/chapter_05_robot_skill/)）。

相关仓库：

- Worker Runtime SDK 与 Skill 源码：`semantic-skill/robot-skill`
- 发现、安装、Worker 启动与执行编排：`semantic-framework` 的 `internal/pilot/`（skillcatalog.go、skillmanager.go、supervisor.go、runtime.go、runner.go）
- 本地调试命令：`semantic-framework` 的 `cmd/semantic-pilot/local_skill.go`

## 目录结构

### 仓库布局

`semantic-skill/robot-skill` 分为两部分：

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

### 单个 Skill 的结构

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

SKILL.md 是唯一清单（不存在单独的 `robot-skill.yaml`）。Pilot 加载时强制校验（`internal/pilot/skillcatalog.go` 的 `loadSkillDefinition`）：

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

校验规则：每个 `module:attr` 引用会检查对应的 `.py` 文件真实存在；`requirements.lock` 必须存在；`required_actions` 与 `stop_actions` 每项必须有 `type` 和 `schema_version >= 1`。

### frontmatter 字段契约表

下表逐字段对应 `semantic-framework/internal/pilot/skillcatalog.go` 的 `loadSkillDefinition`（Go 结构体 yaml tag + 校验分支），是 Pilot 拒绝一个 Skill 包的全部判据：

| 字段 | 层级 | 必填 | 校验规则（源码行为） |
|---|---|---|---|
| `name` | 顶层 | 是 | 非空；与 `version` 一起构成 `name@version` 引用键 |
| `category` | 顶层 | 是 | 必须等于 `robot_skill` |
| `version` | 顶层 | 是 | 非空 |
| `runtime.api_version` | runtime | 是 | 必须等于 `1`（Worker 侧同样只接受 1，`worker.py` `_initialize`） |
| `runtime.python` | runtime | 否 | Pilot 解析但不做强制校验；声明 Worker 运行环境要求 |
| `runtime.entrypoint` | runtime | 是 | `module:attr` 格式；`module` 逐段映射为 `SKILL.md` 同级 `.py` 文件并 `os.Stat` 检查存在 |
| `runtime.stop_entrypoint` | runtime | 是 | 同上 |
| `runtime.input_model` / `runtime.state_model` / `runtime.result_model` | runtime | 是（三个都必填） | 同上；Pilot 逐个校验文件存在 |
| `runtime.controllers` | runtime | 否 | `name → module:attr` 映射；每个引用同样校验 `.py` 文件存在 |
| `required_actions[]` | 顶层 | 是（非空） | 每项必须有 `type` 非空且 `schema_version >= 1` |
| `stop_actions[]` | 顶层 | 是（非空） | 同上；`action.start` 携带 `stop_action: true` 时只能使用本清单中的 Action |
| `debug_input` | 顶层 | 否 | Pilot 不解析；仅作文档样例输入，实际输入必须经 `--input` 提供 |
| （文件）`requirements.lock` | 包根 | 是 | 缺失即拒绝安装；现有 Skill 内容固定为 `pydantic==2.13.4` |

补充语义（同一函数）：`required_actions` 与 `stop_actions` 合并去重校验，即同一 `type@schema_version` 在两个清单里重复声明是允许的（如 `navigation.follow_route` 同时出现在 semantic-navigation 的两份清单中）；`SKILL.md` 必须以 `---\n` 开头且 frontmatter 正确闭合。`tests/test_skill_package_contract.py` 在 Python 侧镜像了这些规则，并额外断言三个内置 Skill 的精确版本号。

## SkillContext API

Skill 脚本依赖的最小接口（`semantic_robot_skill_sdk/context.py`）：

| 方法 | 用途 |
|---|---|
| `input(Model)` | 校验并返回类型化输入 |
| `load_state(Model, default)` | 从检查点恢复 Stage 状态 |
| `checkpoint(state)` | 持久化状态（进程重启后从当前 Stage 重入） |
| `execute(key, action)` | 同步执行一个 Action，返回 ActionResult |
| `start_action(key, action)` | 启动 Action，返回 Handle（`feedback()` / `result()` / `stop()`） |
| `observation(ref)` / `latest_observation(...)` | 读取 Observation |
| `request_agent(ResponseModel, ...)` | 请求 Robot Agent 决策（自动携带 response_model 的 JSON Schema） |
| `resolve_artifact(ref)` / `publish_artifact(...)` | 产物读取与发布（只传引用） |
| `check_cancelled()` | 检查停止请求 |
| `report(kind, ...)` | 上报 Stage/事件进度 |
| `execute_stop(key, action)` / `stop_outcome(...)` | 停止路径专用 |
| `complete(result)` / `fail(code, msg)` / `log(...)` / `now()` | 终态与工具 |

Action 信封由 `Action.from_model(action_type=..., parameters=<Pydantic 模型>, timeout_seconds=..., feedback=FeedbackRequest(...))` 构造，Controller 只负责产出这些信封，不连设备。

### SkillContext 公开方法完整签名

以 `semantic_robot_skill_sdk/context.py` 的 `SkillContext` Protocol 为准（下表同时给出 `rpc_context.py` 中 `RpcSkillContext` 的实际行为）。除标注 `async` 外均为同步调用；`ModelT` 约束为 `type[BaseModel]`：

| 方法（真实签名） | 返回 | 用途与行为 |
|---|---|---|
| 属性 `robot_ref: str` | — | 当前 Execution 绑定的 Robot 引用，Worker 在 `skill.run` params 中注入 |
| `input(model)` | `ModelT` | 用 Skill 声明的模型重新校验运行时输入，返回类型化实例 |
| `load_state(model, default)` | `ModelT` | 无检查点时返回 `default.model_copy(deep=True)`，否则从检查点恢复 |
| `checkpoint(state)` | `None` | 深拷贝保存状态并发送 `checkpoint` 通知；进程重启后从当前 Stage 重入 |
| `observation(observation_ref)` | `Observation \| None` | 命中本地缓存直接返回，否则经 `observation.get` 向 Pilot 拉取 |
| `latest_observation(kind, *, subject_ref=None, max_age_ms=None)` | `Observation \| None` | 经 `observation.latest` 读取满足 kind + subject + 新鲜度过滤的最新观测 |
| `controller(name)` | `Any` | 取 `runtime.controllers` 声明的 Controller 实例；未注册抛 `KeyError` |
| `async execute(key, action)` | `ActionResult` | `start_action(...).result()` 的便捷封装；稳定 key 幂等 |
| `async start_action(key, action)` | `ActionHandle` | 经 `action.start`（`stop_action: False`）启动 Action；启动前先 `check_cancelled()` |
| `async request_agent(key, reason, context, response_model)` | `ModelT` | 经 `agent.request` 请求决策；params 自动携带 `response_model.__name__` 与 `model_json_schema()` |
| `recent_evidence()` | `list[str]` | 汇总已缓存观测的 `evidence_refs` + `artifact_refs`，按序去重 |
| `resolve_artifact(ref)` | `ResolvedArtifact` | 经 `artifact.resolve` 让 Pilot 把 Server Artifact 下载到本 Execution 只读目录 |
| `publish_artifact(path, media_type, summary)` | `PublishedArtifact` | 经 `artifact.publish` 登记工作区内文件；文件内容不进 JSON-RPC |
| `check_cancelled()` | `None` | 停止已锁存时抛 `SkillCancelled`，脚本不得再产生普通 Action |
| `report(event, *, summary, evidence_refs=None, stage=None, stage_status=None, expectation=None, observation_summary=None, deviation=None, progress=None, next_step=None)` | `None` | 发送 `event.report` 通知；Stage 摘要由 Skill 判断，Pilot 不根据 Action 名推测 |
| `async execute_stop(key, action)` | `ActionResult` | 经 `action.start` 携带 `stop_action: True` 执行停止专用 Action（必须在 `stop_actions` 清单中声明） |
| `stop_outcome(*, safe, summary, physical_state, requires_intervention=False, evidence_refs=None)` | `StopOutcome` | 构造结构化停止结论，`on_stop` 的返回值 |
| `complete(result)` | `None` | 发送 `complete` 通知并进入 `completed` 终态 |
| `fail(code, message, evidence=None)` | `None` | 发送 `fail` 通知并进入 `failed` 终态，不抛无语义异常 |
| `log(level, message, **fields)` | `None` | 发送 `log` 通知，自动合并 Worker 启动时下发的 `log_fields` |
| `now()` | `datetime` | 经 `runtime.now` 读取 Pilot 侧 UTC 时间，保持与事件时间线一致 |

流式 Action 的 `ActionHandle` Protocol（`context.py`）有三个方法：`feedback() -> AsyncIterator[ActionFeedback]`（按游标增量续读，恢复后不重复消费）、`async result() -> ActionResult`（读取唯一终态）、`async stop(reason: str) -> ActionResult`（主动请求停止该 Action）。

### 单元测试用的 MockSkillContext

`semantic_robot_skill_sdk/mock.py` 提供与 `SkillContext` 同签名的内存实现，另加测试编排方法（签名以 `mock.py` 为准）：

| 方法 | 签名 | 用途 |
|---|---|---|
| 构造 | `MockSkillContext(skill_input: BaseModel, *, robot_ref="robot://demo-1", workspace=None)` | `workspace` 为产物工作区根目录，缺省时用临时目录 |
| `queue_action` | `(action_type: str, result: ActionResult, *, feedback: list[ActionFeedback] \| None = None, stop_result: ActionResult \| None = None) -> None` | 按 Action 类型预置响应，`feedback` 模拟流式反馈 |
| `queue_agent_reply` | `(reply: dict \| BaseModel) -> None` | 预置下一条类型化 Agent 回复 |
| `add_observation` | `(observation: Observation) -> None` | 注入一条已知观测 |
| `add_artifact` | `(ref: str, *, content: bytes, media_type: str, summary: str = "", filename: str = "input.bin") -> ResolvedArtifact` | 把一份 Server Artifact 放入工作区 |
| `request_stop` | `() -> None` | 模拟 Runtime 锁存停止请求，后续 `check_cancelled()` 抛 `SkillCancelled` |
| `register_controller` | `(name: str, controller: Any) -> None` | 注册 `ctx.controller(name)` 返回的 Controller |
| `run_skill` | `(run, context, *, max_turns: int = 64) -> None`（模块级函数） | 模拟 Runtime 反复重入 `run(ctx)` 直到终态；64 轮未收敛即断言失败 |
| 断言辅助 | `state`（最近检查点）、`status`、`result`、`failure`、`events`、`logs`、`checkpoint_count` 属性 | 直接读取执行轨迹 |

## 入门：最小 Robot Skill

以下骨架与三个现有 Skill 的结构、Pilot 校验和契约测试三方一致。

### 1. 目录与依赖

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

要点：

- Input / State / Result 三个生命周期模型缺一不可；
- 输入模型用 `extra="forbid"` 拒绝未知字段；
- **Pydantic 模型是输入和结果结构的唯一来源**，JSON Schema 有三个真实出口：`worker.initialize` 响应的 `input_schema`（供 Registry / Agent / Web 表单使用）、`agent.request` 携带的 response_model Schema、`skill.validate_input` 的规范化回传。

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

frontmatter 按上文模板填写，`entrypoint: scripts.skill:run`、`stop_entrypoint: scripts.skill:on_stop`、三个 `*_model` 指向第 2 步的类；正文描述 Stage、观测与完成判断、局部恢复预算、需要 Robot Agent 决策的情况和安全停止行为（写法参考 `semantic_navigation/SKILL.md`）。

### 5. 单元测试（不依赖 Pilot）

使用 `MockSkillContext` + `run_skill` 驱动，参考 `tests/test_runtime.py` 和 `grasp_object/tests/`：

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

`MockSkillContext` 支持 `queue_action`（预置 Action 响应）、`queue_agent_reply`、`add_observation`、`request_stop`（验证停止语义）等。

## 完整示例：只读巡检 Skill

上面骨架展示结构，这里给出一个**全文即可运行**的完整 Skill：`object-survey`（对象巡检）只使用两个 `physical: false` 的只读 Action（`robot.get_state`、`perception.locate_object`，见 `r1pro-robot-state`、`r1pro-object-perception` 的 Ability Manifest），不产生任何物理影响，适合作为新 Skill 的起点模板。写法对齐 `semantic_navigation`：Stage 按 `state.stage` 分发、`checkpoint` 先于状态推进生效、Stage 与终态分别收敛。

### 目录与 SKILL.md

```text
object_survey/
├── SKILL.md
├── requirements.lock          # 内容：pydantic==2.13.4
└── scripts/
    ├── __init__.py
    ├── models.py
    └── skill.py
```

`SKILL.md` frontmatter（正文写法参考 `semantic_navigation/SKILL.md`）：

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

`stop_actions` 必须非空（Pilot 强制校验）；只读 Skill 声明一个无害的只读 Action 以满足契约，`on_stop` 本身不发起新的物理动作。

### models.py（全文）

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

### skill.py（全文）

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

`GetRobotStateParameters`、`LocateObjectParameters` 与 `semantic_navigation/scripts/models.py` 中同名的参数模型一致，后者已被三个内置 Skill 长期用于构造这两个 Action；自建 Skill 按目标 Ability Manifest 的 `inputFields` 定义等价模型即可。单元测试写法见上文第 5 步：`MockSkillContext(ObjectSurveyInput(object_ref="tote-large-smoke"))` + `queue_action("robot.get_state", ActionResult(status="succeeded", observations=[...]))` 后用 `run_skill(run, ctx)` 断言终态。

## Worker 运行机制

Worker 是 Skill 的宿主进程，由 Pilot 启动：

```bash
python -m semantic_robot_skill_sdk.worker --skill-dir <skill目录>
```

- 启动后先向 stdout 发 `ready` 通知；此后 **stdout 只承载 JSON-RPC**（worker 内部把 stdout 重定向到 stderr，第三方 print 不会污染协议通道）；
- Pilot 调 `worker.initialize`（携带 entrypoint/stop_entrypoint/input_model/controllers），Worker 导入入口并返回 `input_schema`；
- `skill.validate_input` 只校验输入不执行；
- `skill.run` 携带 `execution_id / robot_ref / input / checkpoint / feedback_cursors`，Worker 保证单 Execution，`run(ctx)` 最多重入 64 次直到终态；
- `skill.stop` 先 `context.request_stop()` 再执行 `on_stop`，先发 `stop.outcome` 通知再返回；
- Skill 运行中 Pilot 仍可并发下发 `skill.stop`（`ConcurrentJsonRpcPeer` 后台读线程按 id 分发）。

Skill → Pilot 反向调用（`RpcSkillContext`）：`action.start / action.feedback / action.result / action.stop / observation.get / observation.latest / agent.request / artifact.resolve / artifact.publish / runtime.now`，以及单向通知 `checkpoint / complete / fail / log / event.report`，全部自动携带 `execution_id`。

### JSON-RPC 消息清单

传输层是 **一行一个 JSON 对象的 JSON-RPC 2.0 行协议**（`semantic_robot_skill_sdk/protocol.py` 的 `LineJsonRpcPeer` / `ConcurrentJsonRpcPeer`），二进制数据只能以 Artifact 引用表达。下表汇总 `worker.py` 与 `rpc_context.py` 的全部方法名：

**Pilot → Worker（Worker 的 `serve()` 分发）**

| 方法 | params 关键字段 | 返回 / 行为 |
|---|---|---|
| `worker.initialize` | `name`、`version`、`runtime`（含 `api_version`、`entrypoint`、`stop_entrypoint`、`input_model`、`controllers`） | 返回 `{status: "initialized", name, version, input_schema}`；已初始化的 Worker 拒绝换 Skill 或版本（错误码 -32000） |
| `skill.validate_input` | `input` | 只校验不执行；返回 `{valid: true, input}` 或 `{valid: false, error}` |
| `skill.run` | `execution_id`、`robot_ref`、`input`、`checkpoint`、`log_fields`、`feedback_cursors` | 后台线程执行；同一 Worker 保证单 Execution（-32001），终态返回 `{status, result, error}` |
| `skill.stop` | `request`（`StopRequest`：`id/source/reason/mode/requested_at`） | 先锁存停止再执行 `on_stop`；发送 `stop.outcome` 通知后返回 StopOutcome（-32002 = 无活动 Execution） |
| `worker.shutdown` | 无 | 返回 `{status: "shutting_down"}` 后退出主循环 |
| （未知方法） | — | 错误码 -32601 |

**Worker → Pilot（`RpcSkillContext` 的同步请求）**

| 方法 | params 关键字段 | 返回 |
|---|---|---|
| `action.start` | `key`、`action`（Action 信封）、`stop_action` | `{action_id}`；`stop_action: true` 时只接受 `stop_actions` 清单中的 Action |
| `action.feedback` | `action_id`、`after_sequence` | `{feedback: [...], terminal: bool}`，按 sequence 游标增量续读 |
| `action.result` | `action_id` | `ActionResult` |
| `action.stop` | `action_id`、`reason` | `ActionResult`（status 通常为 `stopped`） |
| `observation.get` | `observation_ref` | `Observation` 或 `null` |
| `observation.latest` | `kind`、`subject_ref`、`max_age_ms` | `Observation` 或 `null` |
| `agent.request` | `key`、`reason`、`context`、`response_model`、`response_schema` | 按 `response_schema` 校验后的类型化决策 |
| `artifact.resolve` | `ref` | `{ref, local_path, media_type, size_bytes, summary}` |
| `artifact.publish` | `path`、`media_type`、`summary` | `{local_ref, server_ref, sync_status}` |
| `runtime.now` | 无 | RFC3339 UTC 时间字符串 |

**Worker → Pilot 单向通知**：`ready`（Worker 启动后第一条，携带 `skill_dir`）、`checkpoint`（`execution_id` + `state`）、`event.report`、`log`、`complete`、`fail`、`stop.outcome`。其中 `checkpoint / complete / fail` 由 Pilot 内部消化（`complete/fail` 不向 Server 转发，避免用过期 running 状态覆盖正式终态）；`event.report` 的 `stage.running` 还会把 `stage` 写入恢复 checkpoint 后再转发。

### 事件名清单

`event.report` 的 `event` 字段由 Skill 自行定义并原样转发到事件通道（`runtime.go` 不做枚举校验）。三个内置 Skill 实际使用：

| 事件 | 语义 | 典型字段 |
|---|---|---|
| `stage.running` | 进入某 Stage（Pilot 借此把 Stage 写入 checkpoint） | `stage`、`stage_status: "running"`、`expectation`、`next_step` |
| `stage.progress` | Stage 内部进展或偏离 | `stage`、`progress`、`observation_summary`、`deviation` |
| `stage.completed` | 某 Stage 收敛 | `stage`、`stage_status: "completed"`、`summary` |
| `decision.required` | 请求 Agent 决策前的时间线留痕 | `stage`、`stage_status: "waiting_agent"`、`deviation` |

Pilot 侧自身还会发出系统事件（`internal/pilot/runtime.go` 的 `events.Report`）：`skill.started`、`action.started`、`action.terminal`、`feedback.emitted`、`observation.recorded`、`agent.requested`、`agent.resolved`、`stop.outcome`、`skill.stop.finalized`、`worker.restarted`、`artifact.summary.announced` / `artifact.summary.failed`、`execution.terminal`。Skill 自定义事件与系统事件共用同一条通道，下游按 `event` 名区分。

## Pilot 侧生命周期

| 阶段 | 实现 | 说明 |
|---|---|---|
| 发现 | `ScanSkillCatalog` | 只扫描 root 下含 SKILL.md 的一级目录（`active/<name>` 符号链接跟随） |
| 安装 | `InstalledSkillManager.Install` | 解压 ZIP（拒绝符号链接/路径穿越）→ 校验 → 原子挪到 `packages/<name>/<version>` |
| 启用 | `Enable(name, version)` | `active/<name>` 符号链接原子切换；执行中的 Skill 拒绝 Disable/Uninstall |
| 启动 | `supervisor.go` | `exec python -m semantic_robot_skill_sdk.worker --skill-dir ...`，PYTHONPATH 追加 skills 目录 |
| 执行 | `runtime.go` | 构造 `skill.run` params；路由 checkpoint / action / agent.request；停止要求拿到 `stop.outcome` 安全证据才记 `stopped`，否则 `interrupted` |
| Action 路由 | `runner.go` | action key 幂等（同 key 同内容复用结果，不同内容报冲突）；物理 Action 有 Robot 级互斥锁 |

## 本地调试

### 手动驱动 Worker

```bash
cd semantic-skill/robot-skill
python -m semantic_robot_skill_sdk.worker --skill-dir semantic_robot_skills/skills/semantic_navigation
# stdin/stdout 只能发 JSON-RPC（一行一个 JSON）
```

手动跨 Skill 导入调试时需自行设置 PYTHONPATH（Pilot 启动时会自动追加，手动不会）。

### Pilot 本地 Skill Run

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

要点：

- `--skill` 必须精确到版本（`name@version`）；
- 本地模式不装配 Agent：`agent.request` 一律失败，进入 `waiting_agent` 时命令直接报错；
- 前置条件：MuJoCo Scene + AbilityFramework 已就绪（见 `examples/mujoco-skill-debug/README.md`）；同一 Robot 不能同时被常驻 Pilot 和本地命令控制。

#### 全部命令行 flags（cmd/semantic-pilot/local_skill.go）

| Flag | 缺省值 | 说明 |
|---|---|---|
| `--profile` | 环境变量 `SEMANTIC_ROBOT_CONFIG`，其次 `SEMANTIC_ROBOT_DEPLOYMENT` | RobotDeployment YAML（必填；必须含 `ability_framework.endpoint`，否则启动即报错） |
| `--skill` | 无 | `name@version`，两者都不可为空（必填） |
| `--input` | 无 | Skill 输入 JSON 文件；`-` 表示从 stdin 读取，内容必须是 JSON object（必填） |
| `--skill-catalog` | 环境变量 `SEMANTIC_ROBOT_SKILL_CATALOG_DIR` | 本地 Skill 目录根；未提供时回退到部署配置 `pilot.robot_skill_directory/active` |
| `--python` | 环境变量 `SEMANTIC_ROBOT_SKILL_PYTHON`，其次 `python` | 启动 Worker 进程使用的 Python 解释器 |
| `--python-path` | 无（可重复） | 逐条追加 Worker 进程的 `PYTHONPATH`（手动跨 Skill 导入调试时使用） |
| `--ability-framework` | 无 | 覆盖部署配置中的 `ability_framework.endpoint` |
| `--execution-id` | 自动生成 | 指定本地执行 ID |
| `--timeout` | `15m` | 执行最长时间；超时或 Ctrl+C 都会走正式 `runtime.Stop(..., mode="safe")` 链路（30 秒停止预算），不直接杀进程 |
| `--events` | `-`（stderr） | JSONL 事件输出路径；`-` 表示 stderr，空字符串表示关闭 |
| `--result` | `-`（stdout） | 最终结果 JSON 输出路径；`-` 表示 stdout |

启动流程（同一文件）：加载并严格校验部署配置 → 以 10 秒超时刷新 AbilityFramework Action 目录（不在线则失败）→ `ScanSkillCatalog` 解析 `--skill` 指定的版本 → 启动 Worker 并等待终态；终态不是 `completed` 时命令以非零退出。

#### events.jsonl 与 result.json 的预期内容

`--events` 文件每行一个 JSON 对象（`localSkillEventWriter`），分两类：

```text
事件行：{"time": "<UTC>", "kind": "event", "event": "<事件名>", "execution_id": "...", "skill": "...", "status": "<执行状态>", "fields": {...}}
日志行：{"time": "<UTC>", "kind": "log", "level": "...", "message": "...", "execution_id": "...", "skill": "...", "fields": {...}}
```

一次成功的只读巡检（上文完整示例）预期依次出现的事件（`event` 字段）：

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

物理 Skill（如 grasp-object）还会看到 `feedback.emitted`、`observation.recorded`、`stop.outcome` / `skill.stop.finalized`；需要 Agent 决策时本地命令先发 `agent.requested` 再失败退出。`fields` 内是各事件的原始 params（含 `stage`、`key`、`progress` 等，与上文事件名清单一致）。

`--result` 文件是缩进的最终结果 JSON（`writeLocalSkillResult`）：

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

失败时 `error` 为 `{code, message, evidence_refs}`；发生过停止时 `stop_outcome` 为 `on_stop` 返回的 `{safe, summary, physical_state, requires_intervention, evidence_refs}`。

## 测试

```bash
cd semantic-skill/robot-skill
make check   # compileall 语法检查
make test    # pytest：仓库级跨进程/契约测试 + 各 Skill 的 tests/
```

注意：本机需要 Python 3.11+（系统只有 `python` 命令时可用 `uv venv --python 3.11 .venv` 后在 venv 下执行）。

测试分层：

- Model 与 Stage 单元测试（MockSkillContext）；
- 仓库级 JSON-RPC 跨进程全流程（`tests/test_jsonrpc_worker.py`：ready → initialize → validate → run → 终态 → shutdown）；
- 包结构契约测试（`test_skill_package_contract.py`，注意该测试硬编码了现有 Skill 的精确版本号，新增/升级 Skill 时需同步更新）；
- Pilot 本地 Skill Run → 真实 AbilityFramework 与 Robot SDK → 仿真/真机完整执行 → Framework Task 与 Web 调试入口。

### 测试位置清单

| 文件 / 目录 | 覆盖内容 |
|---|---|
| `tests/test_jsonrpc_worker.py` | 真实子进程 + 管道的 JSON-RPC 全流程：`ready → worker.initialize → skill.validate_input → skill.run`（逐条应答 `action.start/feedback/result`、`observation.latest`、`log`）`→ 终态 → worker.shutdown`；同时验证 stdout 被污染时明确失败 |
| `tests/test_runtime.py` | MockSkillContext 关键恢复语义：同 key 复用 Action 结果、同 key 不同内容拒绝、反馈游标续读、`latest_observation` 过滤、Artifact 工作区边界、`agent.request` 自动携带 Schema、`event.report` 字段透传 |
| `tests/test_skill_package_contract.py` | 包结构契约：SKILL.md 是唯一清单（无 `robot-skill.yaml`）、五个 `module:attr` 入口文件存在、`requirements.lock` 内容、`schema_version: 2`、Skill 脚本禁止导入设备/模型库和 `print()`、SDK Wheel 只含 `semantic_robot_skill_sdk*`。硬编码了三个内置 Skill 的精确版本号，新增/升级 Skill 时需同步更新 |
| `semantic_robot_skills/skills/*/tests/` | 各 Skill 的 Stage 单元测试（`test_semantic_navigation.py`、`test_navigation_carrying.py`、`test_grasp_object.py`、`test_place_object.py`），全部基于 MockSkillContext |
| `make test` 实际执行的命令 | `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -p no:cacheprovider -q tests semantic_robot_skills/skills/*/tests`（先经 `make check` 的 compileall 语法检查） |

注意：仓库内不存在名为 `skills/test_skill` 的冒烟 Skill 或对应测试文件；最简可运行参考是上文"完整示例：只读巡检 Skill"，以及 `tests/test_jsonrpc_worker.py` 对 semantic-navigation Worker 的驱动序列。

## 设计要点

- Stage 表达用户能够理解的执行阶段；先落 `checkpoint` 再做不可逆操作；
- 通过对象和区域身份（ref）表达业务目标；精确位姿、接触、载荷在执行时重新观察；
- Skill 只描述 Stage、Action、反馈和恢复逻辑，设备连接和底层实现由 Ability 与 Robot SDK 负责；
- 停止路径专用 `execute_stop` / `on_stop`，不依赖普通 Action；停止结果未知时不启动下一项 Action；
- 需要业务选择、批准范围变化或执行状态无法确认时，用 `request_agent` 请求 Robot Agent，Agent 只能返回 Skill 定义的类型化决定。

## 相关层次

- 概念模型：[架构 · Robot 执行与具身闭环](/architecture/06-robot-execution/)
- 实现细节：[内部实现 · Pilot 与 Robot Execution](/developer/reference/internals/robot-execution-and-environment/)
