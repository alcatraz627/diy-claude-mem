#!/usr/bin/env bash
# PostToolUse hook for Bash commands.
# Reads JSON from stdin, logs the command to today's shell log.
# Phase 2: noise filter, deduplication, PID capture from tool_response.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPEND_SCRIPT="$SCRIPT_DIR/shell-log-append.sh"
CONFIG_SCRIPT="$SCRIPT_DIR/config.sh"
# Fallback for dev repo layout
[ -f "$APPEND_SCRIPT" ] || APPEND_SCRIPT="$SCRIPT_DIR/../shell-log-append.sh"
[ -f "$CONFIG_SCRIPT" ] || CONFIG_SCRIPT="$SCRIPT_DIR/../config.sh"

# Source config for DIYMEN_SKIP_PATTERNS
[ -f "$CONFIG_SCRIPT" ] && source "$CONFIG_SCRIPT" 2>/dev/null || true

INPUT=$(cat 2>/dev/null) || INPUT="{}"

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"' 2>/dev/null) || COMMAND="unknown"
IS_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null) || IS_BG="false"

# ── Noise filter ──────────────────────────────────────────────────────────────
if [ "${#DIYMEN_SKIP_PATTERNS[@]}" -gt 0 ]; then
  for pattern in "${DIYMEN_SKIP_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern" 2>/dev/null; then
      exit 0
    fi
  done
fi

# ── Deduplication ─────────────────────────────────────────────────────────────
# Don't log the same command twice in a row for this session.
LAST_CMD_FILE="/tmp/diy-mem-last-${SESSION_ID}.cmd"
LAST_CMD=$(cat "$LAST_CMD_FILE" 2>/dev/null || echo "")
if [ "$COMMAND" = "$LAST_CMD" ] && [ "$IS_BG" != "true" ]; then
  exit 0
fi
echo "$COMMAND" > "$LAST_CMD_FILE" 2>/dev/null || true

# ── PID capture ───────────────────────────────────────────────────────────────
# Parse tool_response.output for PID patterns when running in background.
PID=""
if [ "$IS_BG" = "true" ]; then
  TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response.output // ""' 2>/dev/null) || TOOL_RESPONSE=""
  if [ -n "$TOOL_RESPONSE" ]; then
    # Try common PID patterns: "PID 1234", "pid: 1234", "[PID: 1234]", "Process ID: 1234"
    PID=$(echo "$TOOL_RESPONSE" | grep -oE '\b(pid|PID)[: ]+[0-9]+' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
    [ -z "$PID" ] && PID=$(echo "$TOOL_RESPONSE" | grep -oE '[Pp]rocess (ID|id)[: ]+[0-9]+' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
    [ -z "$PID" ] && PID=$(echo "$TOOL_RESPONSE" | grep -oE '\[PID[: ]+[0-9]+\]' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
  fi
fi

# ── Port capture ─────────────────────────────────────────────────────────────
# Detect port from command flags or tool_response output.
# Passed as env var to append script (not a positional arg to avoid interface break).
PORT=""
if [ "$IS_BG" = "true" ]; then
  # Try command-line port flags
  PORT=$(echo "$COMMAND" | grep -oE '\-\-port[= ]([0-9]+)' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
  [ -z "$PORT" ] && PORT=$(echo "$COMMAND" | grep -oE 'PORT=([0-9]+)' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
  [ -z "$PORT" ] && PORT=$(echo "$COMMAND" | grep -oE 'port=([0-9]+)' | grep -oE '[0-9]+' | head -1 2>/dev/null || echo "")
  # Try tool_response output (server startup messages)
  if [ -z "$PORT" ] && [ -n "$TOOL_RESPONSE" ]; then
    PORT=$(echo "$TOOL_RESPONSE" | grep -oiE 'listening on[^0-9]*([0-9]+)' | grep -oE '[0-9]+' | tail -1 2>/dev/null || echo "")
    [ -z "$PORT" ] && PORT=$(echo "$TOOL_RESPONSE" | grep -oiE 'localhost:([0-9]+)' | grep -oE '[0-9]+' | tail -1 2>/dev/null || echo "")
    [ -z "$PORT" ] && PORT=$(echo "$TOOL_RESPONSE" | grep -oiE 'port[: ]+([0-9]+)' | grep -oE '[0-9]+' | tail -1 2>/dev/null || echo "")
  fi
fi

DIYMEN_PORT="$PORT" "$APPEND_SCRIPT" "$SESSION_ID" "$COMMAND" "$IS_BG" "$PID" 2>/dev/null || true
exit 0
