---
title: "Server Configuration"
linkTitle: "Server configuration"
weight: 13
description: "semantic-server.yaml field reference: load chain, key boundary, field tables for every top-level section, and hot-reload scope. All extracted from pkg/config structs and the configs/semantic-server.yaml template."
---

This page is the factual reference for the Semantic Server config file `semantic-server.yaml`. Every field is extracted from the `semantic-framework` repository (same below) `pkg/config/config.go` (`Config` struct and code defaults) and `configs/semantic-server.yaml` (the only built-in template in the repo; it and `Default()` are two views of the same source of truth). When fields disagree with code, trust the code and please report it.

Robot-instance deployment config (`robot-deployment.yaml`) is not in this file. See [RobotDeployment](deployment.en.md).

## How config is loaded

The main line is the development path `make init` + `make run` (sources: `Makefile`, `cmd/semantic/init.go`, `cmd/semantic-server/main.go`):

1. `make init` first builds binaries, then runs `semantic init -c .output/configs/semantic-server.yaml` and installs the built-in template into `.output/`:
   - Agent and Skill template trees are copied to `<install root>/configs/agents` and `configs/skills` (existing files are kept file by file; user edits are not overwritten);
   - `data/`, `runtimes.d/`, and `content/scene-catalogs/` are created as empty directories. Runtime and scene catalogs are not copied from the development inventory by init; they are created from a formal Runtime Pack by `semantic runtime install` (`installRuntime` in `cmd/semantic/init.go`);
   - The main config is parsed from the template with `config.ParseYAML`, paths are rewritten, then written back: `store.sqlite_path` → `<install root>/data/semantic.db`, `agents.profiles_dir`/`agents.teams_dir`/`skills.dir`/`simulation.runtimes_dir`/`simulation.catalog_dir` → absolute paths of the installed copies.
2. `make run` starts `semantic-server` with `.output/configs/semantic-server.yaml` — runtime reads the installed copy, not the read-only template in the repository (the template header comment says "do not write this file back at runtime").
3. `semantic-server` startup order: load `.env` first, then load config, then `bootstrap.Wire` assembles and enables hot reload as needed (`cmd/semantic-server/main.go`).

Config file path resolution priority: explicit `-c` > environment variable `SEMANTIC_CONFIG` > the current user's default install path `~/.semantic/configs/semantic-server.yaml` (`ResolvePath` in `pkg/config/path.go`). The resolved path is the only target for startup load, hot reload, and settings API write-back, so the frontend cannot accidentally write settings back to the repository template.

### Config source priority

The final effective value is overlaid in this order (higher overrides lower; source `pkg/config/doc.go`):

```text
Process env (SEMANTIC_ prefix) > ./.env > ~/.semantic/.env > config file (yaml) > in-code defaults
```

