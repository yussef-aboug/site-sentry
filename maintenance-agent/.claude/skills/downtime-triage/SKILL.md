---
name: downtime-triage
description: >
  Diagnose and recover a website that is down, erroring, white-screened, slow, or "broken".
  Use this skill whenever a site is reported down or unhealthy, a monitor alert fires, a
  health check fails, or the operator says anything like "the site is down", "client says
  their website is broken", or "investigate this outage". Diagnose outside-in; recover with
  the least invasive move that works.
---

# Downtime Triage Runbook

Goal order: (1) get the site back up, (2) then find root cause. A site restored from backup
while you investigate beats a site down while you theorize. Record every finding in the
journal as you go — timestamps matter for the client-facing incident summary.

## Step 1 — Confirm it's real (60 seconds)
- `scripts/health-check.sh <url> "<homepage_keyword>"`
- `curl -sI -L --max-time 20 <url>` from here, and check the uptime monitor's status.
- Up from here + monitor green → likely the reporter's device/network/cache. Draft a polite
  "try incognito / other network" reply for the operator. Done.

## Step 2 — Address layer (DNS/domain)
- `dig +short <domain>` and `dig +short NS <domain>` — no A/AAAA answer, or nameservers
  changed to parking → domain/DNS problem.
- `whois <domain> | grep -iE 'expir|status'` — expired or clientHold → the domain lapsed.
- Fix is Tier 3 (operator/client renews at registrar). Report findings + exact renewal
  instructions for the client. Do NOT touch DNS yourself.

## Step 3 — Building layer (hosting)
- Connection refused / timeout on all requests, SSH also unreachable → hosting-level.
- Check the host's status page (linked in `sites/<slug>.md`). Known outage → draft client
  holding message for operator; monitor until restored; no further action.
- No known outage → likely suspended account (billing) or server crash → operator contacts
  host support. Provide them the evidence you gathered.

## Step 4 — Application layer (read the error)
Fetch the body: `curl -s -L <url> | head -100`, and check HTTP code:
- **"critical error" / white screen / 500** → PHP fatal, ~90% a plugin or theme. Go to Step 5.
- **"Error establishing a database connection"** → try `ssh <alias> "cd <wp_path> && wp db check"`.
  DB server down or credentials broken → usually host support; report, don't guess at
  credentials.
- **403** → security rule/firewall misfire; check any security plugin's log; report before
  changing rules.
- **SSL errors** → health check shows expiry; certificate renewal is usually one click in
  hosting (operator) — provide exact instructions.
- **Site up but defaced/spammy content** → possible compromise: STOP. Security-hardening
  skill, "suspected compromise" section. Do not clean autonomously.

## Step 5 — Recovering a fatal error (least invasive first)
Golden question first: **what changed last?** Check `logs/<slug>.md` and WP Umbrella update
history. The most recent change is the prime suspect.
1. Read the actual error: `ssh <alias> "tail -50 <wp_path>/wp-content/debug.log"` (if present)
   or the host's PHP error log. The stack trace usually names the guilty plugin/theme file.
2. WP-CLI may still work when the site doesn't:
   `wp plugin deactivate <suspect> --skip-plugins --skip-themes`
3. WP-CLI dead too → rename the suspect's folder over SSH:
   `mv wp-content/plugins/<suspect> wp-content/plugins/<suspect>.off` → health check.
4. Unknown suspect → rename the whole `plugins` folder; site returns = it was a plugin;
   restore the folder name and disable one-by-one to isolate. Same trick for the theme
   (WordPress falls back to a default theme — ugly but UP).
5. Nothing works within ~20 minutes on a production site → **restore last night's backup**
   (backup-restore skill). Up first, root-cause after.

## Step 6 — Close out
- Journal: timeline (detected → identified → restored), root cause, fix, prevention note.
- Draft the client incident summary in plain English (what happened, how long, what we did,
  what prevents a repeat). Operator sends it.
- If root cause was an update, freeze that item and note it in `sites/<slug>.md`.
