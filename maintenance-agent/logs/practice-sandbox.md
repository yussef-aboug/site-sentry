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

## 2026-07-23 — Downtime triage: critical error, root cause found and fixed (Tier 1, sandbox)

**Reported:** Operator relayed "client says site is down, showing an error, customers can't
reach it." Followed the downtime-triage runbook outside-in rather than guessing.

**Timeline:**
- **02:02 UTC detected:** `scripts/health-check.sh` → HTTP 500, keyword missing, error text in
  body, `wp-login.php` also 500. `curl -sI` confirmed 500 from outside (nginx/InstaWP responding
  fine at the network layer, so not DNS/hosting-level — SSL still valid, ruling out Steps 2–3).
- **Step 4 (application layer):** page body showed WordPress's generic "There has been a
  critical error on this website" — a PHP fatal, not a DB-connection or 403/SSL error.
- **Step 5 (root cause):** no `wp-content/debug.log` present, so ran `wp plugin list` directly,
  which itself fatal'd and printed the real stack trace: `Call to undefined function
  sitesentry_drill_undefined_fn()` thrown from
  `wp-content/mu-plugins/zz-sitesentry-drill.php:1`. Read the file — a single line,
  `<?php sitesentry_drill_undefined_fn();`, planted directly in `mu-plugins/` (must-use plugins
  load unconditionally on every request, before regular plugins, so `wp plugin deactivate`
  cannot disable one — this is why it took the whole site down instantly and WP-CLI itself
  couldn't run any command).
- **02:03 UTC fixed:** renamed the file to `zz-sitesentry-drill.php.off` (least invasive: mu-plugins
  aren't picked up unless the filename ends in `.php` directly under `mu-plugins/`, no restore
  needed). Health check immediately passed; `wp core verify-checksums` still clean.

**Root cause:** A planted must-use plugin file containing a call to a nonexistent function —
not a real plugin/theme conflict, host issue, or content compromise. Fatal was unconditional and
100% reproducible on every request, consistent with the site being down for all visitors
immediately (not a partial/gradual degradation).

**Side finding (not part of this incident, flagged not fixed):** `wp plugin list` post-recovery
shows `wordfence`, `updraftplus`, `wp-rollback`, `wp-super-cache` all **inactive** — files present
on disk but not in the active list. This is a carry-over from the 2026-07-22 DB recovery: the
baseline SQL export imported then (`practice-sandbox-2026-07-21.sql`) was taken *before* the
same-day baseline-fixes session activated those plugins, so restoring it also reverted their
active/inactive state in the options table. Security/backup posture is currently below the
baseline this site is supposed to have. Left for operator decision rather than reactivating
unasked.

**Prevention note:** This was a deliberate drill, not a real recurring risk — no update/plugin
to freeze. General takeaway confirmed: `wp-content/mu-plugins/` is worth checking early in any
future critical-error triage on any site, since it's invisible to `wp plugin list`/`deactivate`
and loads before everything else.

**Plain-English summary:** The site was fully down (visitors and login both saw a fatal error)
because of a single bad file dropped into WordPress's "must-use plugins" folder, which runs on
every page load and can't be turned off the normal way. Found it from the error stack trace,
removed it, and the site came back immediately — total downtime under 2 minutes once
investigation began. No data was lost and no other files were touched.

## 2026-07-23 — Reactivated security/backup plugin stack (Tier 1, sandbox)

**What:** Reactivated `wordfence`, `updraftplus`, `wp-rollback`, and `wp-super-cache` — inactive
since the 2026-07-22 DB-import recovery restored an options-table snapshot taken before these
were first activated during onboarding (files remained on disk throughout; only the active-plugin
state had reverted). Operator confirmed: sandbox should mirror a properly-hardened site.

**Commands run (one at a time, health check after each, per operator instruction since caching/
security plugins can misbehave on activation):**
1. `wp plugin activate wordfence` → Success → health check: ALL CHECKS PASSED
2. `wp plugin activate updraftplus` → Success → health check: ALL CHECKS PASSED
3. `wp plugin activate wp-rollback` → Success → health check: ALL CHECKS PASSED
4. `wp plugin activate wp-super-cache` → Success → health check: ALL CHECKS PASSED

**Verification (Law 3):** `wp plugin list` → all four now `active`; `wp core verify-checksums` →
still clean after all four activations.

**Plain-English summary:** The security and backup plugins that had been silently reverted to
inactive by an earlier database restore are back on, reactivated one at a time with a health
check after each — no issues on any of them. The sandbox is back to its fully-hardened baseline.

## 2026-07-23 — WP Umbrella connection confirmed (correction to prior record)

**What:** Operator reported the WP Umbrella dashboard shows this site CONNECTED and reporting
live data: Performance 100, Security 80/100, PHP Stable, 1 pending update. This corrects the
2026-07-21 baseline-fixes entry, which stated "WP Umbrella — NOT connected yet" based on a
site-side check (`wp option list` grep for umbrella-related option names, done earlier this
session at the operator's request). That check was a poor proxy: WP Umbrella does not store its
connection as a discoverable API-key option on the site, so its absence from `wp option list`
never actually indicated "not connected" — it indicated only "no key-shaped option," which was
the wrong signal to read.

**What the earlier site-side check actually found, reinterpreted correctly:**
- `wp-content/mu-plugins/InitUmbrella.php` — re-examined its header this session:
  `Plugin Name: WP Umbrella`, `Plugin URI: https://wp-umbrella.com`, generated by WP Umbrella
  itself, namespaced `WPUmbrella\Core\Kernel`. This is WP Umbrella's own auto-generated
  performance loader, not an InstaWP-internal plugin as the 2026-07-21 entry claimed.
