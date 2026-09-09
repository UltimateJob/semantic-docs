---
title: "第 7 章：Pilot、Robot Deployment 与设备加入"
linkTitle: "第 7 章：设备加入"
weight: 27
description: "构建 Robot Bundle，准备 RobotDeployment，通过一次性加入码启动隔离实例，并在设备中心确认 Robot online。"
---

**本章目标**：把第 6 章已经验证的 Ability、Robot SDK 与 Pilot 二进制装配为只读 Bundle，为第 2 章跑通的 MuJoCo 场景准备 RobotDeployment，然后用一次性加入码启动 `semantic-robot-instance`。完成后，你应能在 Server 设备中心看到这台 Robot 显示 online，并且 desired Robot Skill 全部安装启用。

## 前置条件

| 项目 | 要求 | 验证 |
|---|---|---|
| Semantic Server | 第 1 章已启动 | `curl -s http://127.0.0.1:8080/api/v1/system/healthz` 返回 `{"status":"ok"}` |
| Token | 第 1 章登录 Token 可用 | `curl -s http://127.0.0.1:8080/api/v1/system/ping -H "Authorization: Bearer $TOKEN"` 返回 `pong:true` |
| AbilityFramework | 第 6 章的 `ability-runtime` 种子仓已 `make check` | `test -x "$SEMANTIC/ability-runtime/AbilityFramework"` |
| Ability 包 | 第 6 章已打出七个 Ability Zip | `ls /tmp/ability-packages/*.zip` 应有 7 个文件 |
| Robot SDK Wheel | 第 6 章之前已构建 | `ls "$SEMANTIC/semantic-robotsdk/robot-sdk/dist/semantic_robot_sdk_r1pro-0.5.0.dev0-py3-none-any.whl"` |
| Pilot 二进制 | Framework 已构建 | `test -x "$SEMANTIC/semantic-framework/.output/bin/semantic-pilot"`（`make build` 产物） |
| Scene 实例 | 第 2 章已启动一个 MuJoCo Scene 实例（仅 MuJoCo 类型包需要） | 第 2 章 `curl "http://127.0.0.1:18090/api/v1/scene-instances/$SCENE_INSTANCE_ID"` 返回 `running` |

## Robot 实例是什么

Robot 实例不是一个单独的 Pilot 进程，而是"固定版本 Bundle + 独立可写运行目录"的组合：

- **Bundle** 是共享只读制品（`semantic-robot-bundle` 组装，目录权限改为只读），固定 Pilot、AbilityFramework、七类 Ability、Robot SDK Wheel 和整套 Python 依赖的精确版本；
- **实例目录** 是每台设备唯一的可写目录，保存 Robot 身份（`instance.yaml`）、连接凭据（`connection.yaml`）、渲染配置、数据库、日志和 Execution 数据。

Bundle 不包含 Robot ID、Pilot credential 或任何运行数据；两台 Robot 可以共用同一个 Bundle，但实例目录、Pilot ID 和 AbilityFramework 端口必须彼此独立。

## 代码位置

- 类型包与示例：`semantic-robot-deployment/type-packages/`、`semantic-robot-deployment/examples/`；
- Bundle 构建与校验：`semantic-robot-deployment/cmd/semantic-robot-bundle/`、`internal/bundle/{build,manifest}.go`；
- 实例启动器：`semantic-robot-deployment/cmd/semantic-robot-instance/main.go`（六个子命令：`start`/`debug-stack`/`render`/`run`/`status`/`stop`）；
- 启动流程实现：`semantic-robot-deployment/internal/instance/{start,render,runner,state,discovery}.go`；
- AbilityFramework 客户端：`semantic-robot-deployment/internal/abilityframework/client.go`；
- 加入码服务端：`semantic-framework/internal/server/http/handlers/robots.go`、`internal/robot/enrollment.go`；
- Pilot 连接与 Skill 对账：`semantic-framework/internal/robot/service.go`、`cmd/semantic-pilot/main.go`；
- Studio 设备中心：`semantic-web/src/views/DevicesView.vue`、`src/components/device/PilotEnrollmentDialog.vue`。

## 运行：从 Bundle 到设备加入

以下步骤按顺序执行；每条命令注明提取来源。

### 1. 构建启动器与 Bundle 构建器

```bash
cd "$SEMANTIC/semantic-robot-deployment"
make verify
```

