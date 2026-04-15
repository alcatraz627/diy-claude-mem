# diy-claude-mem — Implementation Plan
<!-- sessions: shell-obs-4c@2026-04-03 -->

A lightweight, dependency-free shell tracking and memory system for Claude Code.
Built in 3 phases. Scripts live here and are symlinked/copied into `~/.claude/scripts/diy-mem/`.

---

## The Problem

1. `run_in_background: true` Bash calls lose their process context after `/compact`
2. Claude forgets what shells it started mid-session — even before compact
3. No way to look up "what was running" after a long conversation

---

## Integration Layer Decision

| Layer | Used for |
|---|---|
| **Hooks** | Auto-capture (PostToolUse/Bash, PostToolUse/BashOutput, UserPromptSubmit, SessionStart, PreCompact) |
| **Scripts** | All file I/O — abstracted behind dedicated scripts, Claude never reads log files directly |
| **Skills** | Claude-facing interface: `shell-lookup`, `shell-history`, `shell-mark-done` |
| **CLAUDE.md** | Instructions telling Claude to use the scripts, not raw file access |
| **MCP server** | Claude-invoked reads/writes — typed named tools, no path memorization (Phase 1.1) |
| **Plugin** | Not used — overkill for personal use |

---

## Log File Structure

### Daily files
- Path: `~/.claude/shell-logs/YYYY-MM-DD.md`
- One file per day. Files older than 2 months can be deleted.
- Run `shell-log-cleanup.sh` to purge old files.

### Entry format
```
- [HH:MM:SS] [sid:<session_id>] `<command>` [<status>] [est:<duration>]
```

Examples:
```
- [10:42:31] [sid:fix-auth-3b] `npm run dev` [BG] [est:24h]
- [10:43:05] [sid:fix-auth-3b] `git status` [est:30s]
- [10:44:12] [sid:add-feat-2a] `rm -rf ./dist` [est:10m]
- [10:45:00] [sid:fix-auth-3b] `npm run dev` [BG:DONE]
```

### Status tags
- (none) = foreground command, completed
- `[BG]` = background, possibly still running
- `[BG:DONE]` = background, confirmed finished (set by BashOutput hook or mark-done script)

---

## Duration Lookup Table

Used by `track-bash.sh` to estimate max run time. Unenforced — for Claude's reference only.

| Pattern | Estimate | Reasoning |
|---|---|---|
| `rm <file>` | 30s | Single file deletion |
| `rm -rf <dir>` | 10–30m | Depends on dir size |
| `npm install` | 5m | Network + disk |
| `npm run build` | 10m | Compile step |
| `npm run dev` / `node server` | 24h | Long-running server |
| `git clone` | 10m | Network dependent |
| `git pull` / `git push` | 2m | Network |
| `curl` / `wget` | 2m | Network request |
| `python *.py` / `node *.js` | 1h | Script, unknown length |
| `make` / `cargo build` | 15m | Compile |
| `docker build` | 20m | Image build |
| `docker run` | 24h | Long-running container |
| `pg_dump` / `mongodump` | 30m | DB export |
| `sleep` | parsed from args | |
| (default) | 5m | Conservative fallback |

---

## Scripts (I/O Abstraction Layer)

All scripts live in `~/.claude/scripts/diy-mem/`. Claude uses these — never reads log files directly.

### File selector (used internally by all other scripts)
**`shell-log-file.sh [YYYY-MM-DD]`**
- Returns the path to the log file for the given date (default: today)
- Creates `~/.claude/shell-logs/` if missing
- Output: `/Users/<user>/.claude/shell-logs/YYYY-MM-DD.md`

### Write
**`shell-log-append.sh <session_id> <command> <is_bg> [<pid>]`**
- Appends a new entry to today's log
- Looks up duration estimate from the table
- Tags `[BG]` if is_bg=true
- Async-safe: uses >> (append, not overwrite)

### Read
**`shell-log-tail.sh [N] [YYYY-MM-DD]`**
- Returns last N lines of the log file (default 30, default date today)
- Used by injection hook to get recent entries

### Search
**`shell-log-search.sh <query> [today|week|month|all]`**
- Greps across the relevant date range of files
- Returns matching lines with their file date as prefix
- Claude passes scope based on how far back to look

### Update
**`shell-log-mark-done.sh <session_id> <command_fragment> [YYYY-MM-DD]`**
- Finds the most recent `[BG]` entry matching session_id + command_fragment in the target file
- Updates `[BG]` → `[BG:DONE]`
- If no date given, checks today then yesterday

