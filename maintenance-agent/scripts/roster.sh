#!/usr/bin/env bash
# SiteSentry roster — the "what's due across all clients" dashboard.
# Reads every sites/<slug>.md (except _TEMPLATE.md), pulls its plan tier and the
# last_* service dates, and compares each against the cadence thresholds in CADENCE.md.
#
# Usage:
#   scripts/roster.sh              # all sites, all services
#   scripts/roster.sh <slug>       # one site
# Read-only (Tier 0). Never changes anything. Exit 0 always; it's a report.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITES_DIR="$SCRIPT_DIR/../sites"
FILTER="${1:-}"

# Cadence thresholds (days). Keep in sync with CADENCE.md.
declare -A UPDATES=( [essentials]=30 [peace-of-mind]=7 [total-care]=7 )
BACKUP_VERIFY=7
RESTORE_DRILL=30
MALWARE_SCAN=30
LINK_CHECK=30          # peace-of-mind + total-care only
PERF_CHECK=30          # peace-of-mind + total-care only
REPORT=30
QUARTERLY=90           # total-care only

today_epoch=$(date +%s)

# days_since <YYYY-MM-DD> -> integer days, or 99999 if missing/placeholder/unparseable
days_since() {
  local d="$1"
  # strip surrounding whitespace
  d="$(printf '%s' "$d" | tr -d '[:space:]')"
  case "$d" in
    ""|"[date]"|"[YYYY-MM-DD]"|"never"|"never—"*|"[YYYY-MM]") echo 99999; return;;
  esac
  # accept YYYY-MM (monthly report) by pinning to the 1st
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}$ ]] && d="${d}-01"
  local e
  e=$(date -d "$d" +%s 2>/dev/null) || { echo 99999; return; }
  echo $(( (today_epoch - e) / 86400 ))
}

# status <days> <threshold> -> OK / DUE / OVERDUE (overdue at 1.5x)
status() {
  local days="$1" thr="$2"
  [ "$days" -ge 99999 ] && { echo "NEVER"; return; }
  if   [ "$days" -ge $(( thr * 3 / 2 )) ]; then echo "OVERDUE"
  elif [ "$days" -ge "$thr" ];            then echo "DUE"
  else echo "OK"; fi
}

# field <file> <key> -> value after "key:" (first match), trimmed
field() {
  grep -m1 -E "^[[:space:]]*$2[[:space:]]*:" "$1" 2>/dev/null \
    | sed -E "s/^[[:space:]]*$2[[:space:]]*:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

printf '\n=== SiteSentry roster — %s ===\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
printf '%-22s %-14s %-9s %-8s %-8s %-8s %-10s %-9s\n' \
  SITE PLAN UPDATES REPORT LINKS PERF RESTORE QUARTERLY
printf '%s\n' "-------------------------------------------------------------------------------------------"

shopt -s nullglob
any=0
for f in "$SITES_DIR"/*.md; do
  base="$(basename "$f" .md)"
  [ "$base" = "_TEMPLATE" ] && continue
  [ -n "$FILTER" ] && [ "$base" != "$FILTER" ] && continue
  any=1

  plan="$(field "$f" plan)"; plan="${plan%% *}"   # first token, e.g. "peace-of-mind"
  [ -z "$plan" ] && plan="???"
  upd_thr="${UPDATES[$plan]:-30}"

  s_upd=$(status "$(days_since "$(field "$f" last_update_run)")" "$upd_thr")
  s_rep=$(status "$(days_since "$(field "$f" last_report)")" "$REPORT")
  s_rst=$(status "$(days_since "$(field "$f" last_restore_drill)")" "$RESTORE_DRILL")

  if [ "$plan" = "peace-of-mind" ] || [ "$plan" = "total-care" ]; then
    s_lnk=$(status "$(days_since "$(field "$f" last_link_check)")" "$LINK_CHECK")
    s_prf=$(status "$(days_since "$(field "$f" last_performance_check)")" "$PERF_CHECK")
  else
    s_lnk="-"; s_prf="-"
  fi

  if [ "$plan" = "total-care" ]; then
    s_qtr=$(status "$(days_since "$(field "$f" last_quarterly_review)")" "$QUARTERLY")
  else
    s_qtr="-"
  fi

  printf '%-22s %-14s %-9s %-8s %-8s %-8s %-10s %-9s\n' \
    "$base" "$plan" "$s_upd" "$s_rep" "$s_lnk" "$s_prf" "$s_rst" "$s_qtr"
done

[ "$any" = 0 ] && printf '(no matching site files in %s)\n' "$SITES_DIR"
printf '\nLegend: OK = current · DUE = at threshold · OVERDUE = >1.5x threshold · NEVER = no record · - = n/a for tier\n'
printf 'Thresholds and rules: see CADENCE.md\n\n'
exit 0
