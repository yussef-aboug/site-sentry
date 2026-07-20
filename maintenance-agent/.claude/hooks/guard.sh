#!/usr/bin/env bash
# SiteSentry guard — PreToolUse hook for Bash commands.
# Deterministic tripwire: blocks catastrophic commands even if the model is
# confused or manipulated. Exit code 2 = block the tool call and show stderr.
# This is a LAST line of defense, not a substitute for the runbooks.

INPUT="$(cat)"

# Extract the command string (jq if available, raw fallback otherwise).
if command -v jq >/dev/null 2>&1; then
  CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  CMD="$INPUT"
fi

[ -z "$CMD" ] && exit 0

# Forbidden patterns (case-insensitive extended regex).
# Each of these is either irreversible or has no place in routine maintenance.
PATTERNS=(
  'rm[[:space:]]+-[a-z]*r[a-z]*f'          # recursive force delete
  'wp[[:space:]]+db[[:space:]]+drop'        # drop the whole database
  'wp[[:space:]]+db[[:space:]]+reset'       # wipe all tables
  'wp[[:space:]]+db[[:space:]]+clean'
  'wp[[:space:]]+site[[:space:]]+empty'     # delete all content
  'drop[[:space:]]+(database|table)'        # raw SQL drops
  'truncate[[:space:]]+table'
  'wp[[:space:]]+post[[:space:]]+delete[[:space:]].*--force.*--all'
  'mkfs'                                    # format a filesystem
  'dd[[:space:]]+if='                       # raw disk writes
  ':\(\)\{.*\};:'                           # fork bomb
  'chmod[[:space:]]+-R[[:space:]]+777'      # world-writable everything
  '>[[:space:]]*wp-config\.php'             # overwrite site config
  'wp[[:space:]]+user[[:space:]]+delete.*--all'
)

for p in "${PATTERNS[@]}"; do
  if printf '%s' "$CMD" | grep -Eiq "$p"; then
    echo "BLOCKED by SiteSentry guard: command matches forbidden pattern ($p)." >&2
    echo "If this is genuinely needed, the human operator must run it manually." >&2
    exit 2
  fi
done

exit 0
