---
title: "Workflow and Task Orchestration"
linkTitle: "Workflow and Task Orchestration"
weight: 20
description: "Turn an Agent plan into a Workflow, Task, and SubTask that can keep progressing, be observed, be resumed, and be stopped."
---

**Workflow and task orchestration** answers one question: **how an understood goal becomes work that can continue, be observed, and be resumed**.

It sits between the Agent's semantic decisions and the Robot's physical execution. The Agent forms the plan. Workflow keeps the approved work, manages dependencies and resources, starts execution, and continues from events.

## Core objects

```text
Conversation
└── Plan Proposal       Plan before user review
    └── Workflow        Approved work that can keep progressing
        ├── Task        A business result owned by one Agent
        │   └── SubTask A local execution step
        └── Task
```

| Object | Responsibility | Not responsible for |
|---|---|---|
| Plan Proposal | Express the goal, scope, Tasks, relationships, and constraints, and wait for user approval | Starting physical actions directly |
| Workflow | Keep approved work and evaluate dependencies and resources from events | Making semantic decisions in place of an Agent |
| Task | Express one Agent's result responsibility and business input | Describing Stages inside a Robot Skill |
| SubTask | Express an Agent step or Robot step inside a Task | Replacing a concrete Skill / Ability |
| Robot Execution | Record the real Stage, Action, Feedback, and Observation of a Robot Skill | Deciding the overall business plan |

## Code locations

- Workflow service: `semantic-framework/internal/workflow/`;
- Store models: `semantic-framework/internal/store/workflow.go`;
- Store migrations: `semantic-framework/internal/store/migrate.go`;
- Agent: `semantic-framework/internal/agent/`;
- Pilot connection: `semantic-framework/internal/pilot/`;
- HTTP / WS: `semantic-framework/internal/server/http/`, `internal/server/ws/`;
- Studio: `semantic-web/src/stores/workflow.js`, Workflow panel.

## How a task runs

```text
User goal
→ Leader forms a Plan Proposal
→ User approves the exact revision
→ Atomically create Workflow / Task / dependencies
→ Event-driven scheduling
→ Agent Step or Robot Execution
→ Write results back
→ Workflow re-evaluates
→ Complete, pause, resume, or stop
```

The scheduler is not advanced by a fixed poll. These events trigger re-evaluation:

- a Plan is approved;
- a predecessor Task completes;
- an Agent or Robot becomes available;
- a SubTask completes;
- an Interaction is answered;
- an Execution reaches a terminal state;
- a pause or stop is requested.

## State machine

Workflow, Task, and SubTask share these states:

```text
pending
running
paused
stopping
completed
failed
stopped
```

State transitions must use revision optimistic locking. Robot occupancy uses a database unique constraint and must not rely only on in-process state. If a physical stop cannot be confirmed, keep `execution_state_unknown` and require human confirmation. Do not falsely report success or stop.

## Task and SubTask

A Task describes a business result, for example:

```text
Move one tote from the top layer of the source pallet to the target pallet.
```

Task Input includes:

- source object;
- target location;
- user-confirmed constraints;
- required Robot capabilities;
- predecessor results;
- completion conditions.

A Robot Task can form SubTasks:

```text
Source navigation
Grasp
Carrying navigation
Place
```

Each SubTask is only an internal step of the current Task. It does not express Stages inside a Robot Skill.

## Minimal operation: verify Workflow in Studio

1. Start the Server and Studio;
2. Create a Project;
3. Enter a clear robot goal in Conversation;
4. Review the Plan Proposal in the Plan Document panel;
5. Approve the current revision;
6. Inspect the Task DAG and states in the Workflow panel;
7. Wait for the Robot Task to generate SubTasks.

The Workflow should enter `running`. When resources or dependencies are not satisfied, it should show a clear waiting reason.

## What to do when changing Workflow

1. Confirm whether you are changing Plan, Workflow, Task, SubTask, or the scheduler;
2. Update state and migrations in `internal/store/workflow.go`;
3. Update scheduling and recovery logic in `internal/workflow/`;
4. Update HTTP / WS events and the Studio store;
5. Cover complete, failed, pause, stop, Server restart, and repeated operations;
6. Use full integration tests, not a single-state test.

## Testing

```bash
cd "$SEMANTIC/semantic-framework"

# Workflow and Store
go test ./internal/workflow/... ./internal/store/... -count=1

# Agent and interaction
go test ./internal/agent/... -count=1

# Real integration: mock model + HTTP/WS + Store
go test ./tests/integration/ -count=1

# Product chain
make test-v050-real-gate
```

## Boundaries

- Workflow does not generate a new business plan. It only keeps and advances approved work;
- A Task does not know Stages inside a Robot Skill;
- A SubTask is not an Ability and does not store device state;
- Workflow stop must not show `stopped` from a button response alone;
- `execution_state_unknown` must end through a safety confirmation path.

## Further reading

- [Planning and Workflow](../../../architecture/05-planning-and-workflow.en.md);
- [Server, Agent, and Workflow](../../reference/internals/server-agent-and-workflow.en.md);
- [Chapter 4: Plan Proposal, Workflow, and Task](../../quickstart/chapter_04_workflow.en.md);
- [End-to-End Integration](../../integration/end-to-end/_index.en.md).
