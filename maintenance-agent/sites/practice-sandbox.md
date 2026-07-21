# Site: Practice Sandbox (InstaWP)

environment: sandbox           # ← Tier 1: agent may make changes freely (snapshot first)
url: https://oddball-scarab-73427d.instawp.site
ssh_alias: sandbox             # Configured in ~/.ssh/config (key auth + RequestTTY force for InstaWP)
wp_path: /home/nadijuwefo1951/web/oddball-scarab-73427d.instawp.site/public_html   # confirmed via SSH
hosting: InstaWP (Sandbox $2/mo tier) — status: https://status.instawp.com
dns_registrar: n/a (instawp.site subdomain)

## ⚠ Host quirks — READ before any SSH/WP-CLI on this host (InstaWP-specific, confirmed by testing)
- **A PTY is required.** Plain `ssh sandbox "cmd"` (no TTY) HANGS after the command is
  accepted. `~/.ssh/config` sets `RequestTTY force` for this host to prevent that.
  Never use `ssh -T` here — it disables the PTY and hangs.
- **Run WP-CLI from wp_path.** SSH lands in the home dir (no WordPress there), so bare
  `wp ...` fails with "not a WordPress installation". Always `cd` into wp_path first.
- **Working command pattern from an automated (no local TTY) shell:** a forced TTY makes
  ssh ignore a trailing command argument in that context, so feed commands over stdin:
      printf 'cd <wp_path> && wp core version\nexit\n' | ssh sandbox 2>&1
  (equivalently `ssh -tt sandbox "cd <wp_path> && wp core version"`).
- **scp does NOT work here.** scp needs a clean, non-TTY channel, which `RequestTTY force`
  breaks. Do not scp files off this server. Off-server backups = InstaWP snapshots (below).

  These are InstaWP-sandbox quirks. Standard client hosts (cPanel, managed WordPress) do
  not hang on plain ssh, so they won't set RequestTTY force and scp works normally there —
  record each real client's own quirks in that client's site file.

## Care plan
plan: n/a — internal practice site
monthly_edit_budget_minutes: unlimited
maintenance_window: anytime
client_contact: operator (you)

## Verification targets
homepage_keyword: "Welcome to WordPress"   # default first-post text; replace once real content exists
critical_pages:
  - https://oddball-scarab-73427d.instawp.site/
  - https://oddball-scarab-73427d.instawp.site/contact/   # not built yet — currently 404, build in a later lesson
critical_functions:
  - "Contact form renders (WPForms)"   # not applicable yet — no contact page/plugin installed

## Backups
primary: InstaWP snapshots — the off-server restore point on this host (scp doesn't work here;
  take from the InstaWP dashboard, or `instawp versions create` if you install the InstaWP CLI).
  Verified restore point: `sitesentry-baseline-2026-07-21` (permanent as-found baseline, created
  2026-07-21 by operator via the InstaWP dashboard).
secondary: WP Umbrella — NOT connected yet (corrected 2026-07-21; was listed as connected in
  error). The `InitUmbrella` must-use plugin seen in `wp plugin list` is InstaWP's own platform
  plugin, unrelated. Plus an on-server `wp db export` as a quick pre-change dump.
# (restore-drill date is tracked under ## Service tracking below)

## Inventory notes
theme: twentytwentyfive (active, 1.5) — confirmed 2026-07-21 via `wp theme list`
fragile_plugins: none yet — install a page builder later to practice on fragile territory
staging: this IS the practice environment

## Service tracking (agent updates these; roster.sh reads them)
last_update_run: 2026-07-21
last_security_scan: 2026-07-21
last_link_check: [date]
last_performance_check: [date]
last_report: [YYYY-MM]
last_restore_drill: [date]
last_quarterly_review: [date]
edit_minutes_used_this_month: 0
dev_hours_used_this_month: 0

## History
journal: logs/practice-sandbox.md
onboarded: 2026-07-21
notes: Training site. Break it on purpose. If it dies permanently, spin up a new one —
  that itself is good practice. Baseline pass (2026-07-21): clean WP 7.0 install, PHP 8.3.27,
  checksums verify clean, no admin-named user. Gaps found and fixed 2026-07-21: set
  DISALLOW_FILE_EDIT, installed Wordfence + WP Rollback + UpdraftPlus + WP Super Cache,
  patched wp-health 2.25.0→2.25.1. Still open: hide generator-tag version, point UpdraftPlus
  at cloud storage, connect real WP Umbrella + UptimeRobot.