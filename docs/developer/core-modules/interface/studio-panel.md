---
title: "Studio 面板与交互渲染器"
weight: 50
description: "为 Semantic Studio 工作区新增面板与交互渲染器：注册表式前端扩展点。"
---

Semantic Studio 的工作区由可组合的面板（Panel）构成，Conversation 中的结构化消息由可插拔的渲染器（Renderer）呈现。两者都是 `semantic-web` 仓库中面向扩展开发者的注册表式扩展点：**新增一个 Vue 组件并登记，不需要改动现有面板代码**。

Studio 内部架构与状态管理见核心开发部分的 [Studio 前端架构](/developer/reference/internals/semantic-studio/)，本章只讲如何扩展。

## 新增一个 Studio 面板

Studio 中央工作区使用 dockview 布局，所有面板在注册表 `src/studio/panelRegistry.js` 中登记。注册表以面板 type 为 key，每个条目至少包含 `title` 和异步 `component`：

```javascript
// src/studio/panelRegistry.js（结构示意，具体条目以仓库为准）
export const panels = {
  'robot-executions': {
    title: 'Robot Execution',
    component: () => import('@/components/studio/panels/RobotExecutionsPanel.vue'),
    // 可选：preferredRegion、unavailable 等
  },
  // 新面板在这里登记一个条目即可
}

export function getPanelDefinition(type) {
  // 解析并缓存异步组件，返回 { ...definition, resolvedComponent }
}
```

### 1. 实现面板组件

在 `src/components/studio/panels/` 新建 Vue 组件。参考现有面板（如 `RobotExecutionsPanel`）的约定：

```vue
<script setup>
import { useRobotStore } from '@/stores/robot'   // Pinia store

const props = defineProps({ panelParams: Object }) // panelParams.resourceId 指向面板展示的对象
const robots = useRobotStore()

// 领域状态全部从 store 读，不直接持有服务端数据副本：
// robots.executions / robots.selected / robots.byId(...)
</script>
```

三条约定：

- 从 Pinia store（`src/stores/`）读取领域状态，不直接持有服务端数据副本；
- 需要服务端数据时通过 `src/api/` 中对应域的 axios 模块获取；
- 需要实时更新时订阅 WS 事件——`src/ws/` 的 dispatcher 按事件类型分发到对应 store（如 `robot_execution` 事件进入 `robot.applyEvent(event)`），面板只消费 store。

### 2. 注册面板

在 `src/studio/panelRegistry.js` 的 `panels` 对象中登记面板 type、标题与异步组件。注册后面板即可被 dockview 布局实例化：`StudioDock` 的 `addPanel()` 用 `makePanelId(type, resourceId)` 生成面板 id，**同一对象从不同入口打开时复用已存在的面板**（存在即激活，不存在才创建）。

### 3. 挂载入口

如需从导航或命令打开面板，接入对应的视图入口（`src/views/`）或命令网关（`src/studio/` 中的 command gateway）。

### 4. 测试

```bash
npm run lint
npm run test        # vitest 组件与 store 测试
npm run test:e2e    # playwright，验证面板打开与数据加载
```

## 新增一个交互渲染器

Conversation 中的结构化交互消息（如表单、确认卡片）由渲染器按消息类型分发：`src/components/interaction/rendererRegistry.js`。注册表以 `uiKind` 为 key 映射到异步组件：

```javascript
// src/components/interaction/rendererRegistry.js（结构示意）
const definitions = {
  // uiKind → 渲染器组件
  'form': () => import('./renderers/FormRenderer.vue'),
  'confirmation': () => import('./renderers/ConfirmationRenderer.vue'),
}
```

`InteractionShell` 根据当前 interaction 的 `uiKind` 调用 `getInteractionRenderer(uiKind)`，将映射到的 renderer 组件用于渲染。

1. 在 `src/components/interaction/renderers/` 新建渲染器组件，接收消息 payload 作为 props；
2. 在 `rendererRegistry.js` 中登记 `uiKind → 组件` 映射；
3. 未注册的类型回退到默认渲染，注册后立即生效。

渲染器只负责呈现与采集用户输入；回答经现有 Interaction 通道回传 Server，不要自行建立新的提交链路。

## 边界

- Studio 只连接 Server（REST + WebSocket），扩展面板同样不允许直连 Pilot、Runtime 或 Robot；
- 面板复用现有认证：axios 实例统一注入 Bearer token，401 自动刷新（见 [Studio 前端架构](/developer/reference/internals/semantic-studio/)）。

## 相关层次

- 概念模型：[架构 · Project：具身应用工作空间](/architecture/02-project/)
