---
title: "HTTP API"
linkTitle: "HTTP API"
weight: 11
description: "REST endpoint inventory for Semantic Server: auth, Project, Conversation, Plan Proposal, Workflow, simulation, devices, and observation domains. All extracted from router and handler source."
---

This page is the reference inventory of the Semantic Server HTTP API. Every endpoint is extracted from route-registration source `internal/server/http/router.go` (semantic-framework repository, same below). Request/response fields are extracted from structs in `internal/server/http/handlers/` and `internal/store/`. When the inventory disagrees with code, trust the code and please report it.

For protocol boundaries and component split, see [Component interfaces and events](protocols.en.md). For WebSocket event channels, see [WebSocket events](ws.en.md).

## Gateway and ports

- The HTTP gateway listens on `server.http_addr` (default `:8080`) and carries every REST endpoint in this page plus the Pilot transfer entry `/pilot/v1/transfers/*`;
- The WebSocket gateway listens on `server.ws_addr` (default `:8081`) and carries `/ws/*` channels (see the WebSocket events page);
- Middleware chain: RequestID (injects trace_id) → Recovery → Logging → auth middleware.
- Source: `internal/server/http/router.go` (route assembly), `internal/server/http/middleware.go` (HTTP middleware), `pkg/config/config.go` (port defaults).

## Authentication

Source: `internal/server/auth/service.go`, `internal/server/auth/handlers.go`, `internal/server/auth/middleware.go`.

- Auth model: local account + opaque token (hex of 32 random bytes). Tokens are stored in the SQLite tokens table and are **not JWT**;
- Call style: every endpoint except the whitelist requires header `Authorization: Bearer <token>`;
- Token TTL: 24 hours (`tokenTTL = 24 * time.Hour`). An expired token is lazily purged and returns `AUTH_TOKEN_EXPIRED`;
- Seed account: first start automatically creates user `admin`. The initial password comes from environment variable `SEMANTIC_ADMIN_PASSWORD`. When unset it is `admin123` and a WARN asks you to change it;
- Error codes (HTTP 401, matching `error.code`): `AUTH_INVALID_CREDENTIALS`, `AUTH_TOKEN_INVALID`, `AUTH_TOKEN_EXPIRED`, `AUTH_TOKEN_REQUIRED`;
- Pilot devices use a dedicated credential bound to the Pilot instance (exchanged through Pilot Enrollment) and do not reuse a user token. The credential is used only for `/ws/pilot` and `/pilot/v1/transfers/*` (see the Pilot section of [WebSocket events](ws.en.md)).

Auth whitelist (exact match; `publicPaths` in `internal/server/auth/middleware.go`):

| Path | Description |
|---|---|
| `/api/v1/auth/login` | Login |
| `/api/v1/pilot-enrollments/claim` | Pilot claims a credential with a join code |
| `/api/v1/system/healthz` | Health check |
| `/api/v1/system/version` | Version query |

### POST /api/v1/auth/login

Log in and issue a token. Source: `internal/server/auth/handlers.go` (`HandleLogin`).

Request body (`loginRequest`):

| Field | Type | Required | Description |
|---|---|---|---|
| `username` | string | Yes | Username. Missing user and wrong password return the same error code |
| `password` | string | Yes | Password (server stores only a bcrypt hash) |

Response 200 (`tokenResponse`):

```json
{
  "token": "<opaque token>",
  "expires_at": "<RFC3339 时间>"
}
```

Errors: `400 BAD_REQUEST` (missing fields / not JSON), `401 AUTH_INVALID_CREDENTIALS`.

### POST /api/v1/auth/refresh

Exchange the current Bearer token for a new token. The old token is invalidated immediately (one old token can be exchanged only once at a time). This endpoint is in the protected group and the request must carry the about-to-expire token. Source: `internal/server/auth/handlers.go` (`HandleRefresh`), `internal/server/auth/service.go` (`Refresh`).

Request body: none.

Response 200: same as `tokenResponse` (new `token` and `expires_at`).

### POST /api/v1/auth/logout

Revoke the current Bearer token. Missing token still returns success (logout is idempotent). Source: `internal/server/auth/handlers.go` (`HandleLogout`).

Request body: none. Response 200: `{"ok": true}`.

## Common conventions