`verify` 依次执行 `lint`（`go vet ./...`）、`test`（`go test -race ./...`）、`build`（输出 `bin/semantic-robot-bundle` 与 `bin/semantic-robot-instance`）。来源：`semantic-robot-deployment/Makefile`。

构建通过后 `ls bin/` 应出现两个二进制；任一测试失败都会中断，不会产出二进制。

### 2. 组装 Bundle

Bundle 构建器不重新编译任何制品，只把已经通过测试的二进制、Wheel 和 Ability Zip 按类型包声明组装，并在创建共享 Python 环境后把整个目录改为只读（目录权限 `0555`，来源：`internal/bundle/build.go`）。先准备离线 Wheel 目录，第三方依赖版本由类型包内的 `python-requirements.lock` 锁定：

```bash
cd "$SEMANTIC/semantic-robot-deployment"
export ROBOT_ARTIFACTS=/tmp/semantic/robot-artifacts
mkdir -p "$ROBOT_ARTIFACTS/wheels"
python3 -m pip download --only-binary=:all: \
  --dest "$ROBOT_ARTIFACTS/wheels" \
  -r type-packages/r1pro-mujoco/python-requirements.lock
```

再组装 Bundle（`--file` 映射的左侧是 `type-packages/r1pro-mujoco/bundle.yaml` 声明的精确制品路径，来源：`cmd/semantic-robot-bundle/main.go` 的 `build` 子命令与 README「从干净目录构建」）：

```bash
"$SEMANTIC/semantic-robot-deployment/bin/semantic-robot-bundle" build \
  --source "$SEMANTIC/semantic-robot-deployment/type-packages/r1pro-mujoco" \
  --output /tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev \
  --python python3 \
  --wheel-dir "$ROBOT_ARTIFACTS/wheels" \
  --file "bin/semantic-robot-instance=$SEMANTIC/semantic-robot-deployment/bin/semantic-robot-instance" \
  --file "bin/AbilityFramework=$SEMANTIC/ability-runtime/AbilityFramework" \
  --file "bin/semantic-pilot=$SEMANTIC/semantic-framework/.output/bin/semantic-pilot" \
  --file "abilities/r1pro-navigation.zip=/tmp/ability-packages/r1pro-navigation.zip" \
  --file "abilities/r1pro-manipulator-motion.zip=/tmp/ability-packages/r1pro-manipulator-motion.zip" \
  --file "abilities/r1pro-end-effector.zip=/tmp/ability-packages/r1pro-end-effector.zip" \
  --file "abilities/r1pro-robot-state.zip=/tmp/ability-packages/r1pro-robot-state.zip" \
  --file "abilities/r1pro-sensor-capture.zip=/tmp/ability-packages/r1pro-sensor-capture.zip" \
  --file "abilities/r1pro-object-perception.zip=/tmp/ability-packages/r1pro-object-perception.zip" \
  --file "abilities/r1pro-grasp-planning.zip=/tmp/ability-packages/r1pro-grasp-planning.zip"
```

<!-- TODO(实跑): 记录 build 命令的完整 JSON 输出（root/name/version/all_files_available 等字段） -->

`--wheel-dir` 只按 `bundle.yaml` 的精确文件名补齐来源，缺任何一个声明制品都会立即失败。构建成功后用 `inspect` 校验：

```bash
"$SEMANTIC/semantic-robot-deployment/bin/semantic-robot-bundle" inspect \
  --bundle /tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev
```

预期返回 JSON，`name` 为 `r1pro-mujoco`、`version` 为 `0.5.0-dev`、`robot_model` 为 `r1_pro_chassis`，`all_files_available` 为 `true`（字段定义见 `internal/bundle/build.go` 的 `Inspection` 结构体）：

```json
{
  "root": "/tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev",
  "name": "r1pro-mujoco",
  "version": "0.5.0-dev",
  "robot_model": "r1_pro_chassis",
  "backend_profiles": [{"backend": "mujoco", "profile": "r1pro-tote-mujoco-v1"}],
  "instance_launcher": "/tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev/bin/semantic-robot-instance",
  "all_files_available": true
}
```

<!-- TODO(实跑): 核对 inspect 真实输出并补全省略字段 -->

