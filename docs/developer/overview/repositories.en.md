---
title: "Repositories and Artifacts"
linkTitle: "Repositories"
weight: 30
description: "Responsibilities, stacks, artifacts, and version boundaries in the Semantic multi-repo workspace."
---

Semantic is a multi-repository workspace without a top-level monorepo builder. Each repository builds, tests, and publishes independently. Repositories collaborate through artifacts and public protocols.

## Repository map

| Repository | Main responsibility | Main artifacts |
|---|---|---|
| `semantic-framework` | Server, Agent Runtime, Workflow, CLI, Pilot | Server / Pilot / CLI binaries |
| `semantic-web` | Semantic Studio | Vite static site |
| `semantic-skill` | Robot Skill Runtime SDK and Skills | SDK Wheel, Skill Zip |
| `semantic-ability` | AbilityFramework and Abilities | Business Wheels, Ability Zip |
| `semantic-robotsdk` | Robot SDK core and type packages | Python Wheels |
| `semantic-robot-deployment` | Robot Bundle and instance startup | Robot Bundle, instance programs |
| `semantic-simulation` | MuJoCo Runtime and Runtime Pack | Runtime Wheel, Runtime Pack |
| `semantic-scene` | Scene, Robot, Layout, and mesh assets | Versioned asset packages |
| `quick-start` | Multi-repo install and run orchestration | Installer scripts |

## Artifact relationships

```text
Robot SDK Wheel
+ Ability Wheel / Zip
+ Robot Skill SDK Wheel
+ Pilot
→ Robot Bundle

Runtime Pack
+ Scene Package
→ Runtime Installation

Server Registry
+ Skill Zip
→ Pilot Skill install
```

Skills, Abilities, SDKs, Runtime Packs, and Bundles each have independent versions. Robot Skills use exact `name@version`, Actions use `type@schema_version`, and compatible combinations are proven by the release manifest and product Gate.

## Workspace variables

```bash
export SEMANTIC=~/semantic
export SEMANTIC_SDK_REPO=$SEMANTIC/semantic-robotsdk/robot-sdk
export SEMANTIC_ABILITY_REPO=$SEMANTIC/semantic-ability
export SEMANTIC_SKILLS_REPO=$SEMANTIC/semantic-skill/robot-skill
export SEMANTIC_DEPLOYMENT_REPO=$SEMANTIC/semantic-robot-deployment
export SEMANTIC_WEB_REPO=$SEMANTIC/semantic-web
```

For complete build and test commands, see [Build and test](../reference/build/_index.en.md).