- **Unified error format**: every non-2xx response is `{"error": {"code": "<machine-readable error code>", "message": "<human-readable description>"}}`. Source: `internal/server/http/errors.go` (`WriteError`).
- **revision optimistic lock**: mutable objects such as Project, Memory, Plan Proposal, Workflow, and Semantic Map carry a `revision` field. A write must carry the revision the client last read (field name `revision` or `expected_revision`; when both are provided `expected_revision` wins). A mismatch returns `409 REVISION_CONFLICT`.
- **Idempotent stop**: stop-class operations (Run cancel, Robot Execution stop, Workflow stop/pause) return current progress or terminal state on a repeat request and do not run again. Robot Skill start also has a `request_key` idempotency key: within the same Project, a `request_key` that hits an existing Execution returns that Execution directly (`Run` in `internal/robot/service.go`).
- **Event coupling**: after a write commits it publishes the matching WS event (for example `project.updated`, `plan_proposal.approved`). Events are assigned a Project-local sequence by Aggregator and delivered. A successful HTTP response does not mean the subscriber has received the event. When a subscriber finds a sequence gap it should re-read a snapshot (Studio Snapshot / Device Snapshot).
- **Archive semantics**: DELETE of Project and Conversation is archive, not physical delete. Messages, Runs, Interactions, and Traces are kept.

## System endpoints

Source: `internal/server/http/router.go` (`healthzHandler`, `versionHandler`, `pingHandler`).

| Method | Path | Purpose | Notes |
|---|---|---|---|
| GET | `/api/v1/system/healthz` | Process liveness probe | Public; response `{"status":"ok"}`; dependency probes are in TODO(B3) |
| GET | `/api/v1/system/version` | Query version | Public; response `{"version":"..."}`, version from `pkg/version` |
| GET | `/api/v1/system/ping` | Auth-path verification | Protected; response `{"pong":true,"user_id":"..."}`, `user_id` from the Bearer token |

## Project domain

Source: `internal/server/http/handlers/projects.go` (CRUD/activate/memory/runs), `project_bindings.go` (bindings), `projects_v030_snapshot.go` (Studio Snapshot), `robots.go` (Project Robot timeline). Project response bodies uniformly use `store.Project` (`internal/store/project.go`).

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| GET | `/api/v1/projects` | Current user's Project list | query: `include_archived` | — |
| POST | `/api/v1/projects` | Create a Project | `name`, `runtime_profile_id?`, `preferred_runtime_installation_id?` | Event `project.created` |
| GET | `/api/v1/projects/{id}` | Project detail | — | After archive `410 PROJECT_ARCHIVED` |
| PATCH | `/api/v1/projects/{id}` | Rename | `name`, `revision` | Optimistic lock; event `project.updated` |
| DELETE | `/api/v1/projects/{id}` | Archive a Project | `revision` (body or query) | Archive is idempotent and backfills Default Project; event `project.archived` |
| POST | `/api/v1/projects/{id}/activate` | Activate a Project | — | Also releases the previous active Project's simulation; events `project.activated` / `project.deactivated` |
| GET | `/api/v1/projects/{id}/bindings` | Query Agent/Skill bindings | — | — |
| PUT | `/api/v1/projects/{id}/bindings` | Atomically replace bindings | `agent_ids`, `skill_names` | A running Project is rejected (must be active and writable); event `project.bindings.updated` |
| GET | `/api/v1/projects/{id}/memory` | Read Project Memory | — | When not created, content is empty and revision=0 |
| PUT | `/api/v1/projects/{id}/memory` | Save Memory | `content`, `revision` | Cap 1MB; optimistic lock; event `memory.updated` |
| GET | `/api/v1/projects/{id}/conversations` | Conversation list | query: `include_archived` | See Conversation domain |
| POST | `/api/v1/projects/{id}/conversations` | Create a Conversation | `title` | Requires an active Project; event `conversation.created` |
| DELETE | `/api/v1/projects/{id}/conversations/{conversation_id}` | Archive a Conversation | — | `409` when there is an unfinished Run or pending Interaction; event `conversation.archived` |
| GET | `/api/v1/projects/{id}/runs` | Run list | query: `status`, `conversation_id`, pagination | — |
| GET | `/api/v1/projects/{id}/studio/snapshot` | Full Studio snapshot | — | Recover from this on an event gap (see WebSocket events) |
| GET | `/api/v1/projects/{id}/robot-executions` | Project Robot Execution list | — | Cap 200 |

