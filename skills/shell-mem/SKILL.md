---
name: shell-mem
description: Look up recent shell commands, background process history, or mark background processes as done. Use when asked about recent commands, what's running, shell history, or to mark a background process as finished.
---

# Shell Memory

Commands run in this and recent sessions are logged automatically.
Use the scripts below — never read log files directly.

## Read recent commands
```bash
~/.claude/scripts/diy-mem/shell-log-tail.sh [N] [YYYY-MM-DD]
```
Default: last 30 lines of today's log. Pass N for more lines. Pass a date to read an older log.

## Search history
```bash
~/.claude/scripts/diy-mem/shell-log-search.sh "<query>" [today|week|month|all]
```

## Mark a background process as done
```bash
~/.claude/scripts/diy-mem/shell-log-mark-done.sh <session_id> "<command_fragment>" [YYYY-MM-DD]
```
Call this when you know a background process has finished (e.g. after receiving output from it, or when BashOutput fires).

## Cleanup old logs (>60 days)
```bash
~/.claude/scripts/diy-mem/shell-log-cleanup.sh
```

## Log file location
~/.claude/shell-logs/YYYY-MM-DD.md — one file per day.
