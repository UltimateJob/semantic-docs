---
title: "测试策略"
linkTitle: "测试策略"
weight: 20
description: "Semantic 的分层测试策略：单元、接口、集成与产品链验证。"
aliases:
  - /developer/reference/testing-strategy/
---

Semantic 的测试沿组件边界和具身执行风险组织。快速测试保证开发反馈，真实 Runtime 和产品测试保证实际行为。

## 测试层级

| 层级 | 目标 | 示例 |
|---|---|---|
| 单元测试 | 验证模型、算法和状态变化 | Task 依赖、轨迹生成、Store 更新 |
| 组件测试 | 验证一个服务或包 | Agent Runtime、Ability Handler、Web Store |
| 接口测试 | 验证相邻组件数据和错误 | Pilot 消息、Action Schema、Robot SDK 类型 |
| 集成测试 | 验证多组件运行链 | Pilot + Ability + Skill、Server + Web |
| 物理测试 | 验证仿真或真机实际行为 | 抓取、导航、接触、stop/hold |
| 产品测试 | 验证完整用户流程 | Conversation → Plan → Workflow → Robot |

## 确定性与真实模型

确定性 Agent 用于稳定覆盖 Proposal、Task、Interaction、调度和执行收敛。真实模型测试只验证语言理解、Tool 使用和多 Agent 协作，不应代替物理链测试。

## Robot 测试重点

输入模型和 Stage、Action/Feedback/Observation、运动/接触/传感状态、失败与 Recovery、stop/hold、断线重连以及工具和对象最终状态都必须覆盖。仿真测试观察对象真实位移和碰撞；真机测试只能在批准的安全环境执行。

## 状态一致性

Workflow、Task、SubTask、Robot Execution、Pilot 和 Web 应反映同一运行事实。至少覆盖完成、失败、暂停、停止、刷新、断线和 Server 重启。

## 外部贡献者最低验证

无法访问真实资产、设备或模型时，至少运行修改仓库的静态检查、单元测试、合同测试和 Fake 集成测试，并在 MR 中明确哪些真实 Gate 未执行及原因。维护者不得把缺少依赖的跳过结果标记为真实验证通过。

## 参考入口

各仓库命令见[构建、运行与测试](/developer/reference/build/build-run-and-test/)；跨组件验证见[端到端集成](/developer/integration/end-to-end/)。