### Cleanup
**`shell-log-cleanup.sh`**
- Deletes log files older than 60 days from `~/.claude/shell-logs/`
- Prints a summary of what was deleted
- Safe: lists before deleting, never touches files < 60 days old

---

## Phase 1 — Minimal Working Version

**Goal:** Claude always knows what Bash commands ran recently. BG shells visible. Injection only fires if BG entries exist.
**Constraint:** Zero external deps. bash + jq only.

### Hook scripts (wrappers around I/O scripts)

**`hooks/track-bash.sh`**
- PostToolUse matcher: `Bash`
- Reads stdin JSON → extracts `session_id`, `tool_input.command`, `tool_input.run_in_background`
- Calls `shell-log-append.sh`
- Async: true (fire and forget)

**`hooks/mark-done-bash.sh`**
- PostToolUse matcher: `BashOutput`
- Reads stdin JSON → extracts session_id + command
- Calls `shell-log-mark-done.sh`
- Async: true

**`hooks/inject-shell-state.sh`**
- UserPromptSubmit hook
- Calls `shell-log-tail.sh 30`
- Only outputs `additionalContext` if the tail contains `[BG]` entries (not `[BG:DONE]`)
- Output format:
  ```json
  {"additionalContext": "## Active background shells\n- [10:42:31] ..."}
  ```

**`hooks/init-session.sh`**
- SessionStart hook
- Writes a session header line to today's log: `\n### Session: <session_id> started at HH:MM:SS`
- Async: true

### Settings.json additions
```json
PostToolUse  → matcher "Bash"       → hooks/track-bash.sh       (async: true)
PostToolUse  → matcher "BashOutput" → hooks/mark-done-bash.sh    (async: true)
UserPromptSubmit                    → hooks/inject-shell-state.sh
SessionStart                        → hooks/init-session.sh      (async: true)
```

### Skills (Phase 1)
**`skills/shell-mem/SKILL.md`**
Exposes these to Claude as natural-language invocable actions:
- "show recent shell commands" → `shell-log-tail.sh 50`
- "search shell history for X" → `shell-log-search.sh X [scope]`
- "mark X as done" → `shell-log-mark-done.sh`

### CLAUDE.md addition
```
## Shell Memory (diy-mem)

Shell command history is logged automatically. Use scripts in ~/.claude/scripts/diy-mem/ — never read log files directly.

- Recent commands:    ~/.claude/scripts/diy-mem/shell-log-tail.sh [N] [YYYY-MM-DD]
- Search:            ~/.claude/scripts/diy-mem/shell-log-search.sh <query> [today|week|month]
- Mark BG done:      ~/.claude/scripts/diy-mem/shell-log-mark-done.sh <session_id> <cmd_fragment>
- Cleanup old logs:  ~/.claude/scripts/diy-mem/shell-log-cleanup.sh
- Log files:         ~/.claude/shell-logs/YYYY-MM-DD.md (files >2 months can be deleted)

Context is auto-injected when active background shells exist.
```

---

## Phase 1.1 — MCP Server (Claude read/write interface)

**Goal:** Replace long bash paths with named, typed MCP tools Claude can call natively.
**Principle:** Hooks stay as shell scripts (they must be). Only the Claude-invoked operations move to MCP.

### Why MCP here
- Claude currently calls `~/.claude/scripts/diy-mem/shell-log-tail.sh 50` — long, fragile, requires CLAUDE.md lookup
- MCP gives Claude named tools: `shell_tail(n, date)`, `shell_search(query, scope)`, etc.
- Discoverable without CLAUDE.md — Claude sees tool list natively
- Entry point into `mcp-catalog.json` for future project reuse

### MCP server
- Location: `~/Code/Claude/diy-claude-mem/mcp-server/`
- Transport: stdio (spawned by Claude Code, no persistent process needed)
- Runtime: Node.js (`@modelcontextprotocol/sdk`)
- All tools call the existing shell scripts via `child_process` — no logic duplication

### Tools exposed
| Tool | Args | Maps to |
|---|---|---|
| `shell_tail` | `n=30, date="today"` | `shell-log-tail.sh` |
| `shell_search` | `query, scope="today"` | `shell-log-search.sh` |
| `shell_mark_done` | `session_id, cmd, date?` | `shell-log-mark-done.sh` |
| `shell_cleanup` | — | `shell-log-cleanup.sh` |
| `shell_append` | `session_id, cmd, is_bg, pid?` | `shell-log-append.sh` |

