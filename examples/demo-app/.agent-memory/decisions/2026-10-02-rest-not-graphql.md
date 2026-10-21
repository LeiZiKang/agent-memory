---
type: decision
date: 2026-10-02
author: codex
status: active
---
# Use REST, not GraphQL

**Decision**: plain REST endpoints.
**Why**: five endpoints in total; HTTP caching works out of the box; no extra client library.
**Impact**: revisit if the client starts making more than ~3 calls per screen.
