# Semantic Docs

[English](README.md) | [简体中文](README.zh-CN.md)

📚 Semantic 的架构、用户指南、开发参考与发布文档。本仓库使用 Hugo / Docsy 构建静态文档站，不运行业务服务；现有正文主要为中文。

## 工程结构

- `docs/`：文档正文。
- `hugo.toml`：站点配置。
- `layouts/` · `assets/`：模板与资源。
- `_vendor/`：随仓保存的主题依赖，保留各自许可证。
- `scripts/`：工具脚本，包括固定版本的 Hugo 安装器。

## 🛠 预览与构建

需要 Node.js **22+**、npm，以及下载构建依赖所需的网络访问。

```bash
npm ci
npm run docs:dev
```

npm postinstall 会安装固定版本的 Hugo Extended。访问 `http://127.0.0.1:1313` 预览；开发命令监听 `0.0.0.0`，请仅在可信网络使用。

```bash
npm run docs:build
```

将生成的 `public/` 目录发布到静态托管服务，不要发布整个源码目录、本地配置或依赖缓存。

## 贡献与常见问题

说明应与组件源码和 quick-start 清单保持一致，区分已实现功能与规划、已验证平台与预期支持平台。通过本地预览检查链接和导航。

Hugo 下载失败时，先检查 postinstall 日志与代理配置；不要未经兼容性检查就替换为任意系统版本。

[原始概览](README.reference.md) · [开发文档](docs/developer/)

## 许可证

Copyright 2026 InsightOS。自有代码采用 [Apache-2.0](LICENSE)；第三方组件与资产请查看 [NOTICE](NOTICE) 和[许可范围](LICENSE_SCOPE.md)。
