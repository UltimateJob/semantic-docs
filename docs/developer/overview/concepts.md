---
title: "核心对象与关系"
linkTitle: "核心对象"
weight: 10
description: "理解 Project、Agent、Workflow、Task、Robot Skill、Ability 和 Environment 的关系。"
---

Semantic 把一次具身任务拆成相互连接、职责明确的对象。开发者先理解对象关系，再选择要扩展的模块。

## 对象关系

```text
Project
└── Conversation
    └── Plan Proposal
        └── Workflow
            ├── Task
            │   └── SubTask
            │       └── Robot Execution
            │           └── Robot Skill
            │               └── Action
            │                   └── Ability
            │                       └── Robot SDK
            └── Agent Run
```

| 对象 | 作用 | 典型状态 |
|---|---|---|
| Project | 承载目标、资源、环境和运行历史 | active |
| Conversation | 用户与 Agent 协作的入口 | open / archived |
| Plan Proposal | Agent 提出的待审阅计划 | pending / approved / discarded |
| Workflow | 已批准、可持续推进的工作整体 | pending / running / paused / completed |
| Task | 一个 Agent 负责的业务结果 | pending / running / completed |
| SubTask | Task 内部的 Agent 或 Robot 步骤 | pending / running / completed |
| Robot Execution | 一次 Robot Skill 的真实执行 | running / failed / stopped |
| Environment | Robot 工作的场景、对象和状态 | starting / running |

## Agent 与 Robot 的边界

Agent 负责理解目标、调用 Tool、读取 Skill 和形成计划。Robot 不理解业务目标，只执行已经形成的 SubTask。Workflow 是两者之间的持久化边界。

## 选择扩展点

- 只增加领域知识：写 Agent Skill；
- 增加外部查询或操作：接入 Tool / MCP；
- 修改任务依赖和调度：扩展 Workflow；
- 组合已有动作：写 Robot Skill；
- 增加原子动作：写 Ability；
- 接入新设备：实现 Robot SDK Backend；
- 增加仿真环境：增加 Scene Package 或 Runtime Profile；
- 增加观察和介入能力：扩展 Studio Panel / Renderer。
