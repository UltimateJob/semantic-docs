---
title: "Chapter 7: Pilot, Robot Deployment, and Device Join"
linkTitle: "Chapter 7: Device Join"
weight: 27
description: "Build a Robot Bundle, prepare RobotDeployment, start an isolated instance with a one-time join code, and confirm the Robot is online in the device center."
---

**Goal of this chapter**: assemble the Ability, Robot SDK, and Pilot binary already verified in Chapter 6 into a read-only Bundle, prepare a RobotDeployment for the MuJoCo scene from Chapter 2, then start `semantic-robot-instance` with a one-time join code. When you are done, you should see this Robot online in the Server device center, with every desired Robot Skill installed and enabled.

## Preconditions

| Item | Requirement | Verify |
|---|---|---|
| Semantic Server | Started in Chapter 1 | `curl -s http://127.0.0.1:8080/api/v1/system/healthz` returns `{"status":"ok"}` |
| Token | Chapter 1 login Token still works | `curl -s http://127.0.0.1:8080/api/v1/system/ping -H "Authorization: Bearer $TOKEN"` returns `pong:true` |
| AbilityFramework | Chapter 6 `ability-runtime` seed repo has `make check` | `test -x "$SEMANTIC/ability-runtime/AbilityFramework"` |
| Ability packages | Chapter 6 produced seven Ability Zips | `ls /tmp/ability-packages/*.zip` should show 7 files |
| Robot SDK Wheel | Built before Chapter 6 | `ls "$SEMANTIC/semantic-robotsdk/robot-sdk/dist/semantic_robot_sdk_r1pro-0.5.0.dev0-py3-none-any.whl"` |
| Pilot binary | Framework is built | `test -x "$SEMANTIC/semantic-framework/.output/bin/semantic-pilot"` (`make build` artifact) |
| Scene instance | Chapter 2 started a MuJoCo Scene instance (only MuJoCo type packages need this) | Chapter 2 `curl "http://127.0.0.1:18090/api/v1/scene-instances/$SCENE_INSTANCE_ID"` returns `running` |

## What a Robot instance is

A Robot instance is not a single Pilot process. It is the combination of "a fixed-version Bundle + an independent writable run directory":

- **Bundle** is a shared read-only artifact (assembled by `semantic-robot-bundle`, directory permissions then set read-only). It pins exact versions of Pilot, AbilityFramework, the seven Abilities, Robot SDK Wheels, and the full Python dependency set;
- **Instance directory** is the writable directory unique to each device. It stores Robot identity (`instance.yaml`), connection credentials (`connection.yaml`), render config, databases, logs, and Execution data.

A Bundle does not contain a Robot ID, Pilot credential, or any run data. Two Robots can share one Bundle, but instance directories, Pilot IDs, and AbilityFramework ports must be independent.

## Code locations

- Type packages and examples: `semantic-robot-deployment/type-packages/`, `semantic-robot-deployment/examples/`;
- Bundle build and validation: `semantic-robot-deployment/cmd/semantic-robot-bundle/`, `internal/bundle/{build,manifest}.go`;
- Instance launcher: `semantic-robot-deployment/cmd/semantic-robot-instance/main.go` (six subcommands: `start`/`debug-stack`/`render`/`run`/`status`/`stop`);
- Startup-flow implementation: `semantic-robot-deployment/internal/instance/{start,render,runner,state,discovery}.go`;
- AbilityFramework client: `semantic-robot-deployment/internal/abilityframework/client.go`;
- Join-code server: `semantic-framework/internal/server/http/handlers/robots.go`, `internal/robot/enrollment.go`;
- Pilot connection and Skill reconciliation: `semantic-framework/internal/robot/service.go`, `cmd/semantic-pilot/main.go`;
- Studio device center: `semantic-web/src/views/DevicesView.vue`, `src/components/device/PilotEnrollmentDialog.vue`.

## Run: from Bundle to device join

Run the following steps in order. Each command notes its source.

### 1. Build the launcher and Bundle builder