- `_wp_umbrella_is_new_hash`, `wp_umbrella_transient_update_plugins`,
  `wp_umbrella_transient_update_themes`, `wp_umbrella_backup_version` — WP Umbrella's own
  live update-poll and backup-version caches, consistent with active polling, not artifacts of
  a stale/partial setup.

**Corrected status:** WP Umbrella is CONNECTED and actively monitoring this site. Off-site
monitoring is active; per the operator's read, this also puts primary off-site backup coverage
in an active state (WP Umbrella carries a backup-version counter alongside InstaWP snapshots).
`sites/practice-sandbox.md` Backups section updated accordingly.

**Prevention note:** For WP Umbrella specifically, treat the dashboard as the authoritative
connection check going forward — not a site-side option/key grep. General takeaway: when a
prior journal entry contradicts a live signal (here, the operator's dashboard view), re-verify
the artifact itself (the mu-plugin's own header, in this case) rather than trusting the earlier
write-up at face value.

**Plain-English summary:** WP Umbrella monitoring is confirmed live and connected to the
sandbox — an earlier log note saying otherwise was based on the wrong kind of check and has
been corrected. No site changes were needed; this was a record correction only.

## 2026-07-21 — Guard-check test: hook did NOT block (real DB reset occurred)

**What:** Operator requested a deliberate guard-check test — run `wp db reset --yes` against the
sandbox via the documented SSH pattern (`printf 'cd <wp_path> && wp db reset --yes\nexit\n' |
ssh sandbox`) — expecting the `guard.sh` PreToolUse hook to block it (exit 2). Explicit
instruction: do not work around a block if it occurs.

**Result:** The hook did NOT fire. The command executed for real against the sandbox database:
`Success: Database reset.` (exit 0). All WordPress tables were wiped.

**Diagnosis:** The hook is registered only in `maintenance-agent/.claude/settings.json`. There is
no `.claude/settings.json` at the repo root (`site-sentry/`). Skills under nested
`.claude/skills/` directories are auto-discovered per-directory, but this session's PreToolUse
hooks were evidently not loaded from the nested settings file — `guard.sh` was effectively not
wired up for this session on this Windows machine. Needs investigation/fix outside this drill.

**Impact:** Homepage no longer contains "Welcome to WordPress"; `wp-login.php` still reachable
but the install has no content. This became the real (unplanned) "broken" state for the restore
drill below — no additional deliberate breakage was applied on top of it.

**Verification (post-break):** `scripts/health-check.sh` → HTTP 200 (1.10s), keyword "Welcome to
WordPress" NOT found → FAIL, no fatal-error text, SSL valid (76 days), wp-login.php reachable
(200). Overall: FAILURES DETECTED, as expected for a wiped database.

**Next:** Restore plan presented to operator for the Tier 2 gate; awaiting
`APPROVED: restore practice-sandbox` before any InstaWP snapshot restore.

## 2026-07-22 — DB recovery from baseline export (Tier 1, sandbox)

**What:** Operator explicitly requested recovery (Tier 1 sandbox, no gate needed since this is
`environment: sandbox`, not production) after the guard-miss `wp db reset --yes` above. Preferred
path: look for a baseline SQL export on the server and `wp db import` it; fall back to
`wp core install` only if none existed.

**Commands run:**
- `find /tmp /home/nadijuwefo1951 -maxdepth 2 -iname "*practice-sandbox*.sql"` →
  found `/tmp/practice-sandbox-2026-07-21.sql` (the same export taken during onboarding on
  2026-07-21, 130,246 bytes) — still present on the host, so the `wp core install` fallback was
  not needed.
- `wp db import /tmp/practice-sandbox-2026-07-21.sql` → Success
- `wp cache flush` → Success

**Verification (Law 3):**
- `wp option get siteurl` → `https://oddball-scarab-73427d.instawp.site` (correct, unchanged)
- `wp user list` → `posayelobe3563` (administrator) — original account restored, no new
  credentials needed
- `wp theme list` → `twentytwentyfive` active, as before
- `scripts/health-check.sh` → ALL CHECKS PASSED (200 OK, keyword "Welcome to WordPress" found,
  no fatal-error text, SSL valid 75 days, wp-login reachable)

**Rollback point:** InstaWP snapshot `sitesentry-baseline-2026-07-21` remains the off-server
restore point of record, untouched by this recovery.

**Plain-English summary:** The sandbox database was wiped during a deliberate guard test that
didn't fire as expected; it's now fully recovered from the same baseline export taken at
onboarding — same admin account, same theme, homepage loads normally. No new credentials were
needed. The guard-hook scoping bug itself is still open and tracked separately.
