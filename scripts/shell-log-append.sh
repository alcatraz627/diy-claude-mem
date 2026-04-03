#!/usr/bin/env bash
# Appends a shell command entry to today's log file.
# Usage: shell-log-append.sh <session_id> <command> <is_bg> [pid]
# Always exits 0.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_ID="${1:-unknown}"
COMMAND="${2:-unknown}"
IS_BG="${3:-false}"
PID="${4:-}"

LOG_FILE="$("$SCRIPT_DIR/shell-log-file.sh")" || exit 0
TIMESTAMP="$(date +%H:%M:%S)"

# Duration estimate lookup
estimate_duration() {
  local cmd="$1"
  case "$cmd" in
    *"rm -rf"*)       echo "30m" ;;
    *rm\ *[^/]*)      echo "30s" ;;
    *"npm install"*)   echo "5m" ;;
    *"npm run build"*) echo "10m" ;;
    *"npm run dev"*|*"node server"*|*"node index"*|*"python -m"*|*uvicorn*|*gunicorn*|*"flask run"*|*"rails s"*)
                       echo "24h" ;;
    *"git clone"*)     echo "10m" ;;
    *"git pull"*|*"git push"*|*"git fetch"*)
                       echo "2m" ;;
    *"curl "*|*"wget "*) echo "2m" ;;
    *"python "*.py*|*"python3 "*.py*|*"node "*.js*|*ts-node*)
                       echo "1h" ;;
    *make*|*"cargo build"*|*"go build"*)
                       echo "15m" ;;
    *"docker build"*)  echo "20m" ;;
    *"docker run"*|*"docker-compose up"*)
                       echo "24h" ;;
    *pg_dump*|*mongodump*|*mysqldump*)
                       echo "30m" ;;
    *"sleep "*)
      # Parse the number from sleep command
      local num
      num=$(echo "$cmd" | grep -oE 'sleep +[0-9]+' | grep -oE '[0-9]+' | head -1)
      if [ -n "$num" ]; then
        if [ "$num" -ge 3600 ]; then
          echo "$((num / 3600))h"
        elif [ "$num" -ge 60 ]; then
          echo "$((num / 60))m"
        else
          echo "${num}s"
        fi
      else
        echo "5m"
      fi
      ;;
    *)                 echo "5m" ;;
  esac
}

DURATION=$(estimate_duration "$COMMAND")

# Build the log line
LINE="- [$TIMESTAMP] [sid:$SESSION_ID] \`$COMMAND\`"

if [ "$IS_BG" = "true" ]; then
  LINE="$LINE [BG]"
  if [ -n "$PID" ]; then
    LINE="$LINE [pid:$PID]"
  fi
fi

LINE="$LINE [est:$DURATION]"

echo "$LINE" >> "$LOG_FILE" 2>/dev/null || true
exit 0
