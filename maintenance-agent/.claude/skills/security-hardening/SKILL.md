---
name: security-hardening
description: >
  Apply the SiteSentry security baseline to a WordPress site, interpret security scan scores,
  and respond to suspected hacks or malware. Use for any task mentioning security, hardening,
  vulnerabilities, malware, "the security score", suspicious files, or a possibly hacked site.
---

# Security Runbook

## The SiteSentry baseline (apply at onboarding; audit quarterly)
Work through this list read-first: check each item, report status, then fix gaps (fixes on
production = Tier 2 gate as usual).
1. **No 'admin' username.** `wp user list --fields=user_login,roles` — an administrator named
   admin/administrator gets replaced: create new admin user (operator supplies password out of
   band), reassign content, delete old.
2. **Core integrity:** `wp core verify-checksums` — must pass clean.
3. **Software currency:** no plugin/theme/core more than one security release behind
   (safe-update skill handles the fixing).
4. **Dead weight removed:** `wp plugin list --status=inactive` and `wp theme list` — inactive
   plugins and unused themes are attack surface with zero benefit. Confirm with operator, then
   delete (keep one default theme as fallback).
5. **File editing disabled:** `wp config set DISALLOW_FILE_EDIT true --raw` — stops a
   compromised admin account from editing PHP in the dashboard.
6. **Login protection:** a rate-limiting/2FA plugin from the approved stack (see
   site-onboarding skill) is active and configured.
7. **SSL:** valid, auto-renewing, and site forces HTTPS.
8. **Backups:** off-site and current (backup-restore skill) — backups are a security control.
9. **Debug off in production:** `wp config get WP_DEBUG` → false; debug.log not web-readable.
10. **Version disclosure:** homepage source shouldn't advertise exact WP version (most security
    plugins in the stack handle this; verify with `curl -s <url> | grep -i generator`).

Log the before/after of every item — this audit IS client-report material ("hardened 6 of 10
baseline items this month").

## Interpreting scan scores (WP Umbrella / security plugin)
Read each finding, classify: (a) fix now under baseline above, (b) fix with operator approval,
(c) accepted risk — note why in `sites/<slug>.md`. Never chase a score for its own sake;
explain findings in plain English for the report.

## Suspected compromise — STOP protocol
Triggers: defacement, spam pages/links, unknown admin users, modified core files
(`wp core verify-checksums` failures), security plugin malware alerts, host abuse notice,
Google "site may be hacked" flag.

**Do NOT attempt cleanup on production. Ever.** Cleanup without expertise destroys evidence,
misses backdoors, and creates false confidence. Instead:
1. Freeze: no updates, no edits, no deletes from this moment.
2. Evidence snapshot: full backup of the compromised state (clearly labeled INFECTED —
   never restore it), plus `wp user list`, checksum output, and any scanner report saved
   to the journal.
3. Contain (with operator approval): change all admin passwords + salts
   (`wp config shuffle-salts`), enable maintenance mode if actively serving malware.
4. Report to operator with the evidence and two client-ready options:
   (a) restore last known-clean backup + immediate hardening, with a stated risk that the
   entry hole may persist until identified; (b) professional incident cleanup (budget
   $300–800 for a specialist service) — recommended for e-commerce or if (a) re-infects.
5. Root cause after recovery: what was outdated? Close it, journal it, add prevention note.
