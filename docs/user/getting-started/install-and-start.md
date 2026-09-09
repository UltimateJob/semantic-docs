---
title: "安装与启动"
weight: 10
---

本章介绍把 Semantic 跑起来的两种方式：**路径 A** 使用 quick-start 安装器，自动完成依赖安装、代码克隆、构建和服务启动，适合只想体验完整产品流程的用户；**路径 B** 从各仓库源码手动构建，适合需要阅读或修改代码的开发者。两种路径完成后得到的是同一个本地环境：Semantic Server、Semantic Studio（Web 前端）和一套 MuJoCo 仿真 Robot。

> **无需真机**：两条路径都不需要真实机器人和真实模型密钥。全部教程在 MuJoCo 仿真环境中完成，未配置模型密钥时使用内置 `mock` 模型（见[常见问题](#常见问题)）。

## 选择安装路径

| | 路径 A：一键体验（推荐） | 路径 B：开发者源码安装 |
|---|---|---|
| 适合人群 | 想直接使用产品的用户 | 要参与 Framework/Web 开发的开发者 |
| 操作方式 | 安装器 TUI 分阶段执行，可断点续跑 | 手动执行各仓构建命令 |
| 覆盖范围 | 系统依赖、10 个仓库、Runtime 登记、Robot Bundle、Server/Web 启动 | Framework 与 Web 两个仓库的最小可运行环境 |
| 首次耗时 | 较长（含克隆与构建），后续「日常再开」只需一条命令 | 中等，按需构建 |

## 路径 A：一键体验（推荐）

安装器是 `quick-start` 仓库中的 `semantic_installer.py`，一个零依赖的终端交互程序（仅需 Python 3 标准库）。它把"从裸 Ubuntu 到 Studio 联调"的完整步骤拆成 8 个阶段，每步有 skip 检查（已满足自动跳过）、实时日志和校验命令，状态持久化后可以随时中断续跑。

### 前置条件

| 项目 | 要求 | 说明 |
|---|---|---|
| 操作系统 | Linux（Ubuntu/Debian 系） | 阶段 1 使用 apt 安装系统依赖与 EGL 渲染库 |
| sudo 权限 | 需要 | 密码在 TUI 内输入，仅存于进程内存、不落盘 |
| Python 3 | 系统自带即可 | 安装器本身只用标准库；项目 Python 环境由 uv 管理 |
| Go 1.23+ / Node.js 22 / uv / Git / Git LFS / Make | 可不预装 | 阶段 1 自动安装（国内镜像可配）；已装且满足版本则自动跳过 |
| 显示环境 | 桌面或 EGL/OSMesa | 渲染后端由 `SEMANTIC_MUJOCO_GL` 控制，默认 `egl`，无头机器可改 `osmesa` |
| 网络 | 直连或国内镜像 | apt/Go/npm/PyPI/GitHub 代理均可在安装器中配置 |

### 第 1 步：获取 quick-start

```bash
git clone <quick-start 仓库地址>
cd quick-start
```

安装器按工作区版本清单中的远端与 revision 准备其余仓库；在 TUI 中按 `e` 可配置工作根目录 `SEMANTIC`、管理员密码、服务地址与镜像等。开始前检查所选清单是否适合当前托管组织。公开仓库使用标准 Git 认证；不要把个人凭据写入清单或提交到仓库。

### 第 2 步：运行安装器

```bash
python3 semantic_installer.py            # TUI 模式（推荐）
python3 semantic_installer.py --list     # 只列出全部阶段与步骤，不执行
python3 semantic_installer.py --run-all  # 无头模式：顺序执行全部阶段
python3 semantic_installer.py --stage 1 --stage 2   # 无头模式：执行指定阶段
```

TUI 左侧是阶段/步骤树，中间是实时日志。常用按键：

| 按键 | 作用 |
|---|---|
| `a` | 从阶段 1 连续执行所有步骤（尊重 skip 检查） |
| `Enter` | 执行选中的阶段或单步 |
| `e` | 设置环境变量，保存并生成 `semantic-env.sh` |
| `g` | 原托管环境凭据助手；公开仓库使用标准 Git 认证 |
| `L` | 查看选中服务步骤的日志尾部 |
| `x` | 停止本工具启动的所有后台服务 |
| `?` | 帮助，含已知坑点摘要 |
| `q` | 退出（会询问是否停止后台服务） |

<!-- TODO(实跑): 在干净的 Ubuntu 上完整执行一遍路径 A（TUI 与 --run-all 各一次），记录各阶段真实输出与耗时；本文仅实跑了 --list 与 --help。 -->

### 安装器做了什么

阶段划分与执行内容（与 `--list` 输出一致）：

| 阶段 | 内容 |
|---|---|
| 1 系统依赖 | apt 源、基础工具、Go、Node.js、uv + Python 3.13、EGL 渲染库、镜像配置、版本自检 |
| 2 拉代码与资产 | 克隆 10 个仓库到 `$SEMANTIC` 根目录、切换联调分支、`git lfs pull`、目录核对 |
| 3 构建 Server | 写入 framework `.env`（含管理员密码）、`make build`、`make init`、产物核对 |
| 4 登记 MuJoCo Runtime | `uv sync` 建立运行时环境，`semantic runtime install` 登记 |
| 5 Robot 执行栈 | scaffold 环境、Wheel 缓存检查、构建并激活 r1pro-mujoco Robot Bundle、改 `.output` 配置启用受管 Robot |
| 6 启动 | 后台启动 Server（`make run`，自动注入 `TMPDIR`）与 Web（`npm ci` + `.env` + `npm run dev`），登录并发布三个 Robot Skill |
| 7 Studio 手动联调 | 8 条手动检查清单，完成后按 `m` 标记 |
| 8 日常再开 | 先停本工作区已在跑的 Server/Web，再后台拉起 |

两点目录约定：

- `semantic-deployment` 远端仓在本地必须命名为 `semantic-robot-deployment`（安装器已处理）；
- 阶段 6 启动 Server 时自动注入 `TMPDIR=$SEMANTIC/semantic-framework/.output/tmp`，避免 AbilityFramework 打包时 `/tmp` 与 `$HOME` 跨设备 `rename` 报 `EXDEV`。

生成的文件都在 `quick-start/` 目录：`installer-settings.json`（环境变量）、`installer-status.json`（步骤状态，重开程序续跑）、`semantic-env.sh`（可 `source` 到任意终端）。Server/Web 后台日志在 `$SEMANTIC/.tui-logs/{server,web}.log`。

### 启动后访问

阶段 6 完成后：

| 服务 | 地址 |
|---|---|
| Semantic Studio（浏览器入口） | `http://127.0.0.1:3000` |
| Server HTTP API | `http://127.0.0.1:8080` |
| Server WebSocket | `ws://127.0.0.1:8081` |
| MuJoCo Runtime（阶段 4 登记，按需启动） | `http://127.0.0.1:8090` |

使用 admin 账号登录 Studio 后，即可继续[第一个 Project](/user/getting-started/first-project/)。

### 首次登录账号

首次启动时 Server 自动创建种子用户 **`admin`**，初始密码取 framework `.env` 中的 `SEMANTIC_ADMIN_PASSWORD`（安装器阶段 3.1 写入；TUI 中按 `e` 可修改）。若该变量未设置，使用默认初始密码 `admin123`，且启动日志会输出 WARN 提示尽快修改（源码：`semantic-framework/internal/server/auth/service.go` 的 `SeedAdmin`）。

当前代码没有修改密码的端点：如果需要在启动后更换 admin 密码，执行 `semantic init --reset-data` 备份并重建数据目录，再以新的 `SEMANTIC_ADMIN_PASSWORD` 启动（源码：`semantic-framework/cmd/semantic/init.go`）。

### 日常再开与停止

再次使用时运行安装器并执行阶段 8「日常再开」（自动先停旧进程再拉起），或在 TUI 中按 `x` 停止全部后台服务。不用安装器时，也可以直接 `source semantic-env.sh` 后进入各仓手动启动（同路径 B）。

## 路径 B：开发者源码安装

这条路径手动构建 Framework 与 Web，适合要改代码的开发者；完整的多仓工作区准备（跨仓变量、Git LFS、Runtime 安装）见[第 1 章：工作区](/developer/quickstart/chapter_01_environment/)。此处只保留最小可运行序列。

### 环境要求

- Go 1.23
- Node.js 22
- Python 3.11 或更高版本
- Git、Make 和支持现代浏览器的桌面环境

机器人仿真还需要相应 Runtime。原生 MuJoCo 场景使用 MuJoCo Runtime 和配套 Scene Package。

### 启动 Semantic Server

```bash
cd /path/to/semantic-framework
cp .env.example .env          # 按需设置 SEMANTIC_ADMIN_PASSWORD
make build
make run
```

`make build` 生成 `semantic-server`、`semantic-pilot`、`semantic` 三个二进制到 `.output/bin/`；`make run` 会先执行 `make init`，把内置模板安装为 `.output/configs/semantic-server.yaml` 运行副本（已有文件保持不变），再用该副本启动（源码：`semantic-framework/Makefile`）。运行配置、SQLite、日志都在 `.output/`，不要把源码模板目录当作运行状态。

默认服务地址：

- HTTP API：`http://127.0.0.1:8080`
- WebSocket：`ws://127.0.0.1:8081`

使用以下命令检查运行环境和日志：

```bash
make doctor
make logs
```

Server 使用运行副本配置连接数据库、模型提供方、Runtime Installation 和 Robot Skill Registry。未配置模型密钥时仅内置 `mock` 模型可用，服务不阻塞启动；真实模型密钥通过 Studio 系统设置或 `.env` 提供，日志只记录调用状态与用量。

### 启动 Semantic Web

在另一个终端进入 Web 仓库：

```bash
cd /path/to/semantic-web
npm install
VITE_SERVER_HTTP=http://127.0.0.1:8080 \
VITE_SERVER_WS=ws://127.0.0.1:8081 \
npm run dev
```

Vite 输出浏览器访问地址（dev 端口固定为 `3000`）。进入页面后，Web 会通过 HTTP 获取初始状态，并通过 WebSocket 接收 Conversation、Workflow、Robot 和 Execution 更新。

注意 `VITE_SERVER_WS` 使用根地址 `ws://127.0.0.1:8081`（前端自行拼接路径）；Server 配置里的 `server_websocket_url: ws://127.0.0.1:8081/ws/pilot` 是 Pilot 专用地址，两者不能混用。

若系统提示 inotify watcher 数量不足，先关闭遗留的开发服务器。Linux 主机也可以提高当前用户的 watcher 上限，再重新运行 `npm run dev`。

## 验证服务

两种路径完成后统一检查：

1. Web 能列出 Project。
2. 全局设备中心可以打开。
3. 新建 Conversation 后可以发送消息。
4. Server 日志中没有数据库迁移、模型配置或 WebSocket 连接错误。

<!-- TODO(实跑): 按上述清单在路径 A 与路径 B 各实测一轮，记录 Studio 与 curl 的真实表现。 -->

## 常见问题

**端口被占用（8080/8081/3000/8090）**
Server 端口在运行副本 `.output/configs/semantic-server.yaml` 的 `server.http_addr`/`server.ws_addr` 修改，也可用环境变量覆盖（如 `SEMANTIC_SERVER_HTTP_ADDR`）；改完重启 Server。Web dev 端口固定为 3000。MuJoCo Runtime 的 8090 处理方式见[开发者 FAQ](/developer/faq/)「8090 端口被占用」条目。

**首次登录失败（AUTH_INVALID_CREDENTIALS）**
确认用户名是 `admin`、密码是 `.env` 中 `SEMANTIC_ADMIN_PASSWORD` 的值。若启动后才补设该变量，种子用户已经用默认密码（或当时值）创建，需要 `semantic init --reset-data` 重建后再启动。更多场景见[运行维护的首次登录常见问题](/user/operations/runtime-operations/#首次登录常见问题)。

**`npm run dev` 报 inotify watcher 耗尽**
关闭多余的 Vite、编辑器或测试 watcher；需要长期并行时提高 `fs.inotify.max_user_watches` 与 `fs.inotify.max_user_instances`。详见[问题排查](/user/troubleshooting/)与[开发者 FAQ](/developer/faq/)对应条目。

## 下一步

继续阅读[第一个 Project](/user/getting-started/first-project/)，完成一条从对话到 Robot 执行的产品流程。

## 命令与事实来源

- 安装器行为、按键、阶段与生成文件：`quick-start/semantic-installer-README.md`、`python3 semantic_installer.py --list` / `--help`（实测）、`quick-start/NOTES.md`；
- 种子账号与 token：`semantic-framework/internal/server/auth/service.go`、`internal/server/http/router.go`；
- 端口：`semantic-framework/configs/semantic-server.yaml`（8080/8081）、`semantic-web/vite.config.js`（3000）、`semantic-simulation/mujoco-runtime/README.md`（8090）；
- 构建与初始化：`semantic-framework/Makefile`、`semantic-framework/.env.example`；
- mock 模型：`semantic-framework/configs/semantic-server.yaml` 模板注释。
