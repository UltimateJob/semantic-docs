---
title: "Build and Test"
linkTitle: "Build and Test"
weight: 10
description: "Build commands, test layers, and pre-submit verification scope for each repository."
---

This section is the factual reference developers use before submitting code. Semantic has no top-level monorepo builder. Each repository builds independently. Tests move from unit and interface checks up to a real Runtime and product Gate.

- [Build, run, and test](build-run-and-test.en.md): command matrix and local development entries for each repository;
- [Testing strategy](testing-strategy.en.md): layered approach for deterministic tests, physical tests, and product tests.

## Recommended reading order

1. Start with the command matrix and identify build and basic tests for the repository you changed;
2. Then read the testing strategy and decide whether you need interface, Fake, real Runtime, or product Gate coverage;
3. For cross-repository changes, continue to [Component Integration](../../integration/_index.en.md);
4. Before submit, read [Contributing and release](../contributing/_index.en.md).
