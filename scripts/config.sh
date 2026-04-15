#!/usr/bin/env bash
# Shared configuration for diy-claude-mem.
# Source this file in other scripts:
#   source "$(dirname "$0")/config.sh"
# Always exits cleanly — never call directly.

# ── Noise filter ──────────────────────────────────────────────────────────────
# Commands matching any of these ERE patterns are skipped (not logged).
# Patterns are matched against the full command string (case-sensitive).
DIYMEN_SKIP_PATTERNS=(
  "^ls( |$)"
  "^echo "
  "^cat (> /dev/null|/dev/null)"
  "^pwd$"
  "^cd( |$)"
  "^which "
  "^type "
  "^true$"
  "^false$"
  "^exit( |$)"
  "^source "
  "^\. [^/]"
  "^printf '\\\\033"
  "^read "
  "^: $"
  "^#"
)

# ── Duration estimates ─────────────────────────────────────────────────────────
# Used by shell-log-append.sh via estimate_duration().
# Defined here so they can be updated in one place.
# (Function stays in shell-log-append.sh for portability; patterns live here.)

# ── Port detection ─────────────────────────────────────────────────────────────
# Regex patterns used to detect port numbers in commands and tool output.
# Order matters — first match wins.
DIYMEN_PORT_CMD_PATTERNS=(
  "--port[= ]([0-9]+)"
  "-p ([0-9]+)"
  "PORT=([0-9]+)"
  "port=([0-9]+)"
  ":([0-9]{4,5})($|[^0-9])"
)

DIYMEN_PORT_OUTPUT_PATTERNS=(
  "[Ll]istening on[: ]+.*:([0-9]+)"
  "[Ss]erver.*port[: ]+([0-9]+)"
  "[Ss]tarted.*:([0-9]+)"
  "[Rr]unning.*:([0-9]+)"
  "http://localhost:([0-9]+)"
  "[Pp]ort ([0-9]+)"
)
