#!/usr/bin/env bash
# PostToolUse hook for Bash commands.
# Reads JSON from stdin, logs the command to today's shell log.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPEND_SCRIPT="$SCRIPT_DIR/shell-log-append.sh"
# Fallback for dev repo layout
[ -f "$APPEND_SCRIPT" ] || APPEND_SCRIPT="$SCRIPT_DIR/../shell-log-append.sh"

INPUT=$(cat 2>/dev/null) || INPUT="{}"

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"' 2>/dev/null) || COMMAND="unknown"
IS_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null) || IS_BG="false"

"$APPEND_SCRIPT" "$SESSION_ID" "$COMMAND" "$IS_BG" 2>/dev/null || true
exit 0
