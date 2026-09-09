---
title: "Conversation、Agent 与 Interaction"
weight: 10
---

Conversation 是用户与多个 Agent 协作的主要界面。Leader 负责理解整体目标和组织工作，承担 Task 的 Agent 负责具体结果，Robot Agent 负责结合实际 Robot 推进机器人任务。

## 通过自然语言描述目标

消息可以包含：

- 业务目标和完成条件；
- 目标对象、区域或 Robot；
- 时间、资源和安全约束；
- 从 Viewer 或 Semantic Map 中选择的实体；
- 图片、文件和其他 Artifact。

目标明确时，Agent 可以直接开始查询环境、提出计划或推进当前工作。用户无需描述 Stage、Action、关节轨迹等底层执行细节。

## 多 Agent 消息

主 Conversation 展示对协作有意义的输出：

- Leader 的目标理解、计划说明和最终汇总；
- Robot、Map、Monitor、Developer 等 Agent 的任务规划摘要；
- Agent 提出的 Interaction；
- Recovery 分析和调整结果；
- Task 结果与相关 Artifact。

Task 分配、Run 启动、Robot Execution 接受和状态变化以系统活动展示。工具调用、原始模型结构和 Stage 流水位于 Trace、Execution 和调试面板。

## 结构化 Interaction

Agent 需要用户提供选择、参数或授权时，会在 Conversation 中插入 Interaction。常见形式包括：

- 确认；
- 表单；
- 单选和多选；
- 参数输入；
- 图片、地图实体和文件选择。

回答提交后，原 Agent 在原任务上下文中继续工作。Interaction 卡支持：

- **提交**：保存回答并继续原工作；
- **稍后处理**：折叠卡片，问题保持待处理；
- **跳过**：适用于没有必填项的问题；
- **取消询问**：通知原 Agent 用户取消本次问题，由 Agent 决定下一步。

停止 Workflow 是独立的运行控制操作，入口位于 Workflow 卡片和运行面板。

## 有效地提出任务

一个清晰请求通常包含三部分：

```text
要完成什么
使用哪个环境或对象
怎样判断完成
```

例如：

```text
把来源托盘顶层可搬运的四个周转箱放到目标托盘的空列中。
使用当前场景内可用的 Robot；保持箱体朝向。
完成后确认四个箱体稳定、工具为空，并汇总每个目标列的占用情况。
```

Agent 会按需查询 Semantic Map 和实时资源。存在多个合理业务选择时，Interaction 帮助用户确定结果。
