---
name: maintenance-cycle
description: >
  Run a scheduled maintenance cycle across ALL registered client sites — the batch
  orchestrator that delivers the plan cadence (weekly/monthly updates, checks, reports).
  Use whenever the operator says "run this week's maintenance", "run the monthly cycle",
  "what's due", "service all clients", or kicks off routine upkeep across the roster.
  Reads CADENCE.md + roster.sh, then works each due site one at a time through the right
  per-tier skills, with all safety gates intact.
---

# Maintenance Cycle Runbook

This is how one agent services a whole roster on schedule. It does not replace the
per-task skills — it **sequences** them. Each site is still handled by `safe-update`,
`backup-restore`, etc., with every Law and gate those skills enforce. The cycle's job is
ordering, tier-correct scope, and a clean summary.

Golden rule: **one site fully finished (and logged) before the next begins.** Never
parallelize changes across production sites — a batch that half-breaks five stores at once
is the nightmare this whole system exists to prevent.

## Phase 0 — Scope the cycle (read-only)
1. Confirm what the operator wants: a **weekly** cycle (Peace of Mind + Total Care updates),
   a **monthly** cycle (adds Essentials updates, reports, restore drills), or "what's due".
2. `scripts/roster.sh` — the due/overdue dashboard across all sites. This is your worklist.
3. Cross-check each candidate site's `plan:` against `CADENCE.md` to know exactly which
   services that tier is owed this cycle. A site missing a `plan:` field → stop, ask.
4. Build the plan: for each due site, list {site, tier, services due, risk notes
   (fragile_plugins, WooCommerce, major-version jumps, staging yes/no)}.

## Phase 1 — Present the batch plan and get the gate (Law 2)
- Show the operator the full plan before touching anything: which sites, which services,
  and — called out separately — every **high-risk** item (production sites without staging,
  fragile_plugins, major/core version jumps, any WooCommerce store, any site currently
  OVERDUE or flagged unhealthy).
- The operator approves the cycle with `APPROVED: cycle <weekly|monthly> <date>`.
- **Scope of that approval:** it covers *routine, low-risk* work (minor/patch updates on
  sites that passed staging or are sandbox/staging; backup verification; read-only checks;
  report drafting). It does **NOT** blanket-approve high-risk items — each of those still
  needs its own `APPROVED: <task> <slug>` at the moment it comes up. When in doubt, treat it
  as high-risk and pause.

## Phase 2 — Pre-flight the whole roster (read-only, fast)
Before servicing anyone, sweep all in-scope sites:
- `scripts/health-check.sh <url> "<homepage_keyword>"` on each. Any site that FAILS baseline
  is **down/unhealthy** → pull it OUT of the routine cycle and run `downtime-triage` on it
  first (or escalate). Never run updates on a site that is already broken.
- Confirm each site has a backup within its `backup_verify` window (WP Umbrella dashboard /
  `backup-restore` verify step). Any site with NO current backup = red alert, skip its
  changes, tell the operator same-day.
Produce a short pre-flight verdict per site: HEALTHY-PROCEED / DOWN-TRIAGE / NO-BACKUP-HOLD.

## Phase 3 — Service each HEALTHY-PROCEED site, one at a time
For each site, in ascending risk order (sandbox/staging first, simplest production next,
stores last), run exactly the services its tier owes this cycle:

1. **Snapshot/verify backup** (`backup-restore`) — the rollback point for this site's work.
2. **Updates** (`safe-update`) at the tier cadence. If the site is a store, updates run
   **inside** the `ecommerce-care` procedure (maintenance window, order-safety, `wp wc
   update`), not bare `safe-update`.
3. **Peace of Mind + Total Care also:** `link-error-check`, then `speed-optimization` in
   monitor mode (measure; only *optimize* on Total Care when a metric is out of target or a
   quarterly speed pass is due).
4. **Total Care stores:** `ecommerce-care` order-flow verification after updates.
5. **Verify** (`health-check.sh` + the skill's own checks) and **log** every action in
   `logs/<slug>.md`. Update the site file's `## Service tracking` dates for what you did.
6. **On ANY failure or anomaly on a site:** stop work on that site, roll back per the
   relevant skill, log it, mark the site **NEEDS-ATTENTION**, and MOVE ON to the next site.
   Do not let one broken site stall the whole roster, and never retry the same failed change
   twice in one cycle.

## Phase 4 — Reports and close-out
- For every site whose monthly `report` is due, run `monthly-report` (draft only; operator
  sends). Total Care sites due a quarterly review also get `quarterly-review`.
- Refresh each serviced site's `## Service tracking` dates so the next `roster.sh` is
  accurate. Reset monthly budget counters if a new month started.
- **Cycle summary for the operator** — a single digest table:
  `site | tier | services done | rolled back | NEEDS-ATTENTION | report drafted`.
  Lead with anything that needs a human: NEEDS-ATTENTION sites, NO-BACKUP holds, DOWN sites,
  budget-exhausted edit requests, and stores/updates awaiting per-site approval.

## Edge cases & stop conditions
- **Nothing due:** report "roster current, nothing due" and stop — an empty cycle is a
  success, not a reason to invent work.
- **A site has no staging and a major/core/WooCommerce update is due:** do not push it in the
  routine cycle; surface it in the summary for a dedicated, individually-approved session.
- **Two consecutive sites fail the same way** (e.g. same plugin update breaks both): stop the
  cycle, escalate — that's a pattern (bad release) the operator should see before you continue.
- **Suspected compromise on any site:** STOP that site immediately, `security-hardening`
  STOP protocol, do not "finish the cycle first."
- **Cycle interrupted / resumed:** the journals + `## Service tracking` dates are the source
  of truth for what's already done — re-run `roster.sh` and continue where it left off; never
  redo a change already logged for this cycle.

## Definition of done
Cycle complete = every in-scope site is either serviced-and-logged, or explicitly parked
(DOWN-TRIAGE / NO-BACKUP-HOLD / NEEDS-ATTENTION / awaiting-approval) with a reason, AND the
operator has the one-page cycle summary. No site is left in an unknown state.
