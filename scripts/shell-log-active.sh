#!/usr/bin/env bash
# Returns active [BG] entries (not [BG:DONE]) from recent log files.
# Usage: shell-log-active.sh [days_back]
# Output: one entry per line, same format as log file entries.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAYS="${1:-2}"
LOG_DIR="$HOME/.claude/shell-logs"

if [ ! -d "$LOG_DIR" ]; then
  exit 0
fi

# Collect log files from the last N days (most-recent first)
i=0
while [ "$i" -lt "$DAYS" ]; do
  d=$(date -v-"${i}d" +%Y-%m-%d 2>/dev/null || date -d "-${i} days" +%Y-%m-%d 2>/dev/null || echo "")
  if [ -n "$d" ] && [ -f "$LOG_DIR/$d.md" ]; then
    # Extract lines that have [BG] but not [BG:DONE]
    grep '\[BG\]' "$LOG_DIR/$d.md" 2>/dev/null | grep -v '\[BG:DONE\]' || true
  fi
  i=$((i + 1))
done

exit 0
