#!/usr/bin/env bash
# UserPromptSubmit hook. Injects active background shell info as additionalContext.
# Only outputs JSON if there are active [BG] entries (not [BG:DONE]).
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAIL_SCRIPT="$SCRIPT_DIR/shell-log-tail.sh"
# Fallback for dev repo layout
[ -f "$TAIL_SCRIPT" ] || TAIL_SCRIPT="$SCRIPT_DIR/../shell-log-tail.sh"

# Read stdin (UserPromptSubmit sends JSON but we don't need it)
cat > /dev/null 2>&1 || true

TAIL_OUTPUT=$("$TAIL_SCRIPT" 30 2>/dev/null) || exit 0

if [ -z "$TAIL_OUTPUT" ]; then
  exit 0
fi

# Check if there are active [BG] entries (not just [BG:DONE])
# Remove all [BG:DONE] first, then check for remaining [BG]
ACTIVE_CHECK=$(echo "$TAIL_OUTPUT" | sed 's/\[BG:DONE\]//g' | grep -c '\[BG\]' 2>/dev/null) || ACTIVE_CHECK=0

if [ "$ACTIVE_CHECK" -gt 0 ]; then
  # Build JSON output with additionalContext
  CONTEXT="## Active background shells (from shell log)\n$TAIL_OUTPUT"
  # Use jq to safely encode the string as JSON
  echo "$CONTEXT" | jq -Rs '{"additionalContext": .}' 2>/dev/null || true
fi

exit 0
