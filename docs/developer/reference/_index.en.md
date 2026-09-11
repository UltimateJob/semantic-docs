---
title: "Reference"
linkTitle: "Reference"
weight: 90
description: "Factual reference for build, test, interfaces, configuration, internals, contributing, and release."
---

The reference section is where developers look up facts. It does not tell an onboarding story. Choose an entry by the work you need to do:

| Purpose | Entry | Content |
|---|---|---|
| Build, run, or test one repository | [Build and test](build/_index.en.md) | Command matrix, test layers, and verification scope |
| Look up protocol, auth, or configuration boundaries | [APIs and configuration](api/_index.en.md) | HTTP, WebSocket, JSON-RPC, Action, and configuration contracts |
| Understand why an implementation works this way | [Internals](internals/_index.en.md) | Server, Agent, Workflow, Pilot, Robot, and Studio |
| Submit an MR or publish a release | [Contributing and release](contributing/_index.en.md) | Contribution process, CI, versions, artifacts, and release |
| Hit a problem | [FAQ](../faq/_index.en.md) | Common failures and localization entries |

## Content boundaries

- Tutorial content belongs only in the [Quick Start](../quickstart/_index.en.md);
- Extension contracts belong only in [Core Modules](../core-modules/_index.en.md);
- Cross-component verification belongs only in [Component Integration](../integration/_index.en.md);
- Pages in this section should cite factual sources in the code and avoid maintaining a second complete Schema that drifts from the implementation.