```bash
cd "$SEMANTIC/semantic-robot-deployment"
make verify
```

`verify` runs `lint` (`go vet ./...`), `test` (`go test -race ./...`), then `build` (outputs `bin/semantic-robot-bundle` and `bin/semantic-robot-instance`). Source: `semantic-robot-deployment/Makefile`.

After a successful build, `ls bin/` should show both binaries. Any test failure stops the process and produces no binaries.

### 2. Assemble the Bundle

The Bundle builder does not recompile any artifact. It only assembles already-tested binaries, Wheels, and Ability Zips as declared by the type package, then makes the whole directory read-only after creating the shared Python environment (directory mode `0555`; source: `internal/bundle/build.go`). Prepare an offline Wheel directory first. Third-party dependency versions are locked by `python-requirements.lock` inside the type package:

```bash
cd "$SEMANTIC/semantic-robot-deployment"
export ROBOT_ARTIFACTS=/tmp/semantic/robot-artifacts
mkdir -p "$ROBOT_ARTIFACTS/wheels"
python3 -m pip download --only-binary=:all: \
  --dest "$ROBOT_ARTIFACTS/wheels" \
  -r type-packages/r1pro-mujoco/python-requirements.lock
```

Then assemble the Bundle (the left side of `--file` mappings is the exact artifact path declared by `type-packages/r1pro-mujoco/bundle.yaml`; source: the `build` subcommand of `cmd/semantic-robot-bundle/main.go` and the README section "Build from a clean directory"):

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

`--wheel-dir` only fills sources by the exact filenames in `bundle.yaml`. Missing any declared artifact fails immediately. After a successful build, validate with `inspect`:

```bash
"$SEMANTIC/semantic-robot-deployment/bin/semantic-robot-bundle" inspect \
  --bundle /tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev
```

Expected JSON: `name` is `r1pro-mujoco`, `version` is `0.5.0-dev`, `robot_model` is `r1_pro_chassis`, and `all_files_available` is `true` (field definitions: `Inspection` in `internal/bundle/build.go`):

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

Version pins come from `type-packages/r1pro-mujoco/bundle.yaml`: robot-sdk core/r1pro `0.5.0.dev0`, ability_py `0.4.0`, r1pro-abilities `0.4.0.dev0`, robot-skill-sdk `0.1.0.dev0`; readiness timeout `45s`, shutdown timeout `15s`. The Fake type package (`type-packages/r1pro-fake`) differs only by not carrying websockets and Pinocchio-related Wheels. The rest of the flow is the same.

### 3. Prepare RobotDeployment

RobotDeployment is the only per-device config you maintain, read by `start --config` (note: it is a different file from the RobotInstance YAML used in Chapter 6 — RobotDeployment headers are `api_version: 1`, RobotInstance headers are `apiVersion: semantic.insightos.cn/v1alpha1`). The repository provides two real examples:

- `examples/r1pro-mujoco-01.yaml`: full MuJoCo diagnostic example (this section uses it);
- `examples/robot-deployment-r1pro-fake-02.yaml`: full Fake example.

Copy the MuJoCo example and edit it per device:

```bash
mkdir -p /tmp/semantic/robots
sed -e 's/replace-with-running-scene-instance-id/'"$SCENE_INSTANCE_ID"'/' \
    -e 's|/opt/semantic/assets/robot|/tmp/semantic/assets/robot|' \
    -e 's|/opt/semantic/model-registry.json|/tmp/semantic/model-registry.json|' \
    "$SEMANTIC/semantic-robot-deployment/examples/r1pro-mujoco-01.yaml" \
    > /tmp/semantic/robots/r1pro-mujoco-01.yaml
```

<!-- TODO(实跑): 确认 MuJoCo 资产与 model-registry 在开发机上的真实落盘路径，替换上例中的 sed 目标 -->

Key fields (all from `examples/r1pro-mujoco-01.yaml`; structure: `robotDeployment` in `internal/instance/start.go`):

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