### GET/POST /api/v1/projects request/response skeleton

Request body (`createProjectRequest`, `internal/server/http/handlers/projects.go`):

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Project name. Whitespace is treated as missing |
| `runtime_profile_id` | string | No | Portable runtime-capability preference (references a Runtime Profile) |
| `preferred_runtime_installation_id` | string | No | Runtime-install preference on the current Server |

Response 201: `{"project": <store.Project>}`. `store.Project` (`internal/store/project.go`):

```json
{
  "id": "", "owner_id": "", "name": "", "workspace_root": "",
  "is_default": false, "mode": "", "is_active": false,
  "runtime_profile_id": "", "preferred_runtime_installation_id": "",
  "archived_at": null, "revision": 0,
  "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

PATCH request body (`updateProjectRequest`): `{"name": "", "revision": 0}`. DELETE request body (`archiveProjectRequest`): `{"revision": 0}` (query `?revision=` also works). Both respond `{"project": <store.Project>}`.

Memory request body (`saveMemoryRequest`): `{"content": "", "revision": 0}`; response `{"memory": {"project_id":"","content":"","revision":0,"updated_at":"<RFC3339>"}}` (`store.ProjectMemory`, `internal/store/context.go`).

Common errors: `409 REVISION_CONFLICT`, `409 PROJECT_INACTIVE`, `410 PROJECT_ARCHIVED`, `409 DEFAULT_PROJECT` (Default Project cannot be archived), `409 PROJECT_HAS_ACTIVE_WORK` (still has an unfinished Run or pending Interaction).

## Conversation and Run domain

Source: `internal/server/http/handlers/projects.go` (Project side), `internal/server/http/handlers/chat.go` (session view `sessionView`, message view `messageView`). Message send is not REST: it goes through `chat.message` uplink on `/ws/studio` (or migration `/ws/chat`).

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| POST | `/api/v1/runs/{id}/cancel` | Cancel a specified Run | — | Idempotent stop; exact by Run ID, does not hit a new Run; 202 returns cancelling state |
| GET | `/api/v1/runs/{id}` | Run detail | — | — |

### POST /api/v1/projects/{id}/conversations request/response skeleton

Request body (`createSessionRequest`, title optional, default "新会话"): `{"title": ""}`.

Response 201: `{"conversation": <sessionView>}`. `sessionView` (`internal/server/http/handlers/chat.go`):

```json
{
  "id": "", "project_id": "", "title": "", "archived_at": null,
  "revision": 0, "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

### GET /api/v1/runs/{id} response skeleton

`{"run": <store.RunSession>}`. `store.RunSession` (`internal/store/chat.go`):

```json
{
  "id": "", "project_id": "", "conversation_id": "", "workflow_id": "", "task_id": "",
  "kind": "", "context_id": "", "agent_id": "", "agent_name": "",
  "provider": "", "endpoint": "", "model": "", "trace_id": "",
  "status": "", "error": "", "revision": 0,
  "started_at": "<RFC3339>", "updated_at": "<RFC3339>", "ended_at": null
}
```

POST `/api/v1/runs/{id}/cancel` response 202: `{"run": <store.RunSession>}` (status has entered the cancel flow). Errors: `503 RUN_CONTROL_UNAVAILABLE` (cancel service not assembled), `409 RUN_CANCEL_FAILED`.

## Plan Proposal domain

Source: `internal/server/http/handlers/projects_plan_proposal.go`. A Plan Proposal is produced by a Planning Run. Users can only approve or discard. Revisions before approve happen only in Conversation. Response bodies use `store.PlanProposal` (`internal/store/plan_proposal.go`).

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/plan-proposals/active` | Current unfinished Proposal | — | When there is no active Proposal, returns `{"plan_proposal": null}` instead of using 404 |
| GET | `/api/v1/projects/{id}/plan-proposals/{proposal_id}` | Proposal detail | — | — |
| POST | `/api/v1/projects/{id}/plan-proposals/{proposal_id}/approve` | Approve the plan and create a Workflow | `revision` / `expected_revision` | Optimistic lock; events `plan_proposal.approved`, `workflow.approved` |
| POST | `/api/v1/projects/{id}/plan-proposals/{proposal_id}/discard` | Discard the plan | `revision` / `expected_revision` | Event `plan_proposal.discarded` |

### Request skeleton (shared by approve and discard)

Request body (`planProposalActionRequest`, `internal/server/http/handlers/projects_plan_proposal.go`):

| Field | Type | Required | Description |
|---|---|---|---|
| `revision` | int64 | one of two | Old field name; the Proposal revision the client last read |
| `expected_revision` | int64 | one of two | New field name; when non-0 it wins over `revision` |

The server takes one of the two as the expected revision. `<=0` returns `422 INVALID_REVISION`. A mismatch returns `409 REVISION_CONFLICT`.

### POST .../approve response skeleton

Response 200: `{"workflow_view": <store.WorkflowView>}`. `store.WorkflowView` (`internal/store/workflow.go`):

```json
{
  "workflow": {
    "id": "", "project_id": "", "conversation_id": "", "goal": "",
    "approved_scope": {}, "constraints": {}, "completion_criteria": {}, "map_scope": {},
    "status": "", "reason": "", "revision": 0, "confirmed_revision": 0,
    "created_at": "<RFC3339>", "started_at": null, "updated_at": "<RFC3339>", "ended_at": null
  },
  "tasks": [], "subtasks": [], "dependencies": [], "subtask_dependencies": []
}
```

`tasks`/`subtasks` are `store.Task`/`store.SubTask` arrays. `dependencies`/`subtask_dependencies` are the matching dependency arrays (fields: `internal/store/workflow.go`).

### POST .../discard response skeleton

Response 200: `{"plan_proposal": <store.PlanProposal>}`:

```json
{
  "id": "", "project_id": "", "conversation_id": "", "revision": 0,
  "status": "", "goal": "", "summary": "",
  "approved_scope": {}, "structured_plan": {}, "document_markdown": "",
  "created_at": "<RFC3339>", "updated_at": "<RFC3339>"
}
```

Errors: `503 PLAN_SERVICE_UNAVAILABLE` (Plan service not assembled), `409 REVISION_CONFLICT`, `422 INVALID_REVISION`, `404 RESOURCE_NOT_FOUND`.

## Workflow domain

Source: `internal/server/http/handlers/projects_v030.go` (`WorkflowApplication` interface, `workflowRevisionRequest`). After create, Workflow only exposes run control. The old direct PATCH/feedback/confirm entries are gone.

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/workflows` | Workflow list | query: `include_ended` | — |
| GET | `/api/v1/projects/{id}/workflows/active` | Current unfinished Workflow | — | When none, returns `{"workflow_view": null}` |
| GET | `/api/v1/projects/{id}/workflows/{workflow_id}/view` | Full plan/Task/dependency view | — | — |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/pause` | Pause | `revision`/`expected_revision` | Event `workflow.paused` |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/resume` | Resume | same | Event `workflow.resumed` |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/stop` | Request stop | same | Event `workflow.stopping`; idempotent stop |
| POST | `/api/v1/projects/{id}/workflows/{workflow_id}/retry-decision` | Retry a Robot Agent decision | same | Event `workflow.robot_decision_retried` |

Request body (`workflowRevisionRequest`): `{"revision": 0, "expected_revision": 0, "physical_state_confirmed": false, "reason": ""}`. Route `:action` values are `pause|resume|stop|retry-decision`. Runtime also supports `confirm-stop` (on-site stop confirmation, requires `physical_state_confirmed=true` and non-empty `reason`, otherwise `422 PHYSICAL_CONFIRMATION_REQUIRED`), but it is not registered in the route whitelist and is internal semantics. <!-- TODO(实跑): confirm-stop 未出现在 chi 路由 :action 枚举中，确认运行时实际可达性。 -->

Response 200: `{"workflow_view": <store.WorkflowView>}` (same structure as Plan Proposal approve). Errors: `503 WORKFLOW_SERVICE_UNAVAILABLE`, `409 ACTIVE_WORKFLOW_EXISTS`, `409 PROJECT_INACTIVE`, `422 INVALID_STATE`, `422 INVALID_REVISION`.

## Semantic Map domain

Source: `internal/server/http/handlers/projects_v030_map.go`.

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| GET | `/api/v1/projects/{id}/maps/{map_id}` | Read the semantic map | — | — |
| POST | `/api/v1/projects/{id}/maps/{map_id}/query` | Structured query | `generation`, `entity_id`, `entity_ids`, `entity_type`, `type`, `status`, `region_id`, `predicate`, `subject_id`, `object_id` | Read-only |
| POST | `/api/v1/projects/{id}/maps/{map_id}/generations` | Create a new map generation | `revision`/`expected_revision`, `reason` | Optimistic lock |
| POST | `/api/v1/projects/{id}/maps/{map_id}/updates` | Submit map changes | `generation`, `revision`/`expected_revision`, `source`, `operations[]` (or `entities`/`remove_entity_ids`/`relations`/`remove_relation_ids`) | A changed generation returns `409 MAP_GENERATION_CONFLICT` |

`mapOperation`: `{"op": "", "entity": {}, "entity_id": "", "relation": {}, "relation_id": ""}`.

## Robot Skill packages and device domain

Source: `internal/server/http/handlers/robots.go`; domain logic and error codes in `internal/robot/service.go`. Browsers only talk to the Server and do not connect to Pilot. Pilot offline returns `503 PILOT_OFFLINE`.

### Pilot Enrollment (device join)

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| POST | `/api/v1/pilot-enrollments` | Create a join code | — | Protected; response `{"enrollment": ...}` |
| POST | `/api/v1/pilot-enrollments/claim` | Pilot exchanges a join code for a credential | `join_code`, `pilot_id` | Public; one-shot. Reuse returns `409 PILOT_ENROLLMENT_INVALID`. Response includes `credential` and `websocket_path: "/ws/pilot"` |
| DELETE | `/api/v1/pilot-enrollments/{id}` | Revoke a join code | — | 204 |

### Robot Skill packages

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| GET | `/api/v1/robot-skills` | Published Skill package list | — | — |
| POST | `/api/v1/robot-skills` | Publish a Skill package (zip) | body: package archive | `400 ROBOT_SKILL_INVALID` |
| GET | `/api/v1/robot-skills/{name}/{version}` | Package detail (SKILL.md and directory) | — | Exact `name@version` |
| GET | `/api/v1/robot-skills/{name}/{version}/resources/*` | Read a text resource inside the package | — | — |

### Device center

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| GET | `/api/v1/devices` | Device list | query: `status`, `model`, `backend` | — |
| GET | `/api/v1/devices/snapshot` | Full device snapshot | — | Includes `event_sequence` for `/ws/devices` resume |
| GET | `/api/v1/devices/{robot_id}` | Device detail + recent Execution + Skill packages | — | — |
| GET | `/api/v1/devices/{robot_id}/executions` | Device Execution list | query: `project_id`, `limit` | — |
| POST | `/api/v1/devices/{robot_id}/stop` | Stop the device's current Execution | `execution_id`, `reason` | Idempotent stop; event `robot.execution.stopping` |
| POST | `/api/v1/devices/{robot_id}/skills/{name}/{version}/install` | Install a Skill onto a device | — | Writes desired state. Pilot receives `skill.install` over WS; event `skill.status` |
| POST | `/api/v1/devices/{robot_id}/skills/{name}/{version}/{action}` | enable/disable/uninstall | `:action` ∈ `enable\|disable\|uninstall` | Event `skill.status` |
| DELETE | `/api/v1/devices/{robot_id}/skills/{name}/{version}` | Remove a desired Skill | — | Equivalent to uninstall |
| POST | `/api/v1/devices/{robot_id}/abilities/debug` | Start Ability debug | `ability_instance_id`, `task_name`, `input` | Pilot downlink `ability.debug.start`; event `ability_debug.started` |
| POST | `/api/v1/devices/{robot_id}/abilities/debug/{debug_id}/stop` | Stop Ability debug | — | Event `ability_debug.stopping` |

### Robot Execution (manual debug and run control)

| Method | Path | Purpose | Key request fields | Notes (idempotency/events) |
|---|---|---|---|---|
| POST | `/api/v1/projects/{id}/robots/{robot_id}/skill-executions` | Start a Skill for manual debug | `skill_name`, `skill_version`, `input`, `request_key` | `request_key` is idempotent (`409 ROBOT_REQUEST_CONFLICT` means same key, different request); 202 returns queued |
| GET | `/api/v1/robot-executions/{execution_id}` | Execution detail + event pagination | query: `after_sequence` | Events are ascending by sequence, at most 500 per page; `has_more`+`next_sequence` hint continue-read |
| POST | `/api/v1/robot-executions/{execution_id}/stop` | Stop an Execution | `reason` | Idempotent stop; event `robot.execution.stopping` |
| POST | `/api/v1/robot-executions/{execution_id}/agent-reply` | Reply to an Agent request | body: arbitrary JSON (forwarded as-is to the Worker) | Pilot downlink `agent.reply`; 202 |

Execution response body is `store.RobotExecution` (`internal/store/robot.go`): `id`, `project_id`, `workflow_id`, `task_id`, `subtask_id`, `run_id`, `robot_id`, `pilot_instance_id`, `skill_name`, `skill_version`, `request_key`, `status`, `stage`, `progress`, `input`, `artifact_refs`, `artifact_sync`, `result`, `error`, `revision`, `created_at`, `updated_at`.

Common errors: `404 ROBOT_NOT_FOUND` / `ROBOT_EXECUTION_NOT_FOUND`, `409 ROBOT_BUSY` (debug lock held), `409 ROBOT_SKILL_UNAVAILABLE`, `409 ROBOT_EXECUTION_NOT_ACTIVE`, `503 PILOT_OFFLINE`.

### Transfer entry (internal)

| Method | Path | Purpose | Notes |
|---|---|---|---|
| GET | `/pilot/v1/transfers/*` | Pilot stream-downloads Skill packages and Artifacts | Internal endpoint: authenticated with a Pilot credential (not a user token). The Server issues the URL to Pilot (`package_url` of `skill.install`, `upload_url` of `artifact.upload`). Source: `internal/server/http/router.go`, `internal/server/auth/middleware.go`, `internal/robot/skillpackage.go` |

## Simulation domain

Source: `internal/server/http/handlers/simulation.go`, `simulation_resources.go`, `simulation_scene_packages.go`, `simulation_visual_assets.go`; event publish is in the same files. When the simulation service is not assembled, the whole route group is not registered (`simulationH == nil`).

### Global Runtime installs and scene catalog

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/simulation/runtime-installations` | Runtime install list |
| GET | `/api/v1/simulation/scene-catalog` | Scene catalog |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/probe` | Probe install availability |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/start-test` | Start a test instance |
| POST | `/api/v1/simulation/runtime-installations/{installation_id}/stop` | Stop a test instance |
| PUT | `/api/v1/simulation/runtime-installations/{installation_id}/enabled` | Enable/disable an install |

### Project simulation lifecycle

| Method | Path | Purpose | Notes (events) |
|---|---|---|---|
| POST | `/api/v1/projects/{id}/simulation/runtime/ensure` | Ensure the Project Runtime is ready | Event `simulation.runtime.ready` |
| POST | `/api/v1/projects/{id}/simulation/runtime/recover-interrupted` | Recover an interrupted Runtime | Event `simulation.runtime.recovered` |
| GET/PUT | `/api/v1/projects/{id}/simulation/runtime-preference` | Get/set Runtime preference | PUT event `simulation.runtime.preference_updated` |
| POST | `/api/v1/projects/{id}/simulation/runtime/release` | Leave the Project and reclaim the Runtime | Event `simulation.project.released` |

### Project scenes and instances

| Method | Path | Purpose | Notes (events) |
|---|---|---|---|
| GET/POST | `/api/v1/projects/{id}/simulation/project-scenes` | Scene-reference list/add | POST event `simulation.project_scene.added` |
| POST | `.../project-scenes/{project_scene_id}/layout-drafts` | Create a layout draft | Event `simulation.layout_draft.created` |
| POST | `.../project-scenes/{project_scene_id}/instances` | Start an instance from a Project scene | Event `simulation.scene.started` |
| POST | `.../instances/{instance_id}/switch-variant` | Switch a scene variant | Event `simulation.scene.variant_switched` |
| GET | `.../runtime-profiles` | Runtime Profile list | — |
| GET | `.../snapshot` | Global simulation snapshot | — |
| GET | `.../scenes` | Scene catalog | — |
| POST | `.../scenes/{scene_key}/instances` | Start an instance from a scene key | Event `simulation.scene.started` |
| GET | `.../instances/{instance_id}` | Instance detail | — |
| GET | `.../instances/{instance_id}/snapshot` | Instance state snapshot | — |
| GET | `.../instances/{instance_id}/viewer-scene` | Viewer scene description | Also includes `pose_stream_url` (points at `/ws/simulation-stream`) |
| GET | `.../instances/{instance_id}/viewer-scene/content` | Viewer scene content | — |
| POST | `.../instances/{instance_id}/sync-map` | Sync the instance map | Event `simulation.map.synced` |
| GET | `.../instances/{instance_id}/source-links` | Scene source links | — |
| GET | `.../instances/{instance_id}/evaluation` | Instance evaluation result | — |
| GET | `.../instances/{instance_id}/robots` | Virtual Robot list in the instance | — |
| POST | `.../instances/{instance_id}/{operation}` | Scene operations | `:operation` ∈ `pause\|resume\|step\|reset\|stop`; `step` request body `{"steps": 1..1000}`; event `simulation.scene.<operation>` |
| GET | `.../instances/{instance_id}/robots/{robot_id}/state` | Virtual Robot state | — |
| GET | `.../instances/{instance_id}/robots/{robot_id}/sensors` | Sensor readings | — |
| POST | `.../robots/{robot_id}/commands` | Issue a Robot command | Event `simulation.robot.command.accepted` |
| GET | `.../robots/{robot_id}/commands/{command_id}` | Query command status | — |
| POST | `.../robots/{robot_id}/commands/{command_id}/stop` | Stop a command | Event `simulation.robot.command.stopped` |
| POST | `.../robots/{robot_id}/hold` | E-stop / hold | Event `simulation.robot.hold` |
| GET | `.../scene-assets` | Scene asset list | — |
| GET | `.../visual-assets/{visual_id}/{version}.glb` | Download a visual asset (glb) | — |

### Scene documents

| Method | Path | Purpose | Notes (events) |
|---|---|---|---|
| GET/POST | `.../scene-documents` | Document list/create | POST event `simulation.scene.document.created` |
| GET/PUT | `.../scene-documents/{document_id}` | Read/update a document | PUT event `simulation.scene.document.updated` |
| POST | `.../scene-documents/{document_id}/operations` | Submit document operations | Event `simulation.scene.document.updated` |
| POST | `.../scene-documents/{document_id}/validate` | Validate a document | — |
| POST | `.../scene-documents/{document_id}/build` | Build a scene package | Event `simulation.scene.built` |
| POST | `.../scene-documents/{document_id}/publish` | Publish | Event `simulation.scene.document.published` |
| POST | `.../scene-documents/{document_id}/fork` | Fork | Event `simulation.scene.document.forked` |
| GET/POST | `.../scene-documents/{document_id}/layouts` | Layout list/create | POST event `simulation.scene.layout.created` |
| PATCH | `.../scene-documents/{document_id}/layout` | Rename a layout | Event `simulation.scene.layout.renamed` |
| DELETE | `.../scene-documents/{document_id}/layout` | Delete a layout | Event `simulation.scene.layout.deleted` |
| GET | `.../scenes/{scene_id}/package` | Export a scene package | — |
| POST | `.../scene-packages/import` | Import a scene package | Event `simulation.scene.package.imported` (one per document) |

## Agent directory, skill library, and tool catalog

Source: `internal/server/http/handlers/agents.go`, `skills.go`, `tools.go`.

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| GET | `/api/v1/agents` | Team member directory (read-only roster) | — | Returns an empty list when no Team is configured |
| PUT | `/api/v1/agents/{id}/models` | Update a role's model policy | `model`, `reasoning_effort`, `reasoning_visibility` | — |
| GET | `/api/v1/skills` | Agent Skill catalog (SKILL.md frontmatter summary) | — | No-skill shape returns `[]` |
| GET | `/api/v1/skills/{name}` | Skill detail (including body and extension fields) | — | 404 `SKILL_NOT_FOUND` |
| GET | `/api/v1/skills/{name}/resources/*` | Read a Skill text resource on demand | — | Large/binary files are rejected (`SKILL_RESOURCE_TOO_LARGE` / `SKILL_RESOURCE_NOT_TEXT`) |
| GET | `/api/v1/tools` | Tool catalog (built-in + MCP, including health) | — | Grouped by source |

## Observation domain (read-only)

Source: `internal/server/http/handlers/traces.go`, `metering.go`, `interactions.go`.

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| GET | `/api/v1/traces` | Trace list | pagination | `traceView`: `trace_id`, `name`, `kind`, `started_at`, `duration_ms`, `span_count` |
| GET | `/api/v1/traces/{trace_id}/spans` | Span detail | — | `spanView`: `id`, `parent_id`, `name`, `kind`, `started_at`, `duration_ms`, `attrs` |
| GET | `/api/v1/metering/summary` | Model-call metering summary | pagination | `meteringSummaryView`: `model`, `agent`, `purpose`, `calls`, `prompt_tokens`, `completion_tokens`, `total_tokens` |
| GET | `/api/v1/metering/traces/{id}` | Metering detail for one Trace | — | — |
| GET | `/api/v1/interactions` | Interaction record list | query: `status` (`pending` for approval-card recovery), pagination | `interactionView`: `id`, `project_id`, `session_id`, `revision`, `agent`, `type`, `status`, `payload`, `reply`, and so on |

## Conversation domain (migration /chat)

Source: `internal/server/http/handlers/chat.go`. Kept for old CLI and migration pages. New integrators should use the Project domain + `/ws/studio`.

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| POST | `/api/v1/chat/attachments` | Upload a conversation image | multipart field `file` | ≤20MB, JPEG/PNG/GIF/WebP only; content goes into the artifact store, the message stores only a reference |
| GET | `/api/v1/chat/attachments/{id}` | Fetch image bytes | — | Returns binary (own attachments) |
| POST | `/api/v1/chat/artifacts/register` | Register a workspace file as an Artifact | `project_id`, `path`, `media_type?`, `summary?` | ≤100MB; path must be inside the workspace |
| GET | `/api/v1/chat/artifacts` | Artifact list | — | — |
| GET | `/api/v1/chat/artifacts/{id}` | Artifact metadata | — | Reuses the attachment handler |
| DELETE | `/api/v1/chat/artifacts/{id}` | Delete an Artifact | — | — |
| POST | `/api/v1/chat/sessions` | Create a session | `title?`, `project_id?` (defaults to the current active Project) | Event `conversation.created` |
| GET | `/api/v1/chat/sessions` | Own session list | — | Most recently active first |
| GET | `/api/v1/chat/sessions/{id}/agents` | Per-Agent model snapshot in the session | — | — |
| GET | `/api/v1/chat/sessions/{id}/agents/{agent_id}/tools` | Effective tool set of a session Agent | — | Computed from Profile/Project/permissions |
| PUT | `/api/v1/chat/sessions/{id}/agents/{agent_id}/model` | Session-level model override | `endpoint_id`, `reasoning_effort?` | `409 SESSION_BUSY` during an active Run |
| GET | `/api/v1/chat/sessions/{id}/messages` | Paginated messages | query: `page`, `page_size` (default 50, cap 200) | — |
| GET/PUT | `/api/v1/chat/sessions/{id}/host-execution` | Get/set session execution policy | PUT: `mode`, `enabled` | `409 SESSION_BUSY` during an active Run |
| DELETE | `/api/v1/chat/sessions/{id}` | Archive a session | — | `409` while running; event `conversation.archived`; 204 |

## Settings domain

Source: `internal/server/http/handlers/settings.go`.

| Method | Path | Purpose | Key request fields | Notes |
|---|---|---|---|---|
| GET | `/api/v1/settings` | Effective config snapshot | — | Sensitive values masked |
| PATCH | `/api/v1/settings` | Change config | `base_hash`, `patch` | `base_hash` optimistic lock + merge patch + whitelist hot apply; conflict returns `409` |
| GET | `/api/v1/settings/keys` | Hosted key list | — | Values masked |
| PUT | `/api/v1/settings/keys/{name}` | Write a key | `key_value` | Audit records only the key name, never the value |
| DELETE | `/api/v1/settings/keys/{name}` | Delete a key | — | — |

## Endpoint coverage note

This inventory covers all 140 routes registered in `internal/server/http/router.go` (including 1 internal transfer entry `/pilot/v1/transfers/*`; `/api/v1/simulation/*` and Project simulation sub-routes are not registered when the simulation service is not assembled). Device-domain `{action}` is a single registered route (enum `enable|disable|uninstall`). Plan Proposal `{action}` enum is `approve|discard`. Workflow `{action}` enum is `pause|resume|stop|retry-decision`. Scene operation `{operation}` enum is `pause|resume|step|reset|stop`.

## Related references

- WebSocket event channels and sequence resume: [WebSocket events](ws.en.md);
- Protocol overview and version boundaries: [Interfaces and configuration](_index.en.md), [Component interfaces and events](protocols.en.md).