版本锁定来自 `type-packages/r1pro-mujoco/bundle.yaml`：robot-sdk core/r1pro `0.5.0.dev0`、ability_py `0.4.0`、r1pro-abilities `0.4.0.dev0`、robot-skill-sdk `0.1.0.dev0`；readiness 超时 `45s`、shutdown 超时 `15s`。Fake 类型包（`type-packages/r1pro-fake`）的差别是不携带 websockets 与 Pinocchio 相关 Wheel，其余流程相同。

### 3. 准备 RobotDeployment

RobotDeployment 是每台设备唯一需要按设备维护的配置，由 `start --config` 读取（注意：它与第 6 章用过的 RobotInstance YAML 是两种文件——RobotDeployment 的头是 `api_version: 1`，RobotInstance 的头是 `apiVersion: semantic.insightos.cn/v1alpha1`）。仓库提供两份真实示例：

- `examples/r1pro-mujoco-01.yaml`：完整 MuJoCo 诊断示例（本节以此为准）；
- `examples/robot-deployment-r1pro-fake-02.yaml`：完整 Fake 示例。

复制 MuJoCo 示例并按设备修改：

```bash
mkdir -p /tmp/semantic/robots
sed -e 's/replace-with-running-scene-instance-id/'"$SCENE_INSTANCE_ID"'/' \
    -e 's|/opt/semantic/assets/robot|/tmp/semantic/assets/robot|' \
    -e 's|/opt/semantic/model-registry.json|/tmp/semantic/model-registry.json|' \
    "$SEMANTIC/semantic-robot-deployment/examples/r1pro-mujoco-01.yaml" \
    > /tmp/semantic/robots/r1pro-mujoco-01.yaml
```

<!-- TODO(实跑): 确认 MuJoCo 资产与 model-registry 在开发机上的真实落盘路径，替换上例中的 sed 目标 -->

关键字段（全部取自 `examples/r1pro-mujoco-01.yaml`，结构定义见 `internal/instance/start.go` 的 `robotDeployment`）：

```yaml
api_version: 1
robot:
  id: r1_pro_tote_gripper-1          # Robot 身份，进入默认数据目录名
  display_name: R1 Pro Tote Robot 1
  model: r1_pro_chassis              # 必须被 Bundle 的 backendProfiles 支持
  backend: mujoco
  sdk:
    package: semantic-robot-sdk-r1pro
    endpoint: http://127.0.0.1:18090  # 第 2 章的 plugin-mujoco Runtime 地址
    backend_profile: r1pro-tote-mujoco-v1
    scene_instance_id: <第 2 章运行的 Scene 实例 ID>
  kinematics:
    urdf_path: <R1 Pro URDF 路径>     # MuJoCo 必填，本地 IK 使用
  tools: [...]                        # MuJoCo 必填，左右夹爪机械边界
ability_framework:
  endpoint: http://127.0.0.1:18083    # 本实例独占的 AF HTTP 端口
  managed_by_instance: true           # 由启动器拉起 Bundle 内的 AF
abilities: { navigation: {}, manipulator_motion: {coordination: synchronized}, ... }
pilot:
  id: pilot-r1_pro_tote_gripper-1     # 缺省时自动取 "pilot-" + robot.id
  allow_ability_debug: true
robot_skills:                         # 首次接入时播种为 Server 侧 desired 清单
  - {name: grasp-object, version: 0.4.17, enabled: true}
  - {name: semantic-navigation, version: 0.4.4, enabled: true}
  - {name: place-object, version: 0.4.14, enabled: true}
```

解析是严格的（`yaml.KnownFields(true)`，来源：`internal/instance/start.go` 的 `loadRobotDeployment`）：出现未知字段直接报"解析 RobotDeployment"错误；`api_version`、`robot.id/model/backend`、`robot.sdk.package`、`ability_framework.endpoint` 缺一不可。MuJoCo 后端额外要求 `robot.sdk.endpoint`、`robot.sdk.scene_instance_id`、`robot.tools` 与 `robot.kinematics.urdf_path`（来源：`internal/instance/config.go` 的同类 RobotInstance 校验与示例文件）。`robot_skills` 里的版本必须已在 Server 的 Robot Skill Registry 发布（第 5 章），否则对账安装会一直不收敛。

### 4. 创建一次性加入码

<!-- TODO(实跑): 实跑核对设备中心页面与弹窗的当前文案及弹窗过期倒计时 -->

