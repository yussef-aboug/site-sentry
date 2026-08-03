#!/usr/bin/env bash
# SiteSentry prospect scan - the free health check we offer on the landing page.
#
#   scripts/prospect-scan.sh <url>
#
# READ-ONLY and PASSIVE. It only performs ordinary public GET requests - the same
# things a browser or a search-engine crawler fetches. It never logs in, never
# POSTs, never guesses passwords, never scans ports, and never exploits anything.
# Run it ONLY against a site whose owner asked us to look (a submitted health-check
# form) or that the operator confirms we're authorized to review.
#
# Output is a findings list: [FAIL] = urgent, [WARN] = should fix, [PASS] = good,
# [INFO] = context. The prospect-health-check skill turns this into the client report.
# Exit 0 always - it's a report, not a gate.

set -uo pipefail
RAW="${1:?Usage: prospect-scan.sh <url>}"

# Normalize: add scheme if missing, strip trailing slash.
case "$RAW" in http://*|https://*) URL="$RAW";; *) URL="https://$RAW";; esac
URL="${URL%/}"
HOST="$(printf '%s' "$URL" | sed -E 's~https?://~~; s~/.*$~~')"
UA="Mozilla/5.0 (compatible; SiteSentry-HealthCheck/1.0; +requested-by-site-owner)"
TMP="$(mktemp -d 2>/dev/null || echo /tmp/ss.$$)"; mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

URGENT=0; ADVISED=0
fail(){ echo "[FAIL] $*"; URGENT=$((URGENT+1)); }
warn(){ echo "[WARN] $*"; ADVISED=$((ADVISED+1)); }
pass(){ echo "[PASS] $*"; }
info(){ echo "[INFO] $*"; }

# get <path> -> body in $TMP/body, prints a BARE http_code ("000" if curl itself failed).
# Never let curl's -w output and a fallback both reach stdout (that yields "000000").
get(){
  local c
  c="$(curl -sS -o "$TMP/body" -L -A "$UA" --max-time 25 -w '%{http_code}' "$URL$1" 2>/dev/null)" || c=""
  case "$c" in ''|*[!0-9]*) c=000;; esac
  printf '%s' "$c"
}
# reachable_200 <code> - a check may only draw a conclusion from a real 200 with a body.
reachable_200(){ [ "$1" = "200" ] && [ -s "$TMP/body" ]; }

echo "=============================================================="
echo " SiteSentry free health check - $URL"
echo " $(date -u '+%Y-%m-%d %H:%M UTC')   (read-only public inspection)"
echo "=============================================================="

# ---------------------------------------------------------------- reachability
echo; echo "--- Availability & speed ---"
# Write curl's metrics to a file (newline-separated) so a curl failure can never
# blend its -w output with a shell fallback string.
if curl -sS -o "$TMP/home" -L -A "$UA" --max-time 30 \
     -w '%{http_code}\n%{time_starttransfer}\n%{time_total}\n%{size_download}\n%{url_effective}\n' \
     "$URL" > "$TMP/meta" 2>"$TMP/curlerr"; then CURL_OK=1; else CURL_OK=0; fi
CODE="$(sed -n 1p "$TMP/meta" 2>/dev/null)"; TTFB="$(sed -n 2p "$TMP/meta" 2>/dev/null)"
TOTAL="$(sed -n 3p "$TMP/meta" 2>/dev/null)"; SIZE="$(sed -n 4p "$TMP/meta" 2>/dev/null)"
EFF="$(sed -n 5p "$TMP/meta" 2>/dev/null)"
case "$CODE" in ''|*[!0-9]*) CODE=000;; esac
case "$SIZE" in ''|*[!0-9]*) SIZE=0;; esac

