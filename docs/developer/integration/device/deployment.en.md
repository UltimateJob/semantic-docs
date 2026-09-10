---
title: "Device Deployment and Join"
linkTitle: "Deployment and Join"
weight: 20
description: "Build a Robot Bundle, start an instance, and connect it to Semantic Server with a one-time join code."
---

This page is for deployment developers and device maintainers. A Robot Bundle is the assembled result of verified components. Concrete Robot Skills are still published and installed independently through the Server Registry.

## Startup order

```text
AbilityFramework
→ seven Ability classes
→ heartbeat confirmation
→ semantic-pilot
→ reconcile desired Robot Skills
```

## First join

Create a one-time join code on the Studio device page, then run this on the Robot host:

```bash
semantic-robot-instance start \
  --config <robot-deployment.yaml> \
  --join-code <one-time join code>
```

The join code is only used the first time to claim a credential bound to the Pilot ID. The credential is written to `connection.yaml` in the instance directory. Later starts do not need the join code.

## Bundle contents

A Bundle assembles tested Pilot, AbilityFramework, Robot SDK Wheel, Ability Zip, Robot Skill Runtime SDK Wheel, and pinned dependencies. Each Robot uses its own instance directory. Robots must not share Robot ID, Pilot ID, Execution Store, or ports.

## Stop semantics

On stop, first latch Pilot and block new Actions, then wait for Worker, Ability, and SDK to reach a safe stop point. Close the process only after hold is confirmed. If any step cannot be confirmed, keep `interrupted` or `failed`. Do not show `stopped` from process exit alone.

## Related docs

- Type packages and build commands: `semantic-robot-deployment/type-packages/`;
- SDK, Ability, and Skill development entries are in [Device Integration](_index.en.md);
- End-to-end verification is in [Component Integration](../_index.en.md).
