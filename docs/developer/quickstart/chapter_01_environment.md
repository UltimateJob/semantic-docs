---
title: "第一章：工作区、代码与最小 Server"
linkTitle: "第 1 章：工作区"
weight: 21
description: "从零准备 Semantic 多仓工作区，并启动一个可登录、可访问的最小 Semantic Server。"
---

**本章目标**：完成代码、工具链、工作区变量和最小 Server。完成后，你应能通过浏览器或 REST 登录 Server，并为下一章准备 Runtime。

## 你需要准备什么

| 项目 | 要求 | 验证 |
|---|---|---|
| 操作系统 | Linux 开发机 | `uname -a` |
| Go | 1.23 | `go version` |
| Node.js / npm | 22+ | `node --version` |
| Python | 按仓库要求，常用 3.11+ | `python3 --version` |
| uv | 最新稳定版 | `uv --version` |
| Git / Make | 系统版本 | `git --version`、`make --version` |
| Git LFS | 必需 | `git lfs install` |
| 显示环境 | 有桌面或 EGL/OSMesa | 无头仿真机器需要 EGL |

不要在所有仓库强行复用一个 Python 环境：Robot SDK 是 uv workspace，Ability、Skill 和 Runtime 各自使用独立锁定环境。

## 获取代码

Semantic 是多仓聚根结构，没有顶层 monorepo 构建器。工作区下每个目录是一个独立 Git 仓库。

```bash
export SEMANTIC=~/semantic
mkdir -p "$SEMANTIC"
cd "$SEMANTIC"

# 按你的代码托管地址克隆同级仓库：
# semantic-framework
# semantic-web
# semantic-simulation
# semantic-scene
# semantic-skill
# semantic-ability
# semantic-robotsdk
# semantic-robot-deployment
# semantic-docs
# quick-start

git lfs install
git lfs pull
```

如果不想手动管理仓库，可以使用安装器：

```bash
python3 $SEMANTIC/quick-start/semantic_installer.py
```

注意：远端项目名可能不等于本地目录名。例如 `semantic-deployment` 在本地约定为 `semantic-robot-deployment`。

## 配置跨仓变量

```bash
export SEMANTIC=~/semantic
export SEMANTIC_SDK_REPO=$SEMANTIC/semantic-robotsdk/robot-sdk
export SEMANTIC_ABILITY_REPO=$SEMANTIC/semantic-ability
export SEMANTIC_SKILLS_REPO=$SEMANTIC/semantic-skill/robot-skill
export SEMANTIC_DEPLOYMENT_REPO=$SEMANTIC/semantic-robot-deployment
export SEMANTIC_WEB_REPO=$SEMANTIC/semantic-web
```

这些变量只负责跨仓定位。正式运行时，组件通过 Wheel、Zip、二进制以及 HTTP、WebSocket、JSON-RPC 接口协作，不使用 `PYTHONPATH` 直接导入其他仓源码。

## 准备 Framework 环境

Framework 的主配置来自 `configs/semantic-server.yaml` 模板。运行时不能使用模板本身，必须先安装开发副本：

```bash
cd "$SEMANTIC/semantic-framework"
cp .env.example .env
```

`.env.example` 中的关键变量：

```bash
SEMANTIC_ADMIN_PASSWORD=admin123
SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=
```

- `SEMANTIC_ADMIN_PASSWORD`：首次启动种子用户 `admin` 的初始密码；
- 未设置模型 key 时仍可使用内置 `mock` 模型；
- 真实模型密钥不要提交到 Git。

## 构建并初始化

```bash
cd "$SEMANTIC/semantic-framework"
make lint
make test
make build
make init
```

各命令的作用：

| 命令 | 结果 |
|---|---|
| `make lint` | 检查 Go 格式、vet、golangci-lint、go mod tidy |
| `make test` | 全仓 Go 单测和集成测试 |
| `make build` | 生成 `semantic-server`、`semantic-pilot`、`semantic` 三个二进制 |
| `make init` | 从内置模板安装运行配置到 `.output/` |

重要边界：运行配置、SQLite、日志和生成目录都在 `.output/`，不要直接修改源码模板目录作为运行状态。

## 启动最小 Server

```bash
cd "$SEMANTIC/semantic-framework"
make run
```

启动后默认监听：

| 服务 | 地址 |
|---|---|
| HTTP API | `http://127.0.0.1:8080` |
| WebSocket | `ws://127.0.0.1:8081` |

启动日志位于：

```bash
tail -f .output/logs/semantic-server.jsonl
```

## 登录并获取 Token

首次启动会创建种子用户 `admin`。如果你设置了：

```bash
SEMANTIC_ADMIN_PASSWORD=admin123
```

则使用以下命令登录：

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

echo "$TOKEN"
```

验证认证是否可用：

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"
```

Token 是存储在 Server SQLite 中的 opaque token，默认 TTL 为 24 小时；过期后使用 `POST /api/v1/auth/refresh` 刷新。

## 启动 Studio（可选但推荐）

```bash
cd "$SEMANTIC/semantic-web"
npm ci
VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

浏览器访问 Vite 输出的地址（默认通常是 `http://127.0.0.1:3000`）。使用上面的 `admin` 和初始密码登录。

Studio 只连接 Server，不直接连接 Pilot、AbilityFramework、Robot SDK 或 Runtime。

## 预期结果

本章完成后，你应得到：

```text
Semantic 多仓工作区
→ Framework 已构建并完成 make init
→ Semantic Server 已启动
→ admin 可以登录
→ REST 能返回 /api/v1/skills
→ Studio 可选启动
```

## 常见失败

- **登录失败**：检查 `SEMANTIC_ADMIN_PASSWORD` 是否在进入 `make run` 前设置；Server 启动后修改密码需要重置数据目录；
- **`/api/v1/skills` 返回 401**：Token 已过期，重新登录或调用 `auth/refresh`；
- **构建失败**：先执行 `go mod tidy`，确认 Go 版本和代理配置；
- **找不到仓库**：确认本地目录名与工作区变量一致；
- **Studio 白屏**：检查 `VITE_SERVER_HTTP`、`VITE_SERVER_WS` 和浏览器控制台；
- **端口占用**：修改 `semantic-server.yaml` 或环境变量中的 HTTP/WS 地址。

## 本章小结

- Semantic 是多仓工作区，不是单一 monorepo；
- Framework 源码模板与运行副本分离；
- `make build + make init + make run` 是最小 Server 路径；
- 登录后才能调用业务 REST；
- Studio 是 Server 的 Web 前端，不直接连接设备进程。

## 下一章

进入[第 2 章：Runtime、Scene 与 Virtual Robot](/developer/quickstart/chapter_02_simulation/)，启动一个真实的仿真环境。
