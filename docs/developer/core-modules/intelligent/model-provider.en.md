---
title: "Model Provider"
weight: 30
description: "Configure the model service used by Agent Runs: Provider registration, request adaptation, streaming, and usage metering."
---

A Model Provider connects a Semantic Agent Run to a concrete model service. It handles request format, streaming, Tool Calls, usage metering, and error retries.

Implementation locations:

- Provider registry and key resolution: `pkg/llm/` in `semantic-framework` (registry.go, metering.go)
- Model drivers: `internal/agent/kernel/factory.go`, `model_retry.go`
- Config: the `llm` section of `configs/semantic-server.yaml`, plus environment variables / managed keys

## Supported drivers

`component` accepts only three values (an unknown driver fails closed at startup):

| component | Description | Key |
|---|---|---|
| `openai` | **OpenAI-compatible endpoint** (DeepSeek, vLLM, and similar all use this driver). `base_url` is required | Required |
| `claude` | Anthropic Claude. `base_url` is optional (proxy) | Required |
| `mock` | Built-in mock model for tests and offline development | Not required |

Other backends (gemini/ollama/ark) are not implemented.

## Configuration format

`llm` section of `configs/semantic-server.yaml`:

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

Field notes:

- `service`: service identifier. Endpoints that share a service share credentials;
- `capabilities`: `text / image / tool_call / embedding`;
- `options` whitelist: `temperature`, `max_tokens`, `reasoning_effort` (low/medium/high), `timeout_seconds`. **Unrecognized keys fail immediately** (the settings API pre-validates them as 400 on save). Default request timeout is 5 minutes.

### options defaults

To keep OpenAI-compatible services (for example llama.cpp, whose `n_predict` default is unbounded) from generating forever when the model never emits a stop token, the system applies two layers of default protection:

- **New endpoint materialization**: when you add an `openai` driver endpoint through Web "System settings" or `PATCH /api/v1/settings` and omit options, the server writes `timeout_seconds: 300` and `max_tokens: 8192`. They are visible in the config file and settings UI and can be overridden per endpoint (see `materializeProviderDefaults` in `internal/bootstrap/wire_settings.go`);
- **Existing endpoint fallback**: when the model is built (`internal/agent/kernel/factory.go`), missing options still take effect as `timeout_seconds: 300` and `max_tokens: 8192` (not written into the config file). The claude driver already hard-codes `max_tokens: 4096`.

`max_tokens` limits a **single model response** (including reasoning content from reasoning models), not the whole task. Each turn in a multi-turn Agent loop has its own quota.

### Adjust parameters on the settings page

The "Connected services and endpoints" card on the system settings page has a "Call parameters" fold. You can edit the options above per endpoint (`reasoning_effort` appears only for endpoints that declare that capability). Save uses the options sub-object of `PATCH /api/v1/settings` (the server deep-merges recursively; other endpoint fields and real credentials are unchanged). The `llm` section is on the hot-reload whitelist, so a save takes effect immediately.

## Key management

Keys do not go into the config file. Resolution chain (`pkg/llm/registry.go`):

1. **Environment variables**: `SEMANTIC_LLM_API_KEY_<NAME IN UPPER CASE, '-' BECOMES '_'>` (endpoint `deepseek-v4-flash` → `SEMANTIC_LLM_API_KEY_DEEPSEEK_V4_FLASH`). Look up by `service` name first, then by endpoint name, then by sibling endpoints that share the same `base_url`;
2. **Managed key store**: after the Server starts, you can host keys through Web "System settings" or REST (`GET/PUT/DELETE /api/v1/settings/keys/{name}`). The `KeyStore` interface is the fallback.

`.env` file (priority: process env > `./.env` > `~/.semantic/.env`):

```bash
# .env.example 中的示例
SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=sk-xxx
```

Without a key, only the mock endpoint is available. The Server still starts.

## How a Run chooses a model

- The Agent Profile (`model` in role.yaml) or a session-level override selects the endpoint. If none is fixed, the system `llm.default` is inherited;
- **This version does not allow automatic cross-model fallback** (`ModelResolution.Fallback` is always false);
- Run purpose (Purpose: chat / task / workflow_summary / robot_decision, and so on) is used only for metering attribution, not for model selection.

## Retry and error semantics

`WithSafeModelRetry` (`kernel/model_retry.go`) implements conservative retries:

- **Retry the same endpoint once only.** Do not switch endpoints. Do not replay after a stream is established;
- Retry only structured retryable errors: eino openai `APIError`, anthropic `Error`, and network timeouts (classified by error type, not by parsing error strings);
- Retryable HTTP statuses: 408, 429, 5xx (except 501/505);
- Assistant placeholder messages that contain only ReasoningContent (leftovers from some reasoning models) are cleaned from history before the next send.

## Streaming and structured output

- The conversation channel is fully streamed (`EnableStreaming: true`). Text deltas, ReasoningContent (including `<think>` tag splitting), and framed Tool Calls are reassembled in the kernel and then forwarded;
- **Automatic continuation on truncation**: when a response ends with `finish_reason=length` (generation hit the max_tokens limit), the kernel detects and handles it (`internal/agent/kernel/continuation.go`). A non-empty truncated body appends a "continue" instruction and continues automatically (at most 2 times, invisible to the user). A truncation that fills the thinking budget and leaves an empty body returns an explicit error with parameter-tuning guidance instead of a silent empty reply. Truncations that include tool calls are not continued;
- **There is no `response_format` / JSON Schema hard constraint on output.** Structured output is implemented with **tool-call JSON parameters plus strict server-side validation** (the typical case is `plan.suggest`: parameter JSON Schema plus server-side `DisallowUnknownFields`).

## Usage metering

Every model call records a `MeteringRecord` (`pkg/llm/metering.go`):

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

Query: `GET /api/v1/metering/summary`, `GET /api/v1/metering/traces/{id}`; Trace details: `GET /api/v1/traces`, `GET /api/v1/traces/{trace_id}/spans`. Logs record model name, Run ID, duration, turn, and tokens for performance analysis.

## Connect a new model service

1. Add an endpoint under `llm.providers` (`component: openai` is the most common compatible endpoint) and set `service`, `base_url`, `model`, and `capabilities`. Prefer connecting in Web "System settings" (new endpoints materialize default options, and the endpoint card lets you adjust parameters at any time);
2. Provide a key through an environment variable (`SEMANTIC_LLM_API_KEY_*`) or Web "System settings";
3. Run `make doctor` to check the config schema and key visibility;
4. Restart the Server (llm config supports hot reload; replacement is atomic only after validation passes);
5. Verify: `GET /api/v1/agents` to confirm the model each Agent resolved; start a conversation and inspect `ModelResolution` (`resolved_endpoint/resolved_model/source`) on the `run.started` event.

## Tests

```bash
# mock 模型驱动完整 Run（无需外部服务）
go test ./tests/integration/ -run TestChat -count=1
go test ./tests/integration/ -count=1   # 全部集成测试均默认走 mock 端点

# 单元测试
go test ./pkg/llm/... -count=1
```

Real-model product tests verify Agent decisions and collaboration. Robot motion, contact, and stop are confirmed first with model-free tests (see [Testing strategy](../../reference/build/testing-strategy.en.md)).
