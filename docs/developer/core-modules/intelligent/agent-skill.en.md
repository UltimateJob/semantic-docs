---
title: "Agent Skill"
weight: 10
description: "Write a SKILL.md that teaches an Agent a domain method: frontmatter contract, discovery and loading, authorization chain, and hot reload."
---

An Agent Skill gives an Agent domain knowledge and a working method. It is the lowest-friction extension point in Semantic: **write one `SKILL.md` and no code**. During a Run, the Agent reads the Skill body on demand through the `skill` tool.

Implementation lives in the `semantic-framework` repository:

- Skill loading and storage: `internal/skill/`
- Kernel-side adapter: `internal/agent/kernel/` (skill.go)
- Agent Profile authorization: `internal/agent/profile/` + `configs/agents/`

## Agent Skill structure

An Agent Skill is a directory that contains `SKILL.md`:

```text
hello-semantic/
├── SKILL.md            必需，唯一入口
├── scripts/            可选，脚本资源
├── references/         可选，参考资料
└── assets/             可选，其他静态资源
```

The only standard resource directories are `scripts/`, `references/`, and `assets/` (`internal/skill/resource.go`). Files under other directory names are not listed or previewed by the skill management API.

When resources are read over REST, four hard constraints still apply (`internal/skill/resource.go` + `internal/server/http/handlers/skills.go`):

- Only **regular files** under those three directories can be listed and previewed. Symlinks and hidden directories are always excluded. Paths are checked twice, lexically and with `EvalSymlinks`, to prevent escaping the Skill root;
- Online preview of a single file is capped at `MaxResourcePreviewBytes = 1 MiB`. Oversize files return 413 `SKILL_RESOURCE_TOO_LARGE`;
- Preview content must be UTF-8 text. Binary returns 415 `SKILL_RESOURCE_NOT_TEXT`;
- An illegal path returns 400 `SKILL_RESOURCE_PATH_INVALID`. A missing resource returns 404 `SKILL_RESOURCE_NOT_FOUND`.

Resources are not included in the Skill catalog or the first detail payload: the catalog contains only standard frontmatter fields. Detail responses attach a `resources` array (`path`/`kind`/`media_type`/`size`). Content is read on demand from the resource endpoint.

### SKILL.md format

`SKILL.md` must start with YAML frontmatter. A file without frontmatter is not treated as a Skill (loading fails immediately):

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

Frontmatter field contract (parsing code: `Parse` in `internal/skill/loader.go`):

| Field | Required | Semantics | Missing / invalid behavior |
|---|---|---|---|
| `name` | Yes | Globally unique identifier. A later Skill with the same name overwrites the earlier one and records a WARN (`Reload` in `store.go`) | Missing fails this Skill (`缺少必填字段 name`). The error is collected, the Skill is skipped, and other Skills keep loading |
| `description` | Yes | The only basis for model matching in the progressive-disclosure catalog; whitespace is collapsed to a single line at parse time | Missing fails loading (`缺少必填字段 description`) |
| `category` | No | Catalog rendering groups by category | Missing is filled as `general` (constant `DefaultCategory`) |
| `when_to_use` | No | Applicability description, passed through after parse (not used for matching today) | Missing becomes an empty string |
| Other keys | No | All enter `Extensions` as-is. `tags` is extracted separately for display by `GET /api/v1/skills` (`skillTags` in `handlers/skills.go`) | Arbitrary; does not affect loading |

Frontmatter itself has two more hard rules (`splitFrontMatter`):

- The file must start with `---` and have a closing `---`. Otherwise it is treated as having no frontmatter, `name`/`description` validation necessarily fails, and the directory is not treated as a Skill;
- Frontmatter must be valid YAML. Otherwise this Skill fails loading (`frontmatter 不是合法 YAML`).

Body writing guidance:

