---
title: "协议总览"
linkTitle: "协议总览"
weight: 10
description: "Semantic 各组件之间的接口契约与事件流，供集成开发查阅。"
aliases:
  - /developer/integration/component-interfaces-and-events/
---

Semantic 的组件通过 HTTP、WebSocket、Worker 消息、Ability 调用和 Robot SDK 接口协作。接口定义包含类型、身份、版本和错误语义。按协议分为四类，本页给出各类的接口面与典型交互。

## Server HTTP API（同步控制）

Server 对外的 HTTP API 用于创建、查询和控制 Project 对象：

| 操作 | 语义 |
|---|---|
| 创建/更新 | 写操作带 `revision`，调用方需确认后重试冲突 |
| 停止 | 幂等——重复请求返回当前进度，不重复执行 |
| 查询 | 对象当前状态与列表 |

```bash
# 典型调用（认证经 Bearer token）：
curl -s http://127.0.0.1:8080/api/v1/skills -H "Authorization: Bearer $TOKEN"
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
```

仿真 Runtime 的 HTTP 契约与此同构：`/healthz`、场景目录、实例生命周期（启动 → `starting` → `running`）、快照与虚拟 Robot 描述。两者都是请求-响应类接口，适合同步控制。

## Server WebSocket（增量状态推送）

HTTP :8081 的 WebSocket 通道推送 Conversation、Workflow、Robot、Scene 和 Execution 的**增量状态**——不做全量快照轮询，状态变化即推送。前端 Studio 的 WS dispatcher 按事件类型分发到对应 store（如 `robot_execution` 事件进入 robot store 的 `applyEvent`）。

## Pilot WebSocket（设备侧上行与下行）

Pilot WebSocket 使用专用 credential 和绑定的 Pilot ID 连接 Server。连接建立后，Pilot 上报：

- Robot Profile 与状态；
- AbilityFramework 和 Ability 实例；
- Robot Skill installed/enabled 状态；
- 活动 Robot Execution；
- 事件序列位置。

Server 下发 Skill 安装、运行、Agent Reply 和停止请求。

## Worker JSON-RPC（进程内边界）

Pilot 与 Skill Worker 之间通过 stdin/stdout 交换 JSON-RPC（一行一个 JSON）：

```bash
# 可以直接手动驱动 Worker 调试（绕过 Pilot）：
python -m semantic_robot_skill_sdk.worker \
  --skill-dir semantic_robot_skills/skills/semantic_navigation
```

这个边界的意义：Worker 是隔离进程，崩溃不拖垮 Pilot，且可以用任意 JSON 工具直接对话调试。

## Ability 调用（Action 契约）

Robot Skill Action 包含 Action 类型和 Schema 版本。Pilot 使用 Robot ID、Action 类型、Schema 版本和具体 Ability 实例发起调用：

```text
Skill 声明：{ type: perception.locate_object, schema_version: 2 }
匹配键：  actionType + schemaVersion（Manifest 中声明）
```

AbilityFramework 管理实例生命周期（上传 → 激活 → 心跳确认 running），并传递 Feedback、结果和停止。版本按实际兼容关系管理：

- Robot Skill 请求精确已安装版本（`name@version`）；
- Action 与 Ability 使用 Schema 版本匹配；
- Robot SDK Wheel、Ability 包、Robot Skill 和 Bundle 各自发布版本；
- 发布清单记录经过验证的组合。

## Robot SDK（Python 类型化接口）

Ability 使用 Robot SDK 的类型化 Python API。Robot 包将调用转换为设备或 Runtime 命令，并将原始状态转换为共享模型。`RobotBackend` Protocol 是接入新设备/引擎的扩展点（fake / mujoco / 真机 backend 同构）。

## 接口修改的同步义务

接口修改同步更新类型、实现、测试、示例配置和开发者文档——缺一即破坏集成方。

## 相关参考

- 端点与事件明细：[HTTP API](/developer/reference/api/http/)、[WebSocket 事件](/developer/reference/api/ws/)；
- 把这些接口串成完整链路的联调路径：[端到端集成](/developer/integration/end-to-end/)；
- 可运行的参考实现：[Cookbook](/developer/cookbook/)。