### Registration
- Add to `~/.claude/mcp.json` (global Claude Code MCP config, created if missing)
- Add entry to `~/.claude/mcp-catalog.json` so `/add-mcp` can install it in any project

### CLAUDE.md update
- Replace bash path table with MCP tool names
- Keep bash paths as fallback note

---

## Phase 1.2 — Lock File for Concurrent Writes

**Goal:** Make `shell-log-mark-done.sh` safe for concurrent agents (worktrees, agent teams).
**Principle:** `mkdir` as atomic lock — no external deps, works on macOS without `flock`.

### What's unsafe
`shell-log-mark-done.sh` does a read → sed → write cycle. Two agents writing simultaneously can clobber each other's change.

### Fix
Wrap the sed operation in a `mkdir`-based lock:
```bash
LOCKDIR="/tmp/diy-mem-$(date +%Y-%m-%d).lock"
until mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.05; done
trap "rmdir '$LOCKDIR'" EXIT
# ... sed operation ...
```
- Lock is per-day (matches the file scope)
- Max wait: ~5 retries × 50ms = 250ms before concern
- Trap ensures lock is always released even on error

### Scope
Only `shell-log-mark-done.sh` needs this. `shell-log-append.sh` uses `>>` which is POSIX-atomic for single-line writes.

---

## Phase 1.3 — Global Dispatcher (`shell-mem`)

**Goal:** Single entry point script in `scripts/` that routes all operations via subcommands.
**Used by:** Claude (via MCP fallback or direct Bash call), and humans from the terminal.

### Interface
```
shell-mem <command> [args...]
shell-mem -h | --help
```

### Commands
| Subcommand | Routes to |
|---|---|
| `tail [N] [date]` | `shell-log-tail.sh` |
| `search <query> [scope]` | `shell-log-search.sh` |
| `mark-done <sid> <cmd> [date]` | `shell-log-mark-done.sh` |
| `cleanup` | `shell-log-cleanup.sh` |
| `append <sid> <cmd> <is_bg> [pid]` | `shell-log-append.sh` |
| `file [date]` | `shell-log-file.sh` |

### `-h` output
1. Short TL;DR (3-4 lines, hardcoded)
2. Full details extracted from `PLAN.md` (the Script section)

### Installation
Copied to `~/.claude/scripts/diy-mem/shell-mem` (no `.sh` extension — clean CLI feel).

---

## Phase 2 — Robust + Integrated ✓ Done

**Goal:** Better PID tracking, noise filtering, WAL integration, deduplication, PreCompact snapshot.

### Additions over Phase 1
- **PID capture**: Parse tool_response for PID in `[PID]` or `Listening on :PORT` patterns — store in log entry
- **Noise filter**: Configurable skip-list for trivial commands in `~/.claude/scripts/diy-mem/config.sh`
- **Deduplication**: Don't log identical command twice in a row per session
- **PreCompact snapshot**: Write a snapshot of all active `[BG]` entries into WAL as CHECKPOINT annotation
- **WAL integration**: SessionEnd hook appends shell summary line to `~/.claude/wal.md`
- **Port registry**: Server-type commands (dev, start, serve) log estimated port if detectable

### New scripts
- `hooks/pre-compact-shell.sh` — PreCompact hook, snapshot to WAL
- `hooks/session-end-shell.sh` — SessionEnd hook, WAL summary
- `config.sh` — shared constants (skip-list, duration table externalized)

---

## Phase 2+ — Improvements ✓ Done

**Goal:** Improve runtime correctness, lookup performance, and discoverability beyond Phase 2.

### Additions over Phase 2
- **PID aliveness check**: `inject-shell-state.sh` uses `kill -0 $PID` to classify BG entries
  as live vs orphaned — emits two separate `additionalContext` sections
- **Cross-day active query**: `shell-log-active.sh` — new script for querying active BG entries
  across the last N days; used by `inject-shell-state.sh` and `init-session.sh`
- **Session carryover**: `init-session.sh` injects active BG from previous sessions as
  `additionalContext` at `SessionStart`
- **O(1) search**: `shell-log-search.sh` replaced N-subprocess date loop with `find` +
  lexicographic string comparison (one `date` call per scope)
