---
title: "Pilot 与 Robot Execution"
weight: 20
description: "Pilot 与 Robot Execution：设备连接、Skill 下发、Action 路由与环境运行。"
---

Robot Execution 连接 Framework 中的 Robot Task 与 Pilot 中的 Robot Skill Worker。环境运行连接 Scene Runtime、Semantic Map 和虚拟 Robot。执行链全貌见[第 9 章：完整产品 Gate](/developer/quickstart/chapter_09_product_gate/)。

实现位置：`internal/pilot/`（Pilot 进程与 Server 侧编排）、`internal/robot/`（设备与 enrollment）、`internal/simulation/`（Scene 与虚拟 Robot 生命周期）。

## Robot Execution 链路

```text
Robot Agent robot.run（验证 Robot、Skill 版本与完整输入）
→ Server 创建 Robot Execution
→ Pilot 启动 Robot Skill Worker（python -m semantic_robot_skill_sdk.worker）
→ Worker 执行 Stage 和 Action（JSON-RPC 协议）
→ AbilityFramework 执行 Ability
→ Robot SDK 控制 Robot
→ 事件更新 Execution、SubTask 和 Task
```

- `robot.run` accepted 只记录 execution_ref，**不推进 Task/SubTask 状态**——完成必须由 Robot Execution 终态事件驱动；
- Pilot 接受后返回 Execution ID；模型 Run 可以结束，后续状态由事件推进。

## Pilot 与 Robot

Pilot 使用专用 credential 连接 Server（`/ws/pilot`，enrollment 签发）并绑定 Robot 身份。它负责：

- 上报 Robot、Ability 和 Robot Skill 实际状态；
- 安装和启用 desired Robot Skill（ZIP 校验 + `packages/<name>/<version>` + `active/` 符号链接原子切换，见 [Robot Skill](/developer/core-modules/robot/robot-skill/)）；
- 启动、停止和观察 Worker；
- 转发 Action、Feedback、Observation 和 Artifact；
- 断线恢复后报告当前执行与事件序列位置。

Action 路由（`internal/pilot/runner.go`）：

- action key 幂等：同 key 同内容复用结果，不同内容报 `ErrActionKeyConflict`；interrupted 禁止重放；
- 物理 Action 有 Robot 级互斥锁（`ErrRobotBusy`）；StartTask 失败不自动重试。

Server 根据 Pilot、Ability、Skill、Robot 状态和 Task 占用判断 Robot 是否可分配。

## Execution 事件

事件更新 Stage、Action 和 Execution，并推动 SubTask：

- completed：验证结果后完成 SubTask；
- failed：物理已启动 → `execution_state_unknown`（禁止重放）；未启动 → Recovery；
- waiting_agent：启动 Robot Agent Decision，回复返回原 Worker；
- interrupted：保留 Robot 占用，等待状态确认；
- stopped：根据 stop 与 hold 状态收敛（拿到 `stop.outcome` 安全证据才记 `stopped`，否则 `interrupted`）。

事件补发和按 Execution ID 查询用于恢复连接后的状态同步（Pilot 侧 journal + 事件序列位置）。

## Scene 与虚拟 Robot

Framework 通过 Runtime Installation 启动 Scene Instance（启动链路见 [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/)）。初始 Snapshot 同步到 Semantic Map 后，Runtime 提供虚拟 Robot 描述，Robot Runtime Orchestrator 为每台虚拟 Robot 生成部署配置并启动受管实例（AbilityFramework、Ability、Pilot），使其进入统一 Robot Execution 链路。

- 虚拟 Robot 拉起在场景 running 且首个 Map generation 写入之后异步执行（Launcher 内部约 2 分钟完成对账）；
- Robot Skill 通过 Ability 读取 Runtime 实时状态；Semantic Map 服务 Agent 查询和环境理解。

## 生命周期

- Reset：Robot hold 后重置 Scene，并同步新的环境状态；
- Scene stop：先向 Runtime 逐台 HoldRobot 并确认成功（物理安全边界），再收敛 Pilot/Ability，最后停止 Scene Instance；
- Layout switch：先落 layout_switch 检查点，完整结束当前实例后启动新 Layout；
- Robot 启动失败：Scene 保持可查看，Robot 标记 degraded，不销毁场景。

生命周期测试同时检查进程、Store、Web 状态和实际 Robot 安全状态。

## 本地调试

- 脱离 Agent 调试单个 Robot Skill：`semantic-pilot skill run`（用法见 [Robot Skill](/developer/core-modules/robot/robot-skill/)）；
- 调试 Ability 物理链：`semantic-pilot debug-stack`（见 `semantic-framework/examples/mujoco-skill-debug/README.md`）；
- 独立验证 Scene：直接启动 `plugin-mujoco` 并调用其 HTTP API。

## 测试

```bash
cd semantic-framework
go test ./internal/pilot/... ./internal/robot/... ./internal/simulation/... -count=1
go test ./tests/integration/ -count=1
```

## 相关层次

- 概念模型：[架构 · Robot 执行与具身闭环](/architecture/06-robot-execution/)
