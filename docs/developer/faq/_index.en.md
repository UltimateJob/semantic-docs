---
title: "FAQ"
linkTitle: "FAQ"
weight: 90
description: "Common questions in Semantic development, integration, testing, and operation."
aliases:
  - /developer/reference/faq/
---

The FAQ is organized by the symptoms developers see, not by code directories. When answering a question, confirm in order: symptom, root cause, handling, verification, and the related entry.

## Install and start

- [Build, run, and test](../reference/build/build-run-and-test.en.md);
- [Quick Start](../quickstart/_index.en.md);
- [Build and test](../reference/build/_index.en.md).

## Agent, Tool, and Workflow

- Agent cannot see a Skill: check Store loading and the role `skills.allowlist`;
- A Tool is rejected: check namespace authorization and `approval_required`;
- Workflow does not advance: check dependencies, resources, Agent/Robot availability, and Task state.

## Robot, Runtime, and Studio

- Robot does not execute: check Pilot, Skill version, Ability heartbeat, and Action Schema;
- Scene will not start: check Runtime Installation, asset paths, and instance `failure_reason`;
- Studio does not update: check snapshot, WebSocket sequence, and Store;
- Stop is incomplete: confirm device hold first, then handle state convergence.

## Deeper investigation

Older detailed content for common issues has been moved into this module. New issues should be classified on this page and linked to the single protocol or implementation source.
