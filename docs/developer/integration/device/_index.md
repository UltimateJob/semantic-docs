---
title: "设备集成"
linkTitle: "设备集成"
weight: 10
description: "从 Robot SDK、Ability 到 Pilot 和 Server，接入 Fake 或真实 Robot。"
---

本节面向 Robot 集成开发者。设备集成的目标不是只连接一个控制器，而是让一台 Robot 具备可发现、可执行、可停止、可观察的完整运行链。

## 集成边界

```text
Robot SDK Backend
→ Ability Handler
→ AbilityFramework
→ semantic-pilot
→ Server Robot Gateway
→ Studio Robot Execution
```

## 推荐顺序

1. 在 Fake Backend 中验证 SDK 命令、状态和 `stop/hold`；
2. 为原子动作编写 Ability Manifest、Task Model、Handler 和 Provider；
3. 用 AbilityFramework 上传、激活并通过 heartbeat 确认 Ability；
4. 用 `semantic-pilot` 直跑 Robot Skill；
5. 编写 RobotDeployment 和类型 Bundle；
6. 通过一次性 join code 让 Robot 加入 Server；
7. 在 Framework Robot Execution 和 Studio 中验证完整链路。

## 阅读路径

- 接入设备抽象：[Robot SDK](/developer/core-modules/robot/robot-sdk/)；
- 新增原子动作：[Ability](/developer/core-modules/robot/ability/)；
- 编排阶段化任务：[Robot Skill](/developer/core-modules/robot/robot-skill/)；
- 设备装配和加入：[设备部署与加入](/developer/integration/device/deployment/)；
- 跨组件接口：[组件接口与事件](/developer/integration/component-interfaces-and-events/)。

## 验收标准

设备集成至少应证明：

- Server 能识别唯一 Robot 和 Pilot；
- 所需 Ability 已 running 且 heartbeat 正常；
- Robot Skill 的每个 `required_action` 都能按 `type@schema_version` 精确匹配；
- 运行中能收到 Feedback 和 Observation；
- stop 请求能让设备进入 hold，并留下可追溯证据；
- 设备断线和恢复不会伪报执行成功。
