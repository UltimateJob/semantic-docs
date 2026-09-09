---
title: "Agent Skill"
weight: 10
description: "编写 SKILL.md 教 Agent 领域方法：frontmatter 契约、发现与加载、授权链与热更新。"
---

Agent Skill 为 Agent 提供领域知识和工作方法，是 Semantic 中门槛最低的扩展点：**只写一个 `SKILL.md`，不需要任何代码**。Agent 在 Run 中通过 `skill` 工具按需读取 Skill 正文。

实现位于 `semantic-framework` 仓库：

- Skill 加载与存储：`internal/skill/`
- kernel 侧适配：`internal/agent/kernel/`（skill.go）
- Agent Profile 授权：`internal/agent/profile/` + `configs/agents/`

## Agent Skill 结构

一个 Agent Skill 是一个包含 `SKILL.md` 的目录：

```text
hello-semantic/
├── SKILL.md            必需，唯一入口
├── scripts/            可选，脚本资源
├── references/         可选，参考资料
└── assets/             可选，其他静态资源
```

标准资源目录只有 `scripts/`、`references/`、`assets/` 三个（`internal/skill/resource.go`）。放在其他名字目录下的文件不会被技能管理 API 列出或预览。

资源经 REST 读取时还有四条硬约束（`internal/skill/resource.go` + `internal/server/http/handlers/skills.go`）：

- 仅上述三个目录下的**普通文件**可列出与预览，符号链接与隐藏目录一律排除，路径经词法与 `EvalSymlinks` 双重校验防止逃出 Skill 根目录；
- 在线预览单文件上限 `MaxResourcePreviewBytes = 1 MiB`，超限返回 413 `SKILL_RESOURCE_TOO_LARGE`；
- 预览内容必须是 UTF-8 文本，二进制返回 415 `SKILL_RESOURCE_NOT_TEXT`；
- 非法路径返回 400 `SKILL_RESOURCE_PATH_INVALID`，资源不存在返回 404 `SKILL_RESOURCE_NOT_FOUND`。

资源不进入 Skill 清单或详情首包：清单只含 frontmatter 标准字段，详情才附带 `resources` 数组（`path`/`kind`/`media_type`/`size`），内容按需经资源端点读取。

### SKILL.md 格式

`SKILL.md` 必须以 YAML frontmatter 开头，没有 frontmatter 的文件不会被当作 Skill（加载直接失败）：

```markdown
---
name: hello-semantic
description: 最小 Agent Skill 示例，用于验证 Skill 加载流程
category: general
when_to_use: 用户打招呼或需要演示 Skill 机制时
---

# Hello Semantic

这是一个最小 Agent Skill 示例。

## 工作步骤

1. 向用户问好；
2. 说明当前 Semantic Server 已成功加载本 Skill；
3. 如需展示工具调用，可使用 `system.time` 查询当前时间。
```

frontmatter 字段契约（解析代码：`internal/skill/loader.go` 的 `Parse`）：

| 字段 | 必填 | 语义 | 缺失 / 非法行为 |
|---|---|---|---|
| `name` | 是 | 全局唯一标识。同名 Skill 后加载者覆盖先加载者，并记录 WARN（`store.go` `Reload`） | 缺失即本 Skill 加载失败（`缺少必填字段 name`），错误被收集、该 Skill 被跳过，不阻塞其他 Skill |
| `description` | 是 | 渐进披露清单中模型匹配的唯一依据；解析时压缩空白为单行 | 缺失即加载失败（`缺少必填字段 description`） |
| `category` | 否 | 清单按 category 分组渲染 | 缺失回填 `general`（常量 `DefaultCategory`） |
| `when_to_use` | 否 | 适用时机描述，解析后透传（当前不参与匹配） | 缺失为空字符串 |
| 其他键 | 否 | 全部进入 `Extensions` 原样透传；其中 `tags` 会被 `GET /api/v1/skills` 单独提取展示（`handlers/skills.go` `skillTags`） | 任意，不影响加载 |

frontmatter 本身还有两条硬规则（`splitFrontMatter`）：