- `.env` is read into process env early by `config.LoadDotEnv` and **does not overwrite existing keys**, so the first-loaded `./.env` naturally overrides the user-level `~/.semantic/.env` (`pkg/config/dotenv.go`);
- yaml is strictly validated before load (fail-closed): unknown keys and type errors are aggregated by full yaml path (`validateYAML` in `pkg/config/validate.go`). Failed validation fails startup immediately and does not silently ignore typos;
- Environment-variable overrides are applied after yaml (`applyEnv` in `pkg/config/config.go`). The full list is in [Environment-variable overrides](#environment-variable-overrides) below.

## Key boundary

The template header convention: **secret-class config is read only from environment variables and must not be written into `semantic-server.yaml`**. Enforcement in code:

- **LLM API key** does not enter the config struct (`LLMProviderConfig` has no api_key field). Keys are resolved per endpoint (`apiKey` in `pkg/llm/registry.go`), in this order:
  1. Process env (including `.env` injection) `SEMANTIC_LLM_API_KEY_<SERVICE IN UPPER CASE>` (falls back to the endpoint name when service is undeclared; `-` becomes `_`, for example endpoint `deepseek-chat` → `SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT`);
  2. env `SEMANTIC_LLM_API_KEY_<ENDPOINT IN UPPER CASE>`;
  3. env of sibling endpoints that share the same `base_url` (first set one, by name order);
  4. Server-hosted key store (written from frontend "System settings"; REST is `/api/v1/settings/keys/*`; values are always masked; service name first, then endpoint name).
  Resolution results are cached by endpoint name. The cache is cleared and re-read after config hot reload or a hosted-key write. Without a key only the `mock` endpoint is available. The service does not block startup.
- **Admin seed password** comes from environment variable `SEMANTIC_ADMIN_PASSWORD`. When unset it is `admin123` and a WARN asks you to change it (see the auth section of [HTTP API](http.en.md)).
- **MCP stdio child-process** keys should be injected into the child environment through `.env` (template `mcp_servers` section comments).
- `.env` hot reload and audit logs record only key names, never values (`pkg/config/dotenv.go`, `pkg/config/reload.go`).

## Config section field tables

Defaults below come from the `configs/semantic-server.yaml` template (the initial values of the `make init` installed copy). Differences from code `Default()` are called out separately. Types follow Go struct fields.

### server: HTTP/WS listen

Source: `pkg/config/config.go` (`ServerConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `http_addr` | string | `:8080` | HTTP gateway listen address. Carries all REST endpoints and the Pilot transfer entry |
| `ws_addr` | string | `:8081` | WebSocket gateway listen address. Carries `/ws/*` channels |
| `read_timeout` | duration | `10s` | HTTP request read timeout; write it as a `"10s"`-style string in yaml |
| `write_timeout` | duration | `30s` | HTTP response write timeout. The template comment requires covering the Runtime first-start wait window of up to 20 seconds; <!-- TODO(实跑或确认): 代码 Default() 为 10s，与模板 30s 不一致，确认发布口径以哪个为准 --> |

### log: logging

Source: `pkg/config/config.go` (`LogConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `level` | string | `info` | Minimum log output level: `trace`/`debug`/`info`/`warn`/`error`/`fatal` |

Runtime log file location is derived from `store.sqlite_path`: a standard install is `<instance root>/logs/semantic-server.jsonl` (`pkg/log/runtime_file.go`). It is not written into this config.

### store: metadata storage

Source: `pkg/config/config.go` (`StoreConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `driver` | string | `sqlite` | Metadata storage driver. Currently `sqlite` (zero external dependencies) |
| `sqlite_path` | string | `.output/semantic.db` | SQLite file path. Template placeholder; `semantic init` rewrites it to `<install root>/data/semantic.db` |

### llm: model providers

Source: `pkg/config/config.go` (`LLMConfig`, `LLMProviderConfig`), `pkg/llm/registry.go` (validation and key resolution).

| Field | Type | Default | Description |
|---|---|---|---|
| `default` | string | `mock` | Global default model name. Must be an entry name in `providers`, or startup fails |
| `providers` | map[string]object | only the `mock` endpoint | Model endpoint list. The key is the unique endpoint id. Use a neutral model name, not a purpose binding |

Subfields of `providers.<name>`:

| Field | Type | Required | Description |
|---|---|---|---|
| `service` | string | No | Model-service identifier (for example `openai`/`deepseek`). Endpoints that share a service share credentials. When undeclared, fall back to the endpoint name |
| `component` | string | Yes | Kernel driver: `openai` (OpenAI-compatible) / `claude` (Anthropic Messages API) / `mock` (no-key development tests). An unknown driver errors at startup and on hot reload |
| `base_url` | string | No | Model-service address. When empty, claude uses the official SDK default |
| `model` | string | Yes | Model ID on the endpoint |
| `capabilities` | []string | No | Capability tags: `text` / `image` / `tool_call` / `embedding` |
| `options` | map[string]any | No | Default call parameters. Whitelist: `temperature` / `max_tokens` / `reasoning_effort` / `timeout_seconds`. Unrecognized keys error at startup and hot reload (`applyOptions` in `internal/agent/kernel/factory.go`) |
| `price` | object | No | Per-1K-token unit price for metering estimates: `prompt`, `completion` (float64) |

The template ships only the `mock` endpoint. Real model endpoints are added from frontend "System settings" (written into the installed-copy config and hot-applied through the settings API). The install-template comment: a new openai endpoint automatically materializes default `timeout_seconds: 300` and `max_tokens: 8192`. Endpoint-level details are in developer docs `extension-development/model-provider` (semantic-framework repo).

### agents: Agent runtime

Source: `pkg/config/config.go` (`AgentsConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `profiles_dir` | string | `configs/agents` | Role profile root. Template relative path; `semantic init` rewrites it to the installed-copy absolute path |
| `teams_dir` | string | `configs/agents/teams` | Team definition directory. A missing directory is treated as no Team configured (single-leader mode) |

### skills: skill system

Source: `pkg/config/config.go` (`SkillsConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `dir` | string | `configs/skills` | Skill root (one directory per skill containing SKILL.md; nested category subdirectories are allowed). File changes inside the directory are hot-reloaded by the store watcher (500ms debounce) |

### execution: command-execution hard boundary

Source: `pkg/config/config.go` (`ExecutionConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `allow_host` | bool | `false` | Whether a session may explicitly enable host command execution. This is a server-side hard boundary. Frontend/session can only tighten or temporarily enable inside it, and cannot break a server-disabled state |

### simulation: simulation Runtime and scenes

Source: `pkg/config/config.go` (`SimulationConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `runtimes_dir` | string | `configs/runtimes.d` | Runtime install inventory directory. Each YAML may declare only fixed-structure launch parameters and does not execute a shell. Template relative path; `semantic init` rewrites it to `<install root>/runtimes.d` |
| `catalog_dir` | string | `configs/scenes.d` | Offline scene catalog (admin-maintained). `semantic init` rewrites it to `<install root>/content/scene-catalogs` |

### robot_runtime: Server-hosted simulation Robots

Source: `pkg/config/config.go` (`RobotRuntimeConfig`).

| Field | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `false` | Whether the Server hosts simulation Robot instances. Enable after installing a built Robot type package |
| `bundles_dir` | string | `.output/robot-bundles` | Robot type-package (RobotRuntimeBundle) directory |
| `data_root` | string | `.output` | Root of instance writable data |
| `server_http_url` | string | `http://127.0.0.1:8080` | HTTP address instances use to call back to the Server |
| `server_websocket_url` | string | `ws://127.0.0.1:8081/ws/pilot` | Pilot WebSocket address instances use to call back to the Server |
| `ability_port_first` | int | `18100` | Start of the managed-instance AbilityFramework port pool |
| `ability_port_last` | int | `18199` | End of the managed-instance AbilityFramework port pool |

### mcp_servers: MCP connection list

Source: `pkg/config/config.go` (`MCPServerConfig`). The list defaults to empty (`[]`). R16 mcpregistry consumes this section, connects each server, discovers tools, and merges them into the catalog. Transport supports only `http` (streamable, remote/satellite) and `stdio` (local sidecar).

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Unique server id, also the tool namespace (tool names look like `<name>.<tool>`) |
| `transport` | string | — | `http` (streamable) or `stdio` |
| `endpoint` | string | — | MCP endpoint URL for streamable HTTP. Required for `http` transport |
| `command` | string | — | stdio child executable. Required for `stdio` transport |
| `args` | []string | — | stdio child arguments |
| `env` | []string | — | Extra environment variables for the child (`K=V` form). Prefer injecting secrets through `.env` |
| `enabled` | bool | — | `false` keeps the config but does not connect |
| `namespace` | string | — | Reserved. Today `name` is the namespace and this field is unused |
| `risk` | string | `medium` | Risk-level override for all tools on this server: `low`/`medium`/`high`/`critical` (empty = medium). Write-class servers should raise it explicitly (high triggers human approval) |

## Environment-variable overrides

`applyEnv` in `pkg/config/config.go` lists every overridable key. Prefix `SEMANTIC_`; nested fields are separated by `_`. Illegal durations and numbers fail startup immediately. List-class config cannot be overridden key by key.

| Config item | Environment variable |
|---|---|
| `server.http_addr` / `server.ws_addr` | `SEMANTIC_SERVER_HTTP_ADDR` / `SEMANTIC_SERVER_WS_ADDR` |
| `server.read_timeout` / `server.write_timeout` | `SEMANTIC_SERVER_READ_TIMEOUT` / `SEMANTIC_SERVER_WRITE_TIMEOUT` |
| `log.level` | `SEMANTIC_LOG_LEVEL` |
| `store.driver` / `store.sqlite_path` | `SEMANTIC_STORE_DRIVER` / `SEMANTIC_STORE_SQLITE_PATH` |
| `agents.profiles_dir` / `agents.teams_dir` | `SEMANTIC_AGENTS_PROFILES_DIR` / `SEMANTIC_AGENTS_TEAMS_DIR` |
| `skills.dir` | `SEMANTIC_SKILLS_DIR` |
| `simulation.runtimes_dir` / `simulation.catalog_dir` | `SEMANTIC_SIMULATION_RUNTIMES_DIR` / `SEMANTIC_SIMULATION_CATALOG_DIR` |
| `robot_runtime.enabled` | `SEMANTIC_ROBOT_RUNTIME_ENABLED` |
| `robot_runtime.bundles_dir` / `robot_runtime.data_root` | `SEMANTIC_ROBOT_RUNTIME_BUNDLES_DIR` / `SEMANTIC_ROBOT_RUNTIME_DATA_ROOT` |
| `robot_runtime.server_http_url` / `server_websocket_url` | `SEMANTIC_ROBOT_RUNTIME_SERVER_HTTP` / `SEMANTIC_ROBOT_RUNTIME_SERVER_WS` |
| `robot_runtime.ability_port_first` / `ability_port_last` | `SEMANTIC_ROBOT_RUNTIME_PORT_FIRST` / `SEMANTIC_ROBOT_RUNTIME_PORT_LAST` |
| `llm.default` | `SEMANTIC_LLM_DEFAULT` |
| `mcp_servers` (JSON array, replaced as a whole) | `SEMANTIC_MCP_SERVERS` |
| LLM API key (by endpoint/service) | `SEMANTIC_LLM_API_KEY_<NAME IN UPPER CASE, '-' BECOMES '_'>` |
| Admin seed password | `SEMANTIC_ADMIN_PASSWORD` |

## How a config change takes effect

The Server has built-in config hot reload (`pkg/config/reload.go`, assembled in `internal/bootstrap/wire_reload.go`): Reloader watches the config file and the directory of `./.env`. Changes reload and re-validate after a 500ms debounce. On validation failure or a hot-apply hook failure it **keeps the old config running**, logs only ERROR, and does not let one bad write take the service down. Frontend "System settings" PATCH (`PATCH /api/v1/settings`, with `base_hash` optimistic lock) writes the config file and then takes the same whitelist hot-apply path (`Reloader.ApplyExternal`).

Whitelist sections: after a change, **no restart** is needed. Hot apply takes effect.

| Config section | Hot-apply behavior |
|---|---|
| `llm.*` | Atomically replace the registry snapshot and clear the key cache. Idle model Runners are evicted immediately. In-flight Runners are evicted after the current turn (existing sessions do not switch models mid-run) |
| `log.level` | Logger level takes effect immediately |
| `agents.profiles_dir` | Rebuild the profile loader and preload leader validation; replace atomically after it passes. In-flight sessions still hold the old profile snapshot. New sessions are built through the new loader |
| `skills.dir` | Atomically replace the skill snapshot and switch the watched directory set. File changes inside the directory are already hot-reloaded by the store watcher (500ms debounce) |
| `mcp_servers` | Reconcile sync items against the old and new lists: start sync for adds, stop sync for deletes, rebuild on changes. Catalog changes take effect on the next Agent prepare |
| `execution.*` | The server-side host-execution master switch tightens or opens immediately. Existing sessions do not automatically gain permission from a global-switch change |

Sections that need a restart (outside the whitelist):

- `server.*`, `store.*`, `agents.teams_dir`: a change logs a WARN "needs restart to take effect". Team assembly finishes in the startup sequence and is not rebuilt at runtime;
- `simulation.*`, `robot_runtime.*`: not on the hot-apply whitelist; need a process restart; <!-- TODO(实跑或确认): reload.go 的 restartOnlyDiffs 未包含这两段，变更时不会打"需重启"WARN（静默等到重启），确认是否为预期行为 -->
- **File-content** changes such as role.yaml inside `agents.profiles_dir`: <!-- TODO(实跑或确认): 代码未见对 profiles 目录内容的监听，确认角色文件修改是否只能经重启或修改 profiles_dir 触发重建生效 -->

Instance directories, databases, Runtime installs, and other data owned by subsystems are outside this config. Ops locations are summarized in the user-manual operations and troubleshooting chapters.

## How to verify

- Structural validation: `semantic doctor -c <config path>` runs CLI self-check on the installed copy (`cmd/semantic/doctor.go`, `make doctor`);
- Startup confirmation: `semantic-server` startup logs print "配置加载完成" plus the resolved `path`, `http_addr`, `ws_addr`, `log_level`, and `store_driver` (`cmd/semantic-server/main.go`);
- Online view of the effective snapshot: `GET /api/v1/settings` (sensitive values masked). Changes go through `PATCH /api/v1/settings`. See the settings domain in [HTTP API](http.en.md).
