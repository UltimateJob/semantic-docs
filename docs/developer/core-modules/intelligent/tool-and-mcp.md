---
title: "Tool 与 MCP 接入"
weight: 20
description: "为 Agent 接入可调用能力：内置 Tool 的 Go 契约与注册，以及零代码的 MCP Server 配置接入。"
---

Tool 为 Agent 提供可调用能力：查询环境、读写产物、执行脚本、操作 Robot。Agent 在 Run 中通过 Tool 执行被允许的操作。

有两条接入路径：

- **内置 Tool**：在 `semantic-framework` 中用 Go 实现，适合需要深度访问 Server 内部状态的能力；
- **MCP Server**：纯配置接入外部工具服务，**无需修改 Framework 代码**，适合接入已有系统。

## Tool 契约

Tool 是一个很小的 Go 接口（`internal/tool/tool.go`）：

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

结果与错误协议：

```go
// 成功：返回 {"ok":true,"data":...}
tool.OKResult(map[string]any{...})

// 失败：返回结构化错误，执行器归一为 {"ok":false,"error":{code,message,retryable}}
&tool.Error{Code: "BAD_ARGUMENTS", Message: "...", Retryable: false}
```

Risk 取值 `low / medium / high / critical`，用于审批与展示。

## 实现一个内置 Tool

在 `internal/tool/builtin/` 新建文件：

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

注意事项：

- **模型侧函数名会经过净化**：`myns.action → myns_action`（OpenAI 兼容端点要求 `^[a-zA-Z0-9_-]+$`，见 `kernel/tools.go` 的 `SafeToolName`）；
- `ParametersJSON` 必须是合法 JSON Schema，非法在启动期报错；
- 执行器默认 30s 超时硬上限，同命名空间串行执行；错误码：`UNKNOWN_TOOL / TIMEOUT / TOOL_ERROR`。

### 注册与暴露

注册在启动期完成，契约不全或重名直接 fail-fast：

1. 加入 `builtin.RegisterAll` 的 tools 切片（`builtin/builtin.go`）；或
2. 仿照 robot 工具写 `RegisterMynsTools(reg, 依赖)`，在 `internal/bootstrap/wire_access.go` 装配链中调用。

然后在目标角色的 `role.yaml` 中暴露：

- `tools.namespaces` 加 `myns.*`（或精确名）；
- `tools.pinned` 加工具名可常驻注入；
- `tool_search: true` 的角色里，非 pinned 工具自动进动态检索集（初始对模型隐藏，`tool_search` 命中后可见）；
- risk=high 的写操作如需人工审批，把命名空间加进 `interrupt.approval_required`。

### 规划门禁

处于 Plan Mode 的 Leader Run 有执行层白名单（`internal/tool/execution_scope.go`）：规划 Run 只允许 `system.*`、`artifact.get/list`、`map.query`、`interaction.ask`；对话计划额外允许 `plan.suggest`。新工具若需要在规划阶段使用，必须加入该白名单。

### 内置工具清单

| 工具 | 命名空间 | Risk | 用途 |
|---|---|---|---|
| system.time / system.echo / system.calc | system | low | 基础系统工具 |
| artifact.put / artifact.get / artifact.list / artifact.register | artifact | high / medium / low / - | 产物写入与读取 |
| map.query | map | low | 查询 Semantic Map |
| plan.suggest | plan | low | Leader 提交 Plan Proposal（仅 Plan Mode） |
| interaction.ask | interaction | - | 向用户发起结构化提问 |
| execute | execute | high | Docker 沙箱执行（workspace 挂 /workspace、skills 挂 /skills） |
| execute_host | execute | high | 受控宿主执行 |
| robot.get / robot.run / robot.stop | robot | low / high / high | Robot 查询、执行与停止 |

## MCP Server 接入

除内置 Tool 外，Framework 支持通过 MCP Server 接入外部工具，**不需要修改 Framework 代码**（配置项 `mcp_servers`，实现见 `internal/mcpregistry/`、`pkg/mcp/` 与 `kernel/tools_mcp.go`）。

在 `configs/semantic-server.yaml` 中登记 MCP Server：

```yaml
mcp_servers:
  - name: my-service
    transport: http            # http（streamable）或 stdio
    url: http://127.0.0.1:9000/mcp
    # stdio 传输改用 command / args / env 字段
```

行为要点：

- Server 启动时连接 MCP Server 并同步工具目录（`internal/mcpregistry/syncer.go`），工具自动进入工具目录并按命名空间参与权限过滤；
- MCP 工具与内置工具走**同一套契约净化和门禁**：名称净化、role.yaml 授权、风险审批、30s 超时都一致；
- 工具目录变化通过 `GET /api/v1/tools` 可见（按来源分组，含 schema 与 health）。

选择建议：要接入的外部系统已有（或容易包装出）MCP Server 时优先走 MCP；只有需要直接访问 Framework 内部 Store / EventBus 的能力才写内置 Tool。

## Tool 设计原则

- Tool 定义清晰的动作和类型化输入输出，`description` 写给模型看；
- Tool 从 Agent Run 的 Execution Scope 获得 Project、Conversation、Task、Agent 和批准范围，不要让模型重复填写系统身份；
- 输入错误返回可理解的诊断（结构化 `tool.Error`），而不是裸 error；
- 只读与写操作要符合 Run 目的（规划 Run 的写操作会被执行层拒绝）。

## 测试

```bash
# 单元测试
go test ./internal/tool/... -count=1

# 集成测试（真实 bootstrap.Wire + mock 模型 + 真实 HTTP/WS）
go test ./tests/integration/ -run TestToolSearch -count=1   # 动态工具检索三轮 Run
go test ./tests/integration/ -run TestMCP -count=1          # MCP 工具
```

测试覆盖要点：

- Agent Profile 只获得 namespaces 内的 Tool；
- Tool 输入错误返回结构化诊断；
- 模型侧工具名净化后无冲突；
- MCP Server 断连后工具目录与健康状态正确更新。

## 相关 API

| 接口 | 说明 |
|---|---|
| `GET /api/v1/tools` | 工具目录（按来源分组，含 schema 与 health） |
| `GET /api/v1/agents` | Agent 目录（含各 Agent 实际可见的工具范围） |