1. 登录 Studio，打开**设备中心**（页面标题"设备中心"，来源：`semantic-web/src/views/DevicesView.vue`）；
2. 点击**添加 Pilot** 按钮（来源：`semantic-web/src/components/device/PilotEnrollmentDialog.vue`）；
3. 弹窗展示一次性加入码（六位数字）与"复制命令"按钮，复制出的命令形态即下一步的 `start --config ... --join-code <code>`。

加入码五分钟后过期（来源：`internal/robot/enrollment.go`，`ExpiresAt = now + 5*time.Minute`），且只能被领取一次。它只用于首次配对，不应写入仓库或提交到 Git。

习惯 API 的读者可以用等价命令创建（需要第 1 章的 Token；端点取自 `internal/server/http/router.go`）：

```bash
curl -s -X POST http://127.0.0.1:8080/api/v1/pilot-enrollments \
  -H "Authorization: Bearer $TOKEN"
```

预期返回 201 与 `enrollment.code`（响应结构见 `handlers/robots.go` 的 `HandleCreatePilotEnrollment`）：

```json
{
  "enrollment": {
    "id": "pen-…",
    "code": "042113",
    "status": "pending",
    "expires_at": "2026-09-05T08:15:00Z"
  }
}
```

<!-- TODO(实跑): 记录 enrollment 响应的完整字段（code/expires_at 的真实样例） -->

```bash
JOIN_CODE=<上一步返回的 enrollment.code>
```

### 5. 首次启动实例

启动器推荐从 Bundle 内运行：`--file` 映射已把 `semantic-robot-instance` 放进 `bin/`，从 Bundle 内启动时 `--bundle` 可以省略（启动器默认从自身位置推导 Bundle 根目录，来源：`internal/instance/start.go` 的 `resolveBundleRoot`）。

```bash
BUNDLE=/tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev

"$BUNDLE/bin/semantic-robot-instance" start \
  --config /tmp/semantic/robots/r1pro-mujoco-01.yaml \
  --join-code "$JOIN_CODE" \
  --server-http http://127.0.0.1:8080 \
  --server-ws ws://127.0.0.1:8081/ws/pilot
```

flag 定义来源：`cmd/semantic-robot-instance/main.go` 的 `start` 子命令（`--config` 必填；`--join-code`、`--server-http`、`--server-ws` 仅首次启动需要）。端口与 Server 配置一致：`configs/semantic-server.yaml` 的 `ws_addr: ":8081"`。局域网 mDNS（服务名 `_semantic-server._tcp`，来源：`internal/instance/discovery.go`）可用时，两个 `--server-*` 参数可以省略，启动器会扫描一次局域网；开发机容器网络中 mDNS 通常不可用，建议显式指定。

这是前台进程（`start` 内部调用 `Run`，实现见 `internal/instance/runner.go`）。启动成功前按启动顺序逐级输出；看到 Pilot 启动且无报错后保持终端运行。<!-- TODO(实跑): 记录 start 的完整启动输出与各级日志的确切文案 -->

首次启动成功后，专用 credential 已写入实例目录的 `connection.yaml`（权限 `0600`，字段 `server_http_url`/`server_websocket_url`/`pilot_id`/`credential`/`enrolled_at`，来源：`internal/instance/start.go` 的 `connectionConfig` 与 `saveConnection`）。实例数据目录未显式指定 `--data-dir` 时默认为 `$XDG_STATE_HOME/semantic/robots/<robot-id>`，未设置 XDG 时为 `~/.local/state/semantic/robots/<robot-id>`（来源：`defaultDataDirectory`）。查看实例状态：

```bash
"$BUNDLE/bin/semantic-robot-instance" status \
  --instance ~/.local/state/semantic/robots/r1_pro_tote_gripper-1
```

预期返回 JSON，`status` 为 `running`，并携带 `robot_id`、`pilot_pid`、`ability_instance_ids`（状态机与字段见 `internal/instance/state.go`，状态取值：`rendered`/`starting`/`running`/`stopping`/`interrupted`/`stopped`/`failed`）：

```json
{
  "instance_name": "r1_pro_tote_gripper-1",
  "robot_id": "r1_pro_tote_gripper-1",
  "status": "running",
  "supervisor_pid": 12345,
  "pilot_pid": 12400,
  "ability_instance_ids": ["…七…个…"]
}
```

