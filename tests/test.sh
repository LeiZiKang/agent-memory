#!/bin/bash
# Run: bash tests/test.sh
set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
check="$repo/hooks/memory-check.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
expect() { # name, pattern, output
  if printf '%s' "$3" | grep -qE -- "$2"; then echo "ok   $1"; else echo "FAIL $1"; printf '%s\n' "$3" | sed 's/^/     /'; fail=1; fi
}

# 1. the shipped example is clean
out=$(bash "$check" "$repo/examples/demo-app"); code=$?
[ "$code" = 0 ] && echo "ok   example is clean" || { echo "FAIL example: $out"; fail=1; }

# 2. a bloated, drifting memory triggers every warning
p="$tmp/proj"; m="$p/.agent-memory"; mkdir -p "$p/.git" "$m/decisions" "$m/findings"
{ echo "# proj"; echo "## Current state"; for i in 1 2 3 4 5; do echo "- state line $i"; done
  echo "## Records"; echo "- [gone](findings/nope.md)"; echo "- [old](decisions/2020-01-01-old.md)"; } > "$m/INDEX.md"
{ for d in 2026-01-01 2026-01-02 2026-01-03; do echo "## $d"; head -c 2500 /dev/zero | tr '\0' x; echo; done
  echo "## Waiting"; echo "- login works (as of 2020-01-01)"; } > "$m/handoff.md"
touch -t 202001010000 "$m/handoff.md"
printf -- '---\ntype: decision\nstatus: superseded\nsuperseded_by: missing.md\n---\n' > "$m/decisions/2020-01-01-old.md"
printf -- '---\ntype: finding\n---\n# no status\n' > "$m/findings/2020-01-02-nostatus.md"
out=$(bash "$check" "$p"); code=$?
expect "exit 1 on warnings" "^1$" "$code"
expect "handoff size" "handoff.md is [0-9]+ bytes" "$out"
expect "handoff stale" "last written [0-9]+ days ago" "$out"
expect "append-only" "dated headings" "$out"
expect "waiting section" "waiting/running section" "$out"
expect "state bullets" "current state has 5 bullets" "$out"
expect "broken link" "missing file: findings/nope.md" "$out"
expect "superseded target" "superseded_by 'missing.md' does not exist" "$out"
expect "missing status" "nostatus.md has no 'status" "$out"
expect "unlisted record" "nostatus.md is not listed" "$out"
expect "stale as-of" "as of 2020-01-01" "$out"

# 3. root lookup stops at the git root
mkdir -p "$tmp/outer/.agent-memory" "$tmp/outer/repo/.git" "$tmp/outer/repo/sub"
bash "$repo/hooks/find-memory-root.sh" "$tmp/outer/repo/sub" >/dev/null && { echo "FAIL lookup crossed git root"; fail=1; } || echo "ok   lookup stops at git root"
expect "lookup finds parent" "/proj$" "$(bash "$repo/hooks/find-memory-root.sh" "$p/.git")"

# 4. session-start emits valid hook JSON containing INDEX, handoff and warnings
out=$(echo "{\"cwd\":\"$p\"}" | CLAUDE_PROJECT_DIR= bash "$repo/hooks/memory-session-start.sh" | jq -r .hookSpecificOutput.additionalContext)
expect "inject INDEX" "--- INDEX.md ---" "$out"
expect "inject handoff" "--- handoff.md \\(last written" "$out"
expect "inject warnings" "memory-check warnings" "$out"

# 5. installer: idempotent, adds SessionStart, removes the legacy Stop hook, keeps foreign hooks
h="$tmp/home"; mkdir -p "$h/.claude" "$h/.codex"
echo '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"other"}]},{"hooks":[{"type":"command","command":"bash ~/.config/agent-memory/hooks/memory-stop-check.sh"}]}]}}' > "$h/.claude/settings.json"
HOME="$h" bash "$repo/bin/install.sh" >/dev/null && HOME="$h" bash "$repo/bin/install.sh" >/dev/null
s=$(jq -c . "$h/.claude/settings.json")
expect "legacy stop removed" '^\{"hooks":\{"Stop":\[\{"hooks":\[\{"type":"command","command":"other"\}\]\}\],"SessionStart":\[\{[^]]*memory-session-start[^]]*\]\}\]\}\}$' "$s"
expect "rules imported once" "^1$" "$(grep -c 'agent-memory/RULES.md' "$h/.claude/CLAUDE.md")"
expect "codex block once" "^1$" "$(grep -c 'agent-memory:begin' "$h/.codex/AGENTS.md")"
HOME="$h" bash "$repo/bin/uninstall.sh" --purge >/dev/null
expect "uninstall keeps foreign hooks" '"command":"other"' "$(jq -c . "$h/.claude/settings.json")"
expect "uninstall removes ours" '^0$' "$(grep -c agent-memory "$h/.claude/settings.json")"

exit $fail
