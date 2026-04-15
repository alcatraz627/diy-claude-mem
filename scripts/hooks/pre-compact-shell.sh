#!/usr/bin/env bash
# PreCompact hook. Snapshots active [BG] entries into ~/.claude/wal.md
# so that after compaction, Claude can recover which processes were running.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAIL_SCRIPT="$SCRIPT_DIR/shell-log-tail.sh"
[ -f "$TAIL_SCRIPT" ] || TAIL_SCRIPT="$SCRIPT_DIR/../shell-log-tail.sh"

WAL_FILE="$HOME/.claude/wal.md"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

INPUT=$(cat 2>/dev/null) || INPUT="{}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"

# Get last 100 log lines (covers most sessions)
TAIL_OUTPUT=$("$TAIL_SCRIPT" 100 2>/dev/null) || exit 0

if [ -z "$TAIL_OUTPUT" ]; then
  exit 0
fi

# Find active BG entries: has [BG] but not [BG:DONE]
ACTIVE_BG=$(echo "$TAIL_OUTPUT" | grep '\[BG\]' | grep -v '\[BG:DONE\]' 2>/dev/null || echo "")

if [ -z "$ACTIVE_BG" ]; then
  exit 0
fi

# Build WAL snapshot entry
SNAPSHOT="
=== SHELL SNAPSHOT [sid:$SESSION_ID] — $TIMESTAMP ===
Active background processes at time of compaction:
$ACTIVE_BG
(Resume with: shell_tail or shell-mem tail to see full context)"

# Append to WAL file (create if missing)
mkdir -p "$(dirname "$WAL_FILE")" 2>/dev/null || true
echo "$SNAPSHOT" >> "$WAL_FILE" 2>/dev/null || true

exit 0