<!-- TODO(实跑): 记录 status 真实输出的完整字段 -->

后续启动不再需要加入码：

```bash
"$BUNDLE/bin/semantic-robot-instance" start \
  --config /tmp/semantic/robots/r1pro-mujoco-01.yaml
```

### 6. 观察启动顺序的验证点

启动过程中另开终端，按顺序确认（每一步都以代码中的真实判据为准）：

1. **AbilityFramework 健康检查**：`ability_framework.endpoint` 配置为 `http://127.0.0.1:18083` 时：

   ```bash
   curl -s http://127.0.0.1:18083/api/instance
   ```

   预期返回 `[]` 或实例数组——启动器正是以该接口可访问作为 AF 就绪条件（来源：`internal/abilityframework/client.go` 的 `WaitReady` 轮询 `GET /api/instance`，超时为 Bundle 的 `readinessTimeout: 45s`）。

2. **Ability heartbeat**：七类 Ability 顺序激活，每激活一个就多一条 heartbeat：

   ```bash
   curl -s http://127.0.0.1:18083/api/ability-heartbeat
   ```

   预期最终返回 7 条记录，`abilityName` 覆盖七类（`R1ProNavigation.V2` 等），每条 `state` 为 `running`（字段定义与 `running` 就绪判据来源：`internal/abilityframework/client.go` 的 `Heartbeat` 结构与 `WaitHeartbeat`）：

   ```json
   [
     {
       "id": "…",
       "instanceName": "…",
       "abilityName": "R1ProNavigation.V2",
       "version": "…",
       "state": "running",
       "IPCPort": 0,
       "abilityPort": 0
     }
   ]
   ```

   <!-- TODO(实跑): 记录七个实例的真实 heartbeat 样例 -->

3. **Pilot 进程**：`status` 命令（上文第 5 步）的 `status` 为 `running`、`pilot_pid` 非零；实例目录 `pilot/logs/pilot.log` 出现连接日志（日志路径来源：`internal/instance/runner.go` 的 `startProcess` 参数）。

4. **Server 设备页**：

   ```bash
   curl -s http://127.0.0.1:8080/api/v1/devices -H "Authorization: Bearer $TOKEN"
   ```

   预期 `devices` 数组中出现该 Robot，`status` 为 `online`（端点来源：`internal/server/http/router.go` 的 `/api/v1/devices` 路由与 `handlers/robots.go` 的 `HandleListDevices`）。<!-- TODO(实跑): 记录 devices 响应的真实字段形态 -->

5. **desired Robot Skill 对账**：Pilot 通过 `/ws/pilot` 注册时，会把 RobotDeployment 的 `robot_skills` 上报给 Server；Server 仅在首次接入时把这份清单播种为 desired，随后逐项下发安装/启用命令（来源：`internal/robot/service.go` 的注册逻辑与 `internal/robot/enrollment.go` 的 `ReconcileDesiredSkills`）。安装来源是 Server 的 Robot Skill Registry（第 5 章发布），不是 Bundle。在设备中心详情页或 `GET /api/v1/devices/{robot_id}` 中，三个 Skill 最终应显示 `installed` 且启用状态与 desired 一致。<!-- TODO(实跑): 记录设备详情页 Skill 状态收敛的真实呈现 -->

## 运行后发生了什么

按时间顺序（实现见 `internal/instance/start.go`、`render.go`、`runner.go`、`state.go` 与 `abilityframework/client.go`）：

