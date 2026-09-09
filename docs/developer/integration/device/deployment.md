---
title: "设备部署与加入"
linkTitle: "部署与加入"
weight: 20
description: "构建 Robot Bundle，启动实例并通过一次性加入码连接 Semantic Server。"
---

本页面向部署开发者和设备维护者。Robot Bundle 是已验证组件的装配结果；具体 Robot Skill 仍由 Server Registry 独立发布和安装。

## 启动顺序

```text
AbilityFramework
→ 七类 Ability
→ heartbeat 确认
→ semantic-pilot
→ 对账 desired Robot Skill
```

## 首次加入

在 Studio 设备页面创建一次性加入码，然后在 Robot 主机上运行：

```bash
semantic-robot-instance start \
  --config <robot-deployment.yaml> \
  --join-code <一次性加入码>
```

加入码只用于首次领取与 Pilot ID 绑定的 credential。credential 写入实例目录的 `connection.yaml`，后续启动不再需要加入码。

## Bundle 内容

Bundle 组装已通过测试的 Pilot、AbilityFramework、Robot SDK Wheel、Ability Zip、Robot Skill Runtime SDK Wheel 和固定依赖。每台 Robot 使用独立的实例目录，不能共享 Robot ID、Pilot ID、Execution Store 或端口。

## 停止语义

停止时先锁存 Pilot 并阻止新 Action，再等待 Worker、Ability 和 SDK 到达安全停止点，确认 hold 后才关闭进程。任一环节无法确认，都必须保留 `interrupted` 或 `failed` 状态，不能仅凭进程退出显示 `stopped`。

## 相关文档

- 类型包和构建命令：`semantic-robot-deployment/type-packages/`；
- SDK、Ability、Skill 的开发入口见[设备集成](/developer/integration/device/)；
- 端到端验证见[集成指南](/developer/integration/)。
