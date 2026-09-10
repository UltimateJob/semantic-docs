---
title: "Chapter 1: Workspace, Code, and a Minimal Server"
linkTitle: "Chapter 1: Workspace"
weight: 21
description: "Prepare a Semantic multi-repo workspace from scratch and start a minimal Semantic Server you can log into and call."
---

**Goal of this chapter**: finish the code, toolchain, workspace variables, and a minimal Server. When you are done, you should be able to log into the Server from a browser or REST and be ready for the next chapter's Runtime.

## What you need

| Item | Requirement | Verify |
|---|---|---|
| Operating system | Linux development machine | `uname -a` |
| Go | 1.23 | `go version` |
| Node.js / npm | 22+ | `node --version` |
| Python | Per repository; commonly 3.11+ | `python3 --version` |
| uv | Latest stable | `uv --version` |
| Git / Make | System versions | `git --version`, `make --version` |
| Git LFS | Required | `git lfs install` |
| Display environment | Desktop or EGL/OSMesa | Headless simulation machines need EGL |

Do not force one Python environment across every repository: Robot SDK is a uv workspace; Ability, Skill, and Runtime each use an independently locked environment.

## Get the code

Semantic is a multi-repo polyglot workspace. There is no top-level monorepo builder. Each directory under the workspace is an independent Git repository.

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

If you do not want to manage repositories by hand, use the installer:

```bash
python3 $SEMANTIC/quick-start/semantic_installer.py
```

Note: the remote project name may differ from the local directory name. For example `semantic-deployment` is conventionally `semantic-robot-deployment` locally.

## Configure cross-repo variables

```bash
export SEMANTIC=~/semantic
export SEMANTIC_SDK_REPO=$SEMANTIC/semantic-robotsdk/robot-sdk
export SEMANTIC_ABILITY_REPO=$SEMANTIC/semantic-ability
export SEMANTIC_SKILLS_REPO=$SEMANTIC/semantic-skill/robot-skill
export SEMANTIC_DEPLOYMENT_REPO=$SEMANTIC/semantic-robot-deployment
export SEMANTIC_WEB_REPO=$SEMANTIC/semantic-web
```

These variables only locate repositories across the workspace. In formal runs, components collaborate through Wheels, Zips, binaries, and HTTP, WebSocket, and JSON-RPC interfaces. They do not import other repositories' source through `PYTHONPATH`.

## Prepare the Framework environment

The Framework's main config comes from the `configs/semantic-server.yaml` template. Runtime cannot use the template itself. Install a development copy first:

```bash
cd "$SEMANTIC/semantic-framework"
cp .env.example .env
```

Key variables in `.env.example`:

```bash
SEMANTIC_ADMIN_PASSWORD=admin123
SEMANTIC_LLM_API_KEY_DEEPSEEK_CHAT=
```

- `SEMANTIC_ADMIN_PASSWORD`: initial password of the first-start seed user `admin`;
- Without a model key you can still use the built-in `mock` model;
- Do not commit real model keys to Git.

## Build and initialize

```bash
cd "$SEMANTIC/semantic-framework"
make lint
make test
make build
make init
```

What each command does:

| Command | Result |
|---|---|
| `make lint` | Check Go format, vet, golangci-lint, go mod tidy |
| `make test` | Full-repo Go unit and integration tests |
| `make build` | Produce the `semantic-server`, `semantic-pilot`, and `semantic` binaries |
| `make init` | Install runtime config from the built-in template into `.output/` |

Important boundary: runtime config, SQLite, logs, and generated directories all live under `.output/`. Do not treat the source template directory as runtime state.

## Start the minimal Server

```bash
cd "$SEMANTIC/semantic-framework"
make run
```

Default listen addresses after start:

| Service | Address |
|---|---|
| HTTP API | `http://127.0.0.1:8080` |
| WebSocket | `ws://127.0.0.1:8081` |

Startup logs:

```bash
tail -f .output/logs/semantic-server.jsonl
```

## Log in and get a Token

The first start creates seed user `admin`. If you set:

```bash
SEMANTIC_ADMIN_PASSWORD=admin123
```

log in with:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

echo "$TOKEN"
```

Verify that authentication works:

```bash
curl -s http://127.0.0.1:8080/api/v1/skills \
  -H "Authorization: Bearer $TOKEN"
```

The Token is an opaque token stored in Server SQLite. Default TTL is 24 hours. After expiry, refresh with `POST /api/v1/auth/refresh`.

## Start Studio (optional but recommended)

```bash
cd "$SEMANTIC/semantic-web"
npm ci
VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

Open the address Vite prints (usually `http://127.0.0.1:3000`). Log in with `admin` and the initial password above.

Studio connects only to the Server. It does not connect directly to Pilot, AbilityFramework, Robot SDK, or Runtime.

## Expected result

After this chapter you should have:

```text
Semantic 多仓工作区
→ Framework 已构建并完成 make init
→ Semantic Server 已启动
→ admin 可以登录
→ REST 能返回 /api/v1/skills
→ Studio 可选启动
```

## Common failures

- **Login failed**: check that `SEMANTIC_ADMIN_PASSWORD` was set before `make run`. Changing the password after the Server has started requires resetting the data directory;
- **`/api/v1/skills` returns 401**: the Token expired. Log in again or call `auth/refresh`;
- **Build failed**: run `go mod tidy` first and confirm the Go version and proxy;
- **Repository not found**: confirm local directory names match the workspace variables;
- **Studio blank page**: check `VITE_SERVER_HTTP`, `VITE_SERVER_WS`, and the browser console;
- **Port in use**: change the HTTP/WS addresses in `semantic-server.yaml` or environment variables.

## Chapter summary

- Semantic is a multi-repo workspace, not a single monorepo;
- Framework source templates are separate from the runtime copy;
- `make build + make init + make run` is the minimal Server path;
- Business REST requires login;
- Studio is the Server's Web frontend and does not connect to device processes.

## Next chapter

Continue to [Chapter 2: Runtime, Scene, and Virtual Robot](chapter_02_simulation.en.md) and start a real simulation environment.
