---
title: "Build, Run, and Test"
linkTitle: "Build, run, and test"
weight: 10
description: "Build, run, and test command matrix for each repository, and how to choose a verification scope."
aliases:
  - /developer/reference/build-run-and-test/
---

Semantic is a multi-repo workspace with no top-level monorepo build tool. The only explicit internal workspace is the Robot SDK uv workspace. The following commands are for local development and pre-submit verification.

## Build command matrix

| Repository | Build | Test | Static check |
|---|---|---|---|
| `semantic-framework` | `make build` | `make test` | `make lint` |
| `semantic-web` | `npm run build` | `npm run test`; `npm run test:e2e` is local E2E | `npm run lint` |
| `semantic-skill/robot-skill` | `python -m build --wheel` | `make test` (pytest) | `make check` |
| `semantic-ability/r1pro-ability` | `make build` (shared Wheel) | `make test` (unittest) | `make check` |
| `semantic-robotsdk/robot-sdk` | `uv build --all-packages` | `make test`; `make test-contracts` | `make lint` |
| `semantic-robot-deployment` | `make verify` | `make verify` | `make verify` |
| `semantic-simulation/mujoco-runtime` | `make build` | `make test`; real-environment specialized tests are run separately | `make lint` |
| `semantic-docs` | `npm run docs:build` | Hugo build and link scan | — |

Ability uses `unittest`. Do not write every Python repository as pytest. Real Runtime, asset, and model tests also cannot use an environment-missing skip as a pass.

## Common commands

### Framework

```bash
cd semantic-framework
make lint
make test
make build
make doctor
make run
make logs
```

Product Gates live in `tests/gate/`. Real MuJoCo and real-model commands follow the current Framework Makefile.

### Studio

```bash
cd semantic-web
npm ci
npm run lint
npm run test
npm run test:e2e       # 本地执行，CI 不执行 Playwright
npm run build
```

### Robot Skill

```bash
cd semantic-skill/robot-skill
make check
make test
python -m build --wheel
```

### Ability

```bash
cd semantic-ability/r1pro-ability
make check
make test
make build
```

`make build` builds the shared business Wheel. Concrete Ability Zips must be produced separately with the packaging flow in the repository README.

### Robot SDK

```bash
cd semantic-robotsdk/robot-sdk
make lint
make test
make test-contracts
make build
```

### Robot Deployment

```bash
cd semantic-robot-deployment
make verify
```

### MuJoCo Runtime

```bash
cd semantic-simulation/mujoco-runtime
make install
make lint
make test
make build
# 真实资产和 Profile 测试按 Makefile 的专项目标执行
```

### Docs site

```bash
cd semantic-docs
npm ci
npm run docs:dev
npm run docs:build
```

## Choose a verification scope

1. Run static checks and unit tests for the module you changed;
2. Run interface or contract tests of adjacent components;
3. Complete a fast integration with Fake or a deterministic environment;
4. When physical behavior is involved, run a real Runtime or real-robot test;
5. When Agent decisions are involved, run a real-model product test last.

Model tests cannot replace Robot motion, contact, and safe-stop verification.
