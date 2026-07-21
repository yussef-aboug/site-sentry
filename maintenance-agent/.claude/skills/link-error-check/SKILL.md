---
name: link-error-check
description: >
  Find broken links, missing images, and error pages across a client site — the "broken
  link and error checks" promised on Peace of Mind and Total Care. Use for tasks like
  "check for broken links", "run the monthly error scan", "why are customers seeing 404s",
  or as part of a maintenance cycle. Read-only discovery + a plain-English fix list; fixes
  themselves go through small-edits or are quoted.
---

# Broken Link & Error Check Runbook

Broken links quietly erode trust and SEO — a dead "Menu" link or a 404 on a product page
costs money without ever announcing itself. This skill *finds and classifies*; it does not
mass-edit. Discovery is Tier 0 (read-only, safe on production).

## Phase 0 — Preflight
1. Read `sites/<slug>.md`: url, critical_pages, and note if it's a store (broken checkout
   links are then top priority).
2. `scripts/health-check.sh <url> "<homepage_keyword>"` — must PASS. A site that's already
   down is a `downtime-triage` job, not a link scan.
3. Decide crawl scope with the operator if the site is large (>~500 pages): full crawl vs.
   critical_pages + navigation + recent posts. Throttle to be a polite guest, not a load test.

## Phase 1 — Crawl for broken links (read-only)
Prefer a tool that's present; all are non-destructive. **Always rate-limit** (`-w 1`, one
request/sec) so you don't trip the site's own firewall/fail2ban.

- **wget spider (most portable):**
  ```
  wget --spider -r -p -e robots=off -w 1 --level=5 -o /tmp/<slug>-links.log <url>
  ```
  Then extract failures:
  ```
  grep -B1 -Ei 'broken link|404 Not Found|500 Internal|response: [45][0-9][0-9]' /tmp/<slug>-links.log
  ```
- **linkchecker (richer, if installed):** `linkchecker --check-extern -o csv <url>`
- **Server-side via SSH** for internal integrity: check the WP redirect/404 log if a
  redirection plugin is active (`wp option get`… per plugin), and
  `wp post list --post_status=publish --format=count` to gauge scope.

Capture every non-200 with: the URL that's broken, the page it's linked *from*, and the
status code. Group internal vs. external.

## Phase 2 — Also catch the errors a link crawler misses
- **Missing images / media:** broken `<img>` sources often return 200 on the page but 404 on
  the asset. Scan fetched page bodies for image URLs and HEAD-check them, or
  `wp media list --format=count` vs. actual files under `wp-content/uploads` for orphans.
- **Mixed content** (http assets on an https site) — breaks the padlock:
  `curl -s <url> | grep -Eio 'http://[^"'\'' ]+' | sort -u` (ignore the site's own canonical).
- **Soft errors:** pages returning 200 but showing "Nothing found", PHP notices, or an empty
  main region — spot-check critical_pages bodies for those strings.
- **Redirect chains/loops:** `curl -sIL <url>` and count hops; >2 redirects is a fix-it.

## Phase 3 — Classify (this is the value, not the raw list)
Sort findings by business impact, not by count:
1. **Critical:** broken links/images on critical_pages, checkout/cart, navigation menus,
   or the homepage. Mixed content anywhere.
2. **Moderate:** broken internal links in body content, redirect chains.
3. **Low / external:** dead links to third-party sites (real, but you don't control them —
   note for the client to update or remove).
Distinguish **fixable-by-us** (internal typo, moved page → add redirect, re-upload image)
from **client-decision** (external site died, product discontinued).

## Phase 4 — Report & hand-off
- Journal entry: date, scope crawled, counts by severity, the full list saved to
  `logs/<slug>-links-<date>.txt` (don't bloat the journal with hundreds of URLs).
- For Peace of Mind/Total Care, small fixes (a handful of internal links/images, adding
  redirects) come out of the monthly edit budget → hand the fixable set to `small-edits`,
  logging minutes. A large cleanup (dozens of broken links, a migration artifact) is a quoted
  project, not an edit — draft the scope note.
- One plain-English line for the client report, e.g. "Checked 214 links this month, fixed 3
  broken ones (including a dead link on your Contact page); flagged 2 outdated links to
  external sites for your review."

## Edge cases
- **Crawl gets firewall-blocked / rate-limited** partway (site security plugin): back off,
  reduce depth, and if needed run the crawl from the server side over SSH, or allowlist your
  scanner IP with the operator. Never disable the client's security to finish a scan.
- **Infinite URL spaces** (calendars, faceted filters, `?add-to-cart=` links on stores):
  exclude query-string traps (`--reject-regex` / linkchecker ignore rules) so the crawl ends.
- **Staging/dev URLs leaking** into content (links to a `staging.` or `.instawp.site` host on
  a live site) — flag as critical; that's a migration bug and often an SEO/security issue.
