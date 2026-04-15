#!/usr/bin/env bash
# Prints today's shell log statistics.
# Usage: shell-log-stats.sh [YYYY-MM-DD]
# Output: human-readable summary (command count, sessions, BG status, file size).
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_SCRIPT="$SCRIPT_DIR/shell-log-file.sh"
[ -f "$FILE_SCRIPT" ] || FILE_SCRIPT="$SCRIPT_DIR/../shell-log-file.sh"

LOG_DIR="$HOME/.claude/shell-logs"
TARGET_DATE="${1:-}"

if [ -n "$TARGET_DATE" ]; then
  LOG_FILE="$LOG_DIR/$TARGET_DATE.md"
  DISPLAY_DATE="$TARGET_DATE"
else
  LOG_FILE="$("$FILE_SCRIPT" 2>/dev/null)" || LOG_FILE=""
  DISPLAY_DATE=$(date +%Y-%m-%d)
fi

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  echo "No log file for $DISPLAY_DATE."
  exit 0
fi

TOTAL_CMDS=$(grep -c '^\- \[' "$LOG_FILE" 2>/dev/null || echo 0)
SESSIONS=$(grep -c '^### Session:' "$LOG_FILE" 2>/dev/null || echo 0)
ACTIVE_BG=$(grep '\[BG\]' "$LOG_FILE" 2>/dev/null | grep -cv '\[BG:DONE\]' 2>/dev/null || echo 0)
DONE_BG=$(grep -c '\[BG:DONE\]' "$LOG_FILE" 2>/dev/null || echo 0)
LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')

printf "Today (%s):\n" "$DISPLAY_DATE"
printf "  Commands logged : %s\n" "$TOTAL_CMDS"
printf "  Sessions        : %s\n" "$SESSIONS"
printf "  Active BG       : %s\n" "$ACTIVE_BG"
printf "  Completed BG    : %s\n" "$DONE_BG"
printf "  Log file size   : %s bytes\n" "$LOG_SIZE"

# Show total log file count
if [ -d "$LOG_DIR" ]; then
  TOTAL_FILES=$(find "$LOG_DIR" -maxdepth 1 -name "????-??-??.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  printf "  Total log files : %s\n" "$TOTAL_FILES"
fi

exit 0