- 文件必须以 `---` 开头且存在收尾 `---`，否则视为无 frontmatter——`name`/`description` 校验必然失败，该目录不会被当作 Skill；
- frontmatter 必须是合法 YAML，否则该 Skill 加载失败（`frontmatter 不是合法 YAML`）。

正文的写作建议：

- 说明 Skill 适用的目标、Agent 应关注的信息、推荐工作步骤、可使用的 Tool、输出应达到的结果、需要用户参与的判断；
- 内容使用可迁移的领域表达，具体 Project、对象数量、Robot 数量由运行环境决定；
- **Skill 中间件不会自动执行 `scripts/` 下的脚本**。如果需要运行脚本，正文必须明确指导 Agent 调用 `execute`（Docker 沙箱）或 `execute_host`（受控宿主执行）工具。

### 发现与加载规则

`LoadDir`（`internal/skill/loader.go`）的行为：

- 递归扫描 `skills.dir` 目录树，任意深度的分类子目录都可以（`<分类>/<skill-name>/SKILL.md` 只是组织习惯，`category` 来自 frontmatter 而非目录位置）；
- 发现含 `SKILL.md` 的目录后不再下钻——目录内的 scripts/references 是资源不是 Skill；
- 隐藏目录（`.` 开头）跳过；
- 单个 SKILL.md 解析失败只收集错误继续加载其他 Skill（软错误），skills 只含成功项；`skills.dir` 本身不可读/不是目录是硬错误；
- 返回顺序为文件系统遍历序（字典序），同名冲突时"后加载覆盖先加载"的结果因此是确定的。

Skill 存储位置由配置项 `skills.dir` 决定（`configs/semantic-server.yaml` 模板值为 `configs/skills`，`semantic init` 会把模板安装为运行副本并改写为绝对路径）。种子 Skill 通过 `go:embed` 打进二进制。

### 热更新

Store（`internal/skill/store.go`）挂载 fsnotify 监听，文件变更经 500ms 去抖后自动全量重载，无需重启。已在缓存的会话在下一轮 Run / 新会话看到新内容。`skills.dir` 本身也支持配置热重载。

已知限制：技能根目录被整体删除后，需要配置热重载或重启恢复。

## 授权：让 Agent 能看到 Skill

Skill 加载进 Server 不等于 Agent 能使用它。授权链由 Agent Profile 控制（Profile 完整字段见 [Agent 角色与 Team](/developer/core-modules/intelligent/agent-profile/)）：

**role.yaml 的 `skills.allowlist` 是硬边界（空 = 不使用 Skill）**，Project 级绑定只能继续收窄（交集）。Agent 实际可见的 Skill = allowlist ∩ Project 绑定。

实现于 `internal/skill/store.go` 的 `NewView`（`internal/agent/runtime/team.go` 调用）：

- Agent allowlist 为空时直接得到空视图——allowlist 无法被 Project 或运行期配置扩大；
- Project 绑定（`GetProjectBindings(projectID)` 返回的 `SkillNames`）非空时逐名取交集，为空表示不追加 Project 级限制；
- 两层过滤在每次会话构建时重新计算（`projectSkillReader`），因此 Project 绑定变更即时生效；而 allowlist 来自进程内缓存的 Profile（`profile.Loader.cache`），**修改 allowlist 必须重启 Server**。

一个容易混淆的点：`GET /api/v1/agents` 返回的 `skill_names` 只做 allowlist ∩ 已安装（roster 视图不取 Project 绑定，`team.go` 用 `NewView(skills, allowlist, nil)`）；Project 级交集只作用于会话运行时的 Skill 视图。

新增 Skill 后必须在目标角色的 allowlist 中追加名字，否则该 Agent 永远看不到它。

## 入门教程：新增一个 Agent Skill

以下流程已在本地完整验证。

### 1. 创建 SKILL.md

在 `skills.dir` 指向的目录树下创建（仓库开发态即 `configs/skills/`）：

```text
configs/skills/general/hello-semantic/SKILL.md
```

内容即上文"SKILL.md 格式"中的示例。无需任何 Go 代码注册。

### 2. 授权给目标角色

