#!/usr/bin/env bash
# Searches shell log files for a query string.
# Usage: shell-log-search.sh <query> [today|week|month|all]
# Always exits 0.
#
# Performance note: for week/month scopes, uses find + lexicographic date comparison
# to avoid spawning N date subprocesses (one per day). Since filenames are YYYY-MM-DD,
# string comparison gives identical ordering to numeric date comparison.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERY="${1:-}"
SCOPE="${2:-today}"
LOG_DIR="$HOME/.claude/shell-logs"

if [ -z "$QUERY" ]; then
  echo "Usage: shell-log-search.sh <query> [today|week|month|all]"
  exit 0
fi

if [ ! -d "$LOG_DIR" ]; then
  exit 0
fi

# Returns YYYY-MM-DD for N days ago — one call per scope, not per day
days_ago() {
  local n="$1"
  date -v-"${n}d" +%Y-%m-%d 2>/dev/null || date -d "-${n} days" +%Y-%m-%d 2>/dev/null || echo ""
}

case "$SCOPE" in
  today)
    TODAY=$(date +%Y-%m-%d)
    FILES=""
    [ -f "$LOG_DIR/$TODAY.md" ] && FILES="$LOG_DIR/$TODAY.md"
    ;;
  week)
    CUTOFF=$(days_ago 7)
    # find all log files and filter by name >= cutoff (lexicographic = chronological for ISO dates)
    FILES=$(find "$LOG_DIR" -maxdepth 1 -name "????-??-??.md" -type f 2>/dev/null \
      | sort \
      | while IFS= read -r f; do
          d=$(basename "$f" .md)
          [ "$d" \> "$CUTOFF" ] || [ "$d" = "$CUTOFF" ] && echo "$f"
        done)
    ;;
  month)
    CUTOFF=$(days_ago 30)
    FILES=$(find "$LOG_DIR" -maxdepth 1 -name "????-??-??.md" -type f 2>/dev/null \
      | sort \
      | while IFS= read -r f; do
          d=$(basename "$f" .md)
          [ "$d" \> "$CUTOFF" ] || [ "$d" = "$CUTOFF" ] && echo "$f"
        done)
    ;;
  all)
    FILES=$(find "$LOG_DIR" -maxdepth 1 -name "????-??-??.md" -type f 2>/dev/null | sort)
    ;;
  *)
    TODAY=$(date +%Y-%m-%d)
    FILES=""
    [ -f "$LOG_DIR/$TODAY.md" ] && FILES="$LOG_DIR/$TODAY.md"
    ;;
esac

if [ -z "$FILES" ]; then
  exit 0
fi

echo "$FILES" | while IFS= read -r file; do
  if [ -f "$file" ]; then
    DATE_PART=$(basename "$file" .md)
    grep -i "$QUERY" "$file" 2>/dev/null | while IFS= read -r line; do
      echo "[$DATE_PART] $line"
    done
  fi
done

exit 0
