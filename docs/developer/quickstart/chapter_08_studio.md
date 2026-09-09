---
title: "第八章：Studio、事件流与执行观察"
linkTitle: "第 8 章：Studio 与观察"
weight: 28
description: "在 Semantic Studio 中查看 Project、Workflow、Robot Execution、事件、Observation 和 Artifact。"
---

**本章目标**：把前面已经运行的 Server、Workflow 和 Robot 实例，变成 Studio 中可以观察、恢复和安全操作的产品界面。

## Studio 是什么

Semantic Studio 是 Project 级 Web 工作台，统一展示：

- Conversation；
- Plan Proposal；
- Workflow；
- Environment；
- Robot 和设备；
- Robot Execution；
- Observation；
- Artifact；
- Interaction。

## 为什么需要事件流

具身任务不是一次 HTTP 请求立即返回结果。它会经历计划、审批、资源等待、Stage、Action、Feedback、物理状态变化和 Artifact 生成。

Studio 使用：

```text
REST → 当前 Snapshot
WebSocket → 增量事件
```

页面刷新或断线后，先重新读取 Snapshot，再按 sequence 继续事件，避免丢失或重复。

## 代码位置

- Studio 入口：`semantic-web/src/views/StudioView.vue`；
- 面板注册：`semantic-web/src/studio/panelRegistry.js`；
- WebSocket：`semantic-web/src/ws/`、`src/studio/subscription.js`；
- Store：`semantic-web/src/stores/`；
- API：`semantic-web/src/api/`。

## 启动 Studio

```bash
cd "$SEMANTIC/semantic-web"

npm ci

VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

浏览器打开 Vite 输出地址，默认通常是：

```text
http://127.0.0.1:3000
```

使用第 1 章的 `admin` 和初始密码登录。

## 查看 Project Snapshot

进入 Project 后，Studio 会先读取：

```http
GET /api/v1/projects/{id}/studio/snapshot
```

它恢复当前：

- Conversation；
- Run；
- Interaction；
- Memory；
- Workflow；
- Semantic Map；
- Robot Execution；
- Artifact。

如果 Runtime 或设备数据有问题，Snapshot 失败会显示诊断，不应阻断 Conversation 或其他 Project 功能。

## 查看 Workflow

打开 `Workflow` 面板：

- 查看当前 Workflow 状态；
- 查看 Task DAG；
- 查看每个 Task 的依赖、角色和状态；
- 查看 SubTask；
- 处理 pause、resume、stop 或确认现场安全。

如果看到 `execution_state_unknown`，说明 Robot 物理状态不能由当前连接确认，必须通过安全确认路径处理。

## 查看 Robot Execution

打开 `Robot Execution` 面板：

- 左侧是 Execution 列表；
- 右侧是当前 Execution 的时间线；
- 查看 Stage、Action、Feedback、Observation 和 Artifact；
- 查看当前 Stop 状态和安全证据。

不要根据按钮响应乐观显示 `stopped`；界面必须等待 Server 上报真实停止证据。

## 查看 Observation 和 Artifact

Observation 是物理执行中的结构化观测；Artifact 是执行产物，例如报告、截图或结果文件。

在底部 `Artifacts` 面板中查看：

- Artifact 名称；
- 关联 Execution；
- 版本；
- 下载入口。

## 处理 Interaction

打开底部 `Interactions` 面板：

- 查看待处理审批或补参；
- 表单、单选、多选、资源选择或地图选择；
- 提交后进入 `submitting`；
- 只有 Server 事件或 Snapshot 才能把状态变为终态。

刷新或断线不会丢失 Interaction；Studio 会对账当前状态。

## 验证事件恢复

1. 打开 Workflow 和 Robot Execution；
2. 刷新页面；
3. 断网或关闭 Wi-Fi 几秒；
4. 恢复网络。

预期结果：

- Snapshot 重新加载当前状态；
- WebSocket 使用 sequence 续传；
- 不重复展示旧事件；
- 不伪造丢失的停止或完成状态。

## 常见失败

- **Studio 白屏**：检查 `VITE_SERVER_HTTP`、`VITE_SERVER_WS` 和浏览器控制台；
- **Workflow 不更新**：检查 Project WebSocket 是否在线；
- **Execution 缺失**：检查 Server 中是否有对应 Robot Execution 和 Project 绑定；
- **Interaction 提交失败**：Studio 会对账当前状态，重试提交；
- **页面状态与设备状态不一致**：先刷新 snapshot，再检查事件 sequence 是否出现 gap。

## 本章小结

- Studio 是 Server 的观察和介入层，不直接连接设备进程；
- REST 提供当前 Snapshot，WebSocket 提供增量事件；
- Store 是面板与事件之间的唯一状态来源；
- Interaction、停止和恢复都不能由前端乐观伪造。

## 下一章

进入[第九章：完整产品 Gate](/developer/quickstart/chapter_09_product_gate/)，验证整个产品链。
