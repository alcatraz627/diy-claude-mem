# diy-claude-mem × i-dream Integration Notes

<!-- sessions: impl-impr-a7@2026-04-15 -->

Agent-ready implementation guide for connecting diy-claude-mem shell logs with the i-dream
subconsciousness daemon.

---

## TL;DR

`session_id` is the natural join key. diy-claude-mem logs every Bash call tagged with
`[sid:SESSION_ID]`. i-dream stores session data under `~/.claude/subconscious/` keyed by
session_id. The integration is read-only for diy-claude-mem — i-dream reads from shell
logs; shell logs never write to i-dream.

---

## What Each System Owns

```
┌─────────────────────────────────────────────────────────────┐
│ diy-claude-mem                       i-dream                 │
│ ─────────────────────────────────    ──────────────────────  │
│ ~/.claude/shell-logs/YYYY-MM-DD.md   ~/.claude/subconscious/ │
│                                                              │
│ Knows: what commands ran, when,      Knows: metacog state,   │
│        which are BG, PIDs, ports,    valence, SWS/REM/Wake   │
│        session + duration ests.      cycle, dream replay,    │
│                                      introspection notes     │
│ Key:   [sid:SESSION_ID]              Key: session_id         │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Points

### 1. i-dream reads shell activity for metacognition enrichment

**Where:** `i-dream/src/metacog.rs` (metacognition module)

**What to add:**
- At the start of a REM cycle (dream replay), read active shell entries for the session via:
  ```bash
  ~/.claude/scripts/diy-mem/shell-log-active.sh 1
  ```
  Filter to entries matching the current session_id. Active BG processes are important
  context — they represent "ongoing tasks" the agent may want to incorporate into dreams.

- Emit a metacog annotation: `"session_id has N active BG processes: [list]"` — this feeds
  the introspection narrative.

**API shape (bash call from Rust):**
```rust
use std::process::Command;
let output = Command::new("bash")
    .arg(format!("{}/.claude/scripts/diy-mem/shell-log-active.sh", home))
    .arg("1")
    .output()?;
let active_shells = String::from_utf8_lossy(&output.stdout);
// Filter lines containing [sid:SESSION_ID]
```

---

### 2. i-dream uses command history in Dreaming/SWS consolidation

**Where:** `i-dream/src/dreaming.rs` (SWS slow-wave consolidation pass)

**What to add:**
- SWS consolidation replays recent "working memory" as abstract patterns. Shell history
  is a concrete working-memory trace. Read today's log for the session:
  ```bash
  ~/.claude/scripts/diy-mem/shell-mem tail 50
  ```
  Then filter by `[sid:SESSION_ID]`. Count distinct command types (git, npm, docker, etc.)
  and pass to the SWS pattern extractor as behavioral tags.

**Why this is useful:**
- A session that ran many `git` commands → high "version-control" weight in dream memory
- A session with many BG server processes → flag "long-running infra" in consolidated memory
- Commands classified as "tests" (pytest, jest, cargo test) → reinforce "testing discipline"
  metacog trait

---

### 3. Valence/intuition adjustment from command outcomes

**Where:** `i-dream/src/intuition.rs` (valence module)

**What to add:**
- BG processes that stayed alive across multiple sessions → positive valence (things are
  working, servers are up)
- BG processes that appear as orphaned (PID dead but not marked done) → negative valence
  signal (something crashed unexpectedly)

**Detection:** Use `inject-shell-state.sh`'s orphaned section — if orphaned entries exist
for the session, emit a `valence_adjust(session_id, -0.1, "orphaned_bg_process")` call.

**Log field to parse:**
```
- [14:33:05] [sid:abc-123] `npm run dev` [BG] [pid:9182] [port:3001] [est:24h]
```
After session end: if `kill -0 9182` fails → orphaned.

---

### 4. Prospective memory: port registry handoff

**Where:** `i-dream/src/dreaming.rs` (Wake / prospective memory module)

**What to add:**
- When a session ends (Stop hook fires), extract all `[port:N]` entries from the session's
  log and write them to `~/.claude/subconscious/port-registry.md`:
  ```
  [2026-04-15 14:32] [sid:abc-123] port:3001 cmd:`npm run dev` [pid:9182]
  ```
- At SessionStart, i-dream reads this registry and injects it as prospective memory:
  "Port 3001 was last used by npm run dev in session abc-123 — may still be in use."

---

### 5. Hook coordination: shared Stop hook

**Where:** `i-dream/src/hooks.rs` (if hook coordination is implemented)

**Current state:** Both systems have Stop hooks:
- diy-claude-mem: `session-end-shell.sh` → writes WAL summary
- i-dream: (planned) session consolidation trigger

**Recommended approach:** Keep them independent (both async). Do NOT merge them — shell
logging must succeed even if i-dream's daemon is not running. The async flag on
`session-end-shell.sh` already ensures this.

---

## Shared Data Contract

### session_id format

Both systems use the same session_id from `$CLAUDE_SESSION_ID` / Claude Code's JSON input.
Format from diy-claude-mem: `[sid:SESSION_ID]` in log entries.
Format in i-dream: bare `session_id` string.

**Extraction from log line:**
```bash
SESSION=$(echo "$line" | grep -oE '\[sid:[^]]+\]' | tr -d '[]' | cut -d: -f2)
```

---

## Files to Read Before Implementing

| File | Why |
|---|---|
| `~/.claude/shell-logs/YYYY-MM-DD.md` | Log format reference — understand all tag fields |
| `scripts/shell-log-active.sh` | The best primitive for "what's running now" |
| `scripts/config.sh` | Skip patterns — same list can inform i-dream what to ignore |
| `scripts/hooks/session-end-shell.sh` | Stop hook — coordinate without colliding |
| `scripts/hooks/inject-shell-state.sh` | Orphaned PID detection logic (kill -0) |
| `mcp-server/server.js` | MCP tool API — i-dream can call these if it gets MCP support |

---

## What NOT to integrate

- **Do not write to shell logs from i-dream.** Shell logs are append-only from the hook
  layer. Cross-writes break the single-writer assumption.
- **Do not call `shell-log-mark-done.sh` from i-dream.** Only the hook layer or the user
  should mark processes done.
- **Do not read raw log files from i-dream.** Use the script API (`shell-log-active.sh`,
  `shell-log-tail.sh`) — same rule as for Claude itself.

---

## Implementation Order (recommended)

1. **Start with point 2** (SWS + command history) — purely read-only, low risk, high payoff
2. **Add point 1** (metacog + active shells) — adds live context to dream cycles
3. **Add point 3** (valence from orphaned BG) — requires orphan detection from this project
4. **Add point 4** (port registry handoff) — most complex, new shared file format
5. **Evaluate point 5** (hook coordination) only if double-firing becomes a problem

---

## Quick Test

To verify the integration reads correctly, run from the i-dream project:
```bash
# Should return active BG entries for today
bash ~/.claude/scripts/diy-mem/shell-log-active.sh 1

# Should return stats
bash ~/.claude/scripts/diy-mem/shell-mem stats

# Search for commands from a known session
bash ~/.claude/scripts/diy-mem/shell-mem search "npm" today
```
