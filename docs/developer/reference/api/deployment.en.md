---
title: "RobotDeployment"
linkTitle: "RobotDeployment"
weight: 14
description: "RobotDeployment field reference: the three-layer config objects type package, RobotInstance, and robot-deployment.yaml, plus field tables, a real example, and instance-directory artifacts. All extracted from semantic-robot-deployment and semantic-framework source."
---

RobotDeployment is the deployment-config fact for one Robot (`robot-deployment.yaml`, `api_version: 1`): Pilot, Ability, and Robot SDK share this one file. Ability no longer stores a Robot endpoint of its own. It is consumed at runtime by the semantic framework (`RobotDeployment` in `semantic-framework/internal/pilot/discovery.go`) and strictly parsed by the instance launcher (`semantic-robot-deployment/internal/instance/start.go`).

Place in the system: **a type package (RobotRuntimeBundle) provides templates and artifacts → RobotInstance config declares one Robot's deltas → render produces the instance directory**. `robot-deployment.yaml` in that instance directory is the RobotDeployment described here. How Robot SDK consumes endpoint, profile, and safety limits is in [Robot SDK](../../core-modules/robot/robot-sdk.en.md). The full flow from join code to device online is in [Device deployment](../../integration/device/deployment.en.md).

## Three config objects

| Object | File | Parse code | Description |
|---|---|---|---|
| RobotRuntimeBundle | type-package root `bundle.yaml` | `semantic-robot-deployment/internal/bundle/manifest.go` | Reusable model runtime pack: model, SDK package, default SDK parameters, backend profile, Ability artifacts, and **render templates**. Shared and read-only. Robot ID, Endpoint, and credentials belong to instance config and must not be written into the bundle |
| RobotInstance | instance-delta config (`instance.yaml`) | `semantic-robot-deployment/internal/instance/config.go` | Deltas for one Robot: bundle reference, Robot identity, SDK endpoint, AF address, Server address, and credentials. Strict parse (unknown fields error). After render it is stored as-is in the instance directory |
| RobotDeployment | `robot-deployment.yaml` | `semantic-framework/internal/pilot/discovery.go`, `semantic-robot-deployment/internal/instance/start.go` | Render product, and also the run config for Pilot/Ability/Robot SDK. The `start` subcommand can also take it as input and generate the instance directory in reverse |

### RobotRuntimeBundle (bundle.yaml) key fields

Source: `semantic-robot-deployment/internal/bundle/manifest.go`; real examples `type-packages/r1pro-mujoco/bundle.yaml`, `type-packages/r1pro-fake/bundle.yaml`.

| Field | Description |
|---|---|
| `apiVersion` / `kind` | Must be `semantic.insightos.cn/v1alpha1` / `RobotRuntimeBundle` |
| `metadata.name` / `version` | Type-package id and version |
| `spec.robot.model` | Robot model. The instance must match |
| `spec.robot.sdkPackage` | SDK package name. Written into `robot.sdk.package` at render |
| `spec.robot.defaultSDKOptions` | Stable default SDK parameters (for example joint tolerance, navigation resolution). Instance `options` only override explicitly declared keys |
| `spec.robot.backendProfiles` | `backend` + `profile` combinations. Instance `backendProfile` must hit one of them |
| `spec.artifacts` | Paths for launcher, AbilityFramework, Pilot, Skill SDK wheel, Python interpreter, Ability zip, and other artifacts |
| `spec.templates` | `robotDeployment` / `abilityFramework` templates and optional `modelRegistry`, rendered into derived files in the instance directory |
| `spec.runtime` | `readinessTimeout` (for example 45s) and `shutdownTimeout` (for example 15s) |

### RobotInstance key fields

Source: `semantic-robot-deployment/internal/instance/config.go` (`Config`). `apiVersion` is fixed `semantic.insightos.cn/v1alpha1`, `kind` is fixed `RobotInstance`.

