---
name: harden-from-report
description: >
  Fix the findings from a health-check scan on a site WE MANAGE. Use when the operator says
  "fix the findings", "harden <slug>", "apply the health check fixes", or after a scan of a
  registered client site. Works one finding at a time with a backup, a verification re-scan,
  and a journal entry. Not for prospect sites - we have no authority to change those.
---

# Harden From Report

Turns scan findings into applied, verified fixes. This is the skill that makes the retainer
visibly worth paying for: the client sees a list of problems and then sees them gone.

## 0. Authority check - who owns this site?
**This skill only ever runs against a site registered in `sites/` with `status: active`.**

A prospect who submitted the health-check form asked us to *look*. They did not ask us to
*change anything*, and we have no access and no permission. If the operator points this skill
at a URL with no site file, STOP and say so — the path from prospect to managed site runs
through `CLIENT-ONBOARDING.md`, not through this skill.

Before touching anything, re-verify identity per `CLAUDE.md`: `wp option get home` / `siteurl`
must match the site file's `url`. Wrong box, no changes.

## 1. Read the findings and sort them
Run (or re-use) the scan for the registered site:
```bash
bash scripts/prospect-scan.sh <url> > /tmp/<slug>-scan.txt
```
Apply the severity rubric from `prospect-health-check` (holes before hardening) and sort every
finding into one of four buckets. **State the buckets to the operator before doing anything.**

| Bucket | Meaning |
|---|---|
| **Fix now** | Real hole, safe reversible fix, we control it |
| **Fix with care** | Needs testing or a client decision first |
| **Not ours** | Host/server level - we can advise, not fix |
| **Already fine / unknown** | No action; unknown is not a finding |

## 2. Law 1 - a verified backup, today, before the first change
No exceptions, even for "just deleting readme.html". Confirm a WP Umbrella backup from today,
or take a fresh snapshot, and record where it lives. Note the restore point in the journal
*before* the first change, not after.

## 3. Apply fixes ONE AT A TIME
Never batch. One change, one verification, one journal line. Batched changes turn a five-second
rollback into a debugging session.

### The mu-plugin (most header/version/xmlrpc fixes)
Copy `scripts/templates/sitesentry-hardening.php` to `wp-content/mu-plugins/`, with only the
flags the scan actually raised set to `true`. Everything else stays `false`.
- Create `wp-content/mu-plugins/` if it doesn't exist.
- **Rollback is deleting that one file** — no database state, no theme edits. Say this to the
  operator when requesting approval; it's what makes the change cheap to approve.
- mu-plugins need no activation and survive theme changes and updates.

### File removals
`readme.html`, `license.txt` — delete after confirming the backup. These are restored by core
updates, so re-check them at the next update run rather than assuming they stay gone.

### Things that are NOT hardening fixes
- **Missing meta description** is a content decision (what should it *say*?). Route to
  `small-edits` with the client's or operator's wording — do not invent marketing copy.
- **Slow load time** goes to `speed-optimization`, not here.

## 4. The HSTS / HTTPS ordering rule (get this backwards and you cause an outage)
If the scan reports both "http:// does not redirect to https" and "missing HSTS":
1. Fix the redirect first (host panel, `wp-config`, or `.htaccess` depending on the stack).
2. Verify: `curl -sSI http://<host>` shows a 301 to `https://`, and the certificate is valid
   with auto-renewal confirmed.
3. Only then enable HSTS at `max-age=300`, verify the site still loads, and raise it later.
Never add `preload` — it is effectively irreversible.

## 5. CSP is staging-only until proven
`SITESENTRY_CSP` ships as **Report-Only** deliberately: it logs violations without blocking, so
a bad policy cannot white-screen the site. Enforcing mode requires a staging pass across every
critical page in the site file — page builders and inline scripts break in ways a homepage
spot-check never reveals. If there is no staging environment, Report-Only is where it stays.

## 6. Verify each fix by RE-SCANNING - and know what cannot clear
After each change: `scripts/health-check.sh <url> <keyword>` (site still healthy), then re-run
the scan and confirm that specific finding is gone.

Expected outcomes — do not chase a finding that cannot clear from WordPress:

| Finding | Clears after fix? |
|---|---|
| WordPress version exposed | Yes |
| `readme.html` readable | Yes |
| Missing X-Content-Type-Options / X-Frame-Options / Referrer-Policy | Yes |
| Missing HSTS | Yes, once enabled (in the right order) |
| **Missing CSP** | **Not in Report-Only mode** — the scan looks for `Content-Security-Policy`, and Report-Only sends a differently-named header on purpose, because it observes without blocking. Only enforcing mode clears it, and that needs a staging pass. A still-open CSP finding alongside an active Report-Only policy is the correct, expected state. |
| **`xmlrpc.php` open** | **Usually NOT** — the filter disables the methods but the file still answers. A full block is a server rule. Record it as mitigated-not-eliminated. |
| `Server:` advertises host software | **Never** — that header is the host's |

If a fix doesn't clear and the table says it should, **revert it** rather than leaving a change
whose effect you can't demonstrate.

## 7. Log it, then report in plain English
Journal entry per fix: what, why, exact command, verification result, and the rollback step
(usually "delete `wp-content/mu-plugins/sitesentry-hardening.php`"). Update
`last_security_scan` in the site file.

Then write the client-facing line for the monthly report — what changed and what it means for
them, not the header name: *"We stopped your site from announcing which version of WordPress it
runs, which is the first thing an attacker checks."*

## Guardrails
- Every change here is Tier 2: fresh backup + staging pass or `APPROVED:` + verification.
- Two consecutive failed attempts at the same fix = stop and escalate (`CLAUDE.md`).
- If a fix breaks anything, roll back FIRST, diagnose second. The client's uptime outranks
  the finding.
- Never disable XML-RPC without asking — it breaks the WordPress mobile app, Jetpack, and some
  backup plugins. That's a client question, not a technical one.
