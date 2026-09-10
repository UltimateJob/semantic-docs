---
title: "End-to-End Integration"
linkTitle: "End-to-End Integration"
weight: 30
description: "Verify the full product chain level by level from Runtime or device up to Agent, Workflow, and Studio."
aliases:
  - /developer/integration/end-to-end-integration/
---

End-to-end integration proves each boundary in dependency order. Each step introduces only one new link. Failure scope is limited to the current link or its direct interface.

## Full chain

```text
Runtime or physical device → Robot SDK → Ability → Robot Skill → Pilot
→ Robot Execution → Framework Task → Agent / Conversation → Studio
```

## Eight-step integration method

| Step | What to verify | Pass criteria |
|---|---|---|
| 1 | Runtime or physical device | health is good, instance is running, Robot state is valid |
| 2 | Robot SDK | actions, state, and stop/hold all succeed |
| 3 | AbilityFramework | Ability heartbeat is running, Action return structure is correct |
| 4 | Pilot runs a Skill directly | Stage events are complete, result file is produced |
| 5 | Framework Robot Execution | Task / SubTask converge, Execution state is correct |
| 6 | Studio | live events, Observation, and Artifact are visible |
| 7 | mock Agent | Plan → Workflow can be repeated |
| 8 | Real model | Conversation, approval, planning, and final summary match expectations |

The first 6 steps do not need an LLM. Step 7 uses a mock model to isolate decision uncertainty. Only then introduce a real model and a physical device.

## Acceptance record

At least record user input, the approved plan, Workflow, Task, SubTask, Robot Execution, Action/Feedback/Observation for key Stages, the final Artifact, and the exact versions of every component.

## Failure localization

- Agent cannot see a Skill: check Store loading and the role `skills.allowlist`;
- Robot does not execute: check that Pilot is online, the Skill exact version, and required Actions;
- Action fails: check Ability heartbeat, Manifest input model, and schema version;
- Robot does not move: check the SDK Backend and Runtime `/healthz`;
- Studio does not update: check Server WebSocket and event sequence;
- Stop is incomplete: confirm device hold first, then handle connection recovery and state convergence.

## Related docs

- [Device Integration](../device/_index.en.md);
- [Simulation Integration](../simulation/_index.en.md);
- [Component interfaces and events](../../reference/api/protocols.en.md);
- [Cookbook](../../cookbook/_index.en.md).
