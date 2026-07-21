# Site: Practice Sandbox (InstaWP)

environment: sandbox           # ← Tier 1: agent may make changes freely (snapshot first)
url: https://oddball-scarab-73427d.instawp.site
ssh_alias: sandbox             # Configured in ~/.ssh/config (key auth + RequestTTY force for InstaWP)
wp_path: /home/nadijuwefo1951/web/oddball-scarab-73427d.instawp.site/public_html   # confirmed via SSH
hosting: InstaWP (Sandbox $2/mo tier) — status: https://status.instawp.com
dns_registrar: n/a (instawp.site subdomain)

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
primary: InstaWP snapshots (instawp versions create) — one-command restore. Verified restore point: `sitesentry-baseline-2026-07-21` (permanent as-found baseline, created 2026-07-21 by operator via InstaWP dashboard).
secondary: WP Umbrella — NOT actually connected yet (corrected 2026-07-21; previously listed as connected in error). `InitUmbrella` must-use plugin seen in `wp plugin list` is InstaWP's own platform plugin, unrelated.
last_restore_drill: never — good first exercise

## Inventory notes
theme: twentytwentyfive (active, 1.5) — confirmed 2026-07-21 via `wp theme list`
fragile_plugins: none yet — install a page builder later to practice on fragile territory
staging: this IS the practice environment

## SSH operational note
`RequestTTY force` is set for this host on purpose. Plain `ssh sandbox "<cmd>"` hangs from a
non-interactive shell (forced PTY waits at a prompt, never runs the argv command). Use:
`printf 'cd <wp_path> && <command>\nexit\n' | ssh sandbox`. Never add `-T`/disable the TTY.
Never use scp/sftp against this alias — the forced-TTY channel breaks file transfer; use
InstaWP snapshots for any off-server copy.

## History
journal: logs/practice-sandbox.md
onboarded: 2026-07-21
notes: Training site. Break it on purpose. If it dies permanently, spin up a new one —
  that itself is good practice. Baseline pass (2026-07-21): clean WP 7.0 install, PHP 8.3.27,
  checksums verify clean, no admin-named user. Gaps found: DISALLOW_FILE_EDIT not set, no
  security/rollback/backup plugin installed yet, WP version disclosed in generator meta tag.
  Fixes queued pending InstaWP snapshot confirmation (Law 1).