| Field | Required | Description |
|---|---|---|
| `metadata.name` | Yes | Instance name |
| `spec.bundle` | Yes | Type-package directory (relative paths are resolved against the config file's directory) |
| `spec.robot.id` / `displayName` / `model` / `backend` / `backendProfile` | Yes | Robot identity and backend choice. `model`/`backend`/`backendProfile` must be supported by the bundle |
| `spec.robot.sdkEndpoint` | required for mujoco | Robot SDK service address (http/https) |
| `spec.robot.firmwareProfile` | Yes | Firmware profile |
| `spec.robot.sceneInstanceId` | required for mujoco | Related running scene-instance ID |
| `spec.robot.urdfPath` / `packageDirectories` | required for mujoco | URDF and mesh package directories needed for local IK |
| `spec.robot.options` | No | SDK parameters. Override same-named keys in the type package `defaultSDKOptions` |
| `spec.robot.tools` | required for mujoco | Tool description from the Runtime Robot Profile (see `tools` below) |
| `spec.abilityFramework.endpoint` | Yes | AF address (http/https). The port is the rendered AF listen port |
| `spec.abilityFramework.managed` | No | Whether the instance launcher hosts the AF process |
| `spec.abilityFramework.listenAddress` | No | AF listen address, default `127.0.0.1` |
| `spec.semanticServer.websocketURL` / `httpURL` / `accessToken` | Yes | Callback Server address and Pilot credential (filled from `connection.yaml` by the start flow) |
| `spec.pilot.id` | Yes | Pilot instance ID |

## RobotDeployment field table

The fields below were checked against two consumer structs: `semantic-framework/internal/pilot/discovery.go` (Pilot runtime read) and `semantic-robot-deployment/internal/instance/start.go` (`start` parses with `KnownFields(true)`; unknown keys error). The union of the two validations is: `api_version` must be `1`; `robot.id`, `robot.model`, `robot.backend`, `robot.sdk.package`, and `ability_framework.endpoint` are required; `ability_framework.endpoint` must be a valid URL.

Top level:

| Field | Type | Required | Description |
|---|---|---|---|
| `api_version` | int | Yes | Must be `1` today |
| `robot` | object | Yes | Robot identity, SDK, frames, tools, and safety limits |
| `ability_framework` | object | Yes | AbilityFramework connection |
| `abilities` | map | Yes | Desired semantic role → Ability deploy item (keys such as `navigation`) |
| `pilot` | object | Yes | Pilot process parameters |
| `robot_skills` | []object | No | Desired Robot Skill list |

### robot: Robot identity and SDK

| Field | Type | Required | Description |
|---|---|---|---|
| `robot.id` | string | Yes | Unique Robot id. Enters the instance directory name and Server-side identity |
| `robot.display_name` | string | No | Display name. Defaults to `robot.id` (filled by start) |
| `robot.model` | string | Yes | Robot model. Must match the type package |
| `robot.backend` | string | Yes | Backend type: `mujoco` (MuJoCo Runtime) or `fake` (no simulation dependency) |
| `robot.sdk.package` | string | Yes | SDK package name (rendered from type-package `sdkPackage`) |
| `robot.sdk.endpoint` | string | required when backend=mujoco | Robot SDK HTTP address, for example `http://127.0.0.1:18090`. Environment variable `SEMANTIC_ROBOT_SDK_ENDPOINT` can override per process (`discovery.go`) |
| `robot.sdk.backend_profile` | string | No | Backend profile, for example `r1pro-tote-mujoco-v1`. Defaults to `<backend>-v1` (filled by start) |
| `robot.sdk.firmware_profile` | string | Yes | Firmware profile |
| `robot.sdk.scene_instance_id` | string | required when backend=mujoco | Related running scene-instance ID |
| `robot.sdk.providers` | map[string]string | No | Capability providers: `kinematics`/`motion`/`navigation` (templates use `local` or `fake`) |
| `robot.sdk.options` | map[string]any | No | SDK run parameters: type-package defaults merged with instance deltas |

Keys of `robot.sdk.options` are interpreted by Robot SDK. Keys used by the R1 Pro type package include `timeout_seconds`, `base_footprint_radius_m` (base footprint radius), `navigation_resolution_m` (navigation grid resolution), `manipulation_work_distance_m` (work distance from the target outer surface to the base center), `joint_position_tolerance_rad`, `fixed_end_effector_position_tolerance_m`, `fixed_end_effector_orientation_tolerance_rad` (source: `defaultSDKOptions` in `type-packages/r1pro-mujoco/bundle.yaml`); <!-- TODO(实跑或确认): options 的完整键清单与取值范围由 semantic-robot-sdk 解释，跨仓核实后补充 -->

### robot.frames / robot.tools / robot.kinematics / robot.safety

Type-related sections: the framework side passes them through as a generic map in `discovery.go` (and issues them to the device page via `DeviceConfiguration`). `start.go` has strongly typed structures for `tools` and `kinematics`. Field values are jointly agreed by the type-package template and Robot SDK.

| Field | Type | Description |
|---|---|---|
| `robot.frames` | map | Frames: `world`, `base`, `end_effectors.<side>` (end-effector frame, rendered from tool `frame`) |
| `robot.tools[]` | []object | Tool description: `tool_ref` (for example `component://tool/left`), `side`, `kind`, `frame`, `joint`, `travel_m` (travel), `normal_force_n` (normal grip force), `maximum_force_n` (force limit) |
| `robot.kinematics` | object | `urdf_path`, `package_directories`, `controlled_joint_groups` (for example `left: [torso, left_arm]`), `disabled_collision_pairs`, `named_postures` (named posture joint-angle tables) |
| `robot.safety` | map | Safety limits. The R1 Pro template uses `maximum_base_speed` (base speed limit), `maximum_joint_speed` (joint speed limit), `carrying_motion_scale` (coefficient that scales base speed/acceleration/jerk from live stable_load while carrying) |

Mechanical bounds such as `tools` and `kinematics` are published by the Runtime Robot Profile. The Framework only transports them. Concrete interpretation lives in the Robot type package and SDK (`ToolConfig` comment in `semantic-robot-deployment/internal/instance/config.go`). <!-- TODO(实跑或确认): safety 各键的取值范围与越界行为由 Robot SDK 校验，跨仓核实后补充 -->

### ability_framework / abilities / pilot / robot_skills

| Field | Type | Required | Description |
|---|---|---|---|
| `ability_framework.endpoint` | string | Yes | AF address (for example `http://127.0.0.1:18083`). Pilot reads heartbeat and Manifest through it |
| `ability_framework.managed_by_instance` | bool | No | Whether the instance launcher hosts the AF process |
| `abilities.<role>` | object | — | Deploy item for a semantic role. Optional `instance_id` pins an AF instance UUID. When omitted, auto-bind only if that role has exactly one healthy instance. Multiple instances refuse a random choice (`selectRoleInstance` in `discovery.go`). Role names come from type-package `abilities[].role` and match AbilityRole on AF heartbeat |
| `pilot.id` | string | Yes | Pilot instance ID. Defaults to `pilot-<robot.id>` (filled by start) |
| `pilot.robot_skill_directory` | string | No | Robot Skill storage root (`active`/`packages`/`environments`/`staging`). Written to instance directory `pilot/skills` at render |
| `pilot.worker_timeout_seconds` | int | No | Timeout waiting for active Worker/Execution to converge when Pilot shuts down. Default 30 (filled by start). When unset on the Pilot side, fall back to 15s (`semantic-framework/cmd/semantic-pilot/main.go`) |
| `pilot.heartbeat_interval_seconds` | int | No | Interval for reporting heartbeat to the Server. Default 2 (filled by start). When unset, Pilot falls back to 2s (`internal/pilot/remote.go`) |
| `pilot.allow_ability_debug` | bool | No | Whether the Ability debug entry is allowed (device page manually triggers an AF Task) |
| `robot_skills[].name` / `version` / `enabled` | string/string/bool | — | Desired Robot Skill (`name@version` exact version). This is a **desired-state** declaration after Robot start: the Server issues exact versions from the Registry. Pilot only reports actual install results and does not carry Skill source (`RobotSkillDeployment` in `discovery.go`) |

## Real example

Source: `semantic-robot-deployment/examples/r1pro-mujoco-01.yaml` (isomorphic with the render result of `type-packages/r1pro-mujoco/templates/robot-deployment.yaml.tmpl`; comments differ slightly):

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

Note: the example above rewrites source-file `named_postures` into flow style to keep length down. Semantics are unchanged. The original file in the repository is line-by-line block style.

## Instance-directory artifacts

Both `semantic-robot-instance render` and `start` create an independent writable directory for each Robot. No file in the shared bundle is modified (`semantic-robot-deployment/internal/instance/render.go`). Artifacts:

| Artifact | Mode | Description |
|---|---|---|
| `instance.yaml` | 0600 | RobotInstance config used for render (refreshed after a bundle upgrade) |
| `robot-deployment.yaml` | 0640 | RobotDeployment (written 0640 by the `start` flow; when started in reverse from a deployment yaml it is the serialized run config) |
| `connection.yaml` | 0600 | `start` flow only: after first start claims a credential with a join code via `POST /api/v1/pilot-enrollments/claim`, written with `server_http_url`, `server_websocket_url`, `pilot_id`, `credential`, `enrolled_at`. Later starts only read this file and no longer require an admin token (`internal/instance/start.go`) |
| `ability-framework/config.yaml` | 0640 | AF config rendered from type-package `templates.abilityFramework` |
| `model-registry.json` | 0640 | Copied from the bundle when the type package declares `templates.modelRegistry` (perception/grasp model inventory) |
| `run/bundle.json` | 0640 | Bundle source metadata: `bundle_root`, `bundle_name`, `bundle_version`, `rendered_at` |
| `run/state.json` | 0640 | Instance state: `status` (`rendered`/`starting`/`running`/`stopping`/`interrupted`/`stopped`/`failed`), `robot_id`, process PIDs, `stop_evidence`, and so on (`internal/instance/state.go`) |
| `run/instance.lock` | 0640 | Instance mutex: shared by the resident supervisor and local `semantic-pilot debug-stack` to prevent parallel runs (`internal/instance/runner.go`, `debug_stack.go`) |
| `pilot/robot-state.sqlite` | — | Robot state DB. The fake backend points `sdk.options.state_path` at this file. Initial state takes effect only when first created |
| `executions/`, `pilot/{artifacts,logs,python-cache,skills/{active,packages,environments,staging}}`, `ability-framework/{packages,crs,databases,data,log,artifact-exchange}` | 0750 | Run data and working directories, created uniformly by Render |

## Start entries and managed mode

`semantic-robot-instance` (source `cmd/semantic-robot-instance/main.go`) provides `start` / `render` / `run` / `status` / `stop` / `debug-stack` subcommands:

- **User start flow**: `semantic-robot-instance start --config <robot-deployment.yaml> --join-code <join code> --server-http <URL> --server-ws <URL>`. First start exchanges a credential into `connection.yaml`. `--data-dir` defaults to `semantic/robots/<sanitized robot-id>` under `$XDG_STATE_HOME` (otherwise `~/.local/state`) (`defaultDataDirectory` in `internal/instance/start.go`).
- **Render flow**: `render --config <RobotInstance.yaml> --output <instance directory>`; requires an empty target directory and refuses overwrite.
- **Managed mode**: when `robot_runtime.enabled: true` in `semantic-server.yaml`, the Server acts as supervisor, loads type packages from `bundles_dir`, allocates AF ports from the pool `ability_port_first..ability_port_last`, and turns a Runtime Instance into a `semantic-robot-instance` foreground supervisor process (`semantic-framework/internal/bootstrap/managed_robot_runtime.go`).

## How to verify

- Structural validation: `render`/`start` errors immediately on parse failure (unknown fields, missing required fields, URL/combination checks). No process start is needed;
- Status query: `semantic-robot-instance status --instance <dir>` prints JSON from `state.json`. If the supervisor process has exited and state was not closed, it is marked `failed`;
- Server-side check: the device-workbench "Configuration" view comes from `RobotDeployment.DeviceConfiguration()` (endpoint, profile, providers, frames, tools, and safety limits). See the device channel in [WebSocket events](ws.en.md).
