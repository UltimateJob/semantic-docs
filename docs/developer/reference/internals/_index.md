---
title: "框架内部实现"
weight: 10
---

框架内部实现覆盖 Semantic Framework、Semantic Studio、Pilot、Robot Execution 和环境运行。修改应保持 Project、Agent、Workflow 与 Robot 执行主线连贯。

核心代码集中在 `semantic-framework` 仓库；Studio 前端在 `semantic-web` 仓库。

## 主要模块

| 模块 | 代码位置 | 关注内容 |
|---|---|---|
| Semantic Server | `cmd/semantic-server/`、`internal/server/`、`internal/bootstrap/` | REST API、WebSocket、认证、装配与配置热重载 |
| Agent Runtime | `internal/agent/kernel/`、`internal/agent/runtime/`、`internal/agent/profile/` | Run、Tool、Skill、Interaction、Trace 和模型调用 |
| Workflow | `internal/workflow/`、`internal/store/workflow.go` | Proposal、Task、SubTask、事件驱动调度、暂停恢复与停止 |
| Pilot 与 Robot Execution | `internal/pilot/`、`internal/robot/`、`cmd/semantic-pilot/` | Pilot 连接、Skill 安装、Worker 启动、Action 路由 |
| Environment | `internal/simulation/`、`configs/scenes.d/`、`configs/runtimes.d/` | Scene Catalog、Runtime Installation、Semantic Map 和虚拟 Robot |
| Semantic Studio | `semantic-web` | Conversation、Project 资源、Workflow、设备与 Execution 界面 |

## 开发方法

1. 从用户流程描述问题。
2. 找到拥有该状态和行为的模块。
3. 明确 API、事件和持久化影响。
4. 先覆盖状态变化和失败路径测试。
5. 实现服务端和前端的同一条用户入口。
6. 使用完整产品流程验证刷新、重连、暂停和停止。

跨模块功能通过现有应用服务和事件衔接。状态机保持少量清晰状态，用户可以在 Studio 中理解每个等待或失败状态。
