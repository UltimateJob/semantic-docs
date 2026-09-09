---
title: "开发工具链"
linkTitle: "开发工具链"
weight: 60
description: "使用 quick-start、构建测试、Runtime Pack、Robot Bundle 和产品 Gate 完成开发交付。"
---

开发工具链不是运行时执行链，而是帮助开发者准备、验证和交付 Semantic 的工具集合。

## 工具组成

| 工具 | 作用 | 入口 |
|---|---|---|
| `quick-start` | 多仓安装、配置和启动编排 | `quick-start/semantic_installer.py` |
| Build / Test | 各仓静态检查、单元、合同和集成测试 | [构建与测试](/developer/reference/build/) |
| Runtime Pack | 固定 Runtime 和离线依赖的发布包 | [仿真集成](/developer/integration/simulation/) |
| Robot Bundle | Pilot、Ability、SDK 和 Skill SDK 的装配包 | [设备部署与加入](/developer/integration/device/deployment/) |
| Product Gate | Fake、MuJoCo 和真实模型的完整产品验证 | [端到端集成](/developer/integration/end-to-end/) |

## 开发闭环

```text
准备工作区
→ 启动 Server / Studio / Runtime
→ 单模块测试
→ 相邻接口测试
→ Fake 集成
→ 真实 Runtime 或真机
→ Product Gate
→ 制品发布
```

## 选择验证范围

- Agent 或配置修改：静态检查、Framework 集成测试和确定性模型；
- Robot Skill / Ability / SDK 修改：Action、Feedback、stop/hold 和 Fake 测试；
- Scene / Runtime 修改：合同测试、真实资产和物理状态测试；
- Studio 修改：Vitest、Playwright 和 Server 联调；
- 跨仓产品修改：执行对应 Product Gate。

完整命令和各仓 CI 能力见[构建、运行与测试](/developer/reference/build/build-run-and-test/)和[CI 与发布流程](/developer/reference/contributing/ci-and-release/)。