# HARD GATE - if we never actually reached the site, STOP. Every check below reads the
# fetched body, and an empty body would silently produce reassuring [PASS] lines ("no
# debug.log exposed", "usernames not listed") that are conclusions drawn from nothing.
# Telling a prospect their site is secure because we couldn't connect is worse than useless.
if [ "$CURL_OK" = 0 ] || [ "$CODE" = "000" ] || [ ! -s "$TMP/home" ]; then
  fail "Could not reach $URL - no usable response."
  echo "       curl said: $(tr -d '\r' < "$TMP/curlerr" 2>/dev/null | head -2 | tr '\n' ' ')"
  echo
  echo "  SCAN ABORTED - no checks were performed. Possible causes:"
  echo "    - the site is genuinely down (a finding worth calling the prospect about)"
  echo "    - DNS/domain problem, or the address was mistyped on the form"
  echo "    - a firewall/WAF (Cloudflare, Wordfence) is blocking automated requests"
  echo "    - this machine has no direct outbound internet access (proxy/sandbox)"
  echo "  Verify by loading the URL in a browser before telling the prospect anything."
  echo "=============================================================="
  exit 2
fi

pass "Site is up (HTTP $CODE)"
[ "$CODE" != "200" ] && { URGENT=$((URGENT+1)); echo "[FAIL] Homepage returned HTTP $CODE (expected 200)"; }
awk -v t="${TTFB:-0}" 'BEGIN{ exit !(t>1.5) }' \
  && warn "Slow server response: ${TTFB}s to first byte (good is under 0.8s)" \
  || pass "Server response time: ${TTFB}s to first byte"
awk -v t="${TOTAL:-0}" 'BEGIN{ exit !(t>3) }' \
  && warn "Homepage fully loads in ${TOTAL}s (over 3s loses visitors)" \
  || pass "Homepage load time: ${TOTAL}s"
KB=$(( SIZE / 1024 ))
[ "$KB" -gt 2000 ] && warn "Homepage first response is ${KB}KB - heavy" \
                   || info "Homepage response size: ${KB}KB"

# Say whether a cache answered, because it changes what the timing above MEANS.
# A cache HIT flatters the site; a MISS right after a purge makes a healthy site look
# slow. Without this line a cold-cache reading is indistinguishable from a real
# regression, and we would chase (or dismiss) the wrong thing.
CACHE_STATE="$(curl -sSI -L -A "$UA" --max-time 20 "$URL" 2>/dev/null \
  | grep -iE '^(x-cache|cf-cache-status|x-litespeed-cache|x-proxy-cache|x-wp-super-cache):' \
  | tr -d '\r' | head -2 | sed 's/^/       /')"
if [ -n "$CACHE_STATE" ]; then
  if printf '%s' "$CACHE_STATE" | grep -qi 'hit'; then
    info "Served from cache - the timing above is the cached (best-case) speed:"
  else
    info "NOT served from cache - the timing above is the slower uncached path (normal right after a cache purge):"
  fi
  printf '%s\n' "$CACHE_STATE"
fi
case "$EFF" in "$URL"|"$URL/"|'') :;; *) info "Redirects to: $EFF";; esac

