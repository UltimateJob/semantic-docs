---
title: "Studio Frontend Architecture"
weight: 30
description: "Studio frontend architecture: state sources, view organization, WebSocket protocol, and debugging capabilities."
---

Semantic Studio is the Web tool for operating a Project, collaborating with Agents, and observing embodied runs. It organizes Conversation, environment, Robot, Workflow, and Execution in a Project context.
How to add a Studio panel is in the core-module page [Studio Panels and Interaction Renderers](../../core-modules/interface/studio-panel.en.md).

Implementation lives in the `semantic-web` repository: Vue 3 + Pinia + element-plus + dockview (panel layout) + three (3D Viewer).

## Start and connect

```bash
cd semantic-web
cp .env.example .env        # VITE_SERVER_HTTP=http://127.0.0.1:8080, VITE_SERVER_WS=ws://127.0.0.1:8081
npm install
npm run dev                 # vite 开发服务器，端口 3000
```

Development proxy (`vite.config.js`): `/api → http://127.0.0.1:8080`, `/ws → ws://127.0.0.1:8081`.

## Frontend state sources

- REST (`src/api/`): the axios instance injects a Bearer token uniformly; on 401 it single-flights `POST /auth/refresh` for a new token and replays the request;
- WebSocket (`src/ws/`): event channels `/ws/agent-events` (Chat) and `/ws/studio?project_id=...&token=...` (Studio);
  - State machine offline→connecting→online⇄reconnecting, exponential backoff 1s/2s/4s… capped at 30s;
  - Server protocol-layer ping/pong keep-alive (30s ping / 90s death detect). The application layer does not send ping;
  - Resume: Chat uses `last_event_id`, Studio uses global `after_sequence` (`sync` is sent automatically on reconnect onopen); event IDs are de-duplicated;
- Pinia Stores are organized by domain (chat/project/workflow/device/simulation/robot, and so on).

After a page refresh or WebSocket reconnect, the frontend re-reads current Server state (for example `GET /projects/{id}/studio/snapshot`) and then continues consuming incremental events.

## Main views

- Conversation: multi-Agent messages, Proposal, and Interaction;
- Workflow: Task DAG, SubTask, assignment, pause, and results;
- Environment: Scene, Layout, Runtime, Viewer, and Semantic Map;
- Device: Pilot, Robot, Ability, and Robot Skill;
- Robot Execution: Stage timeline, Action, Observation, and Artifact;
- Debug: Run, Trace, and cross-layer timeline.

Opening the same object from different entries reuses the center Dock and Inspector (dockview panel registry) and keeps the user in the current Project.

## Interaction design

Every run state answers three questions at once:

1. What is happening now;
2. Which Agent, Robot, or user owns the next step;
3. What the user can do.

Real Agent output and system activity are shown separately (`message_kind` distinguishes them). Run details go into Inspector and debug panels. Conversation keeps the summary, questions, and results needed for collaboration.

## Development and tests

```bash
npm run lint
npm run test          # vitest
npm run test:e2e      # playwright
npm run build
```

Code layout: `src/api/` (axios modules by domain), `src/stores/` (Pinia), `src/views/`, `src/components/` (chat/studio/device/simulation, and so on), `src/studio/` (panel registry, command gateway, map selection), `src/ws/` (client + dispatcher).

E2E coverage: Proposal generation and approve, Interaction reply, Workflow and Robot Execution updates, pause/resume and safe stop, page refresh and WebSocket reconnect, Scene Robot and Skill debug. Server-side joint debug: [Server, Agent, and Workflow](server-agent-and-workflow.en.md#local-start).

## Related layers

- Conceptual model: [Architecture · Project: embodied application workspace](../../../architecture/02-project.en.md)
