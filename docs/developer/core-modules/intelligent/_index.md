---
title: "Agent 与智能能力"
linkTitle: "Agent 与智能能力"
weight: 10
description: "让 Agent 获得领域知识、模型服务、外部工具、角色身份和团队协作能力。"
---

**Agent 与智能能力**回答一个问题：**Agent 怎么理解任务、获得知识，并使用正确的模型和工具**。

这组模块不提供物理执行能力。它负责把“用户想要什么”转化为 Workflow 或工具调用，并通过明确的角色、模型、Skill 和工具边界控制 Agent 能做什么。

## 模块组成

| 模块 | 解决的问题 | 典型产物 |
|---|---|---|
| [Agent Skill](/developer/core-modules/intelligent/agent-skill/) | Agent 如何获得领域知识和工作方法 | `SKILL.md`、references、scripts |
| [Tool 与 MCP 接入](/developer/core-modules/intelligent/tool-and-mcp/) | Agent 如何查询或操作外部系统 | MCP Server、Go Tool |
| [Model Provider](/developer/core-modules/intelligent/model-provider/) | Agent Run 使用哪个模型服务 | Provider 配置、密钥环境变量 |
| [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/) | Agent 的身份、权限和协作关系 | `role.yaml`、`AGENT.md`、Team |

## 代码位置

- Skill 模板与实现：`semantic-framework/configs/skills/`、`internal/skill/`；
- 角色与 Team：`semantic-framework/configs/agents/`、`internal/agent/profile/`、`internal/agent/team/`；
- 模型：`semantic-framework/configs/semantic-server.yaml`、`pkg/llm/`；
- 工具：`internal/tool/`、`internal/mcpregistry/`、`pkg/mcp/`。

## 一个 Agent 是如何组装出来的

```text
Model Provider
→ 角色 mode / instruction
→ tools.namespaces + pinned
→ tool_search
→ skills.allowlist
→ approval_required
→ limits
→ Team 中的协作位置
```

运行时，Server 将模型、工具、Skill、审批和上下文限制组装成一次 Agent Run。Agent 只能在授权边界内工作。

## 什么时候扩展哪个模块

- 让 Agent 懂你的业务方法：Agent Skill；
- 让 Agent 调用内部系统：MCP Server 或内置 Tool；
- 更换模型服务：Model Provider；
- 新增角色、权限或协作关系：Agent Profile / Team；
- 让 Agent 发起物理任务：不要直接调设备，应该进入 Workflow / Robot Task。

## 最小示例：新增 Agent Skill

创建目录：

```bash
cd "$SEMANTIC/semantic-framework"
mkdir -p configs/skills/general/hello-semantic
```

写入 `SKILL.md`：

```markdown
---
name: hello-semantic
description: 最小 Agent Skill 示例，用于验证 Skill 加载和角色授权
category: general
when_to_use: 用户需要演示 Agent Skill 的工作方式时
---

# Hello Semantic

1. 说明当前 Skill 已被加载；
2. 查询当前时间；
3. 输出最小机器人任务的分析步骤。
```

授权给 leader：

```yaml
skills:
  allowlist:
    - artifact-usage
    - echo-guide
    - hello-semantic
```

重启 Server 后验证：

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"

curl -s http://127.0.0.1:8080/api/v1/agents \
  -H "Authorization: Bearer $TOKEN"
```

`leader.skill_names` 应包含 `hello-semantic`。

## 模型配置

默认模型为 `mock`。真实 Provider 示例：

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

密钥使用环境变量：

```bash
export SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=<key>
```

## 测试

```bash
cd "$SEMANTIC/semantic-framework"

# Skill
go test ./internal/skill/... -count=1
go test ./tests/integration/ -run TestSkill -count=1

# Agent / Team
go test ./internal/agent/... -count=1
go test ./tests/integration/ -run TestTeam -count=1

# 完整集成
go test ./tests/integration/ -count=1
```

## 边界

- Skill 不是 Tool：它描述工作方法，不执行系统操作；
- Tool 不是业务状态：它只做可校验的输入输出；
- Agent 不能直接访问 Pilot、AbilityFramework 或设备；
- Skill 内容支持热更新，但角色授权需要重启；
- `skills.allowlist` 是角色级硬边界，Project 只能继续收窄。

## 深入阅读

- [Agent Skill](/developer/core-modules/intelligent/agent-skill/)；
- [Tool 与 MCP 接入](/developer/core-modules/intelligent/tool-and-mcp/)；
- [Model Provider](/developer/core-modules/intelligent/model-provider/)；
- [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/)；
- [第三章：Agent Profile、Model 与 Agent Skill](/developer/quickstart/chapter_03_agent_skill/)。
