#!/usr/bin/env bash
# Installs diy-claude-mem scripts and skill into ~/.claude/
# Also registers hooks in ~/.claude/settings.json for any hooks not yet present.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/scripts/diy-mem"
SKILL_DIR="$HOME/.claude/skills/shell-mem"
SETTINGS="$HOME/.claude/settings.json"

# ── Copy scripts ──────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

for f in "$REPO_DIR"/scripts/*.sh; do
  [ -f "$f" ] && cp -f "$f" "$INSTALL_DIR/"
done

for f in "$REPO_DIR"/scripts/hooks/*.sh; do
  [ -f "$f" ] && cp -f "$f" "$INSTALL_DIR/"
done

# Copy dispatcher (no .sh extension)
[ -f "$REPO_DIR/scripts/shell-mem" ] && cp -f "$REPO_DIR/scripts/shell-mem" "$INSTALL_DIR/shell-mem"

chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR/shell-mem" 2>/dev/null || true

# ── Copy skill ────────────────────────────────────────────────────────────────
mkdir -p "$SKILL_DIR"
cp -f "$REPO_DIR/skills/shell-mem/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "✓ Scripts installed to $INSTALL_DIR/"
echo "✓ Skill installed to $SKILL_DIR/"

# ── Register hooks in settings.json ──────────────────────────────────────────
if [ ! -f "$SETTINGS" ]; then
  echo "⚠ settings.json not found at $SETTINGS — skipping hook registration"
  echo "  Add hooks manually per PLAN.md §Phase 1 + Phase 2."
  exit 0
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠ jq not found — skipping hook registration"
  exit 0
fi

register_hook() {
  local event="$1"
  local matcher="${2:-}"
  local command="$3"
  local async="${4:-false}"

  # Check if this command is already registered under this event
  if jq -e --arg ev "$event" --arg cmd "$command" \
    '.hooks[$ev] // [] | .[] | .hooks[] | select(.command == $cmd)' \
    "$SETTINGS" >/dev/null 2>&1; then
    echo "  ↳ already registered: $command"
    return
  fi

  # Build the new hook entry
  local hook_entry
  if [ "$async" = "true" ]; then
    hook_entry='{"async": true, "command": "'"$command"'", "type": "command"}'
  else
    hook_entry='{"command": "'"$command"'", "type": "command"}'
  fi

  local new_entry
  if [ -n "$matcher" ]; then
    new_entry='{"matcher": "'"$matcher"'", "hooks": ['"$hook_entry"']}'
  else
    new_entry='{"hooks": ['"$hook_entry"']}'
  fi

  # Append the new entry to the event array
  local tmp
  tmp=$(mktemp)
  jq --arg ev "$event" --argjson entry "$new_entry" \
    '.hooks[$ev] = ((.hooks[$ev] // []) + [$entry])' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "  ↳ registered: [$event] $command"
}

echo ""
echo "Registering hooks in $SETTINGS …"

register_hook "PostToolUse" "Bash"        "~/.claude/scripts/diy-mem/track-bash.sh"       "true"
register_hook "PostToolUse" "BashOutput"  "~/.claude/scripts/diy-mem/mark-done-bash.sh"   "true"
register_hook "UserPromptSubmit" ""       "~/.claude/scripts/diy-mem/inject-shell-state.sh"
register_hook "SessionStart" ""           "~/.claude/scripts/diy-mem/init-session.sh"      "true"
register_hook "PreCompact" ""             "~/.claude/scripts/diy-mem/pre-compact-shell.sh"
register_hook "Stop" ""                   "~/.claude/scripts/diy-mem/session-end-shell.sh" "true"

echo ""
echo "✓ Hook registration complete."
echo ""
echo "Next: restart Claude Code (or open a new session) for hooks to take effect."
