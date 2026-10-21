#!/bin/bash
# Install agent-memory for Claude Code and Codex. Safe to re-run.
# Usage: bin/install.sh [--lang en|zh-CN]
set -e
repo="$(cd "$(dirname "$0")/.." && pwd)"
lang=en; [ "$1" = "--lang" ] && lang="$2"
rules="$repo/RULES.md"; [ "$lang" != en ] && rules="$repo/RULES.$lang.md"
[ -f "$rules" ] || { echo "no rules file for language '$lang'"; exit 1; }
command -v jq >/dev/null || { echo "jq is required (brew install jq)"; exit 1; }

DEST="${AGENT_MEMORY_HOME:-$HOME/.config/agent-memory}"
ts=$(date +%Y%m%d-%H%M%S)
backup() { [ -e "$1" ] && cp -R "$1" "$1.bak-$ts" && echo "backup: $1.bak-$ts"; return 0; }

# 1. files
backup "$DEST"
mkdir -p "$DEST/hooks"
cp "$rules" "$DEST/RULES.md"
rm -f "$DEST/hooks/memory-stop-check.sh"
cp "$repo"/hooks/*.sh "$DEST/hooks/"
cp "$repo/bin/sync.sh" "$DEST/sync.sh"
chmod +x "$DEST"/hooks/*.sh "$DEST/sync.sh"
echo "installed: $DEST"

# 2. hooks: add the SessionStart entry unless present; drop the Stop hook that
#    older versions installed (it forced a memory write every turn and fed bloat).
add_hooks() { # settings.json path
  local f="$1"
  [ -f "$f" ] || echo '{}' > "$f"
  backup "$f"
  jq --arg start "bash $DEST/hooks/memory-session-start.sh" '
    (.hooks // {}) as $h
    | .hooks = ($h | with_entries(.value |= map(select(([.hooks[]?.command] | map(test("agent-memory/hooks/memory-stop-check")) | any) | not)) | select(.value | length > 0)))
    | if ([.hooks.SessionStart[]?.hooks[]?.command] | map(test("agent-memory/hooks/")) | any) then .
      else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{hooks:[{type:"command", command:$start, timeout:10}]}]) end' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "hooks: $f"
}

# 3. Claude Code: @import the rules + hooks
if [ -d "$HOME/.claude" ]; then
  case "$DEST" in "$HOME"/*) line="@~${DEST#"$HOME"}/RULES.md" ;; *) line="@$DEST/RULES.md" ;; esac
  touch "$HOME/.claude/CLAUDE.md"
  grep -qF "agent-memory/RULES.md" "$HOME/.claude/CLAUDE.md" || { backup "$HOME/.claude/CLAUDE.md"; printf '\n%s\n' "$line" >> "$HOME/.claude/CLAUDE.md"; echo "claude: added $line to ~/.claude/CLAUDE.md"; }
  add_hooks "$HOME/.claude/settings.json"
fi

# 4. Codex: copy rules into AGENTS.md + hooks.json
CODEX="${CODEX_HOME:-$HOME/.codex}"
if [ -d "$CODEX" ]; then
  backup "$CODEX/AGENTS.md"
  bash "$DEST/sync.sh"
  add_hooks "$CODEX/hooks.json"
  echo "codex: new or changed hooks may need approval; open Codex and run /hooks to review and trust them."
fi
echo "done. Try: bash $DEST/hooks/memory-check.sh <project>"
