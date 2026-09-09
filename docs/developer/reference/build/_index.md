---
title: "构建与测试"
linkTitle: "构建与测试"
weight: 10
description: "各仓库的构建命令、测试层级和提交前验证范围。"
---

本节是开发者提交代码前的事实参考。Semantic 没有顶层 monorepo 构建器，各仓库独立构建；测试从单元、接口逐级进入真实 Runtime 和产品 Gate。

- [构建、运行与测试](/developer/reference/build/build-run-and-test/)：各仓库命令矩阵和本地开发入口；
- [测试策略](/developer/reference/build/testing-strategy/)：确定性测试、物理测试和产品测试的分层方法。

## 推荐阅读顺序

1. 先看命令矩阵，确定修改所在仓库的构建和基础测试；
2. 再看测试策略，确定是否需要接口、Fake、真实 Runtime 或产品 Gate；
3. 跨仓改动再进入[集成指南](/developer/integration/)；
4. 提交前查看[贡献与发布](/developer/reference/contributing/)。
