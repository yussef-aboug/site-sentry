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
1. **Deterministic tripwire.** A PreToolUse hook (`.claude/hooks/guard.sh`) physically blocks
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
run `maintenance-cycle` on your own schedule (a weekly calendar reminder, a Windows Task that
opens the session, or a Claude Code Routine), and it tells you what's due and walks you through
it. That keeps the cadence promise without ever removing the human gate on production.

## Setup (one time, ~20 minutes)
1. Install Claude Code (https://code.claude.com/docs) and sign in.
2. From the repo, enter this folder: `cd maintenance-agent` (the shell scripts are committed
   executable; if a checkout dropped the bit, run `chmod +x scripts/*.sh .claude/hooks/*.sh`).
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
