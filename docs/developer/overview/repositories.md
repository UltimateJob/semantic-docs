---
title: "仓库与制品"
linkTitle: "仓库与制品"
weight: 30
description: "Semantic 多仓工作区的职责、技术栈、制品和版本边界。"
---

Semantic 是多仓聚根结构，没有顶层 monorepo 构建器。每个仓库独立构建、测试和发布，跨仓通过制品和公开协议协作。

## 仓库地图

| 仓库 | 主要职责 | 主要制品 |
|---|---|---|
| `semantic-framework` | Server、Agent Runtime、Workflow、CLI、Pilot | Server / Pilot / CLI 二进制 |
| `semantic-web` | Semantic Studio | Vite 静态站点 |
| `semantic-skill` | Robot Skill Runtime SDK 和 Skill | SDK Wheel、Skill Zip |
| `semantic-ability` | AbilityFramework 和 Ability | 业务 Wheel、Ability Zip |
| `semantic-robotsdk` | Robot SDK core 和型号包 | Python Wheel |
| `semantic-robot-deployment` | Robot Bundle 和实例启动 | Robot Bundle、实例程序 |
| `semantic-simulation` | MuJoCo Runtime 和 Runtime Pack | Runtime Wheel、Runtime Pack |
| `semantic-scene` | Scene、Robot、Layout 和 Mesh 资产 | 版本化资产包 |
| `quick-start` | 多仓安装和运行编排 | 安装器脚本 |

## 制品关系

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
→ Pilot Skill 安装
```

具体 Skill、Ability、SDK、Runtime Pack 和 Bundle 各自独立版本。Robot Skill 使用精确 `name@version`，Action 使用 `type@schema_version`，兼容组合由发布清单和产品 Gate 证明。

## 工作区变量

```bash
export SEMANTIC=~/semantic
export SEMANTIC_SDK_REPO=$SEMANTIC/semantic-robotsdk/robot-sdk
export SEMANTIC_ABILITY_REPO=$SEMANTIC/semantic-ability
export SEMANTIC_SKILLS_REPO=$SEMANTIC/semantic-skill/robot-skill
export SEMANTIC_DEPLOYMENT_REPO=$SEMANTIC/semantic-robot-deployment
export SEMANTIC_WEB_REPO=$SEMANTIC/semantic-web
```

完整构建和测试命令见[构建与测试](/developer/reference/build/)。
