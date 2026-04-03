#!/usr/bin/env bash
# PostToolUse hook for BashOutput (background process completion).
# Reads JSON from stdin, marks the matching BG entry as done.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARK_DONE_SCRIPT="$SCRIPT_DIR/shell-log-mark-done.sh"
# Fallback for dev repo layout
[ -f "$MARK_DONE_SCRIPT" ] || MARK_DONE_SCRIPT="$SCRIPT_DIR/../shell-log-mark-done.sh"

INPUT=$(cat 2>/dev/null) || INPUT="{}"

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"' 2>/dev/null) || COMMAND="unknown"

# Use first 50 chars as fragment
CMD_FRAGMENT=$(echo "$COMMAND" | cut -c1-50)

"$MARK_DONE_SCRIPT" "$SESSION_ID" "$CMD_FRAGMENT" 2>/dev/null || true
exit 0
