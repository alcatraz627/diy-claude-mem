---
name: shell-mem
description: Look up recent shell commands, background process history, or mark background processes as done. Use when asked about recent commands, what's running, shell history, or to mark a background process as finished.
---

# Shell Memory

Commands run in this and recent sessions are logged automatically.
Prefer MCP tools (discoverable, no path memorization). Bash fallbacks are listed for reference.

## MCP tools (preferred)

| Tool | Description |
|---|---|
| `shell_tail(n, date)` | Show recent log entries (default: 30 lines, today) |
| `shell_search(query, scope)` | Search history — scope: `today` \| `week` \| `month` \| `all` |
| `shell_active(days)` | List active (not done) background processes from last N days |
| `shell_stats(date?)` | Today's command count, sessions, active/done BG, log size |
| `shell_mark_done(session_id, cmd, date?)` | Mark a BG process as finished |
| `shell_cleanup()` | Delete logs older than 60 days |
| `shell_append(session_id, cmd, is_bg, pid?)` | Manually log a command |

## Bash fallbacks

```bash
# Recent commands
~/.claude/scripts/diy-mem/shell-log-tail.sh [N] [YYYY-MM-DD]

# Active background processes
~/.claude/scripts/diy-mem/shell-log-active.sh [days_back]

# Search
~/.claude/scripts/diy-mem/shell-log-search.sh "<query>" [today|week|month|all]

# Mark done
~/.claude/scripts/diy-mem/shell-log-mark-done.sh <session_id> "<command_fragment>" [YYYY-MM-DD]

# Stats
~/.claude/scripts/diy-mem/shell-log-stats.sh [YYYY-MM-DD]

# Cleanup old logs (>60 days)
~/.claude/scripts/diy-mem/shell-log-cleanup.sh
```

## Log file location
`~/.claude/shell-logs/YYYY-MM-DD.md` — one file per day. 60-day retention.

## Notes
- Context auto-injected at `UserPromptSubmit` when active BG entries exist
- Active BG entries from previous sessions are shown at `SessionStart` as carryover
- PIDs are verified with `kill -0` — orphaned entries are flagged separately
- Use `shell_active` first before `shell_tail` when you only care about what's running
