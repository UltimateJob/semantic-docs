---
title: "参考"
linkTitle: "参考"
weight: 90
description: "构建、测试、接口、配置、内部实现、贡献与发布的事实参考。"
---

参考区是开发者查阅事实的地方，不承担入门叙事。按照工作目的选择入口：

| 目的 | 入口 | 内容 |
|---|---|---|
| 构建、运行或测试一个仓库 | [构建与测试](build/_index.md) | 命令矩阵、测试层级和验证范围 |
| 查协议、认证或配置边界 | [接口与配置](api/_index.md) | HTTP、WebSocket、JSON-RPC、Action 和配置契约 |
| 理解实现为什么这样工作 | [内部实现](internals/_index.md) | Server、Agent、Workflow、Pilot、Robot 和 Studio |
| 提交 MR 或发布版本 | [贡献与发布](contributing/_index.md) | 贡献流程、CI、版本、制品和发布 |
| 遇到问题 | [FAQ](../faq/_index.md) | 常见故障和定位入口 |

## 内容边界

- 教程内容只放在[快速开始](../quickstart/_index.md)；
- 扩展契约只放在[核心模块](../core-modules/_index.md)；
- 跨组件验证只放在[集成指南](../integration/_index.md)；
- 本节页面尽量引用代码中的事实来源，避免维护与实现脱节的第二份完整 Schema。