编辑目标角色的 `configs/agents/<role>/role.yaml`，在 `skills.allowlist` 中追加 `hello-semantic`。Profile 有进程内缓存，需要重启 Server 生效。

### 3. 验证

```bash
# Skill 加载单元测试（含种子 Skill 校验）
go test ./internal/skill/... -count=1

# 真实装配 + 热更集成测试（mock 模型，无需外部服务）
go test ./tests/integration/ -run TestSkill -count=1

# 启动 Server 后经 REST 验证
make run
# 登录获取 token 后：
curl -s http://127.0.0.1:8080/api/v1/skills -H "Authorization: Bearer $TOKEN"
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
# agents 返回中每个 Agent 的 skill_names 应包含新 Skill（仅限已加入 allowlist 的角色）
```

测试位置（均位于 `semantic-framework`）：

| 文件 | 覆盖 |
|---|---|
| `internal/skill/loader_test.go` | LoadDir 发现规则、软/硬错误、Parse 必填校验 |
| `internal/skill/store_test.go` | 快照原子替换、坏变更保留旧快照、Summary 渲染、热更监听 |
| `internal/skill/view_test.go` | allowlist ∩ Project 绑定交集、视图跟随 Store 热更 |
| `internal/skill/resource_test.go` | 资源路径穿越与外部符号链接拒绝 |
| `internal/skill/samples_test.go` | 仓库自带种子 Skill 符合解析契约、scripts 可执行 |
| `tests/integration/skill_test.go` | `TestSkillSeedLoadedAndHotReload`、`TestSkillToolCallRun`（真实装配 + 热更） |

验证要点：

- Skill 未加入任何 allowlist 时，`GET /api/v1/skills` 能看到它（Store 已加载），但 `GET /api/v1/agents` 中没有任何 Agent 的 `skill_names` 包含它——这就是 allowlist 硬边界；
- 也可以在 Server 运行时直接向 skills 目录写入新 SKILL.md，观察 500ms 热更日志（`技能快照已替换`）。

## 接口级最小示例：带资源的 Skill

上面的 hello-semantic 只有一份正文。下面的 `site-inspection` 在此之上加入 `references/` 资源与完整工作方法，字段与行为全部遵循前文契约，可直接落盘复现。

### 1. 目录与文件

```text
configs/skills/general/site-inspection/
├── SKILL.md                       必需，唯一入口
└── references/
    └── inspection-checklist.md    参考资料正文按相对路径引用
```

### 2. SKILL.md 全文

```markdown
---
name: site-inspection
description: 现场巡检方法：按清单逐项检查站点设备状态并输出结构化巡检报告
category: general
when_to_use: 用户要求巡检、盘点设备状态或生成巡检报告时
tags: [inspection, checklist]
---

# 现场巡检方法

## 目标

完成一轮站点巡检并输出报告：每项检查给出 正常 / 异常 / 无法确认 三态结论，
异常项附证据（工具返回的原始数据），无法确认项列出阻塞原因。

## 工作步骤

1. 调用 `skill` 工具加载本技能后，先读取检查清单：
   `references/inspection-checklist.md`（位于本技能目录下，可用宿主文件读取
   工具按相对路径打开；也可通过 REST
   `GET /api/v1/skills/site-inspection/resources/references/inspection-checklist.md` 获取）；
2. 按清单顺序逐项检查，优先使用只读工具（`system.*`、`artifact.get`），
   不确定含义的字段先查询再下结论；
3. 每完成一项立即记录结论与证据，不要在最后凭记忆补写；
4. 全部检查完成后，把报告用 `artifact.put` 保存（`media_type: text/markdown`），
   并在回答中给出报告摘要与 `artifact_id`。

## 判断规则

- 任一必检项为"异常"时，报告结论为"巡检未通过"，并给出建议的下一步；
- 工具不可用或返回错误时记"无法确认"，不要凭猜测填补结论；
- 本技能不指导任何维修操作，仅做状态确认与记录。
```

