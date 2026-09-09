---
title: "Model Provider"
weight: 30
description: "配置 Agent Run 使用的模型服务：Provider 注册、请求适配、流式响应与用量统计。"
---

Model Provider 将 Semantic Agent Run 连接到具体模型服务。它负责请求格式、流式响应、Tool Call、用量统计和错误重试。

实现位置：

- Provider 注册表与密钥解析：`semantic-framework` 的 `pkg/llm/`（registry.go、metering.go）
- 模型驱动：`internal/agent/kernel/factory.go`、`model_retry.go`
- 配置：`configs/semantic-server.yaml` 的 `llm` 段 + 环境变量 / 托管密钥

## 支持的驱动

`component` 只支持三种（未知驱动启动期 fail-closed 报错）：

| component | 说明 | 密钥 |
|---|---|---|
| `openai` | **OpenAI 兼容端点**（DeepSeek、vLLM 等均走此驱动），必须提供 `base_url` | 必须 |
| `claude` | Anthropic Claude，`base_url` 可选（代理） | 必须 |
| `mock` | 内置 mock 模型，用于测试与离线开发 | 不需要 |

其他后端（gemini/ollama/ark）当前未实现。

## 配置格式

`configs/semantic-server.yaml` 的 `llm` 段：

```yaml
llm:
  default: mock                # 默认端点名，必须在 providers 清单中
  providers:
    deepseek-v4-flash:
      service: deepseek-chat   # 同服务端点共享一把密钥
      component: openai
      base_url: https://api.deepseek.com/v1
      model: deepseek-v4-flash
      capabilities: [text, tool_call]
      options:
        temperature: 0.7
      price:
        prompt: 0.001          # 每 1K tokens 单价（计量估算用）
        completion: 0.002
    mock:
      component: mock
      model: mock-1
      capabilities: [text, tool_call]
```

字段说明：

- `service`：服务标识，同一 service 的多个端点共享凭据；
- `capabilities`：`text / image / tool_call / embedding`；
- `options` 白名单：`temperature`、`max_tokens`、`reasoning_effort`（low/medium/high）、`timeout_seconds`。**未识别的键直接报错**（settings API 保存时即预校验为 400）；默认请求超时 5 分钟。

### options 默认值

为防止 OpenAI 兼容服务（如 llama.cpp，`n_predict` 默认不封顶）在模型不吐终止符时无限生成，系统在两层提供默认保护：

- **新端点物化**：经 Web"系统设置"或 `PATCH /api/v1/settings` 新增 `openai` 驱动端点且未显式提供 options 时，自动写入 `timeout_seconds: 300` 与 `max_tokens: 8192`，在配置文件与设置 UI 中可见、可按端点覆盖（实现见 `internal/bootstrap/wire_settings.go` 的 `materializeProviderDefaults`）；
- **存量端点兜底**：模型构建时（`internal/agent/kernel/factory.go`）若 options 缺省，同样按 `timeout_seconds: 300`、`max_tokens: 8192` 生效（配置文件中不可见）；claude 驱动已有 `max_tokens: 4096` 硬编码。

`max_tokens` 限制的是**单次模型响应**（含推理模型的思考内容），不是整个任务——Agent 多轮循环中每轮独立计算配额。

### 在设置页调整参数

系统设置页的"已连接服务与端点"卡片提供"调用参数"折叠区，可按端点编辑上述 options（`reasoning_effort` 仅对声明了该 capability 的端点显示）。保存走 `PATCH /api/v1/settings` 的 options 子对象（服务端递归深合并，端点其余字段与真实凭据不受影响），`llm` 段属热重载白名单，保存即生效。

## 密钥管理

密钥不进配置文件，解析链（`pkg/llm/registry.go`）：

1. **环境变量**：`SEMANTIC_LLM_API_KEY_<名称大写，'-' 转 '_'>`（如端点名 `deepseek-v4-flash` → `SEMANTIC_LLM_API_KEY_DEEPSEEK_V4_FLASH`）。先按 `service` 名查找，再按端点名，再按同 `base_url` 兄弟端点；
2. **托管密钥库**：Server 启动后可经 Web"系统设置"或 REST（`GET/PUT/DELETE /api/v1/settings/keys/{name}`）托管密钥，由 `KeyStore` 接口兜底。

