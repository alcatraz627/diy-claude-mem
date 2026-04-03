#!/usr/bin/env bash
# Shows last N lines of a daily shell log file.
# Usage: shell-log-tail.sh [N] [YYYY-MM-DD]
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
N="${1:-30}"
DATE="${2:-}"

if [ -n "$DATE" ]; then
  LOG_FILE="$("$SCRIPT_DIR/shell-log-file.sh" "$DATE")" || exit 0
else
  LOG_FILE="$("$SCRIPT_DIR/shell-log-file.sh")" || exit 0
fi

if [ -f "$LOG_FILE" ]; then
  tail -n "$N" "$LOG_FILE" 2>/dev/null || true
fi
exit 0