# ---------------------------------------------------------------- https / ssl
echo; echo "--- Security certificate (HTTPS) ---"
if [ "${URL:0:5}" = "https" ]; then
  CERT="$(echo | openssl s_client -servername "$HOST" -connect "$HOST:443" 2>/dev/null)"
  EXP="$(printf '%s' "$CERT" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)"
  ISS="$(printf '%s' "$CERT" | openssl x509 -noout -issuer 2>/dev/null | sed -E 's/.*O ?= ?([^,\/]+).*/\1/')"
  # Sanity: the certificate must actually be FOR this host. If a corporate proxy, sandbox,
  # or WAF terminates TLS, openssl hands back THAT box's certificate - reporting its expiry
  # as the prospect's would be flatly wrong. Only trust a cert whose CN/SAN matches.
  SUBJ="$(printf '%s' "$CERT" | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null | tr 'A-Z' 'a-z')"
  BASE="$(printf '%s' "$HOST" | tr 'A-Z' 'a-z' | sed -E 's/^www\.//')"
  # A wildcard cert (*.instawp.site, *.myhost.com) legitimately covers this host but never
  # contains its full name, so a literal match would cry "interception" on perfectly good
  # shared/managed hosting. Accept the exact name OR the wildcard for its parent domain.
  # Derive the wildcard from the FULL host, not the www-stripped one: stripping first
  # would turn www.example.com into *.com, which is absurdly over-broad.
  WILD="*.$(printf '%s' "$HOST" | tr 'A-Z' 'a-z' | cut -d. -f2-)"
  case "$WILD" in *.*.*) :;; *) WILD="";; esac   # refuse a bare "*.com"-shaped match
  CERT_OK=0
  if [ -n "$CERT" ]; then
    printf '%s' "$SUBJ" | grep -qF "$BASE" && CERT_OK=1
    [ -n "$WILD" ] && printf '%s' "$SUBJ" | grep -qF "$WILD" && CERT_OK=1
  fi
  # Honest limit: this catches a certificate issued for a DIFFERENT name. It cannot
  # catch an interceptor that mints a correctly-named cert from a CA the machine
  # already trusts - name matching alone can't see that. Fine for an operator laptop;
  # worth knowing if you ever run this from behind a corporate TLS proxy.
  if [ -n "$CERT" ] && [ "$CERT_OK" = 0 ]; then
    warn "Could not validate the certificate for $HOST - the TLS connection was answered by something else (proxy/WAF interception). SSL expiry NOT verified; check it manually."
    EXP=""
  elif [ -z "$CERT" ]; then
    warn "Could not read the SSL certificate - check it manually in a browser."
  fi
  # Only report expiry when the cert is genuinely this site's.
  if [ -n "$EXP" ] && [ "$CERT_OK" = 1 ]; then
    EXP_S=$(date -d "$EXP" +%s 2>/dev/null || echo 0); DAYS=$(( (EXP_S - $(date +%s)) / 86400 ))
    if   [ "$EXP_S" = 0 ];   then info "Certificate expiry: $EXP"
    elif [ "$DAYS" -lt 0 ];  then fail "SSL certificate has EXPIRED - browsers show a security warning"
    elif [ "$DAYS" -lt 21 ]; then warn "SSL certificate expires in $DAYS days - renewal needed soon"
    else pass "SSL certificate valid ($DAYS days remaining${ISS:+, issued by $ISS})"; fi
  fi
  # http -> https enforcement
  # Only conclude "no redirect" if the http:// request actually completed - a failed
  # request tells us nothing about the site's redirect behaviour.
  if HRED="$(curl -sS -o /dev/null -A "$UA" --max-time 20 -L -w '%{http_code}|%{url_effective}' "http://$HOST" 2>/dev/null)"; then
    case "$HRED" in
      000\|*) info "Could not check http:// redirect (no response) - not confirmed either way";;
      *https://*) pass "Insecure http:// visitors are redirected to https";;
      # Urgent, not advisory: the site HAS https but does not force it, so a visitor - or
      # an admin logging in at the default wp-login.php - can transact over an
      # unencrypted connection where passwords travel in clear text. Reliably detected,
      # real consequence, cheap fix. It belongs at the top of the list, not buried.
      *) fail "http:// does not redirect to https - anyone visiting the insecure address stays unencrypted, including at the login page, where the password travels in clear text";;
    esac
  else
    info "Could not check http:// redirect (request failed) - not confirmed either way"
  fi
else
  fail "Site is not using HTTPS at all - browsers mark it 'Not secure' and Google penalizes it"
fi

# ---------------------------------------------------------------- WordPress?
echo; echo "--- Platform ---"
IS_WP=0
grep -qiE 'wp-content|wp-includes|/wp-json' "$TMP/home" 2>/dev/null && IS_WP=1
GEN="$(grep -oiE '<meta name="generator" content="WordPress [0-9.]+' "$TMP/home" 2>/dev/null | grep -oE '[0-9.]+$' | head -1)"
if [ "$IS_WP" = 1 ]; then
  info "Platform: WordPress${GEN:+ (version $GEN publicly visible)}"
  # Report the good state too, not just the bad one. A check that only speaks when
  # something is wrong makes a completed fix vanish silently instead of showing up as a
  # win - which under-credits real work in the client's report.
  if [ -n "$GEN" ]; then
    warn "WordPress version $GEN is exposed in the page source - tells attackers exactly which exploits to try"
  else
    pass "WordPress version is not disclosed in the page source"
  fi
