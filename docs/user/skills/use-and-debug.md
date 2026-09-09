---
title: "Skill 的使用与调试"
weight: 10
---

Semantic 中的 Skill 分为 Agent Skill 和 Robot Skill。它们分别帮助 Agent 理解工作方式，以及帮助 Robot 执行可复用的具身任务。

## Agent Skill

Agent Skill 向 Agent 提供领域说明、步骤建议、工具用法和相关资料。Project 可以选择所需 Agent Skill，并按 Agent 角色决定可见范围。

在 Skill 库中可以：

- 阅读 `SKILL.md`；
- 查看关联资料和资源；
- 查看适用 Agent；
- 将 Skill 关联到 Project；
- 在 Conversation 中观察 Agent 如何应用它。

## Robot Skill

Robot Skill 描述由 Stage 组成的机器人任务，例如抓取、导航和放置。详情页展示：

- 名称和版本；
- `SKILL.md`；
- 输入和结果模型；
- 所需 Action 与停止 Action；
- 兼容 Robot 型号；
- 各 Robot 的期望版本和实际安装状态；
- 脚本、资料和资源。

RobotDeployment 声明期望启用的 Robot Skill。Server 与 Pilot 自动完成安装、升级和启用状态同步。

## 调试建议

调试 Robot Skill 时按层定位：

1. 确认 Robot、Pilot 和 Ability 状态。
2. 使用由输入模型生成的表单填写最小业务参数。
3. 观察 Skill Stage 是否按预期推进。
4. 在 Inspector 中查看 Action、Feedback 和 Observation。
5. 结合 Viewer 判断实际运动和接触。
6. 使用安全停止结束异常物理动作。

Robot Skill 输入传递业务目标和约束。精确运动、接触判断与实时状态由 Skill、Ability 和 Robot SDK 在执行过程中共同处理。