`.env` 文件（优先级：进程 env > `./.env` > `~/.semantic/.env`）：

```bash
# .env.example 中的示例
SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=sk-xxx
```

无密钥时仅 mock 端点可用，Server 照常启动。

## Run 如何选择模型

- Agent Profile（role.yaml `model` 字段）或会话级覆盖决定使用的端点；未固定时继承系统 `llm.default`；
- **当前版本不允许跨模型自动回退**（`ModelResolution.Fallback` 恒为 false）；
- Run 目的（Purpose：chat / task / workflow_summary / robot_decision 等）只用于计量归因，不参与选型。

## 重试与错误语义

`WithSafeModelRetry`（`kernel/model_retry.go`）实现保守重试：

- **同端点只重试一次**，不换端点；流建立后不重放；
- 仅对结构化可重试错误重试：eino openai `APIError`、anthropic `Error`、网络超时（按错误类型判断，不解析错误字符串）；
- 可重试 HTTP 状态：408、429、5xx（除 501/505）；
- 对只有 ReasoningContent 的 assistant 占位消息（部分推理模型遗留）做历史清洗后再发送。

## 流式与结构化输出

- 对话通道全程流式（`EnableStreaming: true`）；文本增量、ReasoningContent（含 `<think>` 标签拆分）、分帧 Tool Call 在 kernel 内重组后转发；
- **截断自动续写**：响应以 `finish_reason=length` 结束时（生成触及 max_tokens 上限），kernel 自动感知并处理（`internal/agent/kernel/continuation.go`）——正文非空截断会追加"继续"指令自动续写（最多 2 次，用户无感）；思考占满预算、正文为空的截断则返回明确报错并给出调参指引，不再静默空回复。含工具调用的截断不续写；
- **没有 `response_format`/JSON Schema 强约束输出**。结构化输出通过 **tool-call JSON 参数 + 服务端严格校验**实现（典型即 `plan.suggest`：参数 JSON Schema + 服务端 `DisallowUnknownFields`）。

## 用量计量

每次模型调用记录 `MeteringRecord`（`pkg/llm/metering.go`）：

```go
type MeteringRecord struct {
    TraceID      string
    Agent, Role  string
    Model        string
    Purpose      string    // chat / task / ...
    Usage        Usage     // PromptTokens / CompletionTokens / TotalTokens
    CostEstimate float64   // 按 price 配置估算
}
```

查询：`GET /api/v1/metering/summary`、`GET /api/v1/metering/traces/{id}`；Trace 明细：`GET /api/v1/traces`、`GET /api/v1/traces/{trace_id}/spans`。日志记录模型名称、Run ID、耗时、turn 和 token，用于性能分析。

## 接入一个新的模型服务

1. 在 `llm.providers` 下添加端点（`component: openai` 兼容端点最常用），设置 `service`、`base_url`、`model`、`capabilities`；推荐直接在 Web"系统设置"中连接（新端点会自动物化默认 options，且端点卡片支持随时调整参数）；
2. 通过环境变量（`SEMANTIC_LLM_API_KEY_*`）或 Web"系统设置"提供密钥；
3. `make doctor` 检查配置 schema 与密钥可见性；
4. 重启 Server（llm 配置支持热重载，校验全过才原子替换）；
5. 验证：`GET /api/v1/agents` 确认 Agent 解析到的模型；发起对话观察 `run.started` 事件中的 `ModelResolution`（`resolved_endpoint/resolved_model/source`）。

## 测试

```bash
# mock 模型驱动完整 Run（无需外部服务）
go test ./tests/integration/ -run TestChat -count=1
go test ./tests/integration/ -count=1   # 全部集成测试均默认走 mock 端点

# 单元测试
go test ./pkg/llm/... -count=1
```

模型产品测试（真实模型）用于验证 Agent 决策和协作；Robot 运动、接触和停止先通过无模型测试确认（见[测试策略](/developer/reference/build/testing-strategy/)）。
