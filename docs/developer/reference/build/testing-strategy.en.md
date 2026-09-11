---
title: "Testing Strategy"
linkTitle: "Testing Strategy"
weight: 20
description: "Semantic's layered testing strategy: unit, interface, integration, and product-chain verification."
aliases:
  - /developer/reference/testing-strategy/
---

Semantic tests are organized along component boundaries and embodied-execution risk. Fast tests give development feedback. Real Runtime and product tests guarantee actual behavior.

## Test layers

| Layer | Goal | Examples |
|---|---|---|
| Unit tests | Verify models, algorithms, and state changes | Task dependencies, trajectory generation, Store updates |
| Component tests | Verify one service or package | Agent Runtime, Ability Handler, Web Store |
| Interface tests | Verify adjacent-component data and errors | Pilot messages, Action Schema, Robot SDK types |
| Integration tests | Verify a multi-component run chain | Pilot + Ability + Skill, Server + Web |
| Physical tests | Verify actual simulation or device behavior | Grasp, navigation, contact, stop/hold |
| Product tests | Verify a full user flow | Conversation → Plan → Workflow → Robot |

## Deterministic vs real models

A deterministic Agent is used to stably cover Proposal, Task, Interaction, scheduling, and execution convergence. Real-model tests only verify language understanding, Tool use, and multi-Agent collaboration. They must not replace physical-chain tests.

## Robot test focus

Cover input models and Stages, Action/Feedback/Observation, motion/contact/sensing state, failure and Recovery, stop/hold, disconnect/reconnect, and the final state of tools and objects. Simulation tests observe real object displacement and collision. Physical-device tests may run only in an approved safe environment.

## State consistency

Workflow, Task, SubTask, Robot Execution, Pilot, and Web should reflect the same run fact. At least cover complete, failed, pause, stop, refresh, disconnect, and Server restart.

## Minimum verification for external contributors

When real assets, devices, or models are unavailable, at least run static checks, unit tests, contract tests, and Fake integration tests for the changed repository. In the MR, state which real Gates were not run and why. Maintainers must not mark a skip caused by missing dependencies as a real verification pass.

## Reference entries

Commands for each repository are in [Build, run, and test](build-run-and-test.en.md). Cross-component verification is in [End-to-End Integration](../../integration/end-to-end/_index.en.md).
