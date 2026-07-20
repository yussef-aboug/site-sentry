---
name: site-onboarding
description: >
  Onboard a new client website into SiteSentry care. Use whenever a new site is added, a
  client signs up, or the operator says "set up this new client", "onboard example.com", or
  "take over this site". Produces the site registry file, baseline backup, monitoring, the
  approved plugin stack, and a launch report.
---

# Site Onboarding Runbook

Everything here is about establishing ground truth BEFORE promising anything. Order matters:
backup before you breathe on it.

## 1. Registry first
Copy `sites/_TEMPLATE.md` → `sites/<slug>.md`. Fill what's known; list gaps for the operator
(SSH access, hosting login owner, etc.). Create `logs/<slug>.md` with an "Onboarded" entry.
Access rule: client creates a NEW administrator account for SiteSentry (never share their
personal login) and SSH uses keys, set up by the operator.

## 2. Baseline snapshot of reality (read-only)
- Full backup FIRST (backup-restore skill) — the "as we found it" restore point, kept
  permanently.
- Inventory into the journal: `wp core version`, `wp plugin list`, `wp theme list`,
  `wp user list --fields=user_login,roles`, PHP version (`wp cli info`), hosting details.
- `scripts/health-check.sh` on homepage; identify + record `homepage_keyword` and
  `critical_pages` (ask operator/client: "which 3 pages, if broken, cost you money?").
- `wp core verify-checksums` — failures at onboarding = possible pre-existing compromise;
  security-hardening skill, STOP protocol, BEFORE accepting the site into routine care.

## 3. Monitoring + management stack
- Connect WP Umbrella (operator installs plugin + API key), enable daily off-site backups.
- UptimeRobot monitor, 5-minute interval, alerts to operator email + phone app.
- Note the host's own backup/snapshot capability in the site file (secondary layer).

## 4. Approved plugin stack (install only what's missing; fewer plugins is the philosophy)
- **Backups (secondary):** UpdraftPlus (free) → client's Google Drive or similar cloud —
  redundant to WP Umbrella, owned by the client.
- **Security:** Solid Security Basic or Wordfence Free — ONE of them, never both (login
  rate-limiting, basic scanning, version-hiding). Configure per security-hardening baseline.
- **Rollback convenience:** WP Rollback (free) — one-click plugin/theme version reverts.
- **Caching/performance:** only if the host doesn't already cache (many managed hosts do —
  check first): LiteSpeed Cache on LiteSpeed servers, otherwise WP Super Cache.
- Anything beyond this stack = propose to operator with reasoning; don't accumulate plugins.
Remove (with approval): inactive plugins, unused themes (keep one default), anything
abandoned (no updates in 2+ years — check the plugin page).

## 5. Baseline hardening
Run the security-hardening skill's baseline list. Fixes on this fresh site still follow
Tier 2 gating — the client is watching their new provider's first moves.

## 6. Launch report
Draft for the operator to send: what we found (kindly worded — "opportunities", not blame),
what we did, current health, what happens next (update cadence, report schedule). This first
report sets the tone for the whole retention relationship.
