---
title: "Framework Internals"
weight: 10
---

Framework internals cover Semantic Framework, Semantic Studio, Pilot, Robot Execution, and environment runtime. Changes should keep the Project, Agent, Workflow, and Robot execution main line coherent.

Core code lives in the `semantic-framework` repository. The Studio frontend lives in the `semantic-web` repository.

## Main modules

| Module | Code location | What to watch |
|---|---|---|
| Semantic Server | `cmd/semantic-server/`, `internal/server/`, `internal/bootstrap/` | REST API, WebSocket, authentication, assembly, and configuration hot reload |
| Agent Runtime | `internal/agent/kernel/`, `internal/agent/runtime/`, `internal/agent/profile/` | Run, Tool, Skill, Interaction, Trace, and model calls |
| Workflow | `internal/workflow/`, `internal/store/workflow.go` | Proposal, Task, SubTask, event-driven scheduling, pause/resume, and stop |
| Pilot and Robot Execution | `internal/pilot/`, `internal/robot/`, `cmd/semantic-pilot/` | Pilot connection, Skill install, Worker start, Action routing |
| Environment | `internal/simulation/`, `configs/scenes.d/`, `configs/runtimes.d/` | Scene Catalog, Runtime Installation, Semantic Map, and virtual Robot |
| Semantic Studio | `semantic-web` | Conversation, Project resources, Workflow, device, and Execution UI |

## Development method

1. Describe the problem from the user flow.
2. Find the module that owns that state and behavior.
3. Make the API, event, and persistence impact explicit.
4. Cover state-change and failure-path tests first.
5. Implement the same user entry on the server and the frontend.
6. Verify refresh, reconnect, pause, and stop with a full product flow.

Cross-module features connect through existing application services and events. Keep the state machine to a small number of clear states so users can understand every waiting or failed state in Studio.
