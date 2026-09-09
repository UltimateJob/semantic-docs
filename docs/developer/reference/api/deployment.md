---
title: "RobotDeployment"
linkTitle: "RobotDeployment"
weight: 14
description: "RobotDeployment 字段参考：类型包、RobotInstance 与 robot-deployment.yaml 三层配置对象，字段表、真实示例与实例目录产物，全部从 semantic-robot-deployment 与 semantic-framework 源码提取。"
---

RobotDeployment 是一台 Robot 的部署配置事实（`robot-deployment.yaml`，`api_version: 1`）：Pilot、Ability 与 Robot SDK 共用这一份文件，Ability 不再逐个保存 Robot endpoint。它由语义框架在运行时消费（`semantic-framework/internal/pilot/discovery.go` 的 `RobotDeployment`），也由实例启动器严格解析（`semantic-robot-deployment/internal/instance/start.go`）。

在体系中的位置：**类型包（RobotRuntimeBundle）提供模板与制品 → RobotInstance 配置声明单台 Robot 的差异项 → 渲染（render）产出实例目录**，实例目录中的 `robot-deployment.yaml` 即本文所述的 RobotDeployment。Robot SDK 如何消费其中的 endpoint、profile 与安全限制见 [Robot SDK](/developer/core-modules/robot/robot-sdk/)；从加入码到设备上线的完整流程见[设备部署](/developer/integration/device/deployment/)。

## 三个配置对象

| 对象 | 文件 | 解析代码 | 说明 |
|---|---|---|---|
| RobotRuntimeBundle | 类型包根 `bundle.yaml` | `semantic-robot-deployment/internal/bundle/manifest.go` | 可复用的型号运行包：模型、SDK 包、默认 SDK 参数、backend profile、Ability 制品与**渲染模板**。共享只读；Robot ID、Endpoint、凭据属于实例配置，不能写入 bundle |
| RobotInstance | 实例差异配置（`instance.yaml`） | `semantic-robot-deployment/internal/instance/config.go` | 单台 Robot 的差异项：bundle 引用、Robot 身份、SDK endpoint、AF 地址、Server 地址与凭据。严格解析（未知字段报错），渲染后原样存入实例目录 |
| RobotDeployment | `robot-deployment.yaml` | `semantic-framework/internal/pilot/discovery.go`、`semantic-robot-deployment/internal/instance/start.go` | 渲染产物，也是 Pilot/Ability/Robot SDK 的运行配置。`start` 子命令还可直接以它为输入反向生成实例目录 |

### RobotRuntimeBundle（bundle.yaml）关键字段

源码：`semantic-robot-deployment/internal/bundle/manifest.go`；真实示例 `type-packages/r1pro-mujoco/bundle.yaml`、`type-packages/r1pro-fake/bundle.yaml`。

| 字段 | 说明 |
|---|---|
| `apiVersion` / `kind` | 必须 `semantic.insightos.cn/v1alpha1` / `RobotRuntimeBundle` |
| `metadata.name` / `version` | 类型包标识与版本 |
| `spec.robot.model` | Robot 型号，实例必须匹配 |
| `spec.robot.sdkPackage` | SDK 包名，渲染时写入 `robot.sdk.package` |
| `spec.robot.defaultSDKOptions` | 稳定默认 SDK 参数（如关节公差、导航分辨率），实例 `options` 只覆盖显式声明的键 |
| `spec.robot.backendProfiles` | `backend` + `profile` 组合，实例的 `backendProfile` 必须命中其一 |
| `spec.artifacts` | 启动器、AbilityFramework、Pilot、Skill SDK wheel、Python 解释器、Ability zip 等制品路径 |
| `spec.templates` | `robotDeployment` / `abilityFramework` 模板与可选 `modelRegistry`，渲染成实例目录中的派生文件 |
| `spec.runtime` | `readinessTimeout`（如 45s）与 `shutdownTimeout`（如 15s） |

### RobotInstance 关键字段

源码：`semantic-robot-deployment/internal/instance/config.go`（`Config`）。`apiVersion` 固定 `semantic.insightos.cn/v1alpha1`、`kind` 固定 `RobotInstance`。

