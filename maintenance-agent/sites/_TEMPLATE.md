# Site: [Business Name]

<!-- Copy this file to sites/<slug>.md and fill it in during onboarding.
     The agent may not touch any site that lacks a completed file here. -->

environment: production        # production | staging | sandbox  (controls autonomy tier)
url: https://example.com
ssh_alias: clientname          # Host alias in ~/.ssh/config (key auth; NO credentials here)
wp_path: /var/www/html         # Directory containing wp-config.php on the server
hosting: [Host name + link to their status page]
dns_registrar: [Registrar]    # For expiry checks; agent never changes DNS (Tier 3)

## Host quirks — connection notes (fill in during onboarding; agent READS this first)
# Most standard hosts (cPanel, managed WordPress) need nothing here — plain `ssh <alias> "cmd"`
# and `scp` both work. Record anything non-standard you discover, e.g.:
#   - Needs a forced PTY (RequestTTY force) or `ssh <alias> "cmd"` hangs — and note that scp
#     then won't work, so back up via the host's own snapshots instead.
#   - Non-obvious wp_path, or `wp` requires an explicit --path.
#   - WP-CLI unavailable (shared host, no SSH) -> advisory mode via WP Umbrella + wp-admin.
quirks: none known yet

## Care plan
plan: peace-of-mind            # essentials | peace-of-mind | total-care
monthly_edit_budget_minutes: 60
maintenance_window: Tuesdays 07:00–09:00 ET
client_contact: [Name] — [email]   # Agent DRAFTS emails only; operator sends

## Verification targets (health checks use these)
homepage_keyword: "[Unique phrase that appears on the healthy homepage]"
critical_pages:
  - https://example.com/            # home
  - https://example.com/contact/    # form must render
  - https://example.com/menu/       # [most important business page]
critical_functions:
  - "Contact form submits (test to operator address only)"

## Backups
primary: WP Umbrella daily, off-site (verify in dashboard before changes)
secondary: [UpdraftPlus → Google Drive | host snapshots]
last_restore_drill: [date]         # Refresh monthly via backup-restore skill

## Inventory notes
theme: [name]
fragile_plugins: [e.g. page builder, WooCommerce — never bulk-update these]
staging: [InstaWP clone | host staging URL | none — if none, Tier 2 gate applies to everything]

## History
journal: logs/[slug].md
onboarded: [date]
notes: [Anything unusual: custom code, old PHP, past hacks, client quirks]