写作要点（对照正文逐条可见）：frontmatter 四个标准字段 + 一个扩展键 `tags`；
正文给出**目标、步骤、判断规则**三层，引用 `references/` 时写明相对路径与获取
方式；需要 Agent 执行外部动作时显式点名工具（`artifact.put`）——Skill
middleware 只注入正文，不会替 Agent 执行任何脚本或工具。

### 3. references/inspection-checklist.md（节选）

```markdown
# 巡检检查清单

| 编号 | 检查项 | 数据来源 | 通过标准 |
|---|---|---|---|
| C1 | 系统服务状态 | system.status | 全部组件 running |
| C2 | 在线 Robot | robot 目录接口 | 数量与台账一致，无 error 状态 |
| C3 | 未闭环的审批请求 | interactions（status=pending） | 无超时未处理项 |
| C4 | 巡检记录留存 | artifact.put | 本轮报告已保存并回填 artifact_id |
```

### 4. 授权片段（role.yaml）

在目标角色（如 `configs/agents/leader/role.yaml`）的 `skills.allowlist` 中追加
技能名：

```yaml
skills:
  # 追加前：[artifact-usage, echo-guide, data-profile, semantic-diagnostics, depalletizing-workflow-planning]
  allowlist: [artifact-usage, echo-guide, data-profile, semantic-diagnostics, depalletizing-workflow-planning, site-inspection]
```

Profile 有进程内缓存，保存后需重启 Server 生效。

### 5. 验证命令与预期输出

```bash
cd "$SEMANTIC/semantic-framework"
make run
# 另一个终端：登录获取 token（详见 quickstart 第 3 章）
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

# 清单：确认 site-inspection 已加载（category 升序分组、组内 name 升序）
curl -s http://127.0.0.1:8080/api/v1/skills -H "Authorization: Bearer $TOKEN"
```

预期返回中包含一条（字段即 `skillSummary`，未声明 `when_to_use` 时该键省略）：

```json
{
  "name": "site-inspection",
  "category": "general",
  "description": "现场巡检方法：按清单逐项检查站点设备状态并输出结构化巡检报告",
  "when_to_use": "用户要求巡检、盘点设备状态或生成巡检报告时",
  "tags": ["inspection", "checklist"]
}
```

```bash
# 详情：确认正文与 resources 已随包加载
curl -s http://127.0.0.1:8080/api/v1/skills/site-inspection -H "Authorization: Bearer $TOKEN"
# 预期：skill.body 含"工作步骤"，skill.resources 含
# {"path":"references/inspection-checklist.md","kind":"references","media_type":"text/markdown; charset=utf-8","size":<字节数>}

# 资源按需读取
curl -s http://127.0.0.1:8080/api/v1/skills/site-inspection/resources/references/inspection-checklist.md \
  -H "Authorization: Bearer $TOKEN"
# 预期：{"resource":{...},"content":"# 巡检检查清单\n..."}

# 角色可见性：leader 的 skill_names 应包含 site-inspection
curl -s http://127.0.0.1:8080/api/v1/agents -H "Authorization: Bearer $TOKEN"
```

排查口径：清单可见但 `skill_names` 不含它 → allowlist 未加或未重启；
404 `SKILL_NOT_FOUND` → 目录未放进 `skills.dir` 树或 frontmatter 缺 `name`/
`description`（查看 Server 日志中的"技能加载失败，已跳过" WARN）。

## 相关 API

| 接口 | 说明 |
|---|---|
| `GET /api/v1/skills` | 技能清单 |
| `GET /api/v1/skills/{name}` | 技能详情 |
| `GET /api/v1/skills/{name}/resources/*` | 技能资源列表与预览 |
| `GET /api/v1/agents` | Agent 目录（含各 Agent 实际可见的 skill_names） |

## 术语区分

Agent Skill 与 Robot Skill 是两套体系：

- **Agent Skill**（本文）：`internal/skill`，SKILL.md 渐进披露，指导 Agent 的领域方法；
- **Robot Skill**：见 [Robot Skill](/developer/core-modules/robot/robot-skill/)，由 Pilot 下发到 Robot 上执行的阶段化物理任务。

`plan.suggest` 参数中的 `allowed_skills / required_capabilities` 指 Robot Skill，与 Agent Skill allowlist 无关。