| 字段 | 必填 | 说明 |
|---|---|---|
| `metadata.name` | 是 | 实例名 |
| `spec.bundle` | 是 | 类型包目录（相对路径按配置文件所在目录解析为绝对路径） |
| `spec.robot.id` / `displayName` / `model` / `backend` / `backendProfile` | 是 | Robot 身份与后端选择；`model`/`backend`/`backendProfile` 须被 bundle 支持 |
| `spec.robot.sdkEndpoint` | mujoco 必填 | Robot SDK 服务地址（http/https） |
| `spec.robot.firmwareProfile` | 是 | 固件 profile |
| `spec.robot.sceneInstanceId` | mujoco 必填 | 关联的运行中场景实例 ID |
| `spec.robot.urdfPath` / `packageDirectories` | mujoco 必填 | 本地 IK 所需 URDF 与 mesh 包目录 |
| `spec.robot.options` | 否 | SDK 参数，覆盖类型包 `defaultSDKOptions` 中的同名键 |
| `spec.robot.tools` | mujoco 必填 | Runtime Robot Profile 的工具描述（见下文 `tools`） |
| `spec.abilityFramework.endpoint` | 是 | AF 地址（http/https）；端口即渲染后 AF 监听端口 |
| `spec.abilityFramework.managed` | 否 | 是否由实例启动器托管 AF 进程 |
| `spec.abilityFramework.listenAddress` | 否 | AF 监听地址，默认 `127.0.0.1` |
| `spec.semanticServer.websocketURL` / `httpURL` / `accessToken` | 是 | 回连 Server 的地址与 Pilot credential（由启动流程从 `connection.yaml` 填入） |
| `spec.pilot.id` | 是 | Pilot 实例 ID |

## RobotDeployment 字段表

以下字段从两个消费方结构体核对：`semantic-framework/internal/pilot/discovery.go`（Pilot 运行时读取）与 `semantic-robot-deployment/internal/instance/start.go`（`start` 时以 `KnownFields(true)` 严格解析，未知键报错）。两处校验的并集为：`api_version` 必须为 `1`；`robot.id`、`robot.model`、`robot.backend`、`robot.sdk.package`、`ability_framework.endpoint` 必填，`ability_framework.endpoint` 必须是有效 URL。

顶层：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `api_version` | int | 是 | 当前必须为 `1` |
| `robot` | object | 是 | Robot 身份、SDK、坐标系、工具与安全限制 |
| `ability_framework` | object | 是 | AbilityFramework 连接信息 |
| `abilities` | map | 是 | 期望的语义角色 → Ability 部署项（键如 `navigation`） |
| `pilot` | object | 是 | Pilot 进程参数 |
| `robot_skills` | []object | 否 | 期望安装的 Robot Skill 列表 |

### robot：Robot 身份与 SDK

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `robot.id` | string | 是 | Robot 唯一标识；进入实例目录名与 Server 侧身份 |
| `robot.display_name` | string | 否 | 显示名；缺省取 `robot.id`（start 填充） |
| `robot.model` | string | 是 | Robot 型号，须与类型包一致 |
| `robot.backend` | string | 是 | 后端类型：`mujoco`（MuJoCo Runtime）或 `fake`（无仿真依赖） |
| `robot.sdk.package` | string | 是 | SDK 包名（由类型包 `sdkPackage` 渲染） |
| `robot.sdk.endpoint` | string | backend=mujoco 必填 | Robot SDK HTTP 地址，如 `http://127.0.0.1:18090`；环境变量 `SEMANTIC_ROBOT_SDK_ENDPOINT` 可按进程覆盖（`discovery.go`） |
| `robot.sdk.backend_profile` | string | 否 | 后端 profile，如 `r1pro-tote-mujoco-v1`；缺省取 `<backend>-v1`（start 填充） |
| `robot.sdk.firmware_profile` | string | 是 | 固件 profile |
| `robot.sdk.scene_instance_id` | string | backend=mujoco 必填 | 关联的运行中场景实例 ID |
| `robot.sdk.providers` | map[string]string | 否 | 各能力提供方：`kinematics`/`motion`/`navigation`（模板取 `local` 或 `fake`） |
| `robot.sdk.options` | map[string]any | 否 | SDK 运行参数：类型包默认值与实例差异项合并后写入 |

