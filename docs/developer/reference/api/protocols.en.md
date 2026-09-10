---
title: "Protocol Overview"
linkTitle: "Protocol overview"
weight: 10
description: "Interface contracts and event flows between Semantic components, for integration developers."
aliases:
  - /developer/integration/component-interfaces-and-events/
---

Semantic components collaborate through HTTP, WebSocket, Worker messages, Ability calls, and Robot SDK interfaces. Interface definitions include types, identity, versions, and error semantics. Protocols fall into four kinds. This page gives each kind's interface surface and typical interactions.

## Server HTTP API (synchronous control)

The Server's public HTTP API creates, queries, and controls Project objects:

| Operation | Semantics |
|---|---|
| Create/update | Writes carry `revision`. Callers confirm and retry conflicts |
| Stop | Idempotent — a repeat request returns current progress and does not run again |
| Query | Current object state and lists |

```bash
# 典型调用（认证经 Bearer token）：
curl -s http://127.0.0.1:8080/api/v1/skills -H "Authorization: Bearer $TOKEN"
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
```

The simulation Runtime HTTP contract is isomorphic: `/healthz`, scene catalog, instance lifecycle (start → `starting` → `running`), snapshot, and virtual Robot descriptors. Both are request-response interfaces suited to synchronous control.

## Server WebSocket (incremental state push)

The WebSocket channel on HTTP :8081 pushes **incremental state** for Conversation, Workflow, Robot, Scene, and Execution — it does not poll full snapshots. A state change is pushed immediately. The frontend Studio WS dispatcher routes by event type to the matching store (for example a `robot_execution` event enters the robot store's `applyEvent`).

## Pilot WebSocket (device-side uplink and downlink)

The Pilot WebSocket connects to the Server with a dedicated credential and a bound Pilot ID. After the connection is established, Pilot reports:

- Robot Profile and state;
- AbilityFramework and Ability instances;
- Robot Skill installed/enabled state;
- Active Robot Executions;
- Event-sequence position.

The Server issues Skill install, run, Agent Reply, and stop requests.

## Worker JSON-RPC (in-process boundary)

Pilot and the Skill Worker exchange JSON-RPC over stdin/stdout (one JSON per line):

```bash
# 可以直接手动驱动 Worker 调试（绕过 Pilot）：
python -m semantic_robot_skill_sdk.worker \
  --skill-dir semantic_robot_skills/skills/semantic_navigation
```

Why this boundary exists: the Worker is an isolated process. A crash does not take Pilot down, and you can talk to it directly with any JSON tool for debugging.

## Ability calls (Action contract)

A Robot Skill Action includes an Action type and a Schema version. Pilot starts a call with Robot ID, Action type, Schema version, and a concrete Ability instance:

```text
Skill 声明：{ type: perception.locate_object, schema_version: 2 }
匹配键：  actionType + schemaVersion（Manifest 中声明）
```

AbilityFramework manages instance lifecycle (upload → activate → heartbeat confirms running) and passes Feedback, results, and stop. Versions are managed by actual compatibility:

- A Robot Skill requests an exact installed version (`name@version`);
- Action and Ability match on Schema version;
- Robot SDK Wheel, Ability package, Robot Skill, and Bundle each publish their own versions;
- The release inventory records verified combinations.

## Robot SDK (typed Python interface)

Abilities use the Robot SDK's typed Python API. A Robot package turns calls into device or Runtime commands and turns raw state into shared models. The `RobotBackend` Protocol is the extension point for a new device/engine (fake / mujoco / real backends are isomorphic).

## Sync obligations when changing an interface

An interface change must update types, implementation, tests, example config, and developer docs together. Missing any one of them breaks integrators.

## Related references

- Endpoint and event details: [HTTP API](http.en.md), [WebSocket events](ws.en.md);
- An integration path that strings these interfaces into a full chain: [End-to-end integration](../../integration/end-to-end/_index.en.md);
- Runnable reference implementations: [Cookbook](../../cookbook/_index.en.md).
