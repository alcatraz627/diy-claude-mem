#!/usr/bin/env bash
# SessionStart hook. Writes a session header to today's log file.
# Also injects carryover active BG shells from recent sessions as additionalContext.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_SCRIPT="$SCRIPT_DIR/shell-log-file.sh"
[ -f "$FILE_SCRIPT" ] || FILE_SCRIPT="$SCRIPT_DIR/../shell-log-file.sh"

ACTIVE_SCRIPT="$SCRIPT_DIR/shell-log-active.sh"
[ -f "$ACTIVE_SCRIPT" ] || ACTIVE_SCRIPT="$SCRIPT_DIR/../shell-log-active.sh"

INPUT=$(cat 2>/dev/null) || INPUT="{}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"

LOG_FILE="$("$FILE_SCRIPT")" || exit 0
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

printf '\n### Session: %s — %s\n' "$SESSION_ID" "$TIMESTAMP" >> "$LOG_FILE" 2>/dev/null || true

# Check for active BG from previous sessions (cross-day) and inject as context
if [ -x "$ACTIVE_SCRIPT" ]; then
  ACTIVE_ENTRIES=$("$ACTIVE_SCRIPT" 2 2>/dev/null) || ACTIVE_ENTRIES=""

  if [ -n "$ACTIVE_ENTRIES" ]; then
    CONTEXT="## Carryover: active background shells from previous sessions\nThese were still running when this session started — verify or mark done:\n${ACTIVE_ENTRIES}"
    echo "$CONTEXT" | jq -Rs '{"additionalContext": .}' 2>/dev/null || true
  fi
fi

exit 0
