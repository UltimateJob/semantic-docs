---
title: "Releases & Migration"
linkTitle: "Releases"
weight: 80
description: "Product and component release notes, compatibility, and migration guidance."
---

Semantic is a multi-repository system. Product, Framework, Web, Robot SDK, Ability, Robot Skill, Runtime Pack, and Robot Bundle versions can evolve independently.

When reading a release:

1. Confirm the product version and target component versions.
2. Read new capabilities and breaking changes.
3. Check configuration, Action Schema, and artifact upgrade order.
4. Validate in Fake or simulation environments first.
5. Only then move to real model or real robot chains.

## Release notes

- [v0.5.0 (in development)](v0.5.0.en.md): managed MuJoCo Robot lifecycle, Robot Skill manual debug, depalletizing product chain, and v050 Gate toolchain.
- [v0.4.0](v0.4.0.en.md): MuJoCo simulation workbench, Runtime Pack, and Scene assets.
- [v0.3.0](v0.3.0.en.md): explicit Plan Mode, Workflow/Task/SubTask planning, and built-in Semantic Map.
- [v0.2.0](v0.2.0.en.md): first public baseline.

> v0.3.0 and earlier have Framework/Web tags. v0.4.0 and v0.5.0 boundaries are reconstructed from git history and version-metadata commits; confirm with the owner before publication.

## Compatibility matrix

The matrix is inferred from repository git history, version-metadata commits, and `type-packages/*/bundle.yaml`. v0.2.0/v0.3.0 have tags. v0.4.0/v0.5.0 combinations are inferred; uncertain cells are marked TODO(confirm).

| Product | Framework | Web | Robot SDK (core / r1pro) | AbilityFramework | Ability (r1pro-abilities) | Robot Skill SDK | Robot Skill (r1pro-mujoco) | Runtime Pack (plugin-mujoco) | Robot Bundle |
|---|---|---|---|---|---|---|---|---|---|
| v0.2.0 (2026-08-08) | 0.2.0 | 0.2.0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| v0.3.0 (2026-08-09) | 0.3.0 | 0.3.0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| v0.4.0 (2026-08-12, TODO(confirm): no tag) | 0.4.0-dev | 0.4.0-dev | baseline in progress | n/a | in progress | in progress | in progress | v0.4 refactor | n/a |
| v0.5.0-dev (from 2026-08-15, unreleased) | 0.5.0-dev | 0.5.0-dev | 0.5.0.dev0 / 0.5.0.dev0 | 0.4.0 | 0.4.0.dev0 | 0.1.0.dev0 | grasp-object, semantic-navigation, place-object | 0.4.0.dev0 | r1pro-mujoco 0.5.0-dev, r1pro-fake 0.5.0-dev |

See the [Chinese releases index](_index.en.md) for the full evidence notes behind this matrix.
