# demo-app
> A small habit-tracker web app (fictional example for agent-memory).

## Current state
- Sync API shipped behind a flag; offline mode is next. Details in handoff.md.

## Records
### Decisions
- [2026-10-14 SQLite on device, Postgres on server](decisions/2026-10-14-sqlite-on-device.md) — one schema, synced by row version
- [2026-10-02 Use REST, not GraphQL](decisions/2026-10-02-rest-not-graphql.md) — small API surface, easy to cache
### Findings
- [2026-10-16 Safari drops IndexedDB in private mode](findings/2026-10-16-safari-private-indexeddb.md) — fall back to memory store, warn the user
