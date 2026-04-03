#!/usr/bin/env bash
# Searches shell log files for a query string.
# Usage: shell-log-search.sh <query> [today|week|month|all]
# Always exits 0.

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

get_date_files() {
  local days="$1"
  local i=0
  while [ "$i" -lt "$days" ]; do
    local d
    d=$(date -v-"${i}d" +%Y-%m-%d 2>/dev/null) || d=$(date -d "-${i} days" +%Y-%m-%d 2>/dev/null) || true
    if [ -n "$d" ] && [ -f "$LOG_DIR/$d.md" ]; then
      echo "$LOG_DIR/$d.md"
    fi
    i=$((i + 1))
  done
}

case "$SCOPE" in
  today)
    FILES=$(get_date_files 1)
    ;;
  week)
    FILES=$(get_date_files 7)
    ;;
  month)
    FILES=$(get_date_files 30)
    ;;
  all)
    FILES=$(find "$LOG_DIR" -name "????-??-??.md" -type f 2>/dev/null | sort)
    ;;
  *)
    FILES=$(get_date_files 1)
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
