---
title: "Server 配置"
linkTitle: "Server 配置"
weight: 13
description: "semantic-server.yaml 字段参考：配置加载链、密钥边界、全部顶层配置段的字段表与热重载生效范围，全部从 pkg/config 结构体与 configs/semantic-server.yaml 模板提取。"
---

本文是 Semantic Server 配置文件 `semantic-server.yaml` 的事实参考。全部字段提取自 semantic-framework 仓库（下同）的 `pkg/config/config.go`（`Config` 结构体与代码默认值）和 `configs/semantic-server.yaml`（全仓唯一内置模板，与 `Default()` 互为同一事实源的两个视图）。字段与代码不一致时，以代码为准并请反馈。

Robot 实例侧的部署配置（`robot-deployment.yaml`）不在此文件中，见 [RobotDeployment](/developer/reference/api/deployment/)。

## 配置加载方式

以开发环境 `make init` + `make run` 为主线（来源：`Makefile`、`cmd/semantic/init.go`、`cmd/semantic-server/main.go`）：

1. `make init` 先构建二进制，再执行 `semantic init -c .output/configs/semantic-server.yaml`，把内置模板安装到 `.output/`：
   - Agent 与 Skill 模板树复制到 `<安装根>/configs/agents`、`configs/skills`（逐文件保留已有文件，不覆盖用户修改）；
   - `data/`、`runtimes.d/`、`content/scene-catalogs/` 建立为空目录；Runtime 与场景目录不由 init 复制开发清单，而是由 `semantic runtime install` 从正式 Runtime Pack 建立（`cmd/semantic/init.go` 的 `installRuntime`）；
   - 主配置由模板经 `config.ParseYAML` 解析后重写路径再写回：`store.sqlite_path` → `<安装根>/data/semantic.db`，`agents.profiles_dir`/`agents.teams_dir`/`skills.dir`/`simulation.runtimes_dir`/`simulation.catalog_dir` → 安装副本绝对路径。
2. `make run` 以 `.output/configs/semantic-server.yaml` 启动 `semantic-server`——运行时读取的是安装副本，不是仓库里的只读模板（模板头部注释明确"运行期禁止写回本文件"）。
3. `semantic-server` 启动顺序：先加载 `.env`，再加载配置，随后 `bootstrap.Wire` 装配并按需启用热重载（`cmd/semantic-server/main.go`）。

配置文件路径解析优先级为：`-c` 显式参数 > 环境变量 `SEMANTIC_CONFIG` > 当前用户的默认安装路径 `~/.semantic/configs/semantic-server.yaml`（`pkg/config/path.go` 的 `ResolvePath`）。解析结果同时是启动加载、热重载与设置 API 写回的唯一目标，避免前端把设置误写回仓库模板。

### 配置来源优先级

最终生效值按以下优先级覆盖（高覆盖低，来源 `pkg/config/doc.go`）：

```text
进程环境变量（SEMANTIC_ 前缀） > ./.env > ~/.semantic/.env > 配置文件（yaml） > 代码内默认值
```