else
  info "This does not look like a WordPress site - our care plans are WordPress-specific. Confirm before quoting."
fi

# ---------------------------------------------------------------- exposure checks (public GETs only)
echo; echo "--- Publicly exposed files & endpoints ---"
# Each check reports one of three states - exposed / confirmed-not-exposed / could-not-check.
# "Could not check" must never be rendered as reassurance.
unchecked(){ info "Could not check $1 - not confirmed either way"; }

C=$(get "/readme.html")
if [ "$C" = 000 ]; then unchecked "readme.html (no response)"
elif reachable_200 "$C" && grep -qi wordpress "$TMP/body" 2>/dev/null; then
  V="$(grep -oiE 'Version [0-9.]+' "$TMP/body" | head -1)"
  warn "readme.html is publicly readable${V:+ and discloses $V} - should be removed"
else pass "readme.html not exposed (HTTP $C)"; fi

C=$(get "/xmlrpc.php")
if [ "$C" = 000 ]; then unchecked "xmlrpc.php (no response)"
elif [ "$C" = "200" ] || [ "$C" = "405" ]; then
  warn "xmlrpc.php is open - a common brute-force and amplification target; usually safe to disable"
else pass "xmlrpc.php not openly reachable (HTTP $C)"; fi

C=$(get "/wp-content/debug.log")
if [ "$C" = 000 ]; then unchecked "debug.log (no response)"
elif reachable_200 "$C"; then
  fail "Debug log is publicly downloadable at /wp-content/debug.log - can leak file paths and errors"
else pass "No public debug.log (HTTP $C)"; fi

C=$(get "/wp-content/uploads/")
if [ "$C" = 000 ]; then unchecked "uploads directory listing (no response)"
elif reachable_200 "$C" && grep -qiE 'index of|<title>index of' "$TMP/body" 2>/dev/null; then
  warn "Uploads folder allows directory browsing - anyone can list every uploaded file"
else pass "Uploads folder is not browsable (HTTP $C)"; fi

C=$(get "/wp-json/wp/v2/users")
if [ "$C" = 000 ]; then unchecked "public username listing (no response)"
elif reachable_200 "$C" && grep -qE '"slug"' "$TMP/body" 2>/dev/null; then
  N=$(grep -oE '"slug":"[^"]+"' "$TMP/body" | wc -l | tr -d ' ')
  warn "The REST API publicly lists usernames ($N found) - hands attackers half of every login"
else pass "Usernames are not publicly listed via the REST API (HTTP $C)"; fi

C=$(get "/wp-login.php")
case "$C" in
  000)     unchecked "login page (no response)";;
  200|301|302) info "Login page is at the default address (wp-login.php) - it's the #1 brute-force target";;
  403|404) pass "Default login page is hidden or protected (HTTP $C)";;
  *)       info "Login page returned HTTP $C";;
esac

# ---------------------------------------------------------------- security headers
echo; echo "--- Security headers ---"
curl -sSI -L -A "$UA" --max-time 20 "$URL" > "$TMP/hdr" 2>/dev/null
hdr(){ grep -qi "^$1:" "$TMP/hdr"; }
hdr strict-transport-security && pass "HSTS enabled (forces secure connections)" \
  || warn "Missing HSTS header - browsers aren't told to always use HTTPS"
hdr x-content-type-options \
  && pass "X-Content-Type-Options set (blocks MIME-sniffing attacks)" \
  || warn "Missing X-Content-Type-Options - allows MIME-sniffing attacks"
if hdr x-frame-options || hdr content-security-policy; then
  pass "Clickjacking protection present (X-Frame-Options/CSP)"
else
  warn "Missing X-Frame-Options/CSP - the site can be framed for clickjacking"
