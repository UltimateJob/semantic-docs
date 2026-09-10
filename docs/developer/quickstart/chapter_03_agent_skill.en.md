---
title: "Chapter 3: Agent Profile, Model, and Agent Skill"
linkTitle: "Chapter 3: Agent and Skill"
weight: 23
description: "Configure Agent roles, a model service, and one authorizable, verifiable Agent Skill."
---

**Goal of this chapter**: give an Agent a clear role, a usable model, and one Skill that is actually loaded. When you are done, you should be able to confirm over REST that the Skill is loaded and that the target role can see it.

## What an Agent Skill is

An Agent Skill is domain knowledge and a working method written for an Agent. It does not change model capability. It tells the Agent how to work in a scene, which tools it may use, and which risks it must confirm.

Semantic uses progressive disclosure: the Agent first sees a Skill's `name` and `description`, then reads the body through the `skill` tool when needed during a run. Unused knowledge does not enter context.

## Code locations

- Skill templates: `semantic-framework/configs/skills/`;
- Skill loader: `semantic-framework/internal/skill/`;
- Role config: `semantic-framework/configs/agents/`;
- Team config: `semantic-framework/configs/agents/teams/default.yaml`;
- Model config: `semantic-framework/configs/semantic-server.yaml`.

## Inspect the default roles

```bash
cd "$SEMANTIC/semantic-framework"
ls configs/agents
```

Default roles include:

| Role | mode | Purpose |
|---|---|---|
| `leader` | coordinator | User conversation and overall planning |
| `developer` | worker | General development work |
| `map` | worker | Map and spatial queries |
| `monitor` | worker | Run monitoring |
| `query` | service | On-demand SubAgent |
| `robot` | worker | Robot execution role (actual Robot Workers are generated dynamically from devices) |

Inspect the leader config:

```bash
sed -n '1,220p' configs/agents/leader/role.yaml
```

You should see model, tool namespaces, approval requirements, Skill allowlist, and Team entry.

## Configure a model service

The default config contains only the `mock` model. For a real model, add a Provider in the config copy first:

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

Do not write keys into config. Use an environment variable:

```bash
export SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=<你的 key>
```

Without a key, this chapter can still complete every verification with `mock`.

## Create an Agent Skill

Create it in the Framework skills directory:

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

`SKILL.md` must start with YAML frontmatter. A file without frontmatter is not treated as a Skill.

## Authorize the target role

Loading a Skill does not mean an Agent can use it. Each role's `skills.allowlist` is a hard boundary.

Edit `configs/agents/leader/role.yaml` and add to `skills.allowlist`:

```yaml
skills:
  allowlist:
    - artifact-usage
    - echo-guide
    - hello-semantic
```

Authorization config is cached in-process. Restart the Server after you change it.

## Restart the Server and log in

```bash
cd "$SEMANTIC/semantic-framework"
make run
```

If you have no Token, log in again:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')
```

## Verify the Skill is loaded

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"
```

The expected response should include:

```json
{
  "name": "hello-semantic",
  "description": "最小 Agent Skill 示例，用于验证 Skill 加载和角色授权"
}
```

You can also read a single Skill:

```bash
curl -s http://127.0.0.1:8080/api/v1/skills/hello-semantic \
  -H "Authorization: Bearer $TOKEN"
```

## Verify role visibility

```bash
curl -s http://127.0.0.1:8080/api/v1/agents \
  -H "Authorization: Bearer $TOKEN"
```

In the expected response, `leader`'s `skill_names` should include:

```json
"hello-semantic"
```

If `GET /api/v1/skills` can see it but `GET /api/v1/agents` cannot, the Skill is loaded but not authorized to the current role.

## Observe hot reload

Edit it while the Server is running:

```bash
nano configs/skills/general/hello-semantic/SKILL.md
```

Watch Server logs after save. The Skill Store reloads and atomically replaces the snapshot after about 500ms of debounce.

Hot reload affects only Skill content. Role `skills.allowlist` still requires a Server restart.

## Tests

```bash
cd "$SEMANTIC/semantic-framework"

# Skill 解析、加载和内置样例测试
go test ./internal/skill/... -count=1

# 真实装配、REST、热更集成测试
go test ./tests/integration/ -run TestSkill -count=1
```

## Expected result

After this chapter you should have:

```text
默认角色和 Team 已确认
→ 模型 Provider 已配置（mock 或真实模型）
→ hello-semantic 已出现在 /api/v1/skills
→ leader 的 skill_names 包含 hello-semantic
→ 修改 SKILL.md 后日志出现热更新
```

## Common failures

- **Skill does not appear**: confirm `SKILL.md` starts with `---` and has `name` and `description`;
- **Agent cannot see the Skill**: confirm the role `skills.allowlist` was updated and the Server was restarted;
- **Model call failed**: confirm `SEMANTIC_LLM_API_KEY_<endpoint name>` matches the Provider name in config;
- **Config change has no effect**: confirm you edited the runtime copy under `.output/`, or re-run `semantic init`;
- **Hot reload did not happen**: confirm `skills.dir` points at the directory you are editing.

## Chapter summary

- A Skill is authorizable knowledge for an Agent, not a tool implementation;
- `description` is the main basis for the model to choose a Skill;
- `skills.allowlist` is a role-level hard boundary;
- Skill content supports hot reload; authorization requires a restart;
- The next chapter turns an Agent's plan into a Workflow.

## Next chapter

Continue to [Chapter 4: Plan Proposal, Workflow, and Task](chapter_04_workflow.en.md).