`robot.sdk.options` 的键由 Robot SDK 解释，R1 Pro 类型包使用的键包括 `timeout_seconds`、`base_footprint_radius_m`（底盘足迹半径）、`navigation_resolution_m`（导航栅格分辨率）、`manipulation_work_distance_m`（按目标外表面到基座中心计的作业距离）、`joint_position_tolerance_rad`、`fixed_end_effector_position_tolerance_m`、`fixed_end_effector_orientation_tolerance_rad`（来源：`type-packages/r1pro-mujoco/bundle.yaml` 的 `defaultSDKOptions`）；<!-- TODO(实跑或确认): options 的完整键清单与取值范围由 semantic-robot-sdk 解释，跨仓核实后补充 -->

### robot.frames / robot.tools / robot.kinematics / robot.safety

类型相关段：框架侧 `discovery.go` 按通用 map 透传（并经 `DeviceConfiguration` 下发设备页），`start.go` 对 `tools` 与 `kinematics` 有强类型结构；字段取值由类型包模板与 Robot SDK 共同约定。

| 字段 | 类型 | 说明 |
|---|---|---|
| `robot.frames` | map | 坐标系：`world`、`base`、`end_effectors.<side>`（末端 frame，由工具 `frame` 渲染） |
| `robot.tools[]` | []object | 工具描述：`tool_ref`（如 `component://tool/left`）、`side`、`kind`、`frame`、`joint`、`travel_m`（行程）、`normal_force_n`（正常夹持力）、`maximum_force_n`（力上限） |
| `robot.kinematics` | object | `urdf_path`、`package_directories`、`controlled_joint_groups`（如 `left: [torso, left_arm]`）、`disabled_collision_pairs`、`named_postures`（命名姿态的关节角表） |
| `robot.safety` | map | 安全限制：R1 Pro 模板使用 `maximum_base_speed`（底盘速度上限）、`maximum_joint_speed`（关节速度上限）、`carrying_motion_scale`（携物时按实时 stable_load 缩放底盘速度/加速度/jerk 的系数） |

`tools` 与 `kinematics` 等机械边界由 Runtime Robot Profile 公开、Framework 只负责搬运，具体解释在 Robot 类型包与 SDK（`semantic-robot-deployment/internal/instance/config.go` 的 `ToolConfig` 注释）。<!-- TODO(实跑或确认): safety 各键的取值范围与越界行为由 Robot SDK 校验，跨仓核实后补充 -->

### ability_framework / abilities / pilot / robot_skills

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `ability_framework.endpoint` | string | 是 | AF 地址（如 `http://127.0.0.1:18083`）；Pilot 经其读取 heartbeat 与 Manifest |
| `ability_framework.managed_by_instance` | bool | 否 | 是否由实例启动器托管 AF 进程 |
| `abilities.<role>` | object | — | 语义角色的部署项，可选 `instance_id` 固定 AF 实例 UUID；未填写时仅当该角色恰有一个健康实例时自动绑定，多个实例时拒绝随机选择（`discovery.go` 的 `selectRoleInstance`）。角色名来自类型包 `abilities[].role`，与 AF heartbeat 的 AbilityRole 匹配 |
| `pilot.id` | string | 是 | Pilot 实例 ID；缺省取 `pilot-<robot.id>`（start 填充） |
| `pilot.robot_skill_directory` | string | 否 | Robot Skill 存储根（`active`/`packages`/`environments`/`staging`）；渲染时写入实例目录 `pilot/skills` |
| `pilot.worker_timeout_seconds` | int | 否 | Pilot 停机时等待活动 Worker/Execution 收敛的超时；缺省 30（start 填充），Pilot 侧未设置时回退 15s（`semantic-framework/cmd/semantic-pilot/main.go`） |
| `pilot.heartbeat_interval_seconds` | int | 否 | 向 Server 上报心跳的间隔；缺省 2（start 填充），未设置时 Pilot 侧回退 2s（`internal/pilot/remote.go`） |
| `pilot.allow_ability_debug` | bool | 否 | 是否允许 Ability 调试入口（设备页人工触发 AF Task） |
| `robot_skills[].name` / `version` / `enabled` | string/string/bool | — | 期望 Robot Skill（`name@version` 精确版本）。这是 Robot 启动后的**期望状态**声明：Server 按 Registry 下发精确版本，Pilot 只上报实际安装结果，不携带 Skill 源码（`discovery.go` 的 `RobotSkillDeployment`） |

## 真实示例

