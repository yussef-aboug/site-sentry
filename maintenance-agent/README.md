# SiteSentry Maintenance Agent

A Claude Code agent pack that runs WordPress care-plan operations — updates, downtime triage,
backups/restores, security baseline, client edits, monthly reports — with deterministic
guardrails and human approval gates on production.

> Part of the [SiteSentry](../README.md) repo. This `maintenance-agent/` folder is a
> self-contained Claude Code project: `cd` into it and run `claude` from here so its
> `.claude/` hooks and skills load. The marketing landing page lives at the repo root and is
> independent of this pack.

## What makes it "reliable"
Reliability here is architecture, not hope:
1. **Deterministic tripwire.** A PreToolUse hook (`.claude/hooks/guard.cjs`, Node — runs on
   Windows/macOS/Linux alike; a bash hook silently no-ops on Windows) physically blocks
   catastrophic commands (database drops, recursive deletes, etc.) before they execute — this
   works even if the model is confused or a malicious webpage tries to inject instructions.
   Instructions alone can fail under pressure; hooks don't.
2. **Three Laws in CLAUDE.md** (always loaded): verified backup before any change; staging or
   explicit approval before production; verification + logging after everything.
3. **Runbooks as skills.** Each procedure is a step-ordered skill the agent must follow
   exactly — the same discipline that separates professional maintenance shops from
   "I clicked update and prayed."
4. **Registry + journal.** The agent can only touch sites registered in `sites/`, and every
   action leaves an audit trail in `logs/` that becomes your client reports.
5. **You are the gate.** Production changes wait for your `APPROVED: <task>` message.
   The agent drafts client emails; only you send them.

## Plans, cadence & the skill library

One agent delivers all three landing-page plans — the tier only changes frequency, quantity,
and priority, never the safety discipline. `CADENCE.md` is the source of truth for what each
tier gets and how often; each site's `plan:` field selects its column.

