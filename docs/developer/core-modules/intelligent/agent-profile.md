---
title: "Agent 角色与 Team"
weight: 40
description: "新增 Agent 角色与协作团队：role.yaml 全字段、工具与 Skill 授权、Team 配置。"
---

Agent 角色（Profile）定义一个 Agent 的身份、行为指令、可用工具、可用 Skill、模型与运行限制。新增角色或调整团队协作是纯配置扩展，不需要修改 Go 代码。

实现位于 `semantic-framework`：

- Profile 解析与缓存：`internal/agent/profile/profile.go`
- 配置目录：`configs/agents/<role>/`
- Team 定义：`configs/agents/teams/default.yaml`

## 角色目录结构

每个角色是 `configs/agents/` 下的一个目录：

```text
configs/agents/developer/
├── role.yaml       必需，角色定义
├── AGENT.md        必需，行为指令（instruction_file 指定）
└── SAFETY.md       可选，安全约束
```

当前内置角色与协作位置：

| 角色 | mode | 职责 |
|---|---|---|
| `leader` | coordinator | 用户对话入口，任务分解与分配 |
| `query` | service | 按需调用的可复用子能力（SubAgent） |
| `developer` | worker | 开发类工作 |
| `map` | worker | 地图与空间查询 |
| `monitor` | worker | 执行监控 |
| `robot` | worker | 机器人任务执行 |

Profile 进程内缓存，**修改后需重启 Server 生效**。

## role.yaml 字段

```yaml
name: developer
mode: worker                 # coordinator | worker | service，必填
description: 开发者 Worker
instruction_file: AGENT.md
model: ""                    # 留空继承系统默认模型
reasoning_effort: ""
tools:
  namespaces: [system.*, artifact.*, execute, execute_host, map.query, interaction.ask]
  pinned: [system.time, map.query]   # 常驻注入的工具
  tool_search: true          # 非 pinned 工具进动态检索集
limits:
  max_turns: 20              # 默认 10
  context_tokens: 120000     # 默认 120000
interrupt:
  approval_required: [artifact.put]  # 需人工审批的命名空间
memory:
  long_term: false
skills:
  allowlist:                 # 硬边界：空列表 = 该 Agent 不使用任何 Skill
    - artifact-usage
    - echo-guide
subagent:
  enabled: false             # 仅 service 模式可启用
```

关键语义：

- `mode` 决定角色在协作中的位置：coordinator 负责任务分解，worker 执行具体工作，service 提供可复用子能力；
- `tools.pinned` 常驻注入模型上下文；`tool_search: true` 时其余授权工具进入动态检索集，命中后才对模型可见；
- `skills.allowlist` 是硬边界，Project 级绑定只能继续收窄（交集语义见 [Agent Skill](/developer/core-modules/intelligent/agent-skill/)）；
- `interrupt.approval_required` 按命名空间声明需人工审批的操作，与 Tool 的 `Annotations.Risk` 配合（见 [Tool 与 MCP 接入](/developer/core-modules/intelligent/tool-and-mcp/)）。

## 入门教程：新增一个角色

### 1. 创建角色目录

```text
configs/agents/inspector/
├── role.yaml
└── AGENT.md
```

`AGENT.md` 用领域语言描述角色的目标、工作方式、输出要求和边界——写法与 SKILL.md 正文类似，聚焦"这个 Agent 是谁、怎么做"。

### 2. 授权工具与 Skill

在 `role.yaml` 中按最小权限配置 `tools.namespaces` 和 `skills.allowlist`。新角色默认看不到任何 Skill（空 allowlist = 不使用 Skill）。

### 3. 加入 Team（可选）

编辑 `configs/agents/teams/default.yaml` 把新角色加入团队，使 coordinator 可以给它分配任务：

```yaml
# configs/agents/teams/default.yaml（结构示意）
members:
  - name: inspector-1        # 成员实例名
    role: inspector          # 指向 configs/agents/<role>/
  # ...
subagents:
  - query-1                  # service 模式角色作为按需 SubAgent
```

团队由 `leader`（coordinator）牵头：用户对话进入 leader，leader 分解任务给 worker 成员；service 角色不常驻，按需作为 SubAgent 被调用。

### 4. 验证

```bash
# 重启 Server 后：
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
# 返回中应包含新角色，且 tools / skill_names 与 role.yaml 授权一致
```

## 相关代码

- 子 Agent 注册：`internal/agent/subagent/registry.go`
- Roster / Team 装配：`internal/agent/runtime/service.go`

## 测试

- Profile 解析与缓存行为：`go test ./internal/agent/profile/... -count=1`
- 端到端授权验证：`go test ./tests/integration/ -count=1` 中的 Agent 目录相关用例