Parsing is strict (`yaml.KnownFields(true)`; source: `loadRobotDeployment` in `internal/instance/start.go`): an unknown field immediately reports a "parse RobotDeployment" error. `api_version`, `robot.id/model/backend`, `robot.sdk.package`, and `ability_framework.endpoint` are all required. A MuJoCo backend additionally requires `robot.sdk.endpoint`, `robot.sdk.scene_instance_id`, `robot.tools`, and `robot.kinematics.urdf_path` (source: the same-kind RobotInstance validation in `internal/instance/config.go` and the example file). Versions in `robot_skills` must already be published in the Server Robot Skill Registry (Chapter 5), or reconcile install will never converge.

### 4. Create a one-time join code

<!-- TODO(实跑): 实跑核对设备中心页面与弹窗的当前文案及弹窗过期倒计时 -->

1. Log into Studio and open the **device center** (page title "设备中心"; source: `semantic-web/src/views/DevicesView.vue`);
2. Click **Add Pilot** (source: `semantic-web/src/components/device/PilotEnrollmentDialog.vue`);
3. The dialog shows a one-time join code (six digits) and a "Copy command" button. The copied command is the next step's `start --config ... --join-code <code>`.

The join code expires after five minutes (source: `internal/robot/enrollment.go`, `ExpiresAt = now + 5*time.Minute`) and can be claimed only once. It is only for first pairing. Do not write it into the repository or commit it to Git.

Readers who prefer the API can create one with the equivalent command (needs the Chapter 1 Token; endpoint from `internal/server/http/router.go`):

```bash
curl -s -X POST http://127.0.0.1:8080/api/v1/pilot-enrollments \
  -H "Authorization: Bearer $TOKEN"
```

Expected 201 and `enrollment.code` (response structure: `HandleCreatePilotEnrollment` in `handlers/robots.go`):

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

### 5. First start of the instance

Prefer running the launcher from inside the Bundle: `--file` mapping already placed `semantic-robot-instance` in `bin/`. When started from inside the Bundle, `--bundle` can be omitted (the launcher derives the Bundle root from its own location; source: `resolveBundleRoot` in `internal/instance/start.go`).

```bash
BUNDLE=/tmp/semantic/bundles/r1pro-mujoco-0.5.0-dev

"$BUNDLE/bin/semantic-robot-instance" start \
  --config /tmp/semantic/robots/r1pro-mujoco-01.yaml \
  --join-code "$JOIN_CODE" \
  --server-http http://127.0.0.1:8080 \
  --server-ws ws://127.0.0.1:8081/ws/pilot
```

Flag definitions: the `start` subcommand of `cmd/semantic-robot-instance/main.go` (`--config` is required; `--join-code`, `--server-http`, and `--server-ws` are needed only on first start). Ports match Server config: `ws_addr: ":8081"` in `configs/semantic-server.yaml`. When LAN mDNS (service name `_semantic-server._tcp`; source: `internal/instance/discovery.go`) is available, both `--server-*` flags can be omitted and the launcher scans the LAN once. mDNS is usually unavailable in development-machine container networks, so specify them explicitly.

This is a foreground process (`start` internally calls `Run`; implementation: `internal/instance/runner.go`). Before success it prints each startup stage in order. Keep the terminal running after Pilot starts with no error. <!-- TODO(实跑): 记录 start 的完整启动输出与各级日志的确切文案 -->

After a successful first start, the dedicated credential is written to `connection.yaml` in the instance directory (mode `0600`, fields `server_http_url`/`server_websocket_url`/`pilot_id`/`credential`/`enrolled_at`; source: `connectionConfig` and `saveConnection` in `internal/instance/start.go`). When `--data-dir` is omitted, the instance data directory defaults to `$XDG_STATE_HOME/semantic/robots/<robot-id>`, or `~/.local/state/semantic/robots/<robot-id>` when XDG is unset (source: `defaultDataDirectory`). Inspect instance status:

```bash
"$BUNDLE/bin/semantic-robot-instance" status \
  --instance ~/.local/state/semantic/robots/r1_pro_tote_gripper-1
```

