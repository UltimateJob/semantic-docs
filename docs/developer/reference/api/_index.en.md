---
title: "APIs and Configuration"
linkTitle: "APIs and Configuration"
weight: 20
description: "Semantic's cross-component protocols, authentication, events, configuration contracts, and version boundaries."
---

This section is the entry for protocols and configuration. The current docs give a stable protocol overview by implementation boundary. For concrete fields, also treat the types, Manifest, routes, or Schema in the corresponding repository as authoritative.

- [Component interfaces and events](protocols.en.md): HTTP, WebSocket, Worker JSON-RPC, Action, and Robot SDK boundaries;
- [Agent roles and Team](../../core-modules/intelligent/agent-profile.en.md): `role.yaml`, Tool/Skill authorization, and Team;
- [Scene Package and simulation Runtime](../../core-modules/environment/scene-and-runtime.en.md): Scene, Runtime Profile, and virtual Robot;
- [Ability](../../core-modules/robot/ability.en.md): Manifest, Task Model, Action type, and Schema version;
- [Studio frontend architecture](../internals/semantic-studio.en.md): REST, WebSocket, Store, and event resume.

## Shared requirements for protocol references

Every cross-component protocol must state:

1. identity and authentication;
2. request or message model;
3. responses, events, and state machine;
4. error semantics, idempotency, and retry;
5. version compatibility;
6. source definition location and how to verify it.

## Current authentication entry

The Server login endpoint is `POST /api/v1/auth/login`. It returns an opaque token stored in SQLite. The default TTL is 24 hours. After expiry, use `POST /api/v1/auth/refresh` to obtain a new token. Pilot uses a dedicated credential bound to the device and does not reuse a browser user token.

## Current version boundaries

- Robot Skills use exact `name@version`;
- Ability Actions use `type@schema_version`;
- Robot SDK Wheel, Ability Zip, Skill Zip, Runtime Pack, and Robot Bundle each have their own versions;
- Compatible combinations are proven by the release manifest and product Gate. Do not rely on implicit upgrades.

If you change a protocol, you must update types, implementation, tests, example configuration, compatibility notes, and developer docs together.
