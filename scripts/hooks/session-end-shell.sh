#!/usr/bin/env bash
# Stop hook. Appends a shell activity summary line to ~/.claude/wal.md.
# Fires when Claude finishes responding (Stop event).
# Writes only when shell activity exists for this session.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_SCRIPT="$SCRIPT_DIR/shell-log-file.sh"
[ -f "$FILE_SCRIPT" ] || FILE_SCRIPT="$SCRIPT_DIR/../shell-log-file.sh"

WAL_FILE="$HOME/.claude/wal.md"
TIMESTAMP="$(date '+%H:%M:%S')"

INPUT=$(cat 2>/dev/null) || INPUT="{}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"

LOG_FILE="$("$FILE_SCRIPT")" || exit 0

if [ ! -f "$LOG_FILE" ]; then
  exit 0
fi

# Count commands logged for this session today
CMD_COUNT=$(grep -c "\[sid:$SESSION_ID\]" "$LOG_FILE" 2>/dev/null || echo 0)

if [ "$CMD_COUNT" -eq 0 ]; then
  exit 0
fi

# Count still-active BG processes for this session
ACTIVE_BG_COUNT=$(grep "\[sid:$SESSION_ID\]" "$LOG_FILE" 2>/dev/null | grep '\[BG\]' | grep -cv '\[BG:DONE\]' 2>/dev/null || echo 0)

# Build summary suffix
SUMMARY="$CMD_COUNT cmd(s)"
if [ "$ACTIVE_BG_COUNT" -gt 0 ]; then
  SUMMARY="$SUMMARY, $ACTIVE_BG_COUNT active BG"
fi

# Append one-liner to WAL (create file if missing)
mkdir -p "$(dirname "$WAL_FILE")" 2>/dev/null || true
echo "[$TIMESTAMP] shell: $SUMMARY [sid:$SESSION_ID]" >> "$WAL_FILE" 2>/dev/null || true

exit 0
