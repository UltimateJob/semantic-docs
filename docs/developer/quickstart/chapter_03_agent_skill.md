---
title: "第三章：Agent Profile、Model 与 Agent Skill"
linkTitle: "第 3 章：Agent 与 Skill"
weight: 23
description: "配置 Agent 角色、模型服务和一份可授权、可验证的 Agent Skill。"
---

**本章目标**：让 Agent 有明确角色、可用模型和一份真实加载的 Skill。完成后，你应能通过 REST 确认 Skill 已加载，并确认目标角色能看到它。

## Agent Skill 是什么

Agent Skill 是写给 Agent 的领域知识和工作方法。它不改变模型能力，而是告诉 Agent 在什么场景下如何工作、可以使用什么工具、需要确认什么风险。

Semantic 使用渐进披露：Agent 先看到 Skill 的 `name` 和 `description`，运行中需要时再通过 `skill` 工具读取正文。没有被用到的知识不会进入上下文。

## 代码位置

- Skill 模板：`semantic-framework/configs/skills/`；
- Skill 加载器：`semantic-framework/internal/skill/`；
- 角色配置：`semantic-framework/configs/agents/`；
- Team 配置：`semantic-framework/configs/agents/teams/default.yaml`；
- 模型配置：`semantic-framework/configs/semantic-server.yaml`。

## 先查看默认角色

```bash
cd "$SEMANTIC/semantic-framework"
ls configs/agents
```

默认角色包括：

| 角色 | mode | 用途 |
|---|---|---|
| `leader` | coordinator | 用户对话和整体规划 |
| `developer` | worker | 通用开发工作 |
| `map` | worker | 地图和空间查询 |
| `monitor` | worker | 运行监控 |
| `query` | service | 按需调用的 SubAgent |
| `robot` | worker | Robot 执行角色（实际 Robot Worker 由设备动态生成） |

查看 leader 配置：

```bash
sed -n '1,220p' configs/agents/leader/role.yaml
```

你应看到它包含模型、工具命名空间、审批要求、Skill allowlist 和 Team 入口。

## 配置模型服务

默认配置只包含 `mock` 模型。使用真实模型时，先在配置副本中添加 Provider：

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

密钥不写入配置，使用环境变量：

```bash
export SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=<你的 key>
```

没有 key 时，本章仍可使用 `mock` 完成所有验证。

## 创建一份 Agent Skill

在 Framework 的技能目录中创建：

```bash
mkdir -p configs/skills/general/hello-semantic
cat > configs/skills/general/hello-semantic/SKILL.md <<'EOF'
---
name: hello-semantic
description: 最小 Agent Skill 示例，用于验证 Skill 加载和角色授权
category: general
when_to_use: 用户需要演示 Agent Skill 的工作方式时
---

# Hello Semantic

当用户请求演示 Agent Skill 时：

1. 先说明当前 Skill 已被加载；
2. 查询当前时间，确认工具调用可用；
3. 给出一个最小机器人任务的分析步骤；
4. 输出不超过 5 条结论。
EOF
```

`SKILL.md` 必须以 YAML frontmatter 开头。没有 frontmatter 的文件不会被当作 Skill。

## 授权给目标角色

Skill 被加载不等于 Agent 能使用它。每个角色的 `skills.allowlist` 是硬边界。

编辑 `configs/agents/leader/role.yaml`，在 `skills.allowlist` 中加入：

```yaml
skills:
  allowlist:
    - artifact-usage
    - echo-guide
    - hello-semantic
```

授权配置有进程内缓存，修改后需要重启 Server。

## 重启 Server 并登录

```bash
cd "$SEMANTIC/semantic-framework"
make run
```

如果没有 Token，重新登录：

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
```

## 验证 Skill 已加载

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"
```

预期返回中应包含：

```json
{
  "name": "hello-semantic",
  "description": "最小 Agent Skill 示例，用于验证 Skill 加载和角色授权"
}
```

也可以读取单个 Skill：

```bash
curl -s http://127.0.0.1:8080/api/v1/skills/hello-semantic \
  -H "Authorization: Bearer $TOKEN"
```

## 验证角色可见性

```bash
curl -s http://127.0.0.1:8080/api/v1/agents \
  -H "Authorization: Bearer $TOKEN"
```

预期返回中，`leader` 的 `skill_names` 应包含：

```json
"hello-semantic"
```

如果 `GET /api/v1/skills` 能看到它，但 `GET /api/v1/agents` 中没有，说明 Skill 已加载但没有授权给当前角色。

## 观察热更新

在 Server 运行时直接修改：

```bash
nano configs/skills/general/hello-semantic/SKILL.md
```

保存后观察 Server 日志。Skill Store 会在约 500ms 去抖后重载并原子替换快照。

热更新只影响 Skill 内容；角色 `skills.allowlist` 仍需重启 Server 才生效。

## 测试

```bash
cd "$SEMANTIC/semantic-framework"

# Skill 解析、加载和内置样例测试
go test ./internal/skill/... -count=1

# 真实装配、REST、热更集成测试
go test ./tests/integration/ -run TestSkill -count=1
```

## 预期结果

本章完成后，你应得到：

```text
默认角色和 Team 已确认
→ 模型 Provider 已配置（mock 或真实模型）
→ hello-semantic 已出现在 /api/v1/skills
→ leader 的 skill_names 包含 hello-semantic
→ 修改 SKILL.md 后日志出现热更新
```

## 常见失败

- **Skill 不出现**：确认 `SKILL.md` 以 `---` 开头，并有 `name` 和 `description`；
- **Agent 看不到 Skill**：确认角色 `skills.allowlist` 已加入并重启 Server；
- **模型调用失败**：确认 `SEMANTIC_LLM_API_KEY_<端点名>` 与配置中的 Provider 名称一致；
- **配置修改不生效**：确认你修改的是 `.output/` 中的运行副本，或重新执行 `semantic init`；
- **热更新没有发生**：确认 `skills.dir` 指向的目录是你在编辑的目录。

## 本章小结

- Skill 是 Agent 的可授权知识，不是工具实现；
- `description` 是模型选择 Skill 的主要依据；
- `skills.allowlist` 是角色级硬边界；
- Skill 内容支持热更新，授权需要重启；
- 下一章将把 Agent 的计划转化为 Workflow。

## 下一章

进入[第四章：Plan Proposal、Workflow 与 Task](/developer/quickstart/chapter_04_workflow/)。
