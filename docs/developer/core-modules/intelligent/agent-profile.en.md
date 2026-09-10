---
title: "Agent Roles and Teams"
weight: 40
description: "Add an Agent role and a collaboration team: full role.yaml fields, Tool and Skill authorization, and Team configuration."
---

An Agent role (Profile) defines an Agent's identity, behavior instructions, available tools, available Skills, model, and run limits. Adding a role or adjusting team collaboration is a configuration-only extension; you do not need to change Go code.

Implementation lives in `semantic-framework`:

- Profile parsing and cache: `internal/agent/profile/profile.go`
- Config directory: `configs/agents/<role>/`
- Team definition: `configs/agents/teams/default.yaml`

## Role directory layout

Each role is a directory under `configs/agents/`:

```text
configs/agents/developer/
├── role.yaml       必需，角色定义
├── AGENT.md        必需，行为指令（instruction_file 指定）
└── SAFETY.md       可选，安全约束
```

Built-in roles and their collaboration positions:

| Role | mode | Responsibility |
|---|---|---|
| `leader` | coordinator | User conversation entry; task decomposition and assignment |
| `query` | service | On-demand reusable sub-capability (SubAgent) |
| `developer` | worker | Development work |
| `map` | worker | Map and spatial queries |
| `monitor` | worker | Execution monitoring |
| `robot` | worker | Robot task execution |

Profiles are cached in-process. **Restart the Server after you change them.**

## role.yaml fields

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

Key semantics:

- `mode` places the role in the collaboration: coordinator decomposes work, worker executes concrete work, and service provides reusable sub-capabilities;
- `tools.pinned` tools stay in the model context; when `tool_search: true`, the remaining authorized tools enter the dynamic retrieval set and become visible to the model only after a hit;
- `skills.allowlist` is a hard boundary. Project-level bindings can only narrow it further (intersection semantics are in [Agent Skill](agent-skill.en.md));
- `interrupt.approval_required` declares namespaces that need human approval, and works with a Tool's `Annotations.Risk` (see [Tools and MCP](tool-and-mcp.en.md)).

## Getting started: add a role

### 1. Create the role directory

```text
configs/agents/inspector/
├── role.yaml
└── AGENT.md
```

`AGENT.md` describes the role's goal, working style, output requirements, and boundaries in domain language. Write it like a SKILL.md body: focus on who this Agent is and how it works.

### 2. Authorize Tools and Skills

In `role.yaml`, configure `tools.namespaces` and `skills.allowlist` with least privilege. A new role sees no Skills by default (an empty allowlist means the Agent uses no Skills).

### 3. Join a Team (optional)

Edit `configs/agents/teams/default.yaml` to add the new role so the coordinator can assign work to it:

```yaml
# configs/agents/teams/default.yaml（结构示意）
members:
  - name: inspector-1        # 成员实例名
    role: inspector          # 指向 configs/agents/<role>/
  # ...
subagents:
  - query-1                  # service 模式角色作为按需 SubAgent
```

The team is led by `leader` (coordinator): user conversation enters the leader, and the leader decomposes tasks for worker members. Service roles are not resident; they are invoked on demand as SubAgents.

### 4. Verify

```bash
# 重启 Server 后：
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
# 返回中应包含新角色，且 tools / skill_names 与 role.yaml 授权一致
```

## Related code

- Sub-agent registration: `internal/agent/subagent/registry.go`
- Roster / Team assembly: `internal/agent/runtime/service.go`

## Tests

- Profile parsing and cache behavior: `go test ./internal/agent/profile/... -count=1`
- End-to-end authorization: Agent-directory cases in `go test ./tests/integration/ -count=1`
