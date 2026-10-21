# Handoff (author: codex, rewritten 2026-10-18)

## Done
- `/sync` endpoint behind `SYNC_V1` flag; row-version conflict check covered by tests.

## In progress
- Offline queue in `web/src/offline/`: writes are queued, replay on reconnect is not wired yet.

## Next
1. Wire replay in `web/src/offline/replay.ts`, then run `npm test -- offline`.
2. Ask the user whether conflicts should prompt or silently keep the newest row.

## Open questions
- Conflict policy (above).
