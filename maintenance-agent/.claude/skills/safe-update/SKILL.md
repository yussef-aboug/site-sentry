---
name: safe-update
description: >
  Run WordPress updates (plugins, themes, core) safely on a client site. Use this skill for
  ANY task involving updating, upgrading, or patching WordPress software — including "update
  the site", "run weekly maintenance", "patch that vulnerability", or "updates are pending".
  Never update anything without following this procedure.
---

# Safe Update Runbook

Order of operations is fixed: **verify backup → baseline → staging → production, one item at
a time → verify → log.** Never reorder. Never batch to save time on production.

## Phase 0 — Preflight (read-only)
1. Read `sites/<slug>.md`. Confirm environment, wp_path, fragile_plugins, maintenance window.
   Production + outside window → ask operator before proceeding.
2. Baseline: `scripts/health-check.sh <url> "<homepage_keyword>"` — must PASS. If baseline
   fails, STOP: fix-the-site comes first (downtime-triage skill), never update a broken site.
3. Inventory what needs updating:
   `ssh <alias> "cd <wp_path> && wp plugin list --update=available && wp theme list --update=available && wp core check-update"`
4. Record current versions (this is your rollback map):
   `wp plugin list --fields=name,version,status --format=csv` → paste into the journal entry.

## Phase 1 — Backup verification (Law 1)
- Confirm a backup from TODAY exists in WP Umbrella (operator can confirm from dashboard) OR
  take one now: `wp db export ~/backups/<slug>-$(date +%F).sql` plus files if feasible.
- On InstaWP sites, take a snapshot: `instawp versions create <site>` — one-command restore.
- Write the exact rollback point into the journal BEFORE changing anything.

## Phase 2 — Staging pass (Law 2)
- If the site file lists a staging environment: apply ALL intended updates there first, then
  run health-check + click-through of critical_pages on staging. Any failure → do not
  proceed to production; investigate, note findings, report to operator.
- If no staging exists: present the update list + risk notes to the operator and WAIT for
  `APPROVED: updates <slug>` before Phase 3. High-risk items (fragile_plugins, major-version
  jumps, WooCommerce) should get a staging clone even if one must be created for the occasion.

## Phase 3 — Production, one at a time
For EACH plugin (security-critical ones first, fragile_plugins LAST and individually):
1. `wp plugin update <slug-of-plugin>`
2. `wp plugin list --name=<slug-of-plugin>` → confirm status still "active", version bumped.
3. `scripts/health-check.sh` on homepage + the critical page most related to that plugin.
4. Failure? → rollback THIS plugin immediately (see below), log it, continue with the rest
   only if the site is healthy again.
Then themes: `wp theme update <name>` → health check.
Then core, LAST (plugins/themes get compatibility-tested against new core by their authors,
so core-last minimizes conflict windows):
`wp core update && wp core update-db && wp core verify-checksums` → checksums MUST pass; a
checksum failure after update = STOP + escalate (possible corruption or compromise).
Finally: flush caches (`wp cache flush`; plus any caching plugin's CLI flush) and re-run the
full health check on every critical page.

## Rollback moves (fastest first)
- Single plugin: `wp plugin install <slug-of-plugin> --version=<previous> --force` (version
  from your Phase 0 CSV), or deactivate it: `wp plugin deactivate <slug-of-plugin>`.
- Site won't respond to WP-CLI: retry with `--skip-plugins --skip-themes` flags.
- Still broken: rename the plugin's folder in `wp-content/plugins/` via SSH (instant
  deactivation), health check, then diagnose.
- Nuclear: restore the Phase 1 backup/snapshot. On InstaWP: `instawp versions restore`.
- After ANY rollback: site healthy → log what failed and why → tell operator which item is
  now frozen pending investigation. Never retry the same failed update in the same session.

## Phase 4 — Close out
- Journal entry: date, items updated (old→new versions), checks run, anything rolled back,
  rollback point location.
- One plain-English line for the client report, e.g. "Applied 6 security updates; all systems
  verified healthy afterward."
- Note in journal: "monitor for 24–48h" — some breakage only appears when cron jobs or real
  visitors hit the site.
