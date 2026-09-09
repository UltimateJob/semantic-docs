---
title: "端到端集成"
linkTitle: "端到端集成"
weight: 30
description: "从 Runtime 或设备开始，逐级验证到 Agent、Workflow 和 Studio 的完整产品链。"
aliases:
  - /developer/integration/end-to-end-integration/
---

端到端集成沿依赖方向逐级证明每个边界。每一步只引入一个新环节，失败范围限定在当前环节或其直接接口。

## 完整链路

```text
Runtime 或真机 → Robot SDK → Ability → Robot Skill → Pilot
→ Robot Execution → Framework Task → Agent / Conversation → Studio
```

## 八步联调法

| 步骤 | 验证对象 | 通过标准 |
|---|---|---|
| 1 | Runtime 或真实设备 | health 正常，实例 running，Robot 状态有效 |
| 2 | Robot SDK | 动作、状态、stop/hold 均成功 |
| 3 | AbilityFramework | Ability heartbeat running，Action 返回结构正确 |
| 4 | Pilot 直跑 Skill | Stage 事件完整，结果文件生成 |
| 5 | Framework Robot Execution | Task / SubTask 收敛，Execution 状态正确 |
| 6 | Studio | 实时事件、Observation、Artifact 可见 |
| 7 | mock Agent | Plan → Workflow 可重复执行 |
| 8 | 真实模型 | Conversation、审批、规划和最终总结符合预期 |

前 6 步不需要 LLM；第 7 步用 mock 模型隔离决策不确定性；最后才引入真实模型和真机。

## 验收记录

至少记录用户输入、获批计划、Workflow、Task、SubTask、Robot Execution、关键 Stage 的 Action/Feedback/Observation、最终 Artifact，以及所有组件的精确版本。

## 失败定位

- Agent 看不到 Skill：检查 Store 加载和角色 `skills.allowlist`；
- Robot 不执行：检查 Pilot 在线、Skill 精确版本和 required Action；
- Action 失败：检查 Ability heartbeat、Manifest 输入模型和 schema 版本；
- 机器人不动：检查 SDK Backend 和 Runtime `/healthz`；
- Studio 不更新：检查 Server WebSocket 和事件 sequence；
- 停止未完成：先确认设备 hold，再处理连接恢复和状态收敛。

## 相关文档

- [设备集成](/developer/integration/device/)；
- [仿真集成](/developer/integration/simulation/)；
- [组件接口与事件](/developer/integration/component-interfaces-and-events/)；
- [Cookbook](/developer/cookbook/)。
