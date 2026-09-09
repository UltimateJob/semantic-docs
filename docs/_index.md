---
title: "Semantic Documentation"
mermaid: true
hasmermaid: true
---

{{< blocks/cover title="Semantic Documentation" image_anchor="top" height="med" color="primary" >}}
<p class="lead mt-4">面向具身应用的架构、使用与开发文档</p>
<p>从 Agent 协作和任务规划，到 Robot Skill、Ability、Robot SDK、仿真与真机执行。</p>
<div class="mt-4">
  <a class="btn btn-lg btn-light me-3 mb-2" href="{{< relref "/architecture" >}}">了解 Semantic</a>
  <a class="btn btn-lg btn-secondary me-3 mb-2" href="{{< relref "/user" >}}">开始使用</a>
  <a class="btn btn-lg btn-secondary mb-2" href="{{< relref "/developer" >}}">开发扩展</a>
</div>
{{< /blocks/cover >}}

{{% blocks/section color="white" %}}

## 一条完整的具身任务

```mermaid
flowchart LR
    U[用户] --> A[Agent 协作]
    A --> W[Plan 与 Workflow]
    W --> R[Robot Skill]
    R --> B[Ability 与 Robot SDK]
    B --> E[仿真或真实环境]
    E --> A
```

Semantic 将用户目标、环境理解、多个 Agent 的协作和 Robot 的实际行动组织在同一个 Project 中。

<div class="row mt-4">
  <div class="col-md-4">
    <h4>架构文档</h4>
    <p>理解 Project、环境、Agent、Workflow、Robot 执行和扩展模型如何组成完整的具身应用框架。</p>
    <a href="{{< relref "/architecture" >}}">进入架构 →</a>
  </div>
  <div class="col-md-4">
    <h4>用户手册</h4>
    <p>使用 Semantic Studio 连接环境与 Robot，通过 Conversation 规划任务，并观察和控制实际执行。</p>
    <a href="{{< relref "/user" >}}">进入用户手册 →</a>
  </div>
  <div class="col-md-4">
    <h4>开发者文档</h4>
    <p>开发 Agent Skill、Robot Skill、Ability、Robot SDK、Scene 和 Runtime，并参与 Semantic 核心开发。</p>
    <a href="{{< relref "/developer" >}}">进入开发者文档 →</a>
  </div>
</div>

{{% /blocks/section %}}
