#!/usr/bin/env bash
# Deletes shell log files older than 60 days.
# Usage: shell-log-cleanup.sh
# Always exits 0.

LOG_DIR="$HOME/.claude/shell-logs"

if [ ! -d "$LOG_DIR" ]; then
  echo "No shell-logs directory found."
  exit 0
fi

# Create README if it doesn't exist
if [ ! -f "$LOG_DIR/README.md" ]; then
  cat > "$LOG_DIR/README.md" << 'READMEEOF'
# Shell Logs
Daily log files for Claude Code shell command history.
Format: YYYY-MM-DD.md
Retention: 60 days. Run shell-log-cleanup.sh to purge old files.
READMEEOF
fi

# Calculate cutoff date (60 days ago)
CUTOFF=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d "-60 days" +%Y-%m-%d 2>/dev/null || echo "")

if [ -z "$CUTOFF" ]; then
  echo "Could not calculate cutoff date."
  exit 0
fi

COUNT=0
for file in "$LOG_DIR"/????-??-??.md; do
  [ -f "$file" ] || continue
  FILE_DATE=$(basename "$file" .md)
  # String comparison works for YYYY-MM-DD format
  if [[ "$FILE_DATE" < "$CUTOFF" ]]; then
    rm "$file" 2>/dev/null && COUNT=$((COUNT + 1))
  fi
done

echo "Deleted $COUNT log file(s) older than 60 days."
exit 0
