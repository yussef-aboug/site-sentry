---
name: speed-optimization
description: >
  Measure a site's performance and, on Total Care, safely improve it — the "performance
  monitoring" (Peace of Mind) and "speed optimization" (Total Care) promises. Use for
  "check site speed", "the site feels slow", "run the performance check", "optimize load
  time", or as part of a maintenance cycle. Two modes: MONITOR (measure + report, all tiers
  that include it) and OPTIMIZE (make changes, Total Care only, one lever at a time).
---

# Speed & Performance Runbook

Slow sites lose visitors and Google rankings. But performance work is where well-meaning
"optimization" most often *breaks* a site (a caching or minify plugin can white-screen it),
so this skill is deliberately conservative: **measure first, change one lever at a time,
re-measure, keep only what helped.**

Targets (Google Core Web Vitals):
- **TTFB** (server response) < 800ms, ideally < 200ms.
- **LCP** (largest content paints) ≤ 2.5s.
- **INP** (interaction responsiveness) < 200ms.
- **CLS** (layout shift) < 0.1.

## MODE A — MONITOR (Tier 0, read-only; Peace of Mind + Total Care)

1. **Preflight:** read `sites/<slug>.md`; `health-check.sh` must PASS first.
2. **Measure TTFB and total load** from a cold cache, a few times, on the homepage + 2
   critical_pages:
   ```
   curl -s -o /dev/null -w 'code:%{http_code} ttfb:%{time_starttransfer}s total:%{time_total}s size:%{size_download}\n' -L "<url>"
   ```
   Run 3× per page (discard the first as cache warm-up); record median.
3. **Field data if available:** Core Web Vitals from CrUX/PageSpeed are the truth of real
   users — if the operator can pull a PageSpeed Insights / Search Console CWV snapshot, use
   its LCP/INP/CLS. Lab `curl` timing covers TTFB; it does not measure LCP/INP.
4. **Cheap wins inventory (read-only, over SSH):**
   - Caching present? Look for a page-cache plugin / server cache
     (`wp plugin list --status=active` for LiteSpeed/WP Super Cache/W3TC/WP Rocket; check
     response headers `curl -sI <url>` for `x-cache`, `cf-cache-status`, `x-litespeed-cache`).
   - Object cache? `wp cache type` / presence of Redis/Memcached.
   - Image weight: `du -sh wp-content/uploads` and sample largest files
     (`find wp-content/uploads -type f -size +500k | head`); are they WebP/AVIF or huge PNGs?
   - PHP version (`wp cli info`) — old PHP is slow and insecure.
   - Autoloaded options bloat (a classic silent killer):
     `wp option list --autoload=on --format=count` and total size — flag if > ~1MB.
   - Homepage HTTP request count / total page weight from the MONITOR fetch.
5. **Report:** median TTFB/total per page vs. targets, the biggest bottleneck in plain terms
   ("your homepage is 4.2s, mostly because images total 6MB and there's no caching"), and a
   prioritized recommendation list. On Peace of Mind you STOP here — monitoring means
   measure + advise; actual changes are a Total Care activity (or a quoted one-off).

## MODE B — OPTIMIZE (Total Care only; Tier 2 — full gates)

Only after MONITOR identifies a specific bottleneck. Apply the **highest-impact, lowest-risk**
lever first, one at a time, verifying after each. Backup verified before starting (Law 1);
on production, staging-test or `APPROVED:` (Law 2).

Order of levers (impact ↓, risk ↑):
1. **Enable/repair page caching** — biggest TTFB/LCP win. Configure the approved caching
   plugin for the server (LiteSpeed Cache on LiteSpeed; else WP Super Cache), or confirm
   host-level cache is on. After enabling: **hard-verify** the site still renders logged-out
   AND logged-in, forms submit, and (stores) cart/checkout are excluded from cache.
2. **Serve modern images** — convert/deliver WebP/AVIF and add lazy-loading via the caching/
   image plugin; compress the oversized originals found in MONITOR. Never bulk-convert without
   a backup — keep originals.
3. **Object cache** — enable Redis/Memcached if the host offers it (`wp cache flush` after).
4. **Minify/combine CSS/JS** — LAST and most fragile. Turn on one option at a time
   (CSS minify, then JS, then defer) and re-check every critical page + JS-driven feature
   (sliders, forms, store) after each. This is the #1 cause of "optimization broke my site."
5. **PHP version bump** — coordinate with host; test on staging (plugin compatibility).

After **every** lever: re-run MODE A measurement on the same pages, `health-check.sh`, and a
click-through of critical_pages. Kept only if it measurably helped AND broke nothing.

## Rollback
- A lever that breaks rendering or a feature: disable that one setting immediately
  (`wp plugin deactivate <cache-plugin> --skip-plugins --skip-themes` if a cache plugin
  white-screens), `wp cache flush`, re-verify. Log it as "tried X, reverted, reason".
- Nuclear: restore the pre-optimization snapshot (`backup-restore`).
- Never stack a second lever on top of an unverified first one.

## Close-out & edge cases
- Journal: before/after median TTFB & total per page, which levers were applied/kept/reverted,
  remaining bottlenecks that need hosting or a redesign (out of scope for tuning).
- Client line: "Cut your homepage load from 4.2s to 1.6s by turning on caching and
  compressing images — pages now open noticeably faster."
- **Biggest lever is often the host**, not a plugin: if TTFB stays >800ms with caching on,
  the honest recommendation is a hosting upgrade — say so; don't chase it with more plugins.
- **Stores:** never cache the cart, checkout, or my-account pages; confirm the caching plugin
  excludes them (WooCommerce sets constants many caches honor — verify, don't assume).
- **Page builders (Elementor/Divi):** aggressive CSS/JS optimization frequently breaks their
  layouts — test extra carefully or leave minify off; a fast-but-broken page is a failure.
- Don't chase a PageSpeed *score* for its own sake — optimize the real-user metric (LCP/INP)
  and the client's actual pages, not a synthetic number.
