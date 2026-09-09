# Changelog

本文件记录 Semantic Documentation 已发布版本中的用户可见变化。未来工作和当前进度由 项目里程碑与 Issue 管理。

## v0.5.0-dev - 未发布

### 新增

- 重组架构、开发与用户文档（docs(v0.5) 文档结构调整）。
- 对齐多 Agent 规划与 Pilot 接入架构、统一 Robot Skill 包格式文档。
- 发布记录新增 v0.5.0（开发中）、v0.4.0、v0.3.0 版本页面，含新增、破坏性变化、迁移指引、Action Schema 变化、制品升级顺序与已知限制。
- 发布记录首页新增组件兼容矩阵（Framework × Web × Robot SDK × Ability × Robot Skill × Runtime Pack × Bundle）。

### 验证

- 发布记录各条目注明证据来源（仓名 + commit/tag），未确认项以 `TODO(确认)` 标注。
- Hugo 构建 0 error（`npx hugo --destination /tmp/hugo-agent2`）。

## v0.4.0 - 2026-08-12

### 新增

- 新增机器人类型包与自动编排设计文档。
- 同步计划提案与任务调度架构文档。
- 同步机器人运行包（Runtime Pack）研发状态。

### 验证

- 证据链：semantic-docs @2cc3a34、@91caaad（2026-08-11）、@a16d9f1（2026-08-13）。

## v0.3.0 - 2026-08-09

### 新增

- 同步对话式计划、语义地图 Inspector 与规划参数边界文档。
- 补充旧 Workflow 冲突处理说明。

### 验证

- 证据链：semantic-docs @f3f6172、@613d9ab、@1282132、@b5f398d（2026-08-09）。

## v0.2.0 - 2026-08-08

### 新增

- 建立独立的 `semantic-docs` 仓库和 VitePress 文档站。
- 建立 Semantic 系统架构、使用说明和开发文档的初始基座。
- 建立文档构建、扫描、标签校验、制品和 Release 流水线。
- 记录 Project、Conversation、Agent Run、Context 摘要和 Semantic Studio 工作空间的 v0.2.0 设计。
- 记录 Robot 执行、仿真、Semantic Map、运行停止和 Studio 布局的系统主线。
- 提供安装、配置、Project 使用、运行观察和问题排查入口。

### 验证

- 在 Node.js 22 环境执行 `npm ci` 和 `npm run docs:build`。
- 检查导航、内部链接和文档职责。
- 对照 Framework、Web 和仿真场景复核文档内容。