- State the Skill's applicable goal, what the Agent should pay attention to, recommended steps, Tools it may use, the result the output should reach, and judgments that need the user;
- Use portable domain language. Concrete Project, object count, and Robot count are decided by the runtime environment;
- **Skill middleware does not automatically execute scripts under `scripts/`**. If a script must run, the body must explicitly tell the Agent to call `execute` (Docker sandbox) or `execute_host` (controlled host execution).

### Discovery and loading rules

`LoadDir` (`internal/skill/loader.go`) behaves as follows:

- Recursively scan the `skills.dir` tree. Category subdirectories of any depth are allowed (`<category>/<skill-name>/SKILL.md` is only an organization habit; `category` comes from frontmatter, not directory location);
- After discovering a directory that contains `SKILL.md`, do not recurse further — scripts/references inside the directory are resources, not Skills;
- Hidden directories (starting with `.`) are skipped;
- A single SKILL.md parse failure is collected as a soft error and other Skills keep loading; `skills` contains only successes. `skills.dir` itself being unreadable or not a directory is a hard error;
- Return order is filesystem traversal order (lexicographic), so "later load overwrites earlier load" for same-name conflicts is deterministic.

Skill storage is controlled by `skills.dir` (the `configs/semantic-server.yaml` template value is `configs/skills`; `semantic init` installs the template as a runtime copy and rewrites it to an absolute path). Seed Skills are embedded into the binary with `go:embed`.

### Hot reload

The Store (`internal/skill/store.go`) mounts an fsnotify watcher. File changes trigger a full reload after a 500ms debounce, with no restart. Cached sessions see the new content on the next Run / new session. `skills.dir` itself also supports config hot reload.

Known limit: after the skill root directory is deleted as a whole, you need a config hot reload or a restart to recover.

## Authorization: let an Agent see a Skill

Loading a Skill into the Server does not mean an Agent can use it. The authorization chain is controlled by the Agent Profile (full Profile fields are in [Agent Roles and Teams](agent-profile.en.md)):

**`skills.allowlist` in role.yaml is a hard boundary (empty = use no Skills)**. Project-level bindings can only narrow it further (intersection). The Skills an Agent actually sees = allowlist ∩ Project bindings.

Implemented by `NewView` in `internal/skill/store.go` (called from `internal/agent/runtime/team.go`):

- An empty Agent allowlist yields an empty view immediately — the allowlist cannot be expanded by Project or runtime config;
- When Project bindings (`SkillNames` from `GetProjectBindings(projectID)`) are non-empty, intersection is taken name by name. Empty means no extra Project-level restriction;
- Both filters are recomputed when each session is built (`projectSkillReader`), so Project binding changes take effect immediately. The allowlist comes from the in-process cached Profile (`profile.Loader.cache`), so **changing the allowlist requires a Server restart**.

A common confusion: `skill_names` from `GET /api/v1/agents` is only allowlist ∩ installed (the roster view does not take Project bindings; `team.go` uses `NewView(skills, allowlist, nil)`). The Project-level intersection applies only to the Skill view at session runtime.

After you add a Skill, you must append its name to the target role's allowlist. Otherwise that Agent never sees it.

## Getting started: add an Agent Skill

The following flow has been fully verified locally.

### 1. Create SKILL.md

Create it under the directory tree pointed to by `skills.dir` (`configs/skills/` in repository development mode):

```text
configs/skills/general/hello-semantic/SKILL.md
```

Use the example from "SKILL.md format" above. No Go registration is required.

### 2. Authorize the target role

Edit the target role's `configs/agents/<role>/role.yaml` and append `hello-semantic` to `skills.allowlist`. Profiles are cached in-process, so restart the Server.

### 3. Verify

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

Test locations (all in `semantic-framework`):