- `.env` 在启动早期由 `config.LoadDotEnv` 读入进程 env，**不覆盖已存在的键**，因此先加载的 `./.env` 自然压住用户级 `~/.semantic/.env`（`pkg/config/dotenv.go`）；
- yaml 加载前经严格校验（fail-closed）：未知键与类型错误按完整 yaml 路径聚合报出（`pkg/config/validate.go` 的 `validateYAML`），校验不过直接启动失败，不会静默忽略笔误；
- 环境变量覆盖在 yaml 之后应用（`pkg/config/config.go` 的 `applyEnv`），完整清单见下文[环境变量覆盖](#环境变量覆盖)。

## 密钥边界

模板头部约定：**密钥类配置只从环境变量读取，禁止写入 `semantic-server.yaml`**。代码中的落实：

- **LLM API key** 不进入配置结构体（`LLMProviderConfig` 没有 api_key 字段）。密钥按端点解析（`pkg/llm/registry.go` 的 `apiKey`），顺序为：
  1. 进程 env（含 `.env` 注入）`SEMANTIC_LLM_API_KEY_<service 大写>`（service 未声明时回退端点名；`-` 转 `_`，如端点 `deepseek-chat` → `SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT`）；
  2. env `SEMANTIC_LLM_API_KEY_<端点大写>`；
  3. 同一 `base_url` 的兄弟端点的 env（按名称序取第一个已设置的）；
  4. 服务端托管密钥库（前端"系统设置"写入，REST 见 `/api/v1/settings/keys/*`，值始终掩码，先 service 名后端点名）。
  解析结果按端点名缓存；配置热重载或托管密钥写入后缓存清空重读。无 key 时仅 `mock` 端点可用，服务不阻塞启动。
- **管理员种子密码**取环境变量 `SEMANTIC_ADMIN_PASSWORD`，未设置时为 `admin123` 并 WARN 提示修改（见 [HTTP API](/developer/reference/api/http/) 认证一节）。
- **MCP stdio 子进程**的密钥建议经 `.env` 注入子进程环境（模板 `mcp_servers` 段注释）。
- `.env` 热重载与审计日志只记录键名，绝不记录值（`pkg/config/dotenv.go`、`pkg/config/reload.go`）。

## 配置段字段表

以下默认值取自 `configs/semantic-server.yaml` 模板（即 `make init` 安装副本的初始值）；与代码 `Default()` 不一致处单独标注。类型以 Go 结构体字段为准。

### server：HTTP/WS 监听

源码：`pkg/config/config.go`（`ServerConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `http_addr` | string | `:8080` | HTTP 网关监听地址，承载全部 REST 端点与 Pilot 传输入口 |
| `ws_addr` | string | `:8081` | WebSocket 网关监听地址，承载 `/ws/*` 通道 |
| `read_timeout` | duration | `10s` | HTTP 请求读取超时；yaml 中写 `"10s"` 风格字符串 |
| `write_timeout` | duration | `30s` | HTTP 响应写入超时。模板注释要求覆盖 Runtime 首次启动最长 20 秒的等待窗口；<!-- TODO(实跑或确认): 代码 Default() 为 10s，与模板 30s 不一致，确认发布口径以哪个为准 --> |

### log：日志

源码：`pkg/config/config.go`（`LogConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `level` | string | `info` | 日志最低输出级别：`trace`/`debug`/`info`/`warn`/`error`/`fatal` |

运行日志文件位置由 `store.sqlite_path` 推导：标准安装为 `<实例根>/logs/semantic-server.jsonl`（`pkg/log/runtime_file.go`），不写入本配置。

### store：元数据存储

源码：`pkg/config/config.go`（`StoreConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `driver` | string | `sqlite` | 元数据存储驱动，当前支持 `sqlite`（零外部依赖） |
| `sqlite_path` | string | `.output/semantic.db` | SQLite 文件路径；模板占位值，`semantic init` 改写为 `<安装根>/data/semantic.db` |

### llm：模型提供方

源码：`pkg/config/config.go`（`LLMConfig`、`LLMProviderConfig`）、`pkg/llm/registry.go`（校验与密钥解析）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `default` | string | `mock` | 全局默认模型名，必须是 `providers` 中的条目名，否则启动失败 |
| `providers` | map[string]object | 仅 `mock` 一个端点 | 模型端点清单；键即端点唯一标识，使用中立模型名，不绑定用途 |

`providers.<名称>` 的子字段：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `service` | string | 否 | 模型服务标识（如 `openai`/`deepseek`）；同服务端点共享凭据；未声明时回退端点名 |
| `component` | string | 是 | 内核驱动：`openai`（OpenAI 兼容）/ `claude`（Anthropic Messages API）/ `mock`（无 key 开发测试）；未知驱动启动与热重载均报错 |
| `base_url` | string | 否 | 模型服务地址；claude 留空时使用官方 SDK 默认地址 |
| `model` | string | 是 | 端点上的模型 ID |
| `capabilities` | []string | 否 | 能力标签：`text` / `image` / `tool_call` / `embedding` |
| `options` | map[string]any | 否 | 调用默认参数，白名单：`temperature` / `max_tokens` / `reasoning_effort` / `timeout_seconds`；未识别的键在启动与热重载时报错（`internal/agent/kernel/factory.go` 的 `applyOptions`） |
| `price` | object | 否 | 每 1K tokens 单价，计量估算用：`prompt`、`completion`（float64） |

模板仅内置 `mock` 端点；真实模型端点从前端"系统设置"添加（写入安装副本配置并经 settings API 热应用）。安装模板注释约定：新增 openai 端点会自动物化默认 `timeout_seconds: 300` 与 `max_tokens: 8192`。端点级详细说明见开发者文档 `extension-development/model-provider`（semantic-framework 仓）。

### agents：Agent 运行时

源码：`pkg/config/config.go`（`AgentsConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `profiles_dir` | string | `configs/agents` | 角色 profile 根目录；模板相对路径，`semantic init` 改写为安装副本绝对路径 |
| `teams_dir` | string | `configs/agents/teams` | Team 定义目录；目录不存在视为未配置 Team（单 leader 模式） |

### skills：技能系统

源码：`pkg/config/config.go`（`SkillsConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `dir` | string | `configs/skills` | 技能根目录（每技能一目录含 SKILL.md，支持分类子目录嵌套）；目录内文件变更经 store 监听自动热更（500ms 去抖） |

### execution：命令执行硬边界

源码：`pkg/config/config.go`（`ExecutionConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `allow_host` | bool | `false` | 是否允许会话显式开启宿主命令执行；服务端硬边界，前端/会话只能在其内收紧或临时开启，不能突破服务端禁用状态 |

### simulation：仿真 Runtime 与场景

源码：`pkg/config/config.go`（`SimulationConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `runtimes_dir` | string | `configs/runtimes.d` | Runtime 安装清单目录；每个 YAML 只允许声明固定结构的启动参数，不执行 shell。模板相对路径，`semantic init` 改写为 `<安装根>/runtimes.d` |
| `catalog_dir` | string | `configs/scenes.d` | 离线场景目录（管理员维护）；`semantic init` 改写为 `<安装根>/content/scene-catalogs` |

### robot_runtime：Server 托管的仿真 Robot

源码：`pkg/config/config.go`（`RobotRuntimeConfig`）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `enabled` | bool | `false` | Server 是否托管仿真 Robot 实例；需安装构建完成的 Robot 类型包后启用 |
| `bundles_dir` | string | `.output/robot-bundles` | Robot 类型包（RobotRuntimeBundle）目录 |
| `data_root` | string | `.output` | 实例可写数据的根目录 |
| `server_http_url` | string | `http://127.0.0.1:8080` | 实例回连 Server 的 HTTP 地址 |
| `server_websocket_url` | string | `ws://127.0.0.1:8081/ws/pilot` | 实例回连 Server 的 Pilot WebSocket 地址 |
| `ability_port_first` | int | `18100` | 受管实例 AbilityFramework 端口池起始 |
| `ability_port_last` | int | `18199` | 受管实例 AbilityFramework 端口池结束 |

### mcp_servers：MCP 连接清单

源码：`pkg/config/config.go`（`MCPServerConfig`）。列表默认为空（`[]`）；R16 mcpregistry 消费本段，连接各 server 发现工具并入目录。传输只支持 `http`（streamable，远程/卫星）与 `stdio`（本地 sidecar）。

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `name` | string | — | server 唯一标识，即工具命名空间（工具名形如 `<name>.<tool>`） |
| `transport` | string | — | `http`（streamable）或 `stdio` |
| `endpoint` | string | — | streamable HTTP 的 MCP endpoint URL；`http` 传输必填 |
| `command` | string | — | stdio 子进程可执行文件；`stdio` 传输必填 |
| `args` | []string | — | stdio 子进程参数 |
| `env` | []string | — | 追加到子进程的环境变量（`K=V` 形式）；密钥建议走 `.env` 注入 |
| `enabled` | bool | — | `false` 保留配置但不连接 |
| `namespace` | string | — | 预留字段，当前以 `name` 作为命名空间，本字段暂未消费 |
| `risk` | string | `medium` | 该 server 全部工具的风险等级覆盖：`low`/`medium`/`high`/`critical`（空 = medium）；写操作类 server 应显式提级（high 触发人工审批） |

## 环境变量覆盖

`pkg/config/config.go` 的 `applyEnv` 逐一列出了可覆盖键；前缀 `SEMANTIC_`，嵌套字段以 `_` 分隔。时长与数值非法时启动直接报错；列表类配置无法逐键覆盖。

| 配置项 | 环境变量 |
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
| `mcp_servers`（JSON 数组，整体替换） | `SEMANTIC_MCP_SERVERS` |
| LLM API key（按端点/服务） | `SEMANTIC_LLM_API_KEY_<名称大写，'-' 转 '_'>` |
| 管理员种子密码 | `SEMANTIC_ADMIN_PASSWORD` |

## 配置修改的生效方式

Server 内置配置热重载（`pkg/config/reload.go`，装配在 `internal/bootstrap/wire_reload.go`）：Reloader 监听配置文件与 `./.env` 所在目录，变更经 500ms 去抖后重新加载并校验；校验失败或热应用钩子失败时**保持旧配置运行**，只记 ERROR，不让一次坏写入打挂服务。前端"系统设置"的 PATCH（`PATCH /api/v1/settings`，带 `base_hash` 乐观锁）写回配置文件后走同一条白名单热应用路径（`Reloader.ApplyExternal`）。

白名单内配置段：修改后**无需重启**，热应用生效。

| 配置段 | 热应用行为 |
|---|---|
| `llm.*` | 原子替换注册表快照并清空密钥缓存；空闲模型 Runner 立即淘汰，运行中 Runner 在本轮结束后淘汰（已存在会话不中途换模型） |
| `log.level` | logger 级别即时生效 |
| `agents.profiles_dir` | 重建 profile 加载器并预加载 leader 校验，通过后原子替换；运行中的会话仍持旧 profile 快照，新会话经新加载器构建 |
| `skills.dir` | 原子替换技能快照并切换监听目录集；目录内文件变更本就由 store 监听自动热更（500ms 去抖） |
| `mcp_servers` | 按新旧清单对账同步项：新增启动同步、删除停同步、变更重建；目录变化在下轮 Agent 准备时生效 |
| `execution.*` | 服务端宿主执行总开关立即收紧或放开；已有会话不因全局开关变化自动取得权限 |

需重启生效的配置段（白名单外）：

- `server.*`、`store.*`、`agents.teams_dir`：变更时打 WARN 日志"需重启生效"；Team 组建在启动序列完成，运行中不重组；
- `simulation.*`、`robot_runtime.*`：不在热应用白名单，需重启进程生效；<!-- TODO(实跑或确认): reload.go 的 restartOnlyDiffs 未包含这两段，变更时不会打"需重启"WARN（静默等到重启），确认是否为预期行为 -->
- `agents.profiles_dir` 目录内 role.yaml 等**文件内容**变更：<!-- TODO(实跑或确认): 代码未见对 profiles 目录内容的监听，确认角色文件修改是否只能经重启或修改 profiles_dir 触发重建生效 -->

实例目录、数据库、Runtime 安装等由各子系统自治的数据不在本配置管理范围；运维位置汇总见用户手册的运维与排错章节。

## 验证方式

- 结构校验：`semantic doctor -c <配置路径>` 对安装副本运行 CLI 自检（`cmd/semantic/doctor.go`，`make doctor`）；
- 启动确认：`semantic-server` 启动日志输出"配置加载完成"及解析后的 `path`、`http_addr`、`ws_addr`、`log_level`、`store_driver`（`cmd/semantic-server/main.go`）；
- 在线查看生效快照：`GET /api/v1/settings`（敏感值掩码），修改走 `PATCH /api/v1/settings`，见 [HTTP API](/developer/reference/api/http/) 设置域一节。
