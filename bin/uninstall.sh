#!/bin/bash
# Remove agent-memory hooks and rules from Claude Code and Codex.
# Project .agent-memory/ folders are left untouched. Pass --purge to also delete the install dir.
set -e
DEST="${AGENT_MEMORY_HOME:-$HOME/.config/agent-memory}"
CODEX="${CODEX_HOME:-$HOME/.codex}"
ts=$(date +%Y%m%d-%H%M%S)
strip_hooks() {
  [ -f "$1" ] || return 0
  cp "$1" "$1.bak-$ts"
  jq '(.hooks // {}) |= with_entries(.value |= map(select(([.hooks[]?.command] | map(test("agent-memory/hooks/")) | any) | not)) | select(.value | length > 0))' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  echo "hooks removed: $1 (backup $1.bak-$ts)"
}
strip_hooks "$HOME/.claude/settings.json"
strip_hooks "$CODEX/hooks.json"
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.bak-$ts"
  grep -vF "agent-memory/RULES.md" "$HOME/.claude/CLAUDE.md.bak-$ts" > "$HOME/.claude/CLAUDE.md" || true
  echo "rules import removed: ~/.claude/CLAUDE.md"
fi
if [ -f "$CODEX/AGENTS.md" ]; then
  cp "$CODEX/AGENTS.md" "$CODEX/AGENTS.md.bak-$ts"
  awk 'index($0,"agent-memory:begin"){skip=1} !skip{print} index($0,"agent-memory:end"){skip=0}' "$CODEX/AGENTS.md.bak-$ts" > "$CODEX/AGENTS.md"
  echo "rules block removed: $CODEX/AGENTS.md"
fi
[ "$1" = "--purge" ] && rm -rf "$DEST" && echo "deleted $DEST"
echo "done. Project .agent-memory/ folders were not touched."
