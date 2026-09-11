---
title: "Chapter 8: Studio, Event Streams, and Execution Observation"
linkTitle: "Chapter 8: Studio and Observation"
weight: 28
description: "Inspect Project, Workflow, Robot Execution, events, Observation, and Artifact in Semantic Studio."
---

**Goal of this chapter**: turn the Server, Workflow, and Robot instance you already ran into a product UI in Studio that you can observe, recover, and operate safely.

## What Studio is

Semantic Studio is a Project-level Web workbench. It presents in one place:

- Conversation;
- Plan Proposal;
- Workflow;
- Environment;
- Robot and devices;
- Robot Execution;
- Observation;
- Artifact;
- Interaction.

## Why an event stream is needed

An embodied task is not one HTTP request that returns immediately. It goes through plan, approval, resource wait, Stage, Action, Feedback, physical-state change, and Artifact generation.

Studio uses:

```text
REST → current Snapshot
WebSocket → incremental events
```

After a page refresh or disconnect, first re-read the Snapshot, then continue events by sequence so nothing is lost or duplicated.

## Code locations

- Studio entry: `semantic-web/src/views/StudioView.vue`;
- Panel registry: `semantic-web/src/studio/panelRegistry.js`;
- WebSocket: `semantic-web/src/ws/`, `src/studio/subscription.js`;
- Store: `semantic-web/src/stores/`;
- API: `semantic-web/src/api/`.

## Start Studio

```bash
cd "$SEMANTIC/semantic-web"

npm ci

VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

Open the address Vite prints. The default is usually:

```text
http://127.0.0.1:3000
```

Log in with Chapter 1 `admin` and the initial password.

## Read the Project Snapshot

After you enter a Project, Studio first reads:

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

If Runtime or device data has a problem, a Snapshot failure shows diagnostics and should not block Conversation or other Project features.

## Inspect Workflow

Open the `Workflow` panel:

- Current Workflow status;
- Task DAG;
- Each Task's dependencies, role, and status;
- SubTasks;
- Handle pause, resume, stop, or confirm on-site safety.

If you see `execution_state_unknown`, the Robot physical state cannot be confirmed by the current connection and must go through the safety-confirmation path.

## Inspect Robot Execution

Open the `Robot Execution` panel:

- The left side is the Execution list;
- The right side is the current Execution timeline;
- Inspect Stage, Action, Feedback, Observation, and Artifact;
- Inspect the current Stop status and safety evidence.

Do not optimistically show `stopped` from a button response. The UI must wait for the Server to report real stop evidence.

## Inspect Observation and Artifact

Observation is a structured observation during physical execution. Artifact is an execution product, for example a report, screenshot, or result file.

In the bottom `Artifacts` panel inspect:

- Artifact name;
- Related Execution;
- Version;
- Download entry.

## Handle Interaction

Open the bottom `Interactions` panel:

- Pending approvals or missing parameters;
- Form, single select, multi select, resource select, or map select;
- After submit the state enters `submitting`;
- Only a Server event or Snapshot can move the state to a terminal state.

Refresh or disconnect does not lose an Interaction. Studio reconciles the current state.

## Verify event recovery

1. Open Workflow and Robot Execution;
2. Refresh the page;
3. Disconnect or turn off Wi-Fi for a few seconds;
4. Restore the network.

Expected result:

- Snapshot reloads the current state;
- WebSocket continues with sequence;
- Old events are not shown twice;
- A missing stop or completion state is not fabricated.

## Common failures

- **Studio blank page**: check `VITE_SERVER_HTTP`, `VITE_SERVER_WS`, and the browser console;
- **Workflow does not update**: check that the Project WebSocket is online;
- **Execution missing**: check that the matching Robot Execution and Project binding exist on the Server;
- **Interaction submit failed**: Studio reconciles the current state and retries the submit;
- **Page state disagrees with device state**: refresh the snapshot first, then check whether the event sequence has a gap.

## Chapter summary

- Studio is the Server's observation and intervention layer. It does not connect to device processes;
- REST provides the current Snapshot. WebSocket provides incremental events;
- The Store is the only state source between panels and events;
- Interaction, stop, and recovery must not be fabricated optimistically on the frontend.

## Next chapter

Continue to [Chapter 9: Full Product Gate](chapter_09_product_gate.en.md) and verify the whole product chain.