- **`active` subcommand**: `shell-mem active [days]` — delegates to `shell-log-active.sh`
- **`stats` subcommand**: `shell-mem stats [date]` — delegates to `shell-log-stats.sh`
- **user-skip.conf**: `config.sh` loads optional `user-skip.conf` for user-customizable
  skip patterns without editing core config
- **`shell_active` MCP tool**: added to MCP server (v1.1.0)
- **`shell_stats` MCP tool**: added to MCP server (v1.2.0)
- **MCP-first SKILL.md**: skill docs now lead with MCP tool table; bash paths as fallback

### New scripts
- `shell-log-active.sh` — cross-day active BG query primitive
- `shell-log-stats.sh` — today's log statistics (extracted from shell-mem dispatcher)

### Integration notes
- `docs/idream-integration.md` — agent-ready guide for i-dream integration (5 integration
  points across metacog.rs, dreaming.rs, intuition.rs; shared `session_id` data contract)

---

## Phase 3 — Long-term Memory

**Goal:** AI compression, permanent archive, handoff docs, search lookup, consolidation.

### Borrowed from claude-mem
- **AI summarization**: Stop hook → headless `claude -p` compresses today's BG entries into 3-5 line natural language summary
- **Session archive**: Append compressed summary to `~/.claude/shell-logs/archive.md` (permanent)
- **Token-efficient injection**: SessionStart injects archive summary (not raw log)

### Borrowed from Continuous-Claude-v3
- **Pre-compact handoff**: Before `/compact`, write `~/.claude/shell-logs/handoffs/handoff-<timestamp>.md` with active shells + ledger state
- **Ledger**: `shell-ledger.md` — two sections: "possibly still running" vs "confirmed done"
- **Reload after /clear**: SessionStart reads latest handoff + injects as context

### Port for optional viewer UI
- Assigned from port registry when implemented (never 3000)
- Register in `~/.claude/scratchpad/global/port-registry.md` before use

### New scripts (Phase 3)
- `summarize-shell.sh` — Stop hook, headless Claude compression
- `shell-handoff.sh` — PreCompact (replaces Phase 2 version)
- `shell-ledger-update.sh` — PostToolUse, maintains ledger
- `shell-lookup.sh` — CLI utility (wraps search with pretty output)
- `consolidate-archive.sh` — manual/cron, compresses entries >7 days into monthly summaries

---

## File Layout

```
diy-claude-mem/
├── PLAN.md                              ← this file
├── install.sh                           ← copies scripts, patches settings.json + CLAUDE.md
├── scripts/
│   ├── shell-log-file.sh                ← file selector abstraction
│   ├── shell-log-append.sh              ← write: append entry
│   ├── shell-log-tail.sh                ← read: tail N lines
│   ├── shell-log-search.sh              ← read: search across date range
│   ├── shell-log-mark-done.sh           ← update: BG → BG:DONE
│   ├── shell-log-cleanup.sh             ← delete files >60 days
│   ├── hooks/
│   │   ├── track-bash.sh                ← Phase 1: PostToolUse/Bash
│   │   ├── mark-done-bash.sh            ← Phase 1: PostToolUse/BashOutput
│   │   ├── inject-shell-state.sh        ← Phase 1: UserPromptSubmit
│   │   ├── init-session.sh              ← Phase 1: SessionStart
│   │   ├── pre-compact-shell.sh         ← Phase 2: PreCompact
│   │   └── session-end-shell.sh         ← Phase 2: SessionEnd
│   └── (phase3 scripts...)
└── skills/
    └── shell-mem/
        └── SKILL.md

~/.claude/shell-logs/
├── 2026-04-03.md                        ← daily log (auto-created)
├── 2026-04-04.md
├── ...
├── archive.md                           ← Phase 3: permanent compressed history
├── shell-ledger.md                      ← Phase 3: running/done ledger
└── handoffs/                            ← Phase 3: pre-compact snapshots
    └── handoff-<timestamp>.md
```

---

## Design Principles

1. **Async wherever possible** — never block Claude's response
2. **Fail silently** — missing files, jq errors: all exit 0
3. **No external deps** — bash + jq only (jq ships with Claude Code env)
4. **Scripts are the API** — Claude uses scripts, never raw file reads of log files
5. **Progressively disclose** — Phase 1 injects only when BG entries exist; Phase 3 injects summary only
6. **Never port 3000** — any server component must use port registry at `~/.claude/scratchpad/global/port-registry.md`
7. **60-day retention** — run cleanup.sh periodically; documented in log dir README
