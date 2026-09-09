---
title: "第九章：完整产品 Gate"
linkTitle: "第 9 章：产品 Gate"
weight: 29
description: "执行一次完整的 Fake、MuJoCo 或真实模型产品 Gate，并保留可复现的验收证据。"
aliases:
  - /developer/quickstart/chapter_05_execution_chain/
---

**本章目标**：把前八章分别验证的组件串成一次真正的产品链，并给出每一层的通过标准和失败定位。

## 产品 Gate 是什么

产品 Gate 不是“所有进程都启动了”，而是证明一次用户目标穿过完整链路并留下可追溯证据：

```text
Conversation
→ Plan Proposal
→ Workflow
→ Task / SubTask
→ Robot Execution
→ Environment State
→ Studio Result / Artifact
```

## 前置条件

完成前八章后，你应已经具备：

- Semantic Server 和 Studio；
- 至少一个 Runtime 或真实设备；
- Agent Profile、Model 和 Skill；
- 已批准的 Workflow；
- 已加入的 Robot；
- 已安装的 Robot Skill；
- 已 running 的 Ability。

## 最小 Fake 产品 Gate

Fake Gate 用于验证完整产品状态机，不要求真实物理：

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-real-gate
```

该 Gate 会启动：

- 真实 Server；
- Web 生产构建；
- 两个 Pilot；
- 两个 AbilityFramework；
- 十四个 Ability 进程；
- 三个 Robot Skill Worker；
- 两台隔离 Fake Robot。

它不允许在缺依赖时跳过并伪装成功。

## 真实 MuJoCo 产品 Gate

MuJoCo Gate 用于验证真实物理行为：

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-mujoco-product
```

它验证：

- Scene 资产和 Runtime Installation；
- 虚拟 Robot 的受管启动；
- Ability 和 Skill 的 desired/actual 状态；
- 实际物理运动、接触和停止；
- Studio 中的 Viewer、Sensor 和 Execution。

## 真实模型产品 Gate

真实模型只用于验证 Agent 决策和协作，不代替物理验证：

```bash
cd "$SEMANTIC/semantic-framework"

make test-v050-mujoco-deepseek-single
```

该 Gate 需要真实模型密钥，并按 Framework 配置启用。它可能产生模型调用费用，应在明确开关下手动运行。

## 按层验收

| 层级 | 验证对象 | 通过标准 |
|---|---|---|
| 1 | Server / Studio | 登录、Project、Snapshot、WebSocket 正常 |
| 2 | Runtime / Scene | Scene running，Snapshot 和 Robot 有效 |
| 3 | Agent | Profile、Model、Skill、Tool 可见 |
| 4 | Workflow | Plan 批准，Task 依赖和资源正确 |
| 5 | Pilot / Worker | Skill 版本正确，Stage 和事件完整 |
| 6 | Ability / SDK | Action、Feedback、stop/hold 正常 |
| 7 | Robot / Environment | 对象、工具和最终环境状态正确 |
| 8 | Studio | Execution、Observation、Artifact 可见 |

## 必须保留的验收证据

一次完整 Gate 至少保留：

- 用户输入和获批 Plan；
- Workflow、Task、SubTask 状态；
- Pilot、Skill、Ability、SDK、Runtime 版本；
- Stage、Action、Feedback、Observation；
- 最终环境状态；
- Artifact；
- Studio 截图或执行记录；
- 失败时的日志时间范围和恢复动作。

## 按层排障

| 现象 | 先检查 |
|---|---|
| Agent 看不到 Skill | Skill Store、角色 allowlist、Server 重启 |
| Workflow 不推进 | 依赖、资源、Agent/Robot 可用性、Task 等待原因 |
| Robot 不执行 | Pilot online、Skill 版本、required Action |
| Action 失败 | Ability heartbeat、Manifest、Schema、输入模型 |
| 机器人不动 | SDK Backend、Runtime health、设备状态 |
| Studio 不更新 | Snapshot、WebSocket sequence、Store 状态 |
| 停止未完成 | Pilot、Ability、SDK、hold 证据 |
| Scene 起不来 | Runtime Installation、资产路径、failure_reason |
| 无法复现 | 检查版本清单和 Gate 产物，不要依赖“刚才手改的环境” |

## 通过标准

Gate 不是“看到一次运动”。必须同时满足：

1. 用户目标可追踪到 Task 和 Execution；
2. Workflow 与 Robot Execution 状态一致；
3. 关键物理动作有 Feedback 和 Observation；
4. 停止有 hold 证据；
5. Studio 展示与 Server 数据一致；
6. 所有组件版本被记录；
7. 在干净环境可以重复运行。

## 本系列小结

你已经沿着一条连续路径理解并验证了 Semantic：

```text
Server
→ Environment
→ Agent
→ Workflow
→ Robot Skill
→ Ability / SDK
→ Pilot / Device
→ Studio
→ Product Gate
```

后续开发请进入：

- [核心模块](/developer/core-modules/)：学习完整扩展契约；
- [Cookbook](/developer/cookbook/)：查找真实示例；
- [组件集成](/developer/integration/)：接入具体实现；
- [参考](/developer/reference/)：构建、测试、协议和内部机制。
