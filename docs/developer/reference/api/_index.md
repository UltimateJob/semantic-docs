---
title: "接口与配置"
linkTitle: "接口与配置"
weight: 20
description: "Semantic 的跨组件协议、认证、事件、配置契约和版本边界。"
---

本节是协议和配置的入口。当前文档按实现边界提供稳定的协议概览；涉及具体字段时，应同时以对应仓库的类型、Manifest、路由或 Schema 为准。

- [组件接口与事件](/developer/integration/component-interfaces-and-events/)：HTTP、WebSocket、Worker JSON-RPC、Action 和 Robot SDK 的边界；
- [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/)：`role.yaml`、Tool/Skill 授权和 Team；
- [Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/)：Scene、Runtime Profile 和虚拟 Robot；
- [Ability](/developer/core-modules/robot/ability/)：Manifest、Task Model、Action 类型和 Schema 版本；
- [Studio 前端架构](/developer/reference/internals/semantic-studio/)：REST、WebSocket、Store 和事件续传。

## 协议参考的共同要求

每个跨组件协议都必须说明：

1. 身份和认证；
2. 请求或消息模型；
3. 响应、事件和状态机；
4. 错误语义、幂等和重试；
5. 版本兼容关系；
6. 源定义位置和验证方式。

## 当前认证入口

Server 登录端点为 `POST /api/v1/auth/login`，返回存储在 SQLite 中的 opaque token；默认 TTL 为 24 小时。过期后使用 `POST /api/v1/auth/refresh` 换新 token。Pilot 使用与设备绑定的专用 credential，不复用浏览器用户 token。

## 当前版本边界

- Robot Skill 使用精确 `name@version`；
- Ability Action 使用 `type@schema_version`；
- Robot SDK Wheel、Ability Zip、Skill Zip、Runtime Pack 和 Robot Bundle 分别有自己的版本；
- 兼容组合由发布清单和产品 Gate 证明，不能依赖隐式升级。

如果需要修改协议，必须同步更新类型、实现、测试、示例配置、兼容说明和开发者文档。