1. **取实例锁**：`Run` 先以非阻塞 `flock` 抢实例目录的 `run/instance.lock`；已被占用时报"实例已由另一个 semantic-robot-instance 进程管理"；
2. **解析 RobotDeployment**：严格解析 `--config`，补默认值（`pilot.id` = `pilot-` + robot.id、`backend_profile` = backend + `-v1`、`worker_timeout_seconds` = 30、`heartbeat_interval_seconds` = 2）；
3. **建立连接身份**：实例目录没有 `connection.yaml` 时先经 mDNS 或 `--server-*` 确定 Server 地址，再用加入码调用 `POST /api/v1/pilot-enrollments/claim` 换取专用 Pilot credential；已有时直接读文件，不再要求加入码；
4. **渲染实例目录**：首次启动把实例配置渲染为 `instance.yaml`（0600）、从 Bundle 模板生成 `robot-deployment.yaml` 与 `ability-framework/config.yaml`（0640）、`run/bundle.json` 记录 Bundle 根与版本，并创建 `pilot/`、`executions/`、`ability-framework/` 等目录（0750）；渲染完成后把 credential 连同 Server 地址写入数据目录的 `connection.yaml`（0600）；目录非空时拒绝覆盖；已有实例目录时只刷新 Bundle 派生文件，保留运行数据；
5. **Bundle 校验**：打开共享 Bundle，校验 Robot 的 model/backend/backendProfile 受 `bundle.yaml` 的 `backendProfiles` 支持，任一声明文件缺失直接失败；
6. **拉起 AbilityFramework**：`managed_by_instance: true` 时启动 Bundle 内 `bin/AbilityFramework`，日志写 `ability-framework/log/process.log`，随后按 `readinessTimeout`（45s）轮询 `GET /api/instance` 等待就绪；
7. **上传并激活七类 Ability**：对每个 Ability 先确认模板已存在（缺失则 `POST /api/package` 上传），再 `POST /api/instance` 异步创建实例，逐个等待该实例的 heartbeat 中出现精确的 `instance ID + abilityName` 且 `state=running`；
8. **启动 semantic-pilot**：以 Bundle 内二进制、渲染后的 `robot-deployment.yaml`、credential 与 Bundle 内 Python 启动 Pilot（日志 `pilot/logs/pilot.log`），状态迁移为 `running`；运行期环境固定为实例内路径（`SEMANTIC_ROBOT_CONFIG`、`SEMANTIC_ABILITY_EXECUTION_ROOT`、`SEMANTIC_ROBOT_SDK_ENDPOINT` 等），并清空宿主 `PYTHONPATH`、禁用用户 site-packages；
9. **Pilot 连接 /ws/pilot**：Pilot 用 credential 连接 Server 的 `/ws/pilot`（Server 在 claim 响应中返回 `websocket_path`），注册 Robot、上报 Ability 健康目录与实际 Skill 目录；Server 发布 `pilot.online` 事件；
10. **desired Robot Skill 对账**：首次接入以 Pilot 上报的 `robot_skills` 播种 desired；对账器逐项比较 desired 与 actual，缺的经 `/pilot/v1/transfers` 流式下载安装，启用状态不一致的下发 enable/disable，收敛到 `installed` 且启用一致为止，不做无限重试；
11. **收口**：收到 SIGINT/SIGTERM 后，先等 Pilot 自行提交安全停止证据（`pilot/stop-result.json`，必须 `safe` 且 `hold_confirmed`），再逆序停止七类 Ability 并确认停稳，最后关闭实例管理的 AbilityFramework；全部确认后状态为 `stopped`，任何一环无法确认则落到 `interrupted` 或 `failed`，不伪报 `stopped`。

## 停止与状态

```bash
"$BUNDLE/bin/semantic-robot-instance" stop \
  --instance ~/.local/state/semantic/robots/r1_pro_tote_gripper-1 \
  --timeout 30s
```

`stop` 只向实例 supervisor 发送 SIGTERM 并等待终态，不会绕过安全停止顺序直接杀 Robot 进程（来源：`internal/instance/runner.go` 的 `Stop`；`--timeout` 默认 30s，见 `cmd/semantic-robot-instance/main.go`）。supervisor 不在线时报"实例 supervisor 不在线，无法确认安全停止；请检查 status 和设备状态"。实例本已 `stopped` 时命令直接成功；停止失败时用 `status` 查看 `error` 与 `stop_evidence`，不要直接杀进程。

## 验证清单

- [ ] `make verify` 通过，`bin/` 下有 `semantic-robot-bundle` 与 `semantic-robot-instance`；
- [ ] `semantic-robot-bundle inspect` 返回 `all_files_available: true` 且版本与 `bundle.yaml` 一致；
- [ ] RobotDeployment 能通过严格解析（无未知字段警告，MuJoCo 四项必填齐全）；
- [ ] 加入码创建后五分钟内使用；`connection.yaml` 出现在数据目录且权限为 0600；
- [ ] `curl http://127.0.0.1:18083/api/instance` 可访问；
- [ ] `curl http://127.0.0.1:18083/api/ability-heartbeat` 返回 7 条且 `state` 全部为 `running`；
- [ ] `semantic-robot-instance status --instance <目录>` 显示 `running`；
- [ ] `GET /api/v1/devices` 中该 Robot `status` 为 `online`，设备中心详情页 Pilot online、AF ready、Ability 健康；
- [ ] 设备详情页三个 `robot_skills` 显示已安装且启用状态与 desired 一致；
- [ ] `stop --timeout 30s` 后 `status` 显示 `stopped`（而不是 `interrupted`/`failed`）。

