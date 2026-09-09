---
title: "仿真集成"
linkTitle: "仿真集成"
weight: 20
description: "接入 Scene Package、仿真 Runtime，并生成可执行的虚拟 Robot。"
---

本节面向仿真环境开发者。仿真集成由三个边界组成：Scene 资产、Runtime 引擎和 Framework 的 Runtime Installation。

## 集成边界

```text
Scene Package（场景资产）
→ MuJoCo Runtime（物理生命周期）
→ Runtime Installation（版本与资产登记）
→ Framework Scene Instance
→ VirtualRobotDescriptor
→ Robot SDK / Ability / Robot Skill
```

## 推荐顺序

1. 确认场景、Robot 模型、Mesh 和 Layout 的来源及分发许可；
2. 编写 `asset-manifest.yaml`、`scene_info.yaml` 和 Layout；
3. 在独立 Runtime 中加载 Scene，验证 health、实例状态、快照和 Robot 描述；
4. 生成冻结场景目录；
5. 在 Framework 中登记 Runtime Installation 和 Scene Catalog；
6. 在 Studio 中启动 Scene，确认虚拟 Robot 可被受管部署；
7. 按[设备集成](/developer/integration/device/)继续验证 Ability、Pilot 和 Robot Skill。

## 关键边界

Runtime 只负责物理生命周期、低层轨迹、Snapshot、Virtual Robot、传感器数据和 reset/stop/hold；它不负责 IK、路径规划、抓取策略、Ability、Robot Skill 或 Agent。新增 Scene 通常不需要修改 Runtime 源码。

## 阅读路径

- 场景资产和 Runtime 契约：[Scene Package 与仿真 Runtime](/developer/core-modules/environment/scene-and-runtime/)；
- 五分钟启动：[第 2 章：仿真环境](/developer/quickstart/chapter_02_simulation/)；
- 跨组件验证：[端到端集成](/developer/integration/end-to-end/)。

## 验收标准

- Runtime `/healthz` 正常；
- Scene 能从目录加载并创建实例；
- 实例达到 `running`；
- Snapshot 和 `/robots` 返回有效数据；
- Framework 能登记并托管该 Runtime；
- 虚拟 Robot 能进入与真机一致的 Robot Execution 链路。
