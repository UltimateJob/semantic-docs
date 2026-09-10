---
title: "Agents and Intelligence"
linkTitle: "Agents and Intelligence"
weight: 10
description: "Give an Agent domain knowledge, model services, external tools, a role identity, and team collaboration."
---

**Agents and Intelligence** answers one question: **how an Agent understands a task, obtains knowledge, and uses the right models and tools**.

These modules do not provide physical execution. They turn “what the user wants” into a Workflow or tool call, and they control what an Agent may do through explicit roles, models, Skills, and tool boundaries.

## Module composition

| Module | Problem it solves | Typical artifacts |
|---|---|---|
| [Agent Skill](agent-skill.en.md) | How an Agent obtains domain knowledge and working methods | `SKILL.md`, references, scripts |
| [Tools and MCP](tool-and-mcp.en.md) | How an Agent queries or operates external systems | MCP Server, Go Tool |
| [Model Provider](model-provider.en.md) | Which model service an Agent Run uses | Provider configuration, secret environment variables |
| [Agent roles and Team](agent-profile.en.md) | Agent identity, permissions, and collaboration | `role.yaml`, `AGENT.md`, Team |

## Code locations

- Skill templates and implementation: `semantic-framework/configs/skills/`, `internal/skill/`;
- Roles and Team: `semantic-framework/configs/agents/`, `internal/agent/profile/`, `internal/agent/team/`;
- Models: `semantic-framework/configs/semantic-server.yaml`, `pkg/llm/`;
- Tools: `internal/tool/`, `internal/mcpregistry/`, `pkg/mcp/`.

## How an Agent is assembled

```text
Model Provider
→ role mode / instruction
→ tools.namespaces + pinned
→ tool_search
→ skills.allowlist
→ approval_required
→ limits
→ collaboration position in a Team
```

At runtime, the Server assembles the model, tools, Skills, approvals, and context limits into one Agent Run. The Agent can work only inside the authorized boundary.

## When to extend which module

- Teach the Agent your business method: Agent Skill;
- Let the Agent call an internal system: MCP Server or a built-in Tool;
- Change the model service: Model Provider;
- Add a role, permission, or collaboration relationship: Agent Profile / Team;
- Let the Agent start a physical task: do not call the device directly; enter Workflow / Robot Task.

## Minimal example: add an Agent Skill

Create the directory:

```bash
cd "$SEMANTIC/semantic-framework"
mkdir -p configs/skills/general/hello-semantic
```

Write `SKILL.md`:

```markdown
---
name: hello-semantic
description: Minimal Agent Skill example used to verify Skill loading and role authorization
category: general
when_to_use: When the user needs a demonstration of how an Agent Skill works
---

# Hello Semantic

1. State that the current Skill has been loaded;
2. Query the current time;
3. Output the analysis steps for a minimal robot task.
```

Authorize it for `leader`:

```yaml
skills:
  allowlist:
    - artifact-usage
    - echo-guide
    - hello-semantic
```

Restart the Server, then verify:

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"

curl -s http://127.0.0.1:8080/api/v1/agents \
  -H "Authorization: Bearer $TOKEN"
```

`leader.skill_names` should include `hello-semantic`.

## Model configuration

The default model is `mock`. A real Provider example:

```yaml
llm:
  default: deepseek-chat
  providers:
    deepseek-chat:
      service: deepseek
      component: openai
      base_url: https://api.deepseek.com
      model: deepseek-chat
      capabilities: [text, tool_call]
      options:
        timeout_seconds: 300
        max_tokens: 8192
```

Keys use environment variables:

```bash
export SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=<key>
```

## Testing

```bash
cd "$SEMANTIC/semantic-framework"

# Skill
go test ./internal/skill/... -count=1
go test ./tests/integration/ -run TestSkill -count=1

# Agent / Team
go test ./internal/agent/... -count=1
go test ./tests/integration/ -run TestTeam -count=1

# Full integration
go test ./tests/integration/ -count=1
```

## Boundaries

- A Skill is not a Tool: it describes a working method and does not execute system operations;
- A Tool is not business state: it only performs validated input and output;
- An Agent cannot access Pilot, AbilityFramework, or a device directly;
- Skill content supports hot reload, but role authorization requires a restart;
- `skills.allowlist` is a hard role-level boundary. A Project can only narrow it further.

## Further reading

- [Agent Skill](agent-skill.en.md);
- [Tools and MCP](tool-and-mcp.en.md);
- [Model Provider](model-provider.en.md);
- [Agent roles and Team](agent-profile.en.md);
- [Chapter 3: Agent Profile, Model, and Agent Skill](../../quickstart/chapter_03_agent_skill.en.md).
