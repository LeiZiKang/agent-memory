#!/bin/bash
# SessionStart hook (Claude Code and Codex): inject the nearest .agent-memory/
# INDEX.md + handoff.md and any memory-check warnings as additional context.
input=$(cat)
start="${CLAUDE_PROJECT_DIR:-$(echo "$input" | jq -r '.cwd // empty')}"
[ -n "$start" ] || exit 0
here="$(dirname "$0")"
root=$(bash "$here/find-memory-root.sh" "$start") || exit 0
mem="$root/.agent-memory"
cap=${AGENT_MEMORY_INJECT_BYTES:-8000}

ctx="=== Project memory: $mem (shared by all agents; rules: the .agent-memory section of your global instructions) ==="
if [ -f "$mem/INDEX.md" ]; then
  ctx="$ctx
--- INDEX.md ---
$(head -c "$cap" "$mem/INDEX.md")"
fi
if [ -f "$mem/handoff.md" ]; then
  m=$(stat -f %m "$mem/handoff.md" 2>/dev/null || stat -c %Y "$mem/handoff.md")
  age=$(( ($(date +%s) - m) / 86400 ))
  ctx="$ctx
--- handoff.md (last written ${age} day(s) ago; verify volatile items before reporting them) ---
$(head -c "$cap" "$mem/handoff.md")"
fi
warnings=$(bash "$here/memory-check.sh" "$mem" 2>/dev/null)
if [ -n "$warnings" ]; then
  ctx="$ctx
--- memory-check warnings (fix in passing; don't derail the user's task) ---
$warnings"
fi
jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
exit 0
