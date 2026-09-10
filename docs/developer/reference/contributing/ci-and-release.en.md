---
title: "CI and Release Process"
weight: 20
description: "Cross-repository tests, version inventories, and public-release checks."
---

Semantic is made of multiple independent repositories. The following are cross-repository collaboration and release principles. Concrete automation depends on each repository's actual configuration and does not mean every repository already has equivalent public CI.

## Contribution flow

1. Create a feature or fix branch from the development baseline named by the target repository.
2. Describe the symptom, goal, and acceptance method in an Issue.
3. Run the test and build commands in that repository's README locally.
4. Open a Pull Request that explains impact, compatibility, and verification results; merge after review.
5. For cross-repository changes, link the Issue / PR in each repository and update the consistent version inventory in quick-start.

Do not assume every repository uses the same default branch name, and do not merge different release baselines without verification.

## Test layers

| Layer | Purpose | Input |
|---|---|---|
| Single-repo checks | Format, static checks, unit tests, and build | Current repository and locked dependencies |
| Cross-repo gate | Contracts, Bundles, and frontend/backend integration | A component workspace at matching revisions |
| Simulation verification | Native dependencies, Scene loading, and Robot execution | Legal assets, Runtime, and a complete Bundle |
| Release acceptance | Install, init, start, stop, and uninstall | A clean target system and candidate artifacts |

Model-service gates may call paid external APIs, and physical-robot tests may produce motion. Both must be configured explicitly and run in a controlled environment. Skipping a test is not proof that it passed.

## Build and versions

Use the quick-start directory layout and inventory as the cross-repository baseline. Build dependencies, Runtime Packs, Robot Bundles, and Skill packages each have their own versions. Do not infer every artifact version from one repository tag.

Public CI needs publicly obtainable toolchains and dependencies. Mirrors and proxies are deployment configuration. They must not depend on a developer's personal environment or a private build service.

## Pre-release checks

- Review the worktree and Git history for secrets, internal addresses, personal paths, and screenshots.
- Switch clone URLs, dependency sources, and CI configuration to publicly reachable sources.
- Keep third-party copyright notices and confirm distribution licenses for models and binary assets item by item.
- Record revision, artifact hashes, compatible platforms, migration notes, and actual verification results.
- After release, verify the install entry and version inventory. Do not overwrite immutable versioned artifacts.

Commands are in [Build, run, and test](../build/build-run-and-test.en.md). Contribution requirements are in the [Contributing Guide](_index.en.md).
