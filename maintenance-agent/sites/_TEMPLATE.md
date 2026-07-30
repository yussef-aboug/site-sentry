# Site: [Business Name]

<!-- Copy this file to sites/<slug>.md and fill it in during onboarding.
     The agent may not touch any site that lacks a completed file here.
     Slug rule: lowercase, hyphenated, derived from the business name, UNIQUE across sites/.
     e.g. "Sunrise Bakery" -> sites/sunrise-bakery.md. The slug IS the site's identity
     everywhere (logs/<slug>.md, roster, alerts) — pick it once, never reuse or recycle it. -->

slug: clientname               # MUST equal this file's name without .md, and be unique
status: onboarding             # onboarding | active | paused | offboarded  (see below)
environment: production        # production | staging | sandbox  (controls autonomy tier)
url: https://example.com       # canonical public URL — the ONE address this site lives at
ssh_alias: clientname          # Host alias in ~/.ssh/config (key auth; NO credentials here)
wp_path: /var/www/html         # Absolute directory containing wp-config.php on the server
hosting: [Host name + link to their status page]
dns_registrar: [Registrar]    # For expiry checks; agent never changes DNS (Tier 3)

# status meaning (gates what the agent will do):
#   onboarding — being taken into care; NO routine servicing yet, identity not yet bound.
#   active     — fully onboarded, identity bound, monitored; normal cadence applies.
#   paused     — retainer on hold; read-only only, no changes, excluded from roster "due".
#   offboarded — no longer a client; agent must NOT connect or act. Kept for records only.

## Identity anchors (bind the site to reality so the agent can't act on the wrong box)
# Filled during onboarding stage "Bind identity" and re-checked before EVERY change.
# HARD anchors — the strong proof you're on the right site. The live WordPress must report
# ITSELF as this url. If home/siteurl stop matching, STOP: the alias may have been repointed,
# or you're on the wrong box. Do not "fix" through a mismatch.
expected_home: https://example.com     # must equal `wp option get home`   on the server
expected_siteurl: https://example.com  # must equal `wp option get siteurl` on the server
# SOFT anchors — corroborating signals, NOT hard stops. On shared/managed hosting the server
# node hostname legitimately differs from the domain and can change when the host migrates the
# site. A change here means CONFIRM a host migration with the operator, not auto-abort.
server_hostname: [from `hostname -f`]  # the server node the alias currently lands on
blog_id_check: [from `wp option get blogname`]  # human-readable sanity string

## Host quirks — connection notes (fill in during onboarding; agent READS this first)
# Most standard hosts (cPanel, managed WordPress) need nothing here — plain `ssh <alias> "cmd"`
# and `scp` both work. Record anything non-standard you discover, e.g.:
#   - Needs a forced PTY (RequestTTY force) or `ssh <alias> "cmd"` hangs — and note that scp
#     then won't work, so back up via the host's own snapshots instead.
#   - Non-obvious wp_path, or `wp` requires an explicit --path.
#   - WP-CLI unavailable (shared host, no SSH) -> advisory mode via WP Umbrella + wp-admin.
quirks: none known yet

## Care plan
plan: peace-of-mind            # essentials | peace-of-mind | total-care  (sets cadence — see CADENCE.md)
monthly_edit_budget_minutes: 60          # 0 for essentials; 60 for peace-of-mind/total-care
monthly_dev_budget_hours: 0              # total-care only: 2
is_store: no                             # yes if WooCommerce/other commerce plugin → must be total-care
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
# (restore-drill date is tracked under ## Service tracking below)

## Inventory notes
theme: [name]
fragile_plugins: [e.g. page builder, WooCommerce — never bulk-update these]
staging: [InstaWP clone | host staging URL | none — if none, Tier 2 gate applies to everything]

## Service tracking (agent updates these dates after each run; roster.sh reads them)
last_update_run: [date]            # YYYY-MM-DD
last_security_scan: [date]
last_link_check: [date]            # peace-of-mind / total-care
last_performance_check: [date]     # peace-of-mind / total-care
last_report: [YYYY-MM]             # month of the last monthly report
last_restore_drill: [date]
last_quarterly_review: [date]      # total-care only
edit_minutes_used_this_month: 0    # resets on the 1st
dev_hours_used_this_month: 0       # total-care only

## History
journal: logs/[slug].md
onboarded: [date]                  # date status flipped onboarding -> active
notes: [Anything unusual: custom code, old PHP, past hacks, client quirks]
