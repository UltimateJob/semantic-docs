---
title: "Tools and MCP"
weight: 20
description: "Give Agents callable capabilities: the Go contract and registration for built-in Tools, and zero-code MCP Server configuration."
---

Tools give Agents callable capabilities: query the environment, read and write artifacts, run scripts, and operate Robots. During a Run, an Agent performs only the operations it is allowed to use.

There are two integration paths:

- **Built-in Tool**: implement it in Go inside `semantic-framework`. Use this when the capability needs deep access to Server-internal state;
- **MCP Server**: connect an external tool service with configuration only. **You do not need to change Framework code.** Use this to connect existing systems.

## Tool contract

A Tool is a small Go interface (`internal/tool/tool.go`):

```go
type Tool interface {
    Def() Definition
    Run(ctx context.Context, argsJSON string) (string, error)
}

type Definition struct {
    Name           string      // 全名：<命名空间>.<动作>，如 artifact.put
    Namespace      string      // 权限过滤 / 审批名单维度
    Description    string      // 告诉模型何时、为何使用
    ParametersJSON string      // 参数 JSON Schema（object 根）
    Annotations    Annotations // Risk / Timeout / Streaming / Idempotent
}
```

Result and error protocol:

```go
// 成功：返回 {"ok":true,"data":...}
tool.OKResult(map[string]any{...})

// 失败：返回结构化错误，执行器归一为 {"ok":false,"error":{code,message,retryable}}
&tool.Error{Code: "BAD_ARGUMENTS", Message: "...", Retryable: false}
```

Risk values are `low / medium / high / critical`, used for approval and display.

## Implement a built-in Tool

Create a new file under `internal/tool/builtin/`:

```go
type myTool struct {
    store *store.Store // 按需注入依赖
}

func (t *myTool) Def() tool.Definition {
    return tool.Definition{
        Name:      "myns.action",
        Namespace: "myns",
        Description: "说明何时、为何使用这个工具",
        ParametersJSON: `{
          "type": "object",
          "properties": {
            "target_ref": {"type": "string", "description": "目标对象引用"}
          },
          "required": ["target_ref"],
          "additionalProperties": false
        }`,
        Annotations: tool.Annotations{Risk: tool.RiskLow, Idempotent: true},
    }
}

func (t *myTool) Run(ctx context.Context, argsJSON string) (string, error) {
    var args struct {
        TargetRef string `json:"target_ref"`
    }
    if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
        return "", &tool.Error{Code: "BAD_ARGUMENTS", Message: err.Error()}
    }
    // 需要 Project / Run 边界时从 context 读取，不使用全局状态：
    scope, ok := tool.ExecutionScopeFromContext(ctx)
    _ = scope
    return tool.OKResult(map[string]any{"done": true}), nil
}
```

Notes:

- **Model-side function names are sanitized**: `myns.action → myns_action` (OpenAI-compatible endpoints require `^[a-zA-Z0-9_-]+$`; see `SafeToolName` in `kernel/tools.go`);
- `ParametersJSON` must be a valid JSON Schema. Invalid schema fails at startup;
- The executor has a hard 30s timeout by default and serializes execution within the same namespace. Error codes: `UNKNOWN_TOOL / TIMEOUT / TOOL_ERROR`.

### Register and expose

Registration happens at startup. Incomplete contracts or duplicate names fail fast:

1. Add the tool to the tools slice in `builtin.RegisterAll` (`builtin/builtin.go`); or
2. Follow the robot tools pattern and write `RegisterMynsTools(reg, deps)`, then call it from the assembly chain in `internal/bootstrap/wire_access.go`.

Then expose it in the target role's `role.yaml`:

- Add `myns.*` (or an exact name) to `tools.namespaces`;
- Add the tool name to `tools.pinned` to keep it always injected;
- For roles with `tool_search: true`, non-pinned tools automatically enter the dynamic retrieval set (hidden from the model at first, visible after a `tool_search` hit);
- For high-risk writes that need human approval, add the namespace to `interrupt.approval_required`.

### Planning gate

A Leader Run in Plan Mode has an execution-layer whitelist (`internal/tool/execution_scope.go`): planning Runs may use only `system.*`, `artifact.get/list`, `map.query`, and `interaction.ask`. Conversation plans additionally allow `plan.suggest`. A new tool that must be used during planning has to join that whitelist.

### Built-in tool list

| Tool | Namespace | Risk | Purpose |
|---|---|---|---|
| system.time / system.echo / system.calc | system | low | Basic system tools |
| artifact.put / artifact.get / artifact.list / artifact.register | artifact | high / medium / low / - | Write and read artifacts |
| map.query | map | low | Query the Semantic Map |
| plan.suggest | plan | low | Leader submits a Plan Proposal (Plan Mode only) |
| interaction.ask | interaction | - | Ask the user a structured question |
| execute | execute | high | Docker sandbox execution (workspace mounted at /workspace, skills at /skills) |
| execute_host | execute | high | Controlled host execution |
| robot.get / robot.run / robot.stop | robot | low / high / high | Query, run, and stop a Robot |

## Connect an MCP Server

Besides built-in Tools, the Framework can connect external tools through an MCP Server **without changing Framework code** (config key `mcp_servers`; implementation in `internal/mcpregistry/`, `pkg/mcp/`, and `kernel/tools_mcp.go`).

Register an MCP Server in `configs/semantic-server.yaml`:

```yaml
mcp_servers:
  - name: my-service
    transport: http            # http（streamable）或 stdio
    url: http://127.0.0.1:9000/mcp
    # stdio 传输改用 command / args / env 字段
```

Behavior notes:

- At startup the Server connects to the MCP Server and syncs the tool catalog (`internal/mcpregistry/syncer.go`). Tools enter the catalog automatically and participate in namespace permission filtering;
- MCP tools and built-in tools use **the same contract sanitization and gates**: name sanitization, role.yaml authorization, risk approval, and the 30s timeout are identical;
- Catalog changes are visible on `GET /api/v1/tools` (grouped by source, including schema and health).

Recommendation: prefer MCP when the external system already has (or can easily wrap) an MCP Server. Write a built-in Tool only when you need direct access to the Framework's internal Store / EventBus.

## Tool design principles

- Define a clear action and typed inputs/outputs. Write `description` for the model;
- Tools obtain Project, Conversation, Task, Agent, and approval scope from the Agent Run's Execution Scope. Do not ask the model to repeat system identity;
- Return understandable diagnostics for input errors (structured `tool.Error`), not a bare error;
- Read and write operations must match the Run purpose (writes in a planning Run are rejected at the execution layer).

## Tests

```bash
# 单元测试
go test ./internal/tool/... -count=1

# 集成测试（真实 bootstrap.Wire + mock 模型 + 真实 HTTP/WS）
go test ./tests/integration/ -run TestToolSearch -count=1   # 动态工具检索三轮 Run
go test ./tests/integration/ -run TestMCP -count=1          # MCP 工具
```

Coverage focus:

- An Agent Profile receives only Tools in its namespaces;
- Tool input errors return structured diagnostics;
- Sanitized model-side tool names do not collide;
- After an MCP Server disconnects, the tool catalog and health status update correctly.

## Related APIs

| API | Description |
|---|---|
| `GET /api/v1/tools` | Tool catalog (grouped by source, including schema and health) |
| `GET /api/v1/agents` | Agent directory (including each Agent's actually visible tool scope) |
