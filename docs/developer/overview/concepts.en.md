---
title: "Core Objects and Relationships"
linkTitle: "Core objects"
weight: 10
description: "How Project, Agent, Workflow, Task, Robot Skill, Ability, and Environment relate."
---

Semantic splits one embodied task into connected objects with clear responsibilities. Understand the relationships first, then choose the module to extend.

## Object relationships

```text
Project
└── Conversation
    └── Plan Proposal
        └── Workflow
            ├── Task
            │   └── SubTask
            │       └── Robot Execution
            │           └── Robot Skill
            │               └── Action
            │                   └── Ability
            │                       └── Robot SDK
            └── Agent Run
```

| Object | Role | Typical states |
|---|---|---|
| Project | Holds goals, resources, environment, and run history | active |
| Conversation | Collaboration entry between users and Agents | open / archived |
| Plan Proposal | A plan waiting for review | pending / approved / discarded |
| Workflow | Approved work that can keep progressing | pending / running / paused / completed |
| Task | A business result owned by one Agent | pending / running / completed |
| SubTask | An Agent or Robot step inside a Task | pending / running / completed |
| Robot Execution | One real Robot Skill run | running / failed / stopped |
| Environment | The Scene, objects, and state the Robot works in | starting / running |

## Boundary between Agent and Robot

Agents understand goals, call Tools, read Skills, and form plans. A Robot does not understand the business goal; it executes SubTasks that already exist. Workflow is the persistent boundary between the two.

## Choosing an extension point

- Add domain knowledge only: write an Agent Skill;
- Add an external query or operation: integrate a Tool / MCP;
- Change task dependencies and scheduling: extend Workflow;
- Compose existing actions: write a Robot Skill;
- Add an atomic action: write an Ability;
- Onboard a new device: implement a Robot SDK Backend;
- Add a simulated environment: add a Scene Package or Runtime Profile;
- Add observation or intervention: extend a Studio Panel / Renderer.
