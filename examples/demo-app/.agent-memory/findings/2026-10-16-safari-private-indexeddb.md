---
type: finding
date: 2026-10-16
author: claude-code
status: active
---
# Safari drops IndexedDB in private mode

**Finding**: in Safari private windows, IndexedDB opens but writes are discarded when the tab closes, with no error.
**Evidence**: reproduced on Safari 26.0; `navigator.storage.persisted()` returns false.
**Impact**: detect it at startup, fall back to the in-memory store and show a banner.
