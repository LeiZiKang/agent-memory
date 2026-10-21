#!/bin/bash
# memory-check: lint a project's .agent-memory/ and print one warning per line.
# Usage: memory-check.sh [project-dir | .agent-memory-dir]   (default: current dir)
# Exit 0 when clean, 1 when there are warnings, 2 when no .agent-memory/ was found.
# Limits can be tuned with env vars (bytes / days):
MAX_HANDOFF=${AGENT_MEMORY_MAX_HANDOFF:-6000}
MAX_INDEX=${AGENT_MEMORY_MAX_INDEX:-8000}
STALE_DAYS=${AGENT_MEMORY_STALE_DAYS:-7}
VOLATILE_DAYS=${AGENT_MEMORY_VOLATILE_DAYS:-3}

target="${1:-.}"
if [ "$(basename "$target")" = ".agent-memory" ]; then mem="$target"
else
  root=$(bash "$(dirname "$0")/find-memory-root.sh" "$target") || exit 2
  mem="$root/.agent-memory"
fi
cd "$mem" || exit 2

now=$(date +%s)
warn() { echo "- $*"; found=1; }
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
size() { wc -c < "$1" | tr -d ' '; }
days_since_date() { # YYYY-MM-DD -> whole days ago
  local t
  t=$(date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null) || return 1
  echo $(( (now - t) / 86400 ))
}

# handoff.md: one current snapshot, rewritten rather than appended
if [ -f handoff.md ]; then
  s=$(size handoff.md)
  [ "$s" -gt "$MAX_HANDOFF" ] && warn "handoff.md is ${s} bytes (limit $MAX_HANDOFF). Rewrite it as the current state only; git keeps history (or move old text to archive/)."
  age=$(( (now - $(mtime handoff.md)) / 86400 ))
  [ "$age" -ge "$STALE_DAYS" ] && warn "handoff.md was last written ${age} days ago. Treat it as history and verify before relying on it."
  dated=$(grep -cE '^#{1,3} .*([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{1,2}-[0-9]{1,2})' handoff.md)
  [ "$dated" -ge 3 ] && warn "handoff.md has ${dated} dated headings; it looks append-only. Keep one current section."
  if [ "$age" -ge 2 ] && grep -qiE '^#{1,3} .*(waiting|pending|running|blocked|正在等|在跑|等待)' handoff.md; then
    warn "handoff.md has a waiting/running section that is ${age} days old. Re-check those items before reporting them."
  fi
fi

# INDEX.md: size, one state line, links resolve, records listed
if [ -f INDEX.md ]; then
  s=$(size INDEX.md)
  [ "$s" -gt "$MAX_INDEX" ] && warn "INDEX.md is ${s} bytes (limit $MAX_INDEX). It is injected every session; trim it to purpose, state line and record list."
  state=$(awk '/^## /{insec = ($0 ~ /(Current state|Status|当前状态|现状)/); next} insec && /^[-*] /{n++} END{print n+0}' INDEX.md)
  [ "$state" -gt 3 ] && warn "INDEX.md current state has ${state} bullets. Replace it with one line; details go in handoff.md."
  grep -oE '\]\([^)]+\)' INDEX.md | sed -E 's/^\]\(//; s/\)$//; s/#.*//' | while read -r link; do
    case "$link" in ''|http://*|https://*|mailto:*) continue ;; esac
    [ -e "$link" ] || echo "- INDEX.md links to missing file: $link"
  done | grep . && found=1
else
  warn "INDEX.md is missing."
fi

# decisions/ and findings/: frontmatter status, supersession targets, listed in INDEX
for f in decisions/*.md findings/*.md; do
  [ -f "$f" ] || continue
  head=$(head -n 12 "$f")
  st=$(printf '%s\n' "$head" | sed -nE 's/^status:[[:space:]]*([a-z]+).*/\1/p' | head -n 1)
  case "$st" in
    active) ;;
    superseded)
      by=$(printf '%s\n' "$head" | sed -nE 's/^superseded_by:[[:space:]]*//p' | head -n 1)
      if [ -z "$by" ]; then warn "$f is superseded but has no superseded_by."
      elif [ ! -e "decisions/$by" ] && [ ! -e "findings/$by" ] && [ ! -e "$by" ]; then
        warn "$f: superseded_by '$by' does not exist."
      fi ;;
    *) warn "$f has no 'status: active|superseded' in its frontmatter." ;;
  esac
  [ -f INDEX.md ] && [ "$st" != superseded ] && ! grep -qF "$(basename "$f")" INDEX.md && warn "$f is not listed in INDEX.md."
done

# volatile facts stamped "(as of YYYY-MM-DD)" / "截至 YYYY-MM-DD" that have gone stale
for f in handoff.md INDEX.md; do
  [ -f "$f" ] || continue
  grep -oE '(as of|As of|截至)[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort -u |
  while read -r d; do
    ago=$(days_since_date "$d") || continue
    [ "$ago" -ge "$VOLATILE_DAYS" ] && echo "- $f has a fact stamped as of $d (${ago} days ago). Re-check or delete it."
  done | grep . && found=1
done

[ -n "$found" ] && exit 1
exit 0
