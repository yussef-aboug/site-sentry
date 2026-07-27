#!/usr/bin/env bash
# SiteSentry notifier — sends an operator alert (e.g. an after-hours outage).
# Channel is configured OUTSIDE the repo so no secret/topic is committed:
#   copy scripts/night-watch.conf.example -> scripts/night-watch.local.conf
#   (that file is git-ignored) and set ONE of:
#     NOTIFY_NTFY_TOPIC=<your-unguessable-topic>     # ntfy.sh push (default)
#     NOTIFY_NTFY_SERVER=https://ntfy.sh             # optional, self-host override
#     NOTIFY_WEBHOOK_URL=<url>                        # generic: POSTs the body
# Env vars of the same names override the config file.
#
# Usage: notify.sh "Title" "Message body"
# Exit 0 = sent (or best-effort), 2 = not configured (caller should also log/file it).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/night-watch.local.conf"
[ -f "$CONF" ] && . "$CONF"

TITLE="${1:-SiteSentry alert}"
BODY="${2:-}"
[ -z "$BODY" ] && BODY="$(cat)"   # allow body on stdin

NTFY_SERVER="${NOTIFY_NTFY_SERVER:-https://ntfy.sh}"

if [ -n "${NOTIFY_NTFY_TOPIC:-}" ]; then
  curl -fsS --max-time 20 \
    -H "Title: $TITLE" -H "Priority: high" -H "Tags: rotating_light" \
    -d "$BODY" "$NTFY_SERVER/$NOTIFY_NTFY_TOPIC" >/dev/null \
    && { echo "notify: sent via ntfy"; exit 0; } \
    || { echo "notify: ntfy send FAILED" >&2; exit 1; }
elif [ -n "${NOTIFY_WEBHOOK_URL:-}" ]; then
  curl -fsS --max-time 20 -H 'Content-Type: text/plain' \
    --data-binary "$TITLE"$'\n'"$BODY" "$NOTIFY_WEBHOOK_URL" >/dev/null \
    && { echo "notify: sent via webhook"; exit 0; } \
    || { echo "notify: webhook send FAILED" >&2; exit 1; }
else
  echo "notify: NOT CONFIGURED — set NOTIFY_NTFY_TOPIC or NOTIFY_WEBHOOK_URL in $CONF" >&2
  exit 2
fi