- **`scripts/roster.sh`** — read-only "what's due across all clients" dashboard (per-tier
  cadence vs. each site's `## Service tracking` dates).
- **`maintenance-cycle`** skill — the batch orchestrator: reads the roster, then works each
  due site one at a time through the right per-tier skills, with all gates intact. This is
  what makes the plans deliverable across a whole roster ("run this week's maintenance").

Skills, by what they deliver:

| Skill | Delivers | Tiers |
|---|---|---|
| `prospect-health-check` | Free audit for a LEAD (pre-sale), report + plan rec | sales |
| `site-onboarding` | Take a new site into care | all |
| `safe-update` | Security/software updates (non-stores) | all (monthly/weekly by tier) |
| `backup-restore` | Backups, restores, monthly drill | all |
| `security-hardening` | Security baseline, malware/compromise response | all |
| `downtime-triage` | Recover a down/broken site | all |
| `monthly-report` | The plain-English client report | all |
| `small-edits` | Client content edits within the monthly budget | peace-of-mind, total-care |
| `link-error-check` | Broken-link & error scan | peace-of-mind, total-care |
| `speed-optimization` | Performance monitor (all incl.) + optimize (total-care) | peace-of-mind, total-care |
| `ecommerce-care` | WooCommerce/store maintenance, order-safe | total-care (stores) |
| `quarterly-review` | Quarterly strategy briefing pack | total-care |
| `maintenance-cycle` | Batch-service the whole roster on schedule | operator-driven |

**Scheduling note:** the cycle is *operator-triggered* by design — production changes need
your approval (Law 2), so nothing auto-updates a live site unattended. To put it on a rhythm,
run `maintenance-cycle` on your own schedule, and it tells you what's due and walks you through
it. That keeps the cadence promise without ever removing the human gate on production.

**Automating the weekly nudge (Windows).** `scripts/weekly-check.ps1` runs the roster
read-only, drops a `SiteSentry-whats-due.txt` on your Desktop, and pops a reminder — it makes
no changes. Register it as a weekly scheduled task once:

```powershell
# from maintenance-agent/
powershell -ExecutionPolicy Bypass -File .\scripts\register-weekly-check.ps1
# test it immediately:
powershell -ExecutionPolicy Bypass -File .\scripts\weekly-check.ps1
# change the day/time, or remove it:
powershell -ExecutionPolicy Bypass -File .\scripts\register-weekly-check.ps1 -Day Tuesday -At 8:00AM
powershell -ExecutionPolicy Bypass -File .\scripts\register-weekly-check.ps1 -Unregister
```

So detection is automatic (this nudge + WP Umbrella's 24/7 alerts); the *safe application* of
updates stays a human-approved `maintenance-cycle` run. Requires Git for Windows (for the
bash the roster runs in).

**Night Watch — after-hours outage diagnose + alert (Phase 1).** `scripts/night-watch.sh`
polls registered sites; during the after-hours window (`CADENCE.md` / `night-watch.local.conf`)
a confirmed outage triggers a **read-only** diagnosis (cause + recommended fix, classified
auto-fixable-later vs needs-human) and a push alert — it makes **no changes**. Set up:

```powershell
# 1. configure your alert channel (git-ignored; keep the topic private):
copy scripts\night-watch.conf.example scripts\night-watch.local.conf   # then edit the ntfy topic
# subscribe to that same topic in the free ntfy app on your phone
# 2. test it now (ignores the time window):
powershell -ExecutionPolicy Bypass -File .\scripts\night-watch.ps1 -Force
# 3. schedule it every 5 min, 24/7 (acts only during the window):
powershell -ExecutionPolicy Bypass -File .\scripts\register-night-watch.ps1
```

Prerequisites: the guard hook verified working (the only backstop when no human is watching —
done), and a 24/7 runner (your PC awake overnight, or a cloud runner). It complements
UptimeRobot/WP Umbrella's "it's down" alerts by adding the *diagnosis*. Bounded auto-*fix* is a
deliberate later phase, not enabled here.

## Turning a landing-page lead into a client
Every CTA on the landing page funnels into one form: the **free site health check**. When a
submission arrives, run the `prospect-health-check` skill (or `scripts/prospect-scan.sh <url>`
directly) — a **passive, read-only** public audit of the prospect's site: uptime, speed, SSL,
exposed files, missing security headers, visible plugins, mobile/SEO basics. It produces
findings the agent turns into a plain-English client report plus a plan recommendation.

The scan **fails closed**: if it can't reach the site it aborts with exit 2 and performs no
checks, rather than reporting reassuring passes it never verified. `Could not check …` means
unknown, never "fine". It only ever runs against a site whose owner asked us to look, and never
logs in, POSTs, or probes for vulnerabilities.

> **Writing new `.ps1` files: keep them pure ASCII.** Windows PowerShell reads scripts as
> ANSI unless they carry a UTF-8 BOM, so a UTF-8 em-dash or curly quote arrives as mojibake
> (`—` becomes `â€"`) and breaks parsing with a confusing "Unexpected token" error. Use `-`
> and `'` in scripts; save the typography for the HTML.

**On Windows, run it from PowerShell** — PowerShell has no `bash`, so use the wrapper (it
finds Git Bash for you, and can build the report in the same command):

```powershell
# from maintenance-agent/
powershell -ExecutionPolicy Bypass -File .\scripts\prospect-check.ps1 -Site example.com
# scan + build the client report in one go:
.\scripts\prospect-check.ps1 -Site example.com -Report -Business 'Sunrise Bakery' -Name 'Sarah' `
    -Plan 'Peace of Mind - $229/mo' -Why '...' -Concern 'it went down last month'
# Use SINGLE quotes for anything containing $ — in double quotes PowerShell expands
# $229 as a variable and the price silently vanishes.
```

`scripts/make-report.mjs` then turns those findings into a **client-ready HTML report** —
branded, printable to PDF, self-contained. It refuses to build from an aborted scan for the
same reason the scanner refuses to report one. Generated reports land in `reports/`
(git-ignored — they contain prospect details).

**Nothing reaches a prospect without you.** The skill stops at an approval gate: it shows you
the counts, every urgent finding, the recommendation, the report path, and the drafted email,
then waits for `APPROVED: send <slug>`. Even then you do the sending — the agent never emails
clients (Tier 3).

Flow: form submission → `prospect-health-check` → scan → report → **your approval** →
you send → they say yes → `CLIENT-ONBOARDING.md` → `site-onboarding`.

## Onboarding a new client
When you sign a client, follow **`CLIENT-ONBOARDING.md`** — the operator checklist that takes
you from "signed" to "the agent is servicing the right site." It collects access securely
(dedicated admin account + key-based SSH alias named for the slug), stands up monitoring, then
hands off to the agent's `site-onboarding` skill, which **binds the site's identity** (proves
the SSH alias lands on the correct box before touching anything) and only flips the site to
`status: active` once it's fully set up. The registry's `status` + identity anchors are what
guarantee the agent never acts on the wrong — or a half-configured — site.

## Setup (one time, ~20 minutes)
1. Install Claude Code (https://code.claude.com/docs) and sign in.
2. Open the repo in Claude Code and run agent tasks from `maintenance-agent/`. The guard hook
   is registered at the **repo root** (`site-sentry/.claude/settings.json`, pointing at
   `node maintenance-agent/.claude/hooks/guard.cjs`) — Claude Code loads hook config from the
   PROJECT ROOT, so a subfolder-only `settings.json` silently does not register (skills
   auto-discover from subfolders, hooks do not). Root registration means the guard loads
   whether you open `site-sentry` or `maintenance-agent`. It runs via `node` (no bash, no
   executable bit) so it fires on Windows too. `scripts/*.sh` helpers are committed executable;
   if a checkout dropped the bit, run `chmod +x scripts/*.sh`.
3. SSH: add each site as a key-authenticated alias in `~/.ssh/config`, e.g.
   ```
   Host sandbox
     HostName <from InstaWP dashboard>
     User <from InstaWP dashboard>
     Port <from InstaWP dashboard>
     IdentityFile ~/.ssh/id_ed25519
   ```
   Test `ssh sandbox "wp core version"` yourself before letting the agent use it.
4. Optional but recommended for InstaWP work: `npm i -g @instawp/cli && instawp login`
   (gives the agent one-command snapshots: `instawp versions create`).
5. Open `sites/practice-sandbox.md` and fill in the bracketed fields.
6. Start: `claude` (from this folder). First prompt to try:
   *"Run the site-onboarding skill against the practice sandbox."*

## Operating rules for YOU (the operator)
- **Never run this with permission prompts bypassed** (no `--dangerously-skip-permissions`,
  no auto-accept modes) when any production site is registered. The prompts ARE the product.
- Review the journal entry after every session; you're signing your name to this work.
- When the agent asks for `APPROVED:`, actually read what you're approving.
- Rotate through the monthly restore drill — one client site per week keeps it painless.

## Training path (before the first paying client)
Graduate each stage on the sandbox before advancing:
1. Onboarding skill end-to-end → registry + journal look right.
2. Safe-update skill with a few deliberately old plugins installed.
3. Break/fix: sabotage the site (lesson-3 style), run downtime-triage, confirm the agent
   walks the ladder instead of flailing.
4. Backup-restore drill: snapshot → destroy something → restore → verify.
5. Full month simulation: two edits, one update run, one report. Read the report as a client.
When all five feel boring, you're ready for client #1 — boring is the goal.

## Honest limits (read once, remember forever)
- The agent reduces errors; it cannot eliminate them. The Three Laws exist so that when
  something does break, recovery is minutes (restore point) instead of a crisis.
- WP-CLI availability varies by host. Cheap shared hosting sometimes lacks SSH entirely —
  those clients get managed via WP Umbrella + wp-admin, with the agent in advisory mode.
- Malware cleanup, DNS, and payments are deliberately out of scope (Tier 3). Don't "just
  this once" them.
- Page-builder sites (Elementor/Divi) hold fragile data structures: edits there go through
  wp-admin by a human, not raw CLI content updates. The small-edits skill enforces this.
