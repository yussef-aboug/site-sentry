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
homepage_keyword: "[open the site, pick a unique phrase from the homepage, paste it here]"
critical_pages:
  - https://oddball-scarab-73427d.instawp.site/
  - https://oddball-scarab-73427d.instawp.site/contact/   # if you built one in lesson 1
critical_functions:
  - "Contact form renders (WPForms)"

## Backups
primary: InstaWP snapshots (instawp versions create) — one-command restore
secondary: WP Umbrella (connected)
last_restore_drill: never — good first exercise

## Inventory notes
theme: [check with: wp theme list --status=active]
fragile_plugins: none yet — install a page builder later to practice on fragile territory
staging: this IS the practice environment

## History
journal: logs/practice-sandbox.md
onboarded: [today's date]
notes: Training site. Break it on purpose. If it dies permanently, spin up a new one —
  that itself is good practice.