Expected JSON: `status` is `running`, plus `robot_id`, `pilot_pid`, and `ability_instance_ids` (state machine and fields: `internal/instance/state.go`; status values: `rendered`/`starting`/`running`/`stopping`/`interrupted`/`stopped`/`failed`):

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

Later starts no longer need a join code:

```bash
"$BUNDLE/bin/semantic-robot-instance" start \
  --config /tmp/semantic/robots/r1pro-mujoco-01.yaml
```

### 6. Observe startup-order checkpoints

Open another terminal during startup and confirm in order (each step uses a real criterion in code):

1. **AbilityFramework health check**: when `ability_framework.endpoint` is `http://127.0.0.1:18083`:

   ```bash
   curl -s http://127.0.0.1:18083/api/instance
   ```

   Expected `[]` or an instance array — the launcher treats that endpoint being reachable as AF ready (source: `WaitReady` in `internal/abilityframework/client.go` polls `GET /api/instance`; timeout is the Bundle `readinessTimeout: 45s`).

2. **Ability heartbeat**: the seven Abilities activate in order. Each activation adds one heartbeat:

   ```bash
   curl -s http://127.0.0.1:18083/api/ability-heartbeat
   ```

   Expected final return is 7 records covering the seven `abilityName`s (`R1ProNavigation.V2` and so on), each `state` `running` (field definitions and the `running` ready criterion: `Heartbeat` and `WaitHeartbeat` in `internal/abilityframework/client.go`):

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

3. **Pilot process**: the `status` command (step 5 above) shows `status` `running` and a non-zero `pilot_pid`. Connection logs appear in `pilot/logs/pilot.log` in the instance directory (log path: `startProcess` arguments in `internal/instance/runner.go`).

4. **Server device page**:

   ```bash
   curl -s http://127.0.0.1:8080/api/v1/devices -H "Authorization: Bearer $TOKEN"
   ```

   Expected: this Robot appears in the `devices` array with `status` `online` (endpoint: `/api/v1/devices` in `internal/server/http/router.go` and `HandleListDevices` in `handlers/robots.go`). <!-- TODO(实跑): 记录 devices 响应的真实字段形态 -->

5. **desired Robot Skill reconcile**: when Pilot registers on `/ws/pilot`, it reports `robot_skills` from RobotDeployment to the Server. The Server seeds that list as desired only on first join, then issues install/enable commands item by item (source: registration logic in `internal/robot/service.go` and `ReconcileDesiredSkills` in `internal/robot/enrollment.go`). The install source is the Server Robot Skill Registry (published in Chapter 5), not the Bundle. On the device-center detail page or `GET /api/v1/devices/{robot_id}`, the three Skills should finally show `installed` with enable state matching desired. <!-- TODO(实跑): 记录设备详情页 Skill 状态收敛的真实呈现 -->

## What happens after a run

In time order (implementation: `internal/instance/start.go`, `render.go`, `runner.go`, `state.go`, and `abilityframework/client.go`):

