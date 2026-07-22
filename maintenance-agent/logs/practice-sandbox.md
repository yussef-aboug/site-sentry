# Journal: Practice Sandbox (InstaWP)

## 2026-07-21 — Onboarded

**What:** Ran the site-onboarding skill end-to-end (read-only baseline; no changes made yet).

**Why:** First training exercise per README training path — establish ground truth before any
modification.

**SSH note (operational, keep for future sessions on this host):** `~/.ssh/config` sets
`RequestTTY force` for the `sandbox` alias — this is intentional for this InstaWP host, not a
misconfiguration. A plain `ssh sandbox "<cmd>"` from this agent's shell tool hangs (the forced
PTY sits at an interactive prompt and never receives the argv command). Workaround that works
reliably: pipe the command through stdin with a trailing `exit`, e.g.
`printf 'cd <wp_path> && <command>\nexit\n' | ssh sandbox`. Never use `-T`/`-o RequestTTY=no` on
this host — that disables the PTY it requires and causes a different hang. Never use `scp`/`sftp`
against this alias either — the forced-TTY channel breaks the file-transfer protocol; use InstaWP
snapshots for any off-server copy instead.

**Commands run:**
- `wp core version` → 7.0
- `wp cli info` → PHP 8.3.27, MariaDB 11.4.9, WP-CLI 2.12.0
- `wp plugin list` → `wp-health` (active, 2.25.0, update to 2.25.1 available),
  `InitUmbrella` (must-use, 1.0.0 — InstaWP's own platform plugin; not the "WP Umbrella"
  monitoring product despite the similar name)
- `wp theme list` → `twentytwentyfive` (active, 1.5), only theme installed
- `wp user list --fields=user_login,roles` → `posayelobe3563` (administrator) — not named
  admin/administrator, baseline item 1 passes
- `wp core verify-checksums` → Success, installation verifies clean
- `wp config get DISALLOW_FILE_EDIT` → not defined (gap)
- `wp config get WP_DEBUG` → empty/false (pass — debug is off)
- `curl ... | grep generator` → `<meta name="generator" content="WordPress 7.0" />` (version
  disclosure gap)
- `scripts/health-check.sh` against homepage → ALL CHECKS PASSED (200, SSL valid 76 days,
  no fatal-error text, wp-login reachable)

**Backup (Law 1):**
- `wp db export /tmp/practice-sandbox-2026-07-21.sql` on the server — 130,246 bytes, exported
  cleanly. This file is ON the server only (no scp/sftp possible on this host — see SSH note
  above) and should be treated as a convenience copy, not the restore point of record.
- Files archive: `tar -czf /tmp/practice-sandbox-files-2026-07-21.tar.gz wp-content
  wp-config.php .htaccess` on the server — 8,627,232 bytes, created cleanly. Same caveat as above.
- **Restore point of record:** InstaWP snapshot `sitesentry-baseline-2026-07-21`, created by the
  operator via the InstaWP dashboard (Snapshots → Create) on 2026-07-21. Permanent as-found
  baseline restore point. Law 1 satisfied as of this snapshot — Tier 1 sandbox changes may
  proceed.

**Security baseline (read-first pass, see security-hardening skill):**
1. No 'admin' username — PASS (`posayelobe3563`)
2. Core integrity — PASS (checksums clean)
3. Software currency — MINOR GAP (`wp-health` one patch release behind: 2.25.0 → 2.25.1;
   handle via safe-update skill, not urgent)
4. Dead weight removed — PASS (no inactive plugins, no unused themes)
5. File editing disabled — GAP (`DISALLOW_FILE_EDIT` not set)
6. Login protection — GAP (no rate-limiting/2FA plugin from approved stack installed yet)
7. SSL — PASS (valid, 76 days remaining at check time)
8. Backups off-site and current — GAP (see Backup note above — snapshot pending)
9. Debug off in production — PASS (`WP_DEBUG` falsy)
10. Version disclosure — GAP (generator meta tag reveals "WordPress 7.0")

**Approved plugin stack vs. installed:**
- Backups (secondary/UpdraftPlus): not installed
- Security (Solid Security Basic / Wordfence Free — pick one): not installed
- Rollback (WP Rollback): not installed
- Caching: not evaluated yet (need to confirm whether InstaWP already caches before adding one)
- Monitoring (WP Umbrella): NOT actually connected — `sites/practice-sandbox.md` previously
  listed this as "connected," which was aspirational/incorrect; corrected in the site file.
  `InitUmbrella` must-use plugin seen in `wp plugin list` is InstaWP's own platform plugin, a
  different product.
- UptimeRobot monitor: not yet set up (operator action, external account)

**Verification result:** Health check passed. No changes made to the site this session — this
was a read-only baseline pass. `wp core verify-checksums` clean, so no pre-existing compromise
found; safe to proceed with routine onboarding once the backup is verified.

## 2026-07-21 — Baseline fixes applied (Tier 1, sandbox)

**What:** With Law 1 satisfied by snapshot `sitesentry-baseline-2026-07-21`, applied the queued
baseline fixes and approved plugin stack.

**Commands run:**
- `wp config set DISALLOW_FILE_EDIT true --raw` → Success (gap closed)
- `wp plugin update wp-health` → 2.25.0 → 2.25.1 (gap closed)
- `wp plugin install wordfence --activate` → 8.2.2 (security/login-protection gap closed)
- `wp plugin install wp-rollback --activate` → 3.1.2 (rollback convenience added)
- `wp plugin install updraftplus --activate` → 1.26.5 (secondary backup plugin added; still
  needs operator to point it at cloud storage — not done here, no credentials)
- `wp plugin install wp-super-cache --activate` → 3.1.1 (no existing host-level cache detected
  — plain nginx, no `X-Cache`/`Cache-Control` headers — so this was in scope per the stack rules)

**Verification (Law 3):**
- `wp core verify-checksums` → clean, still passes after all installs
- `scripts/health-check.sh` → ALL CHECKS PASSED (200 OK, SSL valid 76 days, no fatal-error
  text, wp-login reachable) — no regression from baseline
- Generator meta tag still shows `WordPress 7.0` — Wordfence does not strip this by default: it
  requires enabling a specific option under Wordfence, not just installing the plugin. Left
  as an open item rather than pushed through as a code change without checking in first.

**Remaining open items:**
1. Version-disclosure gap (generator tag) — needs a Wordfence config toggle or a small
   `remove_action('wp_head','wp_generator')` snippet; propose to operator before doing either.
2. UpdraftPlus not yet pointed at any remote storage (Google Drive etc.) — needs operator's
   account/credentials.
3. Operator to connect real WP Umbrella (plugin + API key) and set up UptimeRobot — both
   need operator-owned accounts, out of agent scope.
4. Fill in `homepage_keyword`/critical_pages properly once real content exists beyond the
   default "Hello World" post — currently a bare install, `/contact/` still 404.

**Rollback point:** InstaWP snapshot `sitesentry-baseline-2026-07-21` (pre-all-of-the-above).

**Plain-English summary:** The practice sandbox now has the standard SiteSentry protections in
place — a security/login-protection plugin, one-click rollback, a secondary backup plugin, page
caching, and a locked-down file editor — all installed and verified with no downtime or errors.
Two small items are left for a follow-up conversation: hiding the WordPress version number, and
connecting the backup plugin to real cloud storage.
