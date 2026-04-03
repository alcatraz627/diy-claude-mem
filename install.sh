#!/usr/bin/env bash
# Installs diy-claude-mem scripts and skill into ~/.claude/
# Does NOT modify settings.json or CLAUDE.md — those are done separately.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/scripts/diy-mem"
SKILL_DIR="$HOME/.claude/skills/shell-mem"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy all scripts (flat — hooks go into the same dir)
for f in "$REPO_DIR"/scripts/*.sh; do
  [ -f "$f" ] && cp -f "$f" "$INSTALL_DIR/"
done

for f in "$REPO_DIR"/scripts/hooks/*.sh; do
  [ -f "$f" ] && cp -f "$f" "$INSTALL_DIR/"
done

# Make all scripts executable
chmod +x "$INSTALL_DIR"/*.sh

# Install skill
mkdir -p "$SKILL_DIR"
cp -f "$REPO_DIR/skills/shell-mem/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "✓ Scripts installed to $INSTALL_DIR/"
echo "✓ Skill installed to $SKILL_DIR/"
