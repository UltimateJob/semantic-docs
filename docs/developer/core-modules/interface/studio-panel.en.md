---
title: "Studio Panels and Interaction Renderers"
weight: 50
description: "Add a panel and an interaction renderer to the Semantic Studio workspace: registry-style frontend extension points."
---

The Semantic Studio workspace is composed of composable panels. Structured messages in Conversation are presented by pluggable renderers. Both are registry-style extension points in the `semantic-web` repository for extension developers: **add a Vue component and register it. You do not need to change existing panel code**.

Studio internals and state management are in [Studio frontend architecture](../../reference/internals/semantic-studio.en.md) in the core development section. This chapter covers only how to extend.

## Add a Studio panel

The Studio center workspace uses a dockview layout. All panels are registered in `src/studio/panelRegistry.js`. The registry is keyed by panel type. Each entry has at least `title` and an async `component`:

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

### 1. Implement the panel component

Create a Vue component under `src/components/studio/panels/`. Follow existing panel conventions (for example `RobotExecutionsPanel`):

```vue
<script setup>
import { useRobotStore } from '@/stores/robot'   // Pinia store

const props = defineProps({ panelParams: Object }) // panelParams.resourceId 指向面板展示的对象
const robots = useRobotStore()

// 领域状态全部从 store 读，不直接持有服务端数据副本：
// robots.executions / robots.selected / robots.byId(...)
</script>
```

Three conventions:

- Read domain state from Pinia stores (`src/stores/`). Do not hold a local copy of server data;
- When you need server data, fetch it through the matching domain axios module in `src/api/`;
- When you need live updates, subscribe to WS events — the dispatcher in `src/ws/` routes by event type to the matching store (for example `robot_execution` events enter `robot.applyEvent(event)`). The panel only consumes the store.

### 2. Register the panel

Register the panel type, title, and async component in the `panels` object in `src/studio/panelRegistry.js`. After registration, dockview can instantiate it: `StudioDock`'s `addPanel()` generates a panel id with `makePanelId(type, resourceId)`. **Opening the same object from different entries reuses an existing panel** (activate if it exists, create only if it does not).

### 3. Mount an entry point

To open the panel from navigation or a command, connect the matching view entry (`src/views/`) or the command gateway (`src/studio/`).

### 4. Test

```bash
npm run lint
npm run test        # vitest 组件与 store 测试
npm run test:e2e    # playwright，验证面板打开与数据加载
```

## Add an interaction renderer

Structured interaction messages in Conversation (forms, confirmation cards) are dispatched by message type: `src/components/interaction/rendererRegistry.js`. The registry maps `uiKind` to an async component:

```javascript
// src/components/interaction/rendererRegistry.js（结构示意）
const definitions = {
  // uiKind → 渲染器组件
  'form': () => import('./renderers/FormRenderer.vue'),
  'confirmation': () => import('./renderers/ConfirmationRenderer.vue'),
}
```

`InteractionShell` calls `getInteractionRenderer(uiKind)` from the current interaction's `uiKind` and uses the mapped renderer component.

1. Create a renderer component under `src/components/interaction/renderers/` that receives the message payload as props;
2. Register the `uiKind → component` mapping in `rendererRegistry.js`;
3. Unregistered types fall back to the default renderer. Registration takes effect immediately.

A renderer only presents and collects user input. Replies go back to the Server through the existing Interaction channel. Do not create a new submit path.

## Boundaries

- Studio connects only to the Server (REST + WebSocket). Extension panels likewise must not connect directly to Pilot, Runtime, or a Robot;
- Panels reuse existing auth: the axios instance injects a Bearer token and refreshes automatically on 401 (see [Studio frontend architecture](../../reference/internals/semantic-studio.en.md)).

## Related layers

- Conceptual model: [Architecture · Project: embodied application workspace](../../../architecture/02-project.en.md)
