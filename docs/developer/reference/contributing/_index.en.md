---
title: "Contributing Guide"
weight: 30
---

The contribution process keeps cross-repository changes clear, reviewable, and verifiable. This page describes the working method every contributor must follow. Pipeline triggers, version checks, and artifact publishing are in [CI and release](ci-and-release.en.md).

## Start a change

1. Read the related architecture and developer docs.
2. Confirm the repositories and interfaces the change touches.
3. Inspect existing changes in the worktree.
4. Open an Issue for the feature or defect (the host platform decides the template: GitHub or GitLab templates are equivalent) and record the goal and acceptance method.

## External contributors

External contributors fork the repository from `main` (or the default branch), create a topic branch, and submit a PR/MR:

- The docs repository follows the root [CONTRIBUTING.md](https://github.com/insightos-community/semantic-docs/blob/main/CONTRIBUTING.md);
- First submissions should start with a small `docs` change so you can learn the writing rules and build verification;
- Maintainers review the PR/MR. Review comments are applied directly to code and docs.

## Branch model (core team)

- Feature branches are created from `develop` and merge back to `develop` through a Merge Request;
- A release is triggered by a SemVer tag on `develop`;
- Cross-repository features use the same topic branch name in each repository and submit a separate MR per repository.

## Code organization

- Keep module responsibilities aligned with the architecture layers.
- Use existing types and extension points.
- Keep the state machine and recovery entries clear.
- Use key Chinese comments to explain design reasons, concurrency boundaries, and physical-safety boundaries.
- Ordinary field assignment and straightforward branches should be expressed by the code itself.

## Commit convention

Commit titles use a conventional type and scope in the form `type(scope): 中文结果`:

```text
feat(robot-skill): 完成单侧外拉后的双侧接合
fix(workflow): 收口暂停恢复与幂等停止
docs(user): 重写仿真环境使用手册
```

Common types: `feat` (new feature), `fix` (bug fix), `docs` (documentation), `refactor` (refactor), `test` (tests), `chore` (build and tooling). Scope is the module or an in-repository domain name.

The commit body uses Chinese to explain:

- why the change is needed;
- design boundaries;
- key implementation;
- test results.

One commit focuses on one verifiable responsibility. Submit cross-repository features separately in each repository. Do not include build artifacts, caches, secrets, or unrelated formatting in a commit.

## Changelog

Each change adds a record file under `changelog/vX.Y.Z/` in the corresponding repository. The record states user-visible changes, interface changes, and migration requirements. At release time, records are collected into the root `CHANGELOG.md` (collection rules are in [CI and release](ci-and-release.en.md)).

## Merge Request

A Merge Request links the Issue and describes the user flow, affected modules, interface changes, and verification results. UI changes include screenshots. Robot behavior changes include Execution records and actual run results.

Review comments are applied directly to code, tests, and formal docs. Long-lived design goes into architecture or developer docs.

## Documentation contributions

When behavior, interfaces, or process change, update the docs site in the same change:

- Architecture and concept changes → `docs/architecture/`;
- User operation-flow changes → `docs/user/`;
- Extension points, build, test, or contribution-process changes → `docs/developer/`;
- Before submit, run `npm run docs:build` and confirm there are no dead links (see [Build, run, and test](../build/build-run-and-test.en.md)).
