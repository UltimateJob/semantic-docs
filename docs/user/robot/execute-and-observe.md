---
title: "Robot 执行与观察"
weight: 10
---

一次 Robot Skill 运行会形成 Robot Execution。它把业务步骤、Robot 动作、运行反馈、主动观察和最终结果组织为可浏览的执行记录。

## 执行层次

```text
Robot Execution
└── Stage
    └── Action
        └── Ability invocation
```

- **Stage**：Robot Skill 中具有明确目标和判断条件的阶段。
- **Action**：Stage 请求执行的机器人能力。
- **Ability invocation**：AbilityFramework 启动或选择 Ability 实例并执行 Action。
- **Feedback**：低层执行主动上报的进度和状态变化。
- **Observation**：为判断当前状态而发起的主动观察。
- **Artifact**：运行产生的图片、深度数据、文件和其他大体量内容。

## Execution 时间线

设备执行页按时间展示 Stage。选择一个 Stage 后，Inspector 显示：

- Stage 目标、状态和持续时间；
- Action 与 Ability invocation；
- Feedback 和 Observation；
- 错误、恢复信息和 Artifact；
- 运行结果与停止状态。

Project 底部调试区使用横向时间线连接 Workflow、Task、SubTask 和 Stage，便于从业务任务定位到具体 Robot 动作。

## 人工调试 Robot Skill

设备的 Robot Skill 页面提供人工调试入口：

1. 选择在线且空闲的 Robot。
2. 选择已安装、已启用的 Robot Skill 版本。
3. 使用由 Skill 输入模型生成的表单或 JSON 编辑器填写参数。
4. 启动调试并打开对应 Robot Execution。
5. 通过 Viewer 和 Execution 时间线观察结果。

人工调试复用正常 Robot Execution、Pilot、Ability 和 Robot SDK。仿真与真机使用相同入口，Robot 的安全限制和占用规则同时生效。

## 安全停止

活动执行提供“安全停止”。Server 将停止请求发送给 Pilot，Pilot 停止当前 Action 并让 Robot 进入 hold。界面在收到实际停止状态后显示终态。

停止请求已经进入 `stopping` 后，较早产生但迟到的运行事件不会把它恢复为活动态。Pilot 离线时，Execution 显示状态未知，Robot 保持占用且原动作不会在 Server 重启后自动重放。

优先恢复 Pilot 连接并重试正常安全停止。无法恢复时，从所属 Workflow 的运行面板使用“确认现场安全并终结”：弹窗会列出 Robot 和 Execution，现场人员必须确认底盘、机械臂和工具均已停止并处于安全保持状态，同时填写原因。确认记录和停止前错误会保留在 Execution 历史中。

不要通过删除数据库记录释放 Robot，也不要把进程退出或设备离线视为安全 hold 证据。