## 常见问题

- **启动报"实例已由另一个 semantic-robot-instance 进程管理"**：同一实例目录的 `run/instance.lock` 被常驻实例或 debug-stack 持有，一台 Robot 不能同时被两个进程控制。先 `stop --instance <目录> --timeout 30s` 安全停止，再重新启动；详见[开发者 FAQ](/developer/faq/)「设备加入」与第 6 章的 debug-stack 说明；
- **报"claim Pilot 加入码失败: HTTP 409"或 Server 返回"加入码不存在、已使用或已过期"**：加入码五分钟过期且只能领取一次（来源：`internal/robot/enrollment.go`、`handlers/robots.go` 的 `PILOT_ENROLLMENT_INVALID`）。回到设备中心重新点击"添加 Pilot"生成新码；注意错误也可能来自 `pilot_id` 与已有 `connection.yaml` 不一致——保留实例目录但换了配置中的 `robot.id` 时会触发，修正 `--config` 或换新的数据目录；
- **heartbeat 一直等不到（AF 起来了但七个实例不齐）**：先确认 `curl` 的端口与 `--config` 中 `ability_framework.endpoint` 一致；MuJoCo 类型包的 Ability 依赖 SDK endpoint——`robot.sdk.endpoint` 必须指向第 2 章已运行的 Runtime（示例为 `http://127.0.0.1:18090`），SDK 不通时 Ability 进程无法进入 `running`；查看 `ability-framework/log/process.log` 与启动器输出中"启动 Ability …"的具体 role 定位卡住的环节；更多排查见[开发者 FAQ](/developer/faq/)「`GET /api/ability-heartbeat` 没有数据」条目；
- **报"局域网内未发现 Semantic Server"**：mDNS 扫描 2 秒未发现服务（来源：`internal/instance/discovery.go`）。显式补上 `--server-http http://127.0.0.1:8080 --server-ws ws://127.0.0.1:8081/ws/pilot`（两参数必须同时提供）；发现多个 Server 时也要求显式指定；
- **设备中心一直显示 Pilot 未上线 / Skill 不安装**： Pilot 未上线先看实例目录 `pilot/logs/pilot.log` 是否报 credential 或地址错误（`--server-ws` 应为 `ws://<host>:8081/ws/pilot`，与 Server 的 WS 端口一致）；Skill 不安装确认 `robot_skills` 声明的版本已在 Server Registry 发布（第 5 章），版本写错时对账会停在 failed，不会自动换版本重试；详见[开发者 FAQ](/developer/faq/)「设备中心一直提示"Pilot 尚未上线"」条目；
- **端口冲突**：`ability_framework.endpoint` 的端口（示例 18083）是本实例独占的，两台 Robot 共用同一 SDK endpoint（18090）但 AF 端口必须不同；启动前确认端口未被占用，改端口时同步修改 `--config` 后重新 `start`。Server 侧端口占用见[开发者 FAQ](/developer/faq/)「8090 端口被占用」条目的处理方式。

## 本章小结

- Bundle 是共享只读制品（精确版本 + 只读目录），实例目录保存设备身份、credential 与全部运行状态；
- `start --config` 是普通用户启动一台 Robot 的唯一入口：首次用一次性加入码换 credential，后续只读 `connection.yaml`；
- 启动顺序固定为 flock → 渲染实例目录 → AbilityFramework → 七类 Ability（上传、激活、heartbeat）→ semantic-pilot → `/ws/pilot` 注册 → desired Skill 对账；
- 加入码五分钟过期且只能用一次；credential 与 desired 状态在 Server 侧持久化，重连不重播种；
- 停止必须拿到 Pilot 安全停止证据并逆序停稳 Ability，任何环节无法确认都会落在 `interrupted`/`failed`。

## 下一章

进入[第 8 章：Studio、事件流与执行观察](/developer/quickstart/chapter_08_studio/)，在 Studio 中观察这台设备的完整执行过程。