| File | Coverage |
|---|---|
| `internal/skill/loader_test.go` | LoadDir discovery rules, soft/hard errors, Parse required-field checks |
| `internal/skill/store_test.go` | Atomic snapshot replacement, bad changes keep the old snapshot, Summary rendering, hot-reload watch |
| `internal/skill/view_test.go` | allowlist ∩ Project binding intersection; the view follows Store hot reload |
| `internal/skill/resource_test.go` | Resource path traversal and external symlink rejection |
| `internal/skill/samples_test.go` | Repository seed Skills match the parse contract; scripts are executable |
| `tests/integration/skill_test.go` | `TestSkillSeedLoadedAndHotReload`, `TestSkillToolCallRun` (real assembly + hot reload) |

Verification points:

- When a Skill is on no allowlist, `GET /api/v1/skills` can still see it (the Store has loaded it), but no Agent's `skill_names` on `GET /api/v1/agents` contains it — that is the allowlist hard boundary;
- You can also write a new SKILL.md into the skills directory while the Server is running and watch the 500ms hot-reload log (`技能快照已替换`).

## Interface-level minimal example: a Skill with resources

The hello-semantic Skill above has only a body. The `site-inspection` Skill below adds a `references/` resource and a complete working method. Fields and behavior follow the earlier contract and can be reproduced by writing the files to disk.

### 1. Directory and files

```text
configs/skills/general/site-inspection/
├── SKILL.md                       必需，唯一入口
└── references/
    └── inspection-checklist.md    参考资料正文按相对路径引用
```

### 2. Full SKILL.md

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

Writing notes (visible line by line in the body): four standard frontmatter fields plus one extension key `tags`;
the body gives three layers — **goal, steps, and judgment rules**; when citing `references/`, write the relative path and how to obtain it;
when the Agent must perform an external action, name the tool explicitly (`artifact.put`) — Skill
middleware only injects the body and does not execute any script or tool for the Agent.

### 3. references/inspection-checklist.md (excerpt)

```markdown
# 巡检检查清单

| 编号 | 检查项 | 数据来源 | 通过标准 |
|---|---|---|---|
| C1 | 系统服务状态 | system.status | 全部组件 running |
| C2 | 在线 Robot | robot 目录接口 | 数量与台账一致，无 error 状态 |
| C3 | 未闭环的审批请求 | interactions（status=pending） | 无超时未处理项 |
| C4 | 巡检记录留存 | artifact.put | 本轮报告已保存并回填 artifact_id |
```

### 4. Authorization snippet (role.yaml)

Append the Skill name to `skills.allowlist` of the target role (for example `configs/agents/leader/role.yaml`):

```yaml
skills:
  # 追加前：[artifact-usage, echo-guide, data-profile, semantic-diagnostics, depalletizing-workflow-planning]
  allowlist: [artifact-usage, echo-guide, data-profile, semantic-diagnostics, depalletizing-workflow-planning, site-inspection]
```

Profiles are cached in-process. Restart the Server after you save.

### 5. Verification commands and expected output

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

The expected response includes one item (fields are `skillSummary`; `when_to_use` is omitted when undeclared):

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

Triage: visible in the catalog but missing from `skill_names` → allowlist not added or Server not restarted;
404 `SKILL_NOT_FOUND` → the directory is not under the `skills.dir` tree, or frontmatter is missing `name`/
`description` (look for the "技能加载失败，已跳过" WARN in Server logs).

## Related APIs

| API | Description |
|---|---|
| `GET /api/v1/skills` | Skill catalog |
| `GET /api/v1/skills/{name}` | Skill detail |
| `GET /api/v1/skills/{name}/resources/*` | Skill resource list and preview |
| `GET /api/v1/agents` | Agent directory (including each Agent's actually visible skill_names) |

## Terminology

Agent Skill and Robot Skill are two separate systems:

- **Agent Skill** (this page): `internal/skill`, progressive disclosure via SKILL.md, guides an Agent's domain method;
- **Robot Skill**: see [Robot Skill](../robot/robot-skill.en.md), a staged physical task that Pilot sends to a Robot.

`allowed_skills / required_capabilities` in `plan.suggest` parameters refer to Robot Skills and are unrelated to the Agent Skill allowlist.