来源：`semantic-robot-deployment/examples/r1pro-mujoco-01.yaml`（与 `type-packages/r1pro-mujoco/templates/robot-deployment.yaml.tmpl` 的渲染结果同构，注释略有增删）：

```yaml
api_version: 1
robot:
  id: r1_pro_tote_gripper-1          # Robot 唯一标识；也决定默认实例目录名
  display_name: R1 Pro Tote Robot 1
  model: r1_pro_chassis              # 须与类型包 spec.robot.model 一致
  backend: mujoco                    # mujoco | fake
  sdk:
    package: semantic-robot-sdk-r1pro
    endpoint: http://127.0.0.1:18090 # Robot SDK 服务地址
    backend_profile: r1pro-tote-mujoco-v1
    firmware_profile: r1pro-tote-mujoco-v1
    scene_instance_id: replace-with-running-scene-instance-id  # 必须替换为运行中场景实例 ID
    providers:
      kinematics: local
      motion: local
      navigation: local
    options:
      timeout_seconds: 10
      base_footprint_radius_m: 0.42
      navigation_resolution_m: 0.05
      # 作业距离按目标外表面到基座中心计算，而不是按物体中心计算。
      manipulation_work_distance_m: 0.55
      joint_position_tolerance_rad: 0.009
      fixed_end_effector_position_tolerance_m: 0.005
      fixed_end_effector_orientation_tolerance_rad: 0.02
  frames:
    world: world
    base: base_link
    end_effectors:                   # 由 tools[].frame 渲染
      left: left_tote_load_frame
      right: right_tote_load_frame
  tools:                             # 机械边界由类型包/SDK 解释，Framework 只搬运
    - tool_ref: component://tool/left
      side: left
      kind: tote_clamp
      frame: left_tote_load_frame
      joint: left_tote_clamp_joint
      travel_m: 0.039
      normal_force_n: 60
      maximum_force_n: 120
    - tool_ref: component://tool/right
      side: right
      kind: tote_clamp
      frame: right_tote_load_frame
      joint: right_tote_clamp_joint
      travel_m: 0.039
      normal_force_n: 60
      maximum_force_n: 120
  kinematics:
    urdf_path: /opt/semantic/assets/robot/r1_pro_tote_gripper/meshes/r1_pro_tote_gripper.urdf
    package_directories: [/opt/semantic/assets/robot]
    controlled_joint_groups:
      left: [torso, left_arm]
      right: [torso, right_arm]
    disabled_collision_pairs:
      - [left_tote_hook, left_tote_clamp]
      - [right_tote_hook, right_tote_clamp]
    named_postures:
      travel: {torso_joint1: 0.0, torso_joint2: 0.0, torso_joint3: 0.0, torso_joint4: 0.0,
               left_arm_joint1: 0.0, left_arm_joint2: 0.0, left_arm_joint3: 0.0, left_arm_joint4: 0.0,
               left_arm_joint5: 0.0, left_arm_joint6: 0.0, left_arm_joint7: 0.0,
               right_arm_joint1: 0.0, right_arm_joint2: 0.0, right_arm_joint3: 0.0, right_arm_joint4: 0.0,
               right_arm_joint5: 0.0, right_arm_joint6: 0.0, right_arm_joint7: 0.0}
  safety:
    maximum_base_speed: 0.4
    maximum_joint_speed: 0.5
    carrying_motion_scale: 0.5       # 携物时按实时 stable_load 缩放底盘速度/加速度/jerk
ability_framework:
  endpoint: http://127.0.0.1:18083   # AF 地址；受管实例端口由 robot_runtime 端口池分配
  managed_by_instance: true
abilities:                           # 角色 → 部署项；角色名与类型包 abilities[].role 对应
  navigation: {}
  manipulator_motion: {coordination: synchronized}
  end_effector:
    default_tools: [component://tool/left, component://tool/right]
  robot_state: {}
  sensor_capture: {}
  object_perception:
    model_registry_path: /opt/semantic/model-registry.json
  grasp_planning:
    model_registry_path: /opt/semantic/model-registry.json
    transport_object_offset_base_m: [0.65, 0.0, 0.62]
pilot:
  id: pilot-r1_pro_tote_gripper-1
  worker_timeout_seconds: 30
  heartbeat_interval_seconds: 2
  allow_ability_debug: true
robot_skills:                        # 期望状态：Server 按 Registry 下发精确版本
  - {name: grasp-object, version: 0.4.17, enabled: true}
  - {name: semantic-navigation, version: 0.4.4, enabled: true}
  - {name: place-object, version: 0.4.14, enabled: true}
```

