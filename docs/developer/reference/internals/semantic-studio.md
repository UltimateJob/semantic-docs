---
title: "Studio 前端架构"
weight: 30
description: "Studio 前端架构：状态来源、视图组织、WebSocket 协议与调试能力。"
---

Semantic Studio 是操作 Project、与 Agent 协作和观察具身运行的 Web 工具。它以 Project 为上下文组织 Conversation、环境、Robot、Workflow 和 Execution。
如何为 Studio 新增面板见核心模块的 [Studio 面板与交互渲染器](/developer/core-modules/interface/studio-panel/)。

实现位于 `semantic-web` 仓库：Vue 3 + Pinia + element-plus + dockview（面板布局）+ three（3D Viewer）。

## 启动与连接

```bash
cd semantic-web
cp .env.example .env        # VITE_SERVER_HTTP=http://127.0.0.1:8080, VITE_SERVER_WS=ws://127.0.0.1:8081
npm install
npm run dev                 # vite 开发服务器，端口 3000
```

开发代理（`vite.config.js`）：`/api → http://127.0.0.1:8080`、`/ws → ws://127.0.0.1:8081`。

## 前端状态来源

- REST（`src/api/`）：axios 实例统一注入 Bearer token；401 时单飞调用 `POST /auth/refresh` 换新 token 后重放请求；
- WebSocket（`src/ws/`）：事件通道 `/ws/agent-events`（Chat）与 `/ws/studio?project_id=...&token=...`（Studio）；
  - 状态机 offline→connecting→online⇄reconnecting，指数退避 1s/2s/4s…封顶 30s；
  - 服务端协议层 ping/pong 保活（30s ping / 90s 判死），应用层不发 ping；
  - 续传：Chat 用 `last_event_id`，Studio 用全局 `after_sequence`（重连 onopen 时自动发 `sync`）；事件 ID 去重；
- Pinia Store 按领域组织（chat/project/workflow/device/simulation/robot 等）。

页面刷新和 WebSocket 重连后，前端重新读取 Server 当前状态（如 `GET /projects/{id}/studio/snapshot`），再继续消费增量事件。

## 主要视图

- Conversation：多 Agent 消息、Proposal 和 Interaction；
- Workflow：Task DAG、SubTask、分配、暂停和结果；
- Environment：Scene、Layout、Runtime、Viewer 和 Semantic Map；
- Device：Pilot、Robot、Ability 和 Robot Skill；
- Robot Execution：Stage 时间线、Action、Observation 和 Artifact；
- Debug：Run、Trace 和跨层时间线。

同一对象从不同入口打开时复用中央 Dock 与 Inspector（dockview 面板注册表），保持用户位于当前 Project。

## 交互设计

每个运行状态同时回答三个问题：

1. 当前正在发生什么；
2. 哪个 Agent、Robot 或用户负责下一步；
3. 用户可以执行什么操作。

Agent 真实输出与系统活动分别展示（`message_kind` 区分）。运行详情进入 Inspector 和调试面板，Conversation 保留协作所需的摘要、问题和结果。

## 开发与测试

```bash
npm run lint
npm run test          # vitest
npm run test:e2e      # playwright
npm run build
```

代码结构：`src/api/`（按域划分的 axios 模块）、`src/stores/`（Pinia）、`src/views/`、`src/components/`（chat/studio/device/simulation 等）、`src/studio/`（面板注册表、command gateway、map selection）、`src/ws/`（client + dispatcher）。

E2E 覆盖：Proposal 生成和批准、Interaction 回答、Workflow 与 Robot Execution 更新、暂停恢复和安全停止、页面刷新和 WebSocket 重连、Scene Robot 和 Skill 调试。Server 侧联调见 [Server、Agent 与 Workflow](/developer/reference/internals/server-agent-and-workflow/#本地启动)。

## 相关层次

- 概念模型：[架构 · Project：具身应用工作空间](/architecture/02-project/)
