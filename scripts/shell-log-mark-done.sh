#!/usr/bin/env bash
# Marks a background shell entry as done ([BG] -> [BG:DONE]).
# Usage: shell-log-mark-done.sh <session_id> <command_fragment> [YYYY-MM-DD]
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_ID="${1:-}"
CMD_FRAGMENT="${2:-}"
DATE="${3:-}"

if [ -z "$SESSION_ID" ] || [ -z "$CMD_FRAGMENT" ]; then
  echo "Usage: shell-log-mark-done.sh <session_id> <command_fragment> [YYYY-MM-DD]"
  exit 0
fi

try_mark() {
  local log_file="$1"
  if [ ! -f "$log_file" ]; then
    return 1
  fi

  # Check if any line matches session_id AND command_fragment AND has [BG] but not [BG:DONE]
  if grep -q "\[sid:$SESSION_ID\]" "$log_file" 2>/dev/null &&
     grep "\[sid:$SESSION_ID\]" "$log_file" 2>/dev/null | grep -q "$CMD_FRAGMENT" &&
     grep "\[sid:$SESSION_ID\]" "$log_file" 2>/dev/null | grep "$CMD_FRAGMENT" | grep -q '\[BG\]'; then

    # Lock around sed to prevent concurrent write races (mkdir is atomic)
    LOCKDIR="/tmp/diy-mem-$(date +%Y-%m-%d).lock"
    until mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.05; done
    trap "rmdir '$LOCKDIR' 2>/dev/null" EXIT

    # Use sed to replace [BG] with [BG:DONE] on matching lines
    # macOS sed requires -i '' for in-place editing
    sed -i '' "/\[sid:$SESSION_ID\].*$(echo "$CMD_FRAGMENT" | sed 's/[[\.*^$()+?{|]/\\&/g').*\[BG\]/s/\[BG\]/[BG:DONE]/" "$log_file" 2>/dev/null

    local matched
    matched=$(grep "\[sid:$SESSION_ID\]" "$log_file" 2>/dev/null | grep "$CMD_FRAGMENT" | grep '\[BG:DONE\]' | head -1)
    echo "marked done: $matched"
    return 0
  fi
  return 1
}

if [ -n "$DATE" ]; then
  LOG_FILE="$("$SCRIPT_DIR/shell-log-file.sh" "$DATE")" || exit 0
  try_mark "$LOG_FILE" || echo "not found"
else
  # Try today first, then yesterday
  TODAY_FILE="$("$SCRIPT_DIR/shell-log-file.sh")" || exit 0
  if ! try_mark "$TODAY_FILE"; then
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "-1 day" +%Y-%m-%d 2>/dev/null || echo "")
    if [ -n "$YESTERDAY" ]; then
      YESTERDAY_FILE="$("$SCRIPT_DIR/shell-log-file.sh" "$YESTERDAY")" || exit 0
      if ! try_mark "$YESTERDAY_FILE"; then
        echo "not found"
      fi
    else
      echo "not found"
    fi
  fi
fi

exit 0
