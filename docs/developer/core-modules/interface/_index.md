---
title: "Studio 与交互"
linkTitle: "Studio 与交互"
weight: 50
description: "使用 Semantic Studio 观察和执行 Project，并扩展面板、交互渲染器、Store 和事件流。"
---

**Studio 与交互**回答一个问题：**人如何观察具身任务、处理 Interaction，并在必要时介入执行**。

Studio 是 Server 的 Web 前端，不直接连接 Pilot、AbilityFramework、Robot SDK 或 Runtime。所有状态都来自 Server 的 REST Snapshot 和 WebSocket 增量事件。

## 模块组成

| 模块 | 解决的问题 | 典型产物 |
|---|---|---|
| [Studio 面板与交互渲染器](/developer/core-modules/interface/studio-panel/) | 给 Studio 增加观察或交互能力 | Vue 组件、注册表条目 |
| [Studio 前端架构](/developer/reference/internals/semantic-studio/) | 前端状态、API、Store、WS 和恢复机制 | Store、dispatcher、bootstrap |

## 代码位置

- Studio 入口：`semantic-web/src/views/StudioView.vue`；
- 面板：`semantic-web/src/components/studio/`；
- 面板注册：`semantic-web/src/studio/panelRegistry.js`；
- 交互渲染器：`semantic-web/src/components/interaction/`；
- Store：`semantic-web/src/stores/`；
- API：`semantic-web/src/api/`；
- WebSocket：`semantic-web/src/ws/`。

## 启动 Studio

```bash
cd "$SEMANTIC/semantic-web"

npm ci

VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

默认开发地址通常是：

```text
http://127.0.0.1:3000
```

Studio 只连接 Server。开发和 E2E 可使用 Fixture 模式，但生产环境必须连接真实 Server。

## Studio 如何恢复状态

进入 Project 后，Studio 先读取：

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

随后 WebSocket 使用 sequence 续传事件。页面刷新或断线后，先重新读取 Snapshot，再继续事件，不会依赖前端本地状态伪造结果。

## 面板系统

所有面板都在注册表中登记：

```javascript
export const panels = {
  'workflow-run': {
    title: 'Workflow',
    component: () => import('@/components/studio/panels/WorkflowRunPanel.vue'),
    preferredRegion: 'editor'
  }
}
```

面板打开统一经过 `StudioView` 的区域路由。面板不能根据当前 Dock 焦点猜测应该放到中央、底部还是侧栏。

## 交互渲染器

Conversation 中的结构化 Interaction 按 `uiKind` 分发：

| uiKind | 渲染器 |
|---|---|
| `confirm` | ConfirmRenderer |
| `form` / `parameter` | FormRenderer |
| `single_select` / `multi_select` | ChoiceRenderer |
| `image_select` / `file_select` | ResourceChoiceRenderer |
| `map_select` | MapSelectRenderer |

渲染器负责采集用户输入；提交必须通过现有 Interaction 通道返回 Server。前端不能把提交后的本地状态直接当作终态，必须等待 Server 事件或 Snapshot。

## 新增一个 Studio 面板

1. 在 `src/components/studio/panels/` 中新增 Vue 组件；
2. 从 Pinia Store 读取状态，不保存服务端状态副本；
3. 通过 `src/api/` 获取必要 REST 数据；
4. 如需实时更新，消费现有 WS dispatcher 更新 Store；
5. 在 `src/studio/panelRegistry.js` 注册；
6. 通过视图、活动栏或命令网关挂载打开入口；
7. 编写 Vitest 和 Playwright 测试。

## 新增一个 Interaction 渲染器

1. 在 `src/components/interaction/renderers/` 新增组件；
2. 将 payload 写入 `interactions.drafts`；
3. 通过 `interactions.submit(id, answer)` 提交；
4. 在 `rendererRegistry.js` 注册 `uiKind`；
5. 为提交载荷编写精确 Vitest；
6. 确认不支持类型的回退文案。

## 测试

```bash
cd "$SEMANTIC/semantic-web"

npm run lint
npm run test
npm run test:e2e
npm run build
```

真实 Framework 联调使用：

```bash
npm run test:framework:v050
```

## 边界

- Studio 不直接连接 Pilot、AbilityFramework、Robot SDK 或 Runtime；
- 面板不能自己创建 Project 业务 WebSocket；
- 面板不保存服务端状态副本；
- 停止状态必须等待 Server 上报证据；
- Fixture 只用于前端开发和测试，不能作为生产行为证明。

## 深入阅读

- [Studio 面板与交互渲染器](/developer/core-modules/interface/studio-panel/)；
- [Studio 前端架构](/developer/reference/internals/semantic-studio/)；
- [第八章：Studio、事件流与执行观察](/developer/quickstart/chapter_08_studio/)。