说明：上例将源文件 `named_postures` 改写为 flow 风格以控制篇幅，语义不变；仓库中的原始文件为逐行块风格。

## 实例目录产物

`semantic-robot-instance render` 与 `start` 都会为每台 Robot 建立独立可写目录，共享 bundle 中的任何文件不会被修改（`semantic-robot-deployment/internal/instance/render.go`）。产物：

| 产物 | 权限 | 说明 |
|---|---|---|
| `instance.yaml` | 0600 | 渲染所用的 RobotInstance 配置（升级 bundle 后随之刷新） |
| `robot-deployment.yaml` | 0640 | RobotDeployment（`start` 流程写入 0640；由部署 yaml 反向启动时为序列化后的运行配置） |
| `connection.yaml` | 0600 | 仅 `start` 流程：首次启动以 join code 调 `POST /api/v1/pilot-enrollments/claim` 领取 credential 后写入，含 `server_http_url`、`server_websocket_url`、`pilot_id`、`credential`、`enrolled_at`；后续启动只读此文件，不再要求管理员 token（`internal/instance/start.go`） |
| `ability-framework/config.yaml` | 0640 | 由类型包 `templates.abilityFramework` 渲染的 AF 配置 |
| `model-registry.json` | 0640 | 类型包声明 `templates.modelRegistry` 时从 bundle 复制（感知/抓取模型清单） |
| `run/bundle.json` | 0640 | bundle 来源元数据：`bundle_root`、`bundle_name`、`bundle_version`、`rendered_at` |
| `run/state.json` | 0640 | 实例状态：`status`（`rendered`/`starting`/`running`/`stopping`/`interrupted`/`stopped`/`failed`）、`robot_id`、各进程 PID、`stop_evidence` 等（`internal/instance/state.go`） |
| `run/instance.lock` | 0640 | 实例互斥锁：常驻 supervisor 与本地 `semantic-pilot debug-stack` 共用，防止并行运行（`internal/instance/runner.go`、`debug_stack.go`） |
| `pilot/robot-state.sqlite` | — | Robot 状态库；fake 后端经 `sdk.options.state_path` 指向此文件，初态只在首次建立时生效 |
| `executions/`、`pilot/{artifacts,logs,python-cache,skills/{active,packages,environments,staging}}`、`ability-framework/{packages,crs,databases,data,log,artifact-exchange}` | 0750 | 运行数据与工作目录，Render 统一建立 |

## 启动入口与受管模式

`semantic-robot-instance`（源码 `cmd/semantic-robot-instance/main.go`）提供 `start` / `render` / `run` / `status` / `stop` / `debug-stack` 子命令：

- **用户启动流**：`semantic-robot-instance start --config <robot-deployment.yaml> --join-code <加入码> --server-http <URL> --server-ws <URL>`。首次启动换取 credential 写入 `connection.yaml`；`--data-dir` 缺省为 `$XDG_STATE_HOME`（否则 `~/.local/state`）下的 `semantic/robots/<robot-id 安全化>`（`internal/instance/start.go` 的 `defaultDataDirectory`）。
- **渲染流**：`render --config <RobotInstance.yaml> --output <实例目录>`；要求目标目录为空，拒绝覆盖。
- **受管模式**：`semantic-server.yaml` 的 `robot_runtime.enabled: true` 时，Server 作为 supervisor 从 `bundles_dir` 加载类型包、从端口池 `ability_port_first..ability_port_last` 分配 AF 端口，把 Runtime Instance 转成 `semantic-robot-instance` 前台 supervisor 进程（`semantic-framework/internal/bootstrap/managed_robot_runtime.go`）。

## 验证方式

- 结构校验：`render`/`start` 解析失败即报错（未知字段、必填缺失、URL/组合校验），无需启动进程；
- 状态查询：`semantic-robot-instance status --instance <目录>` 输出 `state.json` 的 JSON，supervisor 进程已退出而状态未收口时标记 `failed`；
- Server 侧核对：设备工作台的"配置"视图来自 `RobotDeployment.DeviceConfiguration()`（endpoint、profile、providers、坐标系、工具与安全上限），见 [WebSocket 事件](/developer/reference/api/ws/)的设备通道。
