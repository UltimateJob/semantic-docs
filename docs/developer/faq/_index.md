---
title: "FAQ"
linkTitle: "FAQ"
weight: 90
description: "Semantic 开发、集成、测试和运行中的常见问题。"
aliases:
  - /developer/reference/faq/
---

FAQ 按开发者遇到的现象组织，不按代码目录组织。回答问题时依次确认：现象、根因、处理、验证和相关入口。

## 安装与启动

- [构建、运行与测试](/developer/reference/build/build-run-and-test/)；
- [快速开始](/developer/quickstart/)；
- [构建与测试](/developer/reference/build/)。

## Agent、Tool 与 Workflow

- Agent 看不到 Skill：检查 Store 加载和角色 `skills.allowlist`；
- Tool 被拒绝：检查 namespace 授权和 `approval_required`；
- Workflow 不推进：检查依赖、资源、Agent/Robot 可用性和 Task 状态。

## Robot、Runtime 与 Studio

- Robot 不执行：检查 Pilot、Skill 版本、Ability heartbeat 和 Action Schema；
- Scene 起不来：检查 Runtime Installation、资产路径和实例 `failure_reason`；
- Studio 不更新：检查 snapshot、WebSocket sequence 和 Store；
- 停止未完成：先确认设备 hold，再处理状态收敛。

## 深入排查

常见问题的旧版详细内容已迁移到本模块；新增问题应按本页分类，并链接到唯一的协议或实现来源。
