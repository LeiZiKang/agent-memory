---
type: decision
date: 2026-10-14
author: claude-code
status: active
---
# SQLite on device, Postgres on server

**Decision**: store data in SQLite (wa-sqlite) in the browser and Postgres on the server, with the same table layout; sync rows by a monotonically increasing `version`.
**Why**: one schema to reason about; row versions make conflict detection a single comparison.
**Impact**: every table needs `version` and `updated_at`; migrations run on both sides.
