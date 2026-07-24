#!/usr/bin/env bash
# SiteSentry Night Watch — after-hours outage detector + alerter (READ-ONLY).
# Runs on a schedule (every ~5 min). During the after-hours window it checks each
# registered site; on a confirmed outage it gathers read-only evidence, sends ONE
# throttled alert, and logs it. It makes NO changes to any site — diagnose-only.
#
#   night-watch.sh            # normal (honors the after-hours window)
#   night-watch.sh --force    # ignore the window (for testing)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SITES_DIR="$AGENT_DIR/sites"
LOGS_DIR="$AGENT_DIR/logs"
STATE_DIR="$LOGS_DIR/.night-watch"
CONF="$SCRIPT_DIR/night-watch.local.conf"
[ -f "$CONF" ] && . "$CONF"

AFTER_HOURS_START="${AFTER_HOURS_START:-20:00}"
AFTER_HOURS_END="${AFTER_HOURS_END:-08:00}"
REALERT_MINUTES="${REALERT_MINUTES:-120}"
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1
mkdir -p "$STATE_DIR"

hhmm_to_min() { local h=${1%%:*} m=${1##*:}; echo $((10#$h*60 + 10#$m)); }
in_window() {
  local now s e; now=$(hhmm_to_min "$(date +%H:%M)")
  s=$(hhmm_to_min "$AFTER_HOURS_START"); e=$(hhmm_to_min "$AFTER_HOURS_END")
  if [ "$s" -lt "$e" ]; then [ "$now" -ge "$s" ] && [ "$now" -lt "$e" ]
  else [ "$now" -ge "$s" ] || [ "$now" -lt "$e" ]; fi
}
field() {
  grep -m1 -E "^[[:space:]]*$2[[:space:]]*:" "$1" 2>/dev/null \
    | sed -E "s/^[[:space:]]*$2[[:space:]]*:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//"
}

if [ "$FORCE" = 0 ] && ! in_window; then
  echo "night-watch: outside after-hours window ($AFTER_HOURS_START-$AFTER_HOURS_END); nothing to do."
  exit 0
fi

shopt -s nullglob
for f in "$SITES_DIR"/*.md; do
  slug="$(basename "$f" .md)"; [ "$slug" = "_TEMPLATE" ] && continue
  url="$(field "$f" url)"; [ -z "$url" ] && continue
  keyword="$(field "$f" homepage_keyword | tr -d '"')"
  alias="$(field "$f" ssh_alias)"; alias="${alias%% *}"
  wp_path="$(field "$f" wp_path)"
  is_store="$(field "$f" is_store)"
  state="$STATE_DIR/$slug.down"

  if bash "$SCRIPT_DIR/health-check.sh" "$url" "$keyword" >/dev/null 2>&1; then
    rm -f "$state"; continue          # healthy -> clear any outage state
  fi

  now_epoch=$(date +%s)               # DOWN — throttle repeat alerts
  if [ -f "$state" ]; then
    last=$(cat "$state" 2>/dev/null || echo 0)
    [ $(( (now_epoch - last) / 60 )) -lt "$REALERT_MINUTES" ] && continue
  fi
  echo "$now_epoch" > "$state"

  ts="$(date -u '+%Y-%m-%d %H:%M UTC')"
  code=$(curl -s -o "/tmp/nw_body.$$" -L -w '%{http_code}' --max-time 20 "$url" 2>/dev/null); [ -z "$code" ] && code=000
  errline=$(grep -Eio 'critical error on this website|error establishing a database connection|fatal error[^<]{0,80}' "/tmp/nw_body.$$" 2>/dev/null | head -1)
  host="$(echo "$url" | sed -E 's~https?://~~; s~/.*~~')"
  dns=$(dig +short "$host" 2>/dev/null | head -1)
  logtail=""
  if [ -n "$alias" ] && [ -n "$wp_path" ]; then
    logtail=$(printf 'cd "%s" && tail -3 wp-content/debug.log 2>/dev/null; echo "--- recently changed ---"; ls -t wp-content/mu-plugins/*.php wp-content/plugins 2>/dev/null | head -4\nexit\n' "$wp_path" \
      | ssh -o BatchMode=yes -o ConnectTimeout=10 "$alias" 2>/dev/null | tr -d '\r' | head -12)
  fi

  cause="Unknown — see evidence below"
  if [ -z "$dns" ]; then cause="No DNS answer for $host — possible domain/DNS issue"
  elif [ "$code" = "000" ]; then cause="No HTTP response — hosting-level outage or connection refused"
  elif echo "$code" | grep -q '^5'; then cause="HTTP $code — server/PHP error, usually a plugin or theme fatal"
  elif [ -n "$errline" ]; then cause="PHP fatal / WordPress critical error on the page"; fi

  verdict="likely AUTO-FIXABLE later by the agent (non-store, reversible fix)"
  case "$is_store" in yes|Yes|YES|true|True) verdict="NEEDS A HUMAN — store/e-commerce, do not auto-fix";; esac

  msg=$(printf '%s is DOWN (detected %s)\nURL: %s\nHTTP: %s\n%sLikely cause: %s\nAssessment: %s\n%s(Diagnose-only — no changes made. Dispatch the agent to run downtime-triage and fix.)\n' \
    "$slug" "$ts" "$url" "$code" \
    "$([ -n "$errline" ] && printf 'Error: %s\n' "$errline")" \
    "$cause" "$verdict" \
    "$([ -n "$logtail" ] && printf 'Recent server signal:\n%s\n' "$logtail")")

  printf '%s' "$msg" | bash "$SCRIPT_DIR/notify.sh" "SiteSentry: $slug DOWN" || true
  { echo ""; echo "## $ts — Night Watch: $slug DOWN (diagnose-only, no changes)"; printf '%s\n' "$msg"; } >> "$LOGS_DIR/$slug.md"
  rm -f "/tmp/nw_body.$$"
  echo "night-watch: DOWN + alerted -> $slug"
done
