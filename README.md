# Semantic Docs

[English](README.md) | [简体中文](README.zh-CN.md)

📚 Architecture, user guides, developer references, and release documentation for Semantic. This repository builds a Hugo/Docsy documentation site; it does not run the product services. Most current guide content is Chinese.

## Structure

- `docs/` — documentation content.
- `hugo.toml` — site configuration.
- `layouts/` · `assets/` — templates and assets.
- `_vendor/` — vendored theme dependencies with their own licenses.
- `scripts/` — tooling, including the pinned Hugo installer.

## 🛠 Preview and publish

Requires Node.js **22+**, npm, and network access for build dependencies.

```bash
npm ci
npm run docs:dev
```

The npm postinstall step installs the pinned Hugo Extended version. Preview at `http://127.0.0.1:1313`; the development command binds to `0.0.0.0`, so use a trusted network.

```bash
npm run docs:build
```

Publish the generated `public/` directory to a static host. Do not publish the source workspace, local configuration, or dependency cache.

## Contribute and troubleshoot

Keep descriptions aligned with the component source and quick-start manifest. Distinguish an implemented feature from a plan, and a verified platform from a proposed one. Check links and page navigation in the preview.

If installation cannot download Hugo, inspect the postinstall output and configured proxy. Do not substitute an arbitrary system Hugo version without checking compatibility.

[Previous overview](README.reference.md) · [Developer documentation](docs/developer/)

## License

Copyright 2026 InsightOS. First-party code: [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and [license scope](LICENSE_SCOPE.md) for third-party components and assets.