1. **Take the instance lock**: `Run` first grabs `run/instance.lock` in the instance directory with non-blocking `flock`. If it is already held, it reports that another semantic-robot-instance process is managing the instance;
2. **Parse RobotDeployment**: parse `--config` strictly and fill defaults (`pilot.id` = `pilot-` + robot.id, `backend_profile` = backend + `-v1`, `worker_timeout_seconds` = 30, `heartbeat_interval_seconds` = 2);
3. **Establish connection identity**: when the instance directory has no `connection.yaml`, first resolve the Server address via mDNS or `--server-*`, then call `POST /api/v1/pilot-enrollments/claim` with the join code for a dedicated Pilot credential. When the file exists, read it and do not require a join code;
4. **Render the instance directory**: on first start, render instance config as `instance.yaml` (0600), generate `robot-deployment.yaml` and `ability-framework/config.yaml` from Bundle templates (0640), record Bundle root and version in `run/bundle.json`, and create `pilot/`, `executions/`, `ability-framework/`, and related directories (0750). After render, write the credential and Server addresses into `connection.yaml` in the data directory (0600). A non-empty directory refuses overwrite. An existing instance directory only refreshes Bundle-derived files and keeps run data;
5. **Validate the Bundle**: open the shared Bundle and check that the Robot's model/backend/backendProfile is supported by `backendProfiles` in `bundle.yaml`. Any missing declared file fails immediately;
6. **Start AbilityFramework**: when `managed_by_instance: true`, start `bin/AbilityFramework` inside the Bundle, write logs to `ability-framework/log/process.log`, then poll `GET /api/instance` until ready within `readinessTimeout` (45s);
7. **Upload and activate the seven Abilities**: for each Ability, confirm the template exists (upload with `POST /api/package` if missing), then `POST /api/instance` to create the instance asynchronously, and wait until that instance's heartbeat shows the exact `instance ID + abilityName` with `state=running`;
8. **Start semantic-pilot**: start Pilot with the Bundle binary, the rendered `robot-deployment.yaml`, the credential, and Bundle Python (logs `pilot/logs/pilot.log`). Status moves to `running`. Runtime environment is fixed to in-instance paths (`SEMANTIC_ROBOT_CONFIG`, `SEMANTIC_ABILITY_EXECUTION_ROOT`, `SEMANTIC_ROBOT_SDK_ENDPOINT`, and so on). Host `PYTHONPATH` is cleared and user site-packages are disabled;
9. **Pilot connects `/ws/pilot`**: Pilot connects to Server `/ws/pilot` with the credential (the Server returns `websocket_path` in the claim response), registers the Robot, and reports the Ability health catalog and actual Skill catalog. The Server publishes `pilot.online`;
10. **desired Robot Skill reconcile**: on first join, seed desired from the Pilot-reported `robot_skills`. The reconciler compares desired and actual item by item, stream-downloads missing ones through `/pilot/v1/transfers`, and issues enable/disable when enable state disagrees, until everything is `installed` and enable state matches. It does not retry forever;
11. **Shutdown**: on SIGINT/SIGTERM, first wait for Pilot to submit its own safe-stop evidence (`pilot/stop-result.json`, must be `safe` and `hold_confirmed`), then stop the seven Abilities in reverse order and confirm they are settled, then close the instance-managed AbilityFramework. After all confirms, status is `stopped`. If any step cannot be confirmed, it lands on `interrupted` or `failed` and does not falsely report `stopped`.

## Stop and status

```bash
"$BUNDLE/bin/semantic-robot-instance" stop \
  --instance ~/.local/state/semantic/robots/r1_pro_tote_gripper-1 \
  --timeout 30s
```

`stop` only sends SIGTERM to the instance supervisor and waits for a terminal state. It does not bypass the safe-stop order and kill Robot processes directly (source: `Stop` in `internal/instance/runner.go`; `--timeout` defaults to 30s, see `cmd/semantic-robot-instance/main.go`). If the supervisor is offline it reports that the instance supervisor is offline and a safe stop cannot be confirmed; check status and device state. If the instance is already `stopped`, the command succeeds immediately. On stop failure, inspect `error` and `stop_evidence` with `status`. Do not kill the process directly.

## Verification checklist

- [ ] `make verify` passes and `bin/` has `semantic-robot-bundle` and `semantic-robot-instance`;
- [ ] `semantic-robot-bundle inspect` returns `all_files_available: true` and versions match `bundle.yaml`;
- [ ] RobotDeployment passes strict parse (no unknown-field warning; all four MuJoCo required fields present);
- [ ] The join code is used within five minutes; `connection.yaml` appears in the data directory with mode 0600;
- [ ] `curl http://127.0.0.1:18083/api/instance` is reachable;
- [ ] `curl http://127.0.0.1:18083/api/ability-heartbeat` returns 7 records, all `state` `running`;
- [ ] `semantic-robot-instance status --instance <dir>` shows `running`;
- [ ] `GET /api/v1/devices` shows this Robot `status` `online`; device-center detail shows Pilot online, AF ready, and Abilities healthy;
- [ ] The device detail page shows the three `robot_skills` installed with enable state matching desired;
- [ ] After `stop --timeout 30s`, `status` shows `stopped` (not `interrupted`/`failed`).

