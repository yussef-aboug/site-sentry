---
name: backup-restore
description: >
  Take, verify, and restore WordPress backups, and run the monthly restore drill. Use this
  skill whenever a task involves backups, restores, snapshots, "make sure we can recover",
  disaster recovery, or before/after risky changes. A backup that has never been restored is
  treated as nonexistent.
---

# Backup & Restore Runbook

Two rules govern everything here: backups live **off the site's own server** (a backup on a
hacked or dead server is not a backup), and a backup only counts once a **restore of it has
succeeded somewhere**. That's why the monthly drill exists.

## Taking a backup (manual, e.g. pre-change)
A complete backup = database + files (at minimum `wp-content/`, which holds uploads, themes,
plugins; ideally also `wp-config.php` and `.htaccess`).
```
ssh <alias> "cd <wp_path> && wp db export /tmp/<slug>-$(date +%F).sql"
ssh <alias> "cd <wp_path> && tar -czf /tmp/<slug>-files-$(date +%F).tar.gz wp-content wp-config.php .htaccess 2>/dev/null"
scp <alias>:/tmp/<slug>-*.tar.gz <alias>:/tmp/<slug>-*.sql ./backups-local/   # pull OFF the server
ssh <alias> "rm /tmp/<slug>-*"                                                # no backups left on host
```
On InstaWP sites, snapshots substitute: `instawp versions create <site>`.
Verify integrity before trusting: `.sql` ends with a dump-completed marker and is non-trivial
in size; `tar -tzf` lists without errors. Log location + sizes in the journal.

## Verifying scheduled backups (part of weekly routine)
- WP Umbrella dashboard shows a backup within the last 24–48h for every production site
  (operator confirms visually; you record the answer).
- Secondary backup (UpdraftPlus → cloud storage, or host snapshots) also current.
- Any site with NO backup in 48h = raise to operator same day. This is a red-alert condition,
  not a note for the monthly report.

## Restoring
Restore = the moment of maximum danger. On production, restoring is a **Tier 2 gate**:
present what will be restored, from when, and what content created since then will be lost
(orders! form entries!) — wait for `APPROVED: restore <slug>`.
1. Take a snapshot of the CURRENT broken state first (evidence + undo-the-undo).
2. Database: `wp db import <file>.sql`
3. Files: extract the tar over `wp-content` (or restore via the backup tool / host panel /
   `instawp versions restore` — prefer the managed tool's own restore when it exists).
4. `wp cache flush`, then full health check on all critical pages + wp-admin login page.
5. Journal the restore point used and verify the client knows about any content gap.

## Monthly restore drill (per site)
1. Spin a disposable InstaWP sandbox.
2. Restore the site's most recent real backup into it (db import + files, fix URLs:
   `wp search-replace 'https://<real-domain>' 'https://<sandbox-domain>' --all-tables`).
3. Health check + click the critical pages.
4. Success → update `last_restore_drill:` in `sites/<slug>.md`, delete the sandbox.
   Failure → red alert to operator: the client's safety net has a hole in it. Fixing this
   outranks all routine work.
