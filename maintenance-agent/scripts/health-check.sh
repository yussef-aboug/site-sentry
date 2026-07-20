#!/usr/bin/env bash
# SiteSentry health check.
# Usage: scripts/health-check.sh <url> [expected-keyword]
# Exit 0 = all checks pass. Exit 1 = at least one failure (details on stdout).
# Run BEFORE a change (baseline) and AFTER (verification). Compare the two.

URL="${1:?Usage: health-check.sh <url> [expected-keyword]}"
KEYWORD="${2:-}"
FAIL=0
HOST="$(printf '%s' "$URL" | sed -E 's~https?://~~; s~/.*$~~')"

echo "=== SiteSentry health check: $URL ($(date -u +'%Y-%m-%d %H:%M UTC')) ==="

# 1. HTTP status + response time (follow redirects, browser-ish UA)
read -r CODE TIME < <(curl -sS -o /tmp/hc_body.html -L -A "Mozilla/5.0 (SiteSentry-HC)" \
  -w "%{http_code} %{time_total}" --max-time 30 "$URL" 2>/dev/null || echo "000 0")
if [ "$CODE" = "200" ]; then
  echo "[PASS] HTTP status: $CODE (${TIME}s)"
else
  echo "[FAIL] HTTP status: $CODE (expected 200)"; FAIL=1
fi

# 2. Response time sanity
if awk "BEGIN{exit !($TIME > 8)}"; then
  echo "[WARN] Slow response: ${TIME}s (>8s) — investigate if new"
fi

# 3. Expected keyword present in body (catches white screens & wrong content)
if [ -n "$KEYWORD" ]; then
  if grep -qi -- "$KEYWORD" /tmp/hc_body.html; then
    echo "[PASS] Keyword found: \"$KEYWORD\""
  else
    echo "[FAIL] Keyword NOT found: \"$KEYWORD\" — possible white screen or error page"; FAIL=1
  fi
fi

# 4. Obvious fatal-error strings in body
if grep -Eqi "critical error on this website|error establishing a database connection|fatal error" /tmp/hc_body.html; then
  echo "[FAIL] Error text detected in page body"; FAIL=1
else
  echo "[PASS] No fatal-error text in body"
fi

# 5. SSL certificate expiry
if [[ "$URL" == https* ]]; then
  EXP="$(echo | openssl s_client -servername "$HOST" -connect "$HOST:443" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)"
  if [ -n "$EXP" ]; then
    EXP_S=$(date -d "$EXP" +%s 2>/dev/null || echo 0)
    NOW_S=$(date +%s)
    DAYS=$(( (EXP_S - NOW_S) / 86400 ))
    if [ "$DAYS" -lt 0 ];   then echo "[FAIL] SSL certificate EXPIRED"; FAIL=1
    elif [ "$DAYS" -lt 14 ]; then echo "[WARN] SSL expires in ${DAYS} days"
    else echo "[PASS] SSL valid, ${DAYS} days remaining"; fi
  else
    echo "[WARN] Could not read SSL certificate"
  fi
fi

# 6. wp-login reachable (admin not white-screened) — non-fatal check
LCODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 -L "${URL%/}/wp-login.php" || echo 000)
case "$LCODE" in
  200|301|302|403) echo "[PASS] wp-login.php reachable ($LCODE)";;
  *) echo "[WARN] wp-login.php returned $LCODE";;
esac

echo "=== Result: $([ $FAIL -eq 0 ] && echo ALL CHECKS PASSED || echo FAILURES DETECTED) ==="
exit $FAIL
