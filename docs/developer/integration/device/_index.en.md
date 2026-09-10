---
title: "Device Integration"
linkTitle: "Device Integration"
weight: 10
description: "Connect a Fake or physical Robot from Robot SDK and Ability through Pilot and Server."
---

This section is for Robot integration developers. The goal of device integration is not only to connect a controller. It is to give a Robot a complete runnable chain that can be discovered, executed, stopped, and observed.

## Integration boundary

```text
Robot SDK Backend
→ Ability Handler
→ AbilityFramework
→ semantic-pilot
→ Server Robot Gateway
→ Studio Robot Execution
```

## Recommended order

1. Verify SDK commands, state, and `stop/hold` on a Fake Backend;
2. Write Ability Manifest, Task Model, Handler, and Provider for atomic actions;
3. Upload and activate with AbilityFramework, and confirm the Ability through heartbeat;
4. Run a Robot Skill directly with `semantic-pilot`;
5. Write a RobotDeployment and type Bundle;
6. Let the Robot join the Server with a one-time join code;
7. Verify the full chain in Framework Robot Execution and Studio.

## Reading path

- Connect the device abstraction: [Robot SDK](../../core-modules/robot/robot-sdk.en.md);
- Add an atomic action: [Ability](../../core-modules/robot/ability.en.md);
- Orchestrate a staged task: [Robot Skill](../../core-modules/robot/robot-skill.en.md);
- Device assembly and join: [Device deployment and join](deployment.en.md);
- Cross-component interfaces: [Component interfaces and events](../../reference/api/protocols.en.md).

## Acceptance criteria

Device integration must at least prove:

- the Server can identify a unique Robot and Pilot;
- the required Abilities are running and heartbeat is healthy;
- every `required_action` of a Robot Skill matches exactly as `type@schema_version`;
- Feedback and Observation arrive during a run;
- a stop request can put the device into hold and leave traceable evidence;
- device disconnect and recovery do not falsely report execution success.
