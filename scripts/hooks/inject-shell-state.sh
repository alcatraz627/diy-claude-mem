#!/usr/bin/env bash
# UserPromptSubmit hook. Injects active background shell info as additionalContext.
# Only outputs JSON if there are active [BG] entries (not [BG:DONE]).
# Uses shell-log-active.sh (cross-day aware) and kill -0 to detect dead PIDs.
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTIVE_SCRIPT="$SCRIPT_DIR/shell-log-active.sh"
[ -f "$ACTIVE_SCRIPT" ] || ACTIVE_SCRIPT="$SCRIPT_DIR/../shell-log-active.sh"

# Fallback: if shell-log-active.sh not installed yet, use tail approach
TAIL_SCRIPT="$SCRIPT_DIR/shell-log-tail.sh"
[ -f "$TAIL_SCRIPT" ] || TAIL_SCRIPT="$SCRIPT_DIR/../shell-log-tail.sh"

# Read stdin (UserPromptSubmit sends JSON but we don't need it)
cat > /dev/null 2>&1 || true

# Get active BG entries (cross-day, last 2 days)
if [ -x "$ACTIVE_SCRIPT" ]; then
  ACTIVE_ENTRIES=$("$ACTIVE_SCRIPT" 2 2>/dev/null) || ACTIVE_ENTRIES=""
else
  # Fallback: tail + filter
  TAIL_OUTPUT=$("$TAIL_SCRIPT" 30 2>/dev/null) || TAIL_OUTPUT=""
  ACTIVE_ENTRIES=$(echo "$TAIL_OUTPUT" | sed 's/\[BG:DONE\]//g' | grep '\[BG\]' 2>/dev/null) || ACTIVE_ENTRIES=""
fi

if [ -z "$ACTIVE_ENTRIES" ]; then
  exit 0
fi

# Classify entries: live (PID still running) vs orphaned (PID gone)
LIVE_ENTRIES=""
ORPHANED_ENTRIES=""

while IFS= read -r entry; do
  [ -z "$entry" ] && continue

  # Extract PID if present: [pid:12345]
  PID=$(echo "$entry" | grep -oE '\[pid:[0-9]+\]' | grep -oE '[0-9]+' | head -1)

  if [ -n "$PID" ]; then
    # kill -0 checks existence without sending a signal
    if kill -0 "$PID" 2>/dev/null; then
      LIVE_ENTRIES="${LIVE_ENTRIES}${entry}"$'\n'
    else
      ORPHANED_ENTRIES="${ORPHANED_ENTRIES}${entry}"$'\n'
    fi
  else
    # No PID info — assume live (can't verify)
    LIVE_ENTRIES="${LIVE_ENTRIES}${entry}"$'\n'
  fi
done <<< "$ACTIVE_ENTRIES"

# Strip trailing newlines
LIVE_ENTRIES="${LIVE_ENTRIES%$'\n'}"
ORPHANED_ENTRIES="${ORPHANED_ENTRIES%$'\n'}"

# Build context output
CONTEXT=""

if [ -n "$LIVE_ENTRIES" ]; then
  CONTEXT="## Active background shells\n${LIVE_ENTRIES}"
fi

if [ -n "$ORPHANED_ENTRIES" ]; then
  if [ -n "$CONTEXT" ]; then
    CONTEXT="${CONTEXT}\n\n## Orphaned background shells (PID no longer running — mark done)\n${ORPHANED_ENTRIES}"
  else
    CONTEXT="## Orphaned background shells (PID no longer running — mark done)\n${ORPHANED_ENTRIES}"
  fi
fi

if [ -z "$CONTEXT" ]; then
  exit 0
fi

echo "$CONTEXT" | jq -Rs '{"additionalContext": .}' 2>/dev/null || true

exit 0