fi
hdr content-security-policy && pass "Content-Security-Policy present"
SRV="$(grep -i '^server:' "$TMP/hdr" | head -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ //')"
[ -n "$SRV" ] && info "Web server: $SRV"
PHPV="$(grep -i '^x-powered-by:' "$TMP/hdr" | head -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ //')"
[ -n "$PHPV" ] && warn "Server advertises its software version ($PHPV) - unnecessary information disclosure"

# ---------------------------------------------------------------- plugins/theme visible in source
if [ "$IS_WP" = 1 ]; then
  echo; echo "--- Plugins & theme visible in the public page source ---"
  grep -oE '/wp-content/plugins/[a-z0-9._-]+' "$TMP/home" 2>/dev/null | awk -F/ '{print $4}' | sort -u > "$TMP/plugins"
  PC=$(wc -l < "$TMP/plugins" | tr -d ' ')
  if [ "$PC" -gt 0 ]; then
    info "$PC plugin(s) detectable from the homepage (there are usually more not visible):"
    sed 's/^/       - /' "$TMP/plugins"
  else info "No plugins detectable from the homepage source"; fi
  THEME="$(grep -oE '/wp-content/themes/[a-z0-9._-]+' "$TMP/home" 2>/dev/null | awk -F/ '{print $4}' | sort -u | head -2 | tr '\n' ' ')"
  [ -n "$THEME" ] && info "Theme: $THEME"
  # Security and backup plugins are ADMIN-SIDE: they usually add nothing to a public
  # page, so absence from the homepage source is NOT evidence of absence from the site.
  # (Proven on our own sandbox: Wordfence and UpdraftPlus were both installed and
  # neither was detectable.) Presence is meaningful; absence is genuinely unknown, and
  # must never be reported as "you have no backups" - that claim would be indefensible.
  grep -qiE 'wordfence|ithemes-security|solid-security|sucuri|all-in-one-wp-security' "$TMP/plugins" 2>/dev/null \
    && pass "A security plugin is visibly installed" \
    || unchecked "whether a security plugin is installed (admin-side plugins are invisible from outside)"
  grep -qiE 'updraft|backwpup|duplicator|backupbuddy|wp-umbrella' "$TMP/plugins" 2>/dev/null \
    && pass "A backup plugin is visibly installed" \
    || unchecked "whether backups are running (backup plugins are invisible from outside - this is the single most important thing to confirm)"
fi

# ---------------------------------------------------------------- basics / SEO hygiene
echo; echo "--- Basics ---"
grep -qiE '<meta[^>]+name="viewport"' "$TMP/home" 2>/dev/null \
  && pass "Mobile viewport tag present" || warn "No mobile viewport tag - likely poor on phones"
grep -qiE '<title>[^<]{5,}' "$TMP/home" 2>/dev/null \
  && pass "Homepage has a page title" || warn "Homepage is missing a proper <title>"
grep -qiE '<meta[^>]+name="description"' "$TMP/home" 2>/dev/null \
  && pass "Meta description present" || warn "No meta description - Google invents its own snippet"
MIXED=$(grep -oE 'src="http://[^"]+' "$TMP/home" 2>/dev/null | wc -l | tr -d ' ')
[ "${MIXED:-0}" -gt 0 ] && warn "$MIXED insecure http:// asset link(s) - causes mixed-content warnings" \
                        || pass "No insecure asset links found"
C=$(get "/robots.txt"); [ "$C" = "200" ] && pass "robots.txt present" || info "No robots.txt"
C=$(get "/sitemap.xml"); [ "$C" = "200" ] && pass "sitemap.xml present" || info "No sitemap.xml at the standard address"

# ---------------------------------------------------------------- summary
echo
echo "=============================================================="
echo " SUMMARY: $URGENT urgent issue(s), $ADVISED recommended fix(es)"
if   [ "$URGENT" -gt 0 ]; then echo " Verdict: needs attention now - lead with the urgent items."
elif [ "$ADVISED" -gt 3 ]; then echo " Verdict: working but under-protected - classic care-plan candidate."
else echo " Verdict: in decent shape - sell ongoing protection, not rescue."; fi
echo "=============================================================="
exit 0
