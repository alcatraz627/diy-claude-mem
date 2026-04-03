#!/usr/bin/env bash
# Returns path to the daily shell log file. Creates dir if missing.
# Usage: shell-log-file.sh [YYYY-MM-DD]
set -euo pipefail

DATE="${1:-$(date +%Y-%m-%d)}"
DIR="$HOME/.claude/shell-logs"
mkdir -p "$DIR"
echo "$DIR/$DATE.md"