## Common questions

- **Startup reports that another semantic-robot-instance process is already managing the instance**: `run/instance.lock` in the same instance directory is held by a resident instance or debug-stack. One Robot cannot be controlled by two processes. First `stop --instance <dir> --timeout 30s` for a safe stop, then start again. See [Developer FAQ](../faq/_index.en.md) "Device join" and the Chapter 6 debug-stack notes;
- **Reports "claim Pilot join code failed: HTTP 409" or the Server returns that the join code does not exist, was used, or expired**: the join code expires in five minutes and can be claimed only once (source: `internal/robot/enrollment.go`, `PILOT_ENROLLMENT_INVALID` in `handlers/robots.go`). Go back to the device center and click "Add Pilot" for a new code. The error can also come from `pilot_id` disagreeing with an existing `connection.yaml` — that happens when you keep the instance directory but change `robot.id` in config. Fix `--config` or use a new data directory;
- **Heartbeat never arrives (AF is up but the seven instances are incomplete)**: first confirm the `curl` port matches `ability_framework.endpoint` in `--config`. MuJoCo type-package Abilities depend on the SDK endpoint — `robot.sdk.endpoint` must point at the Chapter 2 Runtime that is already running (example `http://127.0.0.1:18090`). If the SDK is unreachable, Ability processes cannot enter `running`. Inspect `ability-framework/log/process.log` and the "start Ability …" role in launcher output to locate the stuck step. More triage: [Developer FAQ](../faq/_index.en.md) "`GET /api/ability-heartbeat` has no data";
- **Reports that no Semantic Server was found on the LAN**: mDNS scanned for 2 seconds and found no service (source: `internal/instance/discovery.go`). Add `--server-http http://127.0.0.1:8080 --server-ws ws://127.0.0.1:8081/ws/pilot` explicitly (both flags must be provided together). Multiple discovered Servers also require an explicit choice;
- **Device center keeps showing Pilot offline / Skills not installed**: if Pilot is offline, first check `pilot/logs/pilot.log` in the instance directory for credential or address errors (`--server-ws` should be `ws://<host>:8081/ws/pilot`, matching the Server WS port). If Skills are not installed, confirm the versions declared in `robot_skills` are published in the Server Registry (Chapter 5). A wrong version stops reconcile at failed and does not automatically retry another version. See [Developer FAQ](../faq/_index.en.md) "Device center keeps saying Pilot is not online";
- **Port conflict**: the `ability_framework.endpoint` port (example 18083) is exclusive to this instance. Two Robots can share the same SDK endpoint (18090) but AF ports must differ. Confirm the port is free before start. When you change the port, update `--config` and `start` again. Server-side port conflicts: [Developer FAQ](../faq/_index.en.md) "Port 8090 is in use".

## Chapter summary

- A Bundle is a shared read-only artifact (exact versions + a read-only directory). The instance directory stores device identity, credentials, and all run state;
- `start --config` is the only entry for an ordinary user to start a Robot: first start exchanges a one-time join code for a credential; later starts only read `connection.yaml`;
- Startup order is fixed: flock → render instance directory → AbilityFramework → seven Abilities (upload, activate, heartbeat) → semantic-pilot → `/ws/pilot` register → desired Skill reconcile;
- A join code expires in five minutes and can be used once. Credentials and desired state persist on the Server side. Reconnect does not re-seed;
- Stop must obtain Pilot safe-stop evidence and settle Abilities in reverse order. Any unconfirmed step lands on `interrupted`/`failed`.

## Next chapter

Continue to [Chapter 8: Studio, Event Streams, and Execution Observation](chapter_08_studio.en.md) and observe this device's full execution in Studio.
