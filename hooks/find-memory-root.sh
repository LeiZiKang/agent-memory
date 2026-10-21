#!/bin/bash
# Print the directory that holds the nearest .agent-memory/, walking up from $1.
# Stops at the git root or $HOME (exclusive). Exit 1 if none.
d="$(cd "$1" 2>/dev/null && pwd -P)" || exit 1
home="$(cd "$HOME" && pwd -P)"
while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "$home" ]; do
  [ -d "$d/.agent-memory" ] && { echo "$d"; exit 0; }
  [ -e "$d/.git" ] && exit 1
  d="$(dirname "$d")"
done
exit 1
