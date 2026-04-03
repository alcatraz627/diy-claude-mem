#!/usr/bin/env bash
# SessionStart hook. Writes a session header to today's log file.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_SCRIPT="$SCRIPT_DIR/shell-log-file.sh"
# Fallback for dev repo layout
[ -f "$FILE_SCRIPT" ] || FILE_SCRIPT="$SCRIPT_DIR/../shell-log-file.sh"

INPUT=$(cat 2>/dev/null) || INPUT="{}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"

LOG_FILE="$("$FILE_SCRIPT")" || exit 0
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

printf '\n### Session: %s — %s\n' "$SESSION_ID" "$TIMESTAMP" >> "$LOG_FILE" 2>/dev/null || true
exit 0
