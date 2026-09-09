---
title: "构建、运行与测试"
linkTitle: "构建、运行与测试"
weight: 10
description: "各仓库的构建、运行与测试命令矩阵，以及验证范围的选择。"
aliases:
  - /developer/reference/build-run-and-test/
---

Semantic 是多仓工作区，没有顶层 monorepo 构建工具；唯一明确的内部 workspace 是 Robot SDK 的 uv workspace。以下命令用于本地开发和提交前验证。

## 构建命令矩阵

| 仓库 | 构建 | 测试 | 静态检查 |
|---|---|---|---|
| `semantic-framework` | `make build` | `make test` | `make lint` |
| `semantic-web` | `npm run build` | `npm run test`；`npm run test:e2e` 为本地 E2E | `npm run lint` |
| `semantic-skill/robot-skill` | `python -m build --wheel` | `make test`（pytest） | `make check` |
| `semantic-ability/r1pro-ability` | `make build`（共享 Wheel） | `make test`（unittest） | `make check` |
| `semantic-robotsdk/robot-sdk` | `uv build --all-packages` | `make test`；`make test-contracts` | `make lint` |
| `semantic-robot-deployment` | `make verify` | `make verify` | `make verify` |
| `semantic-simulation/mujoco-runtime` | `make build` | `make test`；真实环境专项测试另行执行 | `make lint` |
| `semantic-docs` | `npm run docs:build` | Hugo 构建和链接扫描 | — |

Ability 使用 `unittest`，不能把所有 Python 仓库笼统写成 pytest。真实 Runtime、资产和模型测试也不能用缺环境时的 skip 代替通过。

## 常用命令

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

产品 Gate 位于 `tests/gate/`，真实 MuJoCo 和真实模型命令以当前 Framework Makefile 为准。

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

`make build` 构建共享业务 Wheel；具体 Ability Zip 需要按仓库 README 的打包流程单独生成。

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

### 文档站

```bash
cd semantic-docs
npm ci
npm run docs:dev
npm run docs:build
```

## 选择验证范围

1. 运行修改模块的静态检查和单元测试；
2. 运行相邻组件的接口或合同测试；
3. 使用 Fake 或确定性环境完成快速集成；
4. 涉及物理行为时运行真实 Runtime 或真机测试；
5. 涉及 Agent 决策时最后再运行真实模型产品测试。

模型测试不能替代 Robot 的运动、接触和安全停止验证。
