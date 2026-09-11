---
title: "Studio and Interaction"
linkTitle: "Studio and Interaction"
weight: 50
description: "Use Semantic Studio to observe and run a Project, and extend panels, interaction renderers, Stores, and event streams."
---

**Studio and Interaction** answers one question: **how people observe an embodied task, handle Interactions, and intervene in execution when needed**.

Studio is the Server's web frontend. It does not connect directly to Pilot, AbilityFramework, Robot SDK, or Runtime. All state comes from the Server's REST Snapshot and WebSocket incremental events.

## Module composition

| Module | Problem it solves | Typical artifacts |
|---|---|---|
| [Studio panels and interaction renderers](studio-panel.en.md) | Add observation or interaction capability to Studio | Vue components, registry entries |
| [Studio frontend architecture](../../reference/internals/semantic-studio.en.md) | Frontend state, APIs, Stores, WS, and recovery | Store, dispatcher, bootstrap |

## Code locations

- Studio entry: `semantic-web/src/views/StudioView.vue`;
- Panels: `semantic-web/src/components/studio/`;
- Panel registration: `semantic-web/src/studio/panelRegistry.js`;
- Interaction renderers: `semantic-web/src/components/interaction/`;
- Stores: `semantic-web/src/stores/`;
- APIs: `semantic-web/src/api/`;
- WebSocket: `semantic-web/src/ws/`.

## Start Studio

```bash
cd "$SEMANTIC/semantic-web"

npm ci

VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

The default development URL is usually:

```text
http://127.0.0.1:3000
```

Studio connects only to the Server. Development and E2E may use Fixture mode, but production must connect to a real Server.

## How Studio restores state

After entering a Project, Studio first reads:

```http
GET /api/v1/projects/{id}/studio/snapshot
```

It restores the current:

- Conversation;
- Run;
- Interaction;
- Memory;
- Workflow;
- Semantic Map;
- Robot Execution;
- Artifact.

WebSocket then resumes events by sequence. After a page refresh or disconnect, Studio rereads the Snapshot and then continues events. It does not invent results from local frontend state.

## Panel system

Every panel is registered in the registry:

```javascript
export const panels = {
  'workflow-run': {
    title: 'Workflow',
    component: () => import('@/components/studio/panels/WorkflowRunPanel.vue'),
    preferredRegion: 'editor'
  }
}
```

Opening a panel always goes through `StudioView` region routing. A panel must not guess whether it belongs in the center, bottom, or sidebar from the current Dock focus.

## Interaction renderers

Structured Interactions in a Conversation are dispatched by `uiKind`:

| uiKind | Renderer |
|---|---|
| `confirm` | ConfirmRenderer |
| `form` / `parameter` | FormRenderer |
| `single_select` / `multi_select` | ChoiceRenderer |
| `image_select` / `file_select` | ResourceChoiceRenderer |
| `map_select` | MapSelectRenderer |

The renderer collects user input. Submit must return to the Server through the existing Interaction channel. The frontend must not treat local post-submit state as final. It must wait for a Server event or Snapshot.

## Add a Studio panel

1. Add a Vue component under `src/components/studio/panels/`;
2. Read state from a Pinia Store. Do not keep a copy of server state;
3. Fetch required REST data through `src/api/`;
4. For live updates, consume the existing WS dispatcher that updates the Store;
5. Register the panel in `src/studio/panelRegistry.js`;
6. Mount an open entry through a view, activity bar, or command gateway;
7. Write Vitest and Playwright tests.

## Add an Interaction renderer

1. Add a component under `src/components/interaction/renderers/`;
2. Write the payload into `interactions.drafts`;
3. Submit through `interactions.submit(id, answer)`;
4. Register the `uiKind` in `rendererRegistry.js`;
5. Write precise Vitest coverage for the submit payload;
6. Confirm fallback copy for unsupported types.

## Testing

```bash
cd "$SEMANTIC/semantic-web"

npm run lint
npm run test
npm run test:e2e
npm run build
```

For real Framework integration, use:

```bash
npm run test:framework:v050
```

## Boundaries

- Studio does not connect directly to Pilot, AbilityFramework, Robot SDK, or Runtime;
- A panel must not create its own Project business WebSocket;
- A panel does not keep a copy of server state;
- Stop state must wait for Server-reported evidence;
- Fixtures are only for frontend development and testing. They are not proof of production behavior.

## Further reading

- [Studio panels and interaction renderers](studio-panel.en.md);
- [Studio frontend architecture](../../reference/internals/semantic-studio.en.md);
- [Chapter 8: Studio, event streams, and execution observation](../../quickstart/chapter_08_studio.en.md).
