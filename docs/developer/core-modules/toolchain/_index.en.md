---
title: "Developer Toolchain"
linkTitle: "Developer Toolchain"
weight: 60
description: "Use quick-start, build and test, Runtime Pack, Robot Bundle, and product Gate to finish development delivery."
---

The developer toolchain is not the runtime execution chain. It is the set of tools that help developers prepare, verify, and deliver Semantic.

## Tool composition

| Tool | Role | Entry |
|---|---|---|
| `quick-start` | Multi-repo install, configuration, and startup orchestration | `quick-start/semantic_installer.py` |
| Build / Test | Static checks, unit, contract, and integration tests per repository | [Build and test](../../reference/build/_index.en.md) |
| Runtime Pack | Release package that pins a Runtime and offline dependencies | [Simulation Integration](../../integration/simulation/_index.en.md) |
| Robot Bundle | Assembly package of Pilot, Ability, SDK, and Skill SDK | [Device deployment and join](../../integration/device/deployment.en.md) |
| Product Gate | Full product verification with Fake, MuJoCo, and a real model | [End-to-End Integration](../../integration/end-to-end/_index.en.md) |

## Development loop

```text
Prepare the workspace
→ Start Server / Studio / Runtime
→ Single-module tests
→ Adjacent-interface tests
→ Fake integration
→ Real Runtime or physical device
→ Product Gate
→ Artifact release
```

## Choose the verification scope

- Agent or configuration changes: static checks, Framework integration tests, and a deterministic model;
- Robot Skill / Ability / SDK changes: Action, Feedback, stop/hold, and Fake tests;
- Scene / Runtime changes: contract tests, real assets, and physical-state tests;
- Studio changes: Vitest, Playwright, and Server integration;
- Cross-repository product changes: run the matching Product Gate.

For complete commands and each repository's CI capabilities, see [Build, run, and test](../../reference/build/build-run-and-test.en.md) and [CI and release](../../reference/contributing/ci-and-release.en.md).
