---
name: site-onboarding
description: >
  Onboard a new client website into SiteSentry care. Use whenever a new site is added, a
  client signs up, or the operator says "set up this new client", "onboard example.com", or
  "take over this site". Produces the site registry file, a bound site identity, baseline
  backup, monitoring, the approved plugin stack, and a launch report.
---

# Site Onboarding Runbook

Everything here is about establishing ground truth BEFORE promising anything. Order matters:
identity and backup before you breathe on it. A site is not "in care" until stage 7 flips its
status to `active` — until then it gets NO routine servicing.

The operator-side intake (what to collect from the client, in what order) lives in
`CLIENT-ONBOARDING.md`. This skill is the agent's half: it assumes the operator has gathered
access and hands you a filled-in draft site file to verify and complete.

## 0. Name it once (slug)
Pick the slug from the business name: lowercase, hyphenated, unique across `sites/`.
"Sunrise Bakery" → `sunrise-bakery`. Before creating anything, `ls sites/` and confirm the
slug isn't taken (never recycle a slug from an offboarded client — pick a distinct one). The
slug is the site's identity everywhere: `sites/<slug>.md`, `logs/<slug>.md`, roster, alerts.

## 1. Registry first
Copy `sites/_TEMPLATE.md` → `sites/<slug>.md`. Set `slug:` to match the filename and
`status: onboarding`. Fill what's known; list gaps for the operator (SSH access, hosting login
owner, etc.). Create `logs/<slug>.md` with an "Onboarded — started" entry.
Access rule: client creates a NEW administrator account for SiteSentry (never share their
personal login) and SSH uses keys, set up by the operator — never credentials in these files.

## 2. Bind identity — prove you're on the right site (do this BEFORE anything else touches it)
This is the step that guarantees the agent only ever acts on the correct site. Connect via the
`ssh_alias` and confirm the box you land on is genuinely this client's site:
- `wp option get home` and `wp option get siteurl` → must match the site file's `url`.
  Record them into `expected_home` / `expected_siteurl`.
- `hostname -f` → record into `server_hostname`. `wp option get blogname` → `blog_id_check`.
- Confirm `wp_path` actually contains `wp-config.php` (`test -f <wp_path>/wp-config.php`).
- Public check: `scripts/health-check.sh <url>` reaches a live WordPress site at that URL.
If the URL the server reports does NOT match the URL you were given, or the alias lands on a
box already bound to a DIFFERENT slug, STOP and tell the operator — do not proceed. A wrong
binding here is how an agent ends up editing the wrong client's site; catching it costs
seconds, missing it can be catastrophic. Only once these anchors are written and matching may
onboarding continue.

## 3. Baseline snapshot of reality (read-only)
- Full backup FIRST (backup-restore skill) — the "as we found it" restore point, kept
  permanently.
- Inventory into the journal: `wp core version`, `wp plugin list`, `wp theme list`,
  `wp user list --fields=user_login,roles`, PHP version (`wp cli info`), hosting details.
- `scripts/health-check.sh` on homepage; identify + record `homepage_keyword` and
  `critical_pages` (ask operator/client: "which 3 pages, if broken, cost you money?").
- `wp core verify-checksums` — failures at onboarding = possible pre-existing compromise;
  security-hardening skill, STOP protocol, BEFORE accepting the site into routine care.

## 4. Monitoring + management stack
- Connect WP Umbrella (operator installs plugin + API key), enable daily off-site backups.
- UptimeRobot monitor, 5-minute interval, alerts to operator email + phone app.
- Note the host's own backup/snapshot capability in the site file (secondary layer).

## 5. Approved plugin stack (install only what's missing; fewer plugins is the philosophy)
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

## 6. Baseline hardening
Run the security-hardening skill's baseline list. Fixes on this fresh site still follow
Tier 2 gating — the client is watching their new provider's first moves.

## 7. Go active + launch report
- Set `status: active`, `onboarded: <today>`, and confirm all identity anchors and the plan
  fields (`plan`, `is_store`, budgets) are filled — a blank `plan` is a config error. Run
  `scripts/roster.sh <slug>` and confirm the site now appears correctly.
- Draft the launch report for the operator to send: what we found (kindly worded —
  "opportunities", not blame), what we did, current health, what happens next (update cadence,
  report schedule). This first report sets the tone for the whole retention relationship.

## Before the FIRST maintenance action on any newly-active site
Re-run the stage-2 identity check (home/siteurl/hostname vs. the anchors). From then on, the
relevant skills re-verify identity as part of their pre-change checks. The rule is simple:
**never change a site you haven't just re-confirmed is the right one.**
