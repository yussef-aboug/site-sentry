---
name: quarterly-review
description: >
  Prepare the Total Care quarterly strategy check-in — the data pack and talking points the
  operator uses for the client call. Use every ~3 months for Total Care sites, when the
  operator says "prep the quarterly review", "get ready for the client strategy call", or a
  quarterly-review is due in the maintenance cycle. Produces the operator's briefing; the
  call itself is human.
---

# Quarterly Strategy Review Runbook

Total Care clients pay for a website that keeps getting *better*, not just maintained. The
quarterly review is where that shows: 90 days of protection made visible, plus a short,
honest recommendation on what the site should do next. This skill assembles the briefing —
the operator runs the actual call and makes the pitch.

This is a synthesis job, not a change job (Tier 0). Invent nothing: every number comes from
the journals, the monthly reports, and the monitoring tools. A fabricated metric in a
strategy review ends a high-value account.

## Phase 1 — Gather the quarter's ground truth
- The last 3 `logs/<slug>.md` months and the 3 `monthly-report` drafts: updates applied,
  issues caught/rolled back, edits and dev hours used, incidents, restore drills.
- Monitoring (operator exports / you summarize): uptime % for the quarter, incident count +
  durations, backup success rate, security scan status.
- **Performance trend:** the last 3 `speed-optimization` MONITOR readings — is TTFB/LCP
  trending up (worse) or down (better)? Run a fresh MONITOR pass so the call has current data.
- **Budget usage:** edit-minutes and dev-hours used vs. allotted each month — under-use and
  over-use are both worth discussing (right-sizing the plan).
- **Growth signals if the client shares them / analytics is accessible:** traffic trend, top
  pages, top entry points, mobile share. Read-only; never guess business numbers.

## Phase 2 — Assess: what's working, what's aging
- **Health scorecard:** uptime, avg load time, security posture, backup/restore-drill status
  — green/yellow/red, with the quarter's trend arrow.
- **What we caught:** the protection story — updates that failed testing and were rolled back,
  attacks blocked, issues fixed before the client noticed. This is the retention core.
- **What's aging:** PHP nearing end-of-life, a plugin abandoned by its author (no update in
  2+ years — verify), a theme going stale, growing autoloaded-options bloat, image weight
  creeping up. Real risks framed as foresight, not alarmism.
- **Budget fit:** are they consistently maxing dev hours (→ maybe a bigger plan or a project)
  or never using them (→ reassure value / redirect the hours to improvements)?

## Phase 3 — Recommend (one page, prioritized, honest)
Draft 2–4 concrete, ranked recommendations for the *next* quarter, each with the why and a
rough effort/cost bucket. Examples: "migrate to PHP 8.x before the host drops 7.x (security +
speed)", "replace the abandoned gallery plugin with a maintained one", "a landing page for
the service you mentioned is trending", "image/caching pass to pull LCP under 2.5s". Mark
which fit inside Total Care dev hours vs. which are separate quoted projects — no surprise
bills, ever.

## Phase 4 — Produce the operator's briefing pack
Output to `logs/reviews/<slug>-<YYYY-Qn>.md`:
1. **One-line health headline** for the quarter.
2. **Scorecard** (the green/yellow/red table with trends).
3. **"What we did & caught"** — counts + the standout saves.
4. **Recommendations** — ranked, with effort/cost and in-plan vs. quoted.
5. **Talking points / suggested agenda** for the 15–20 min call.
6. **⚠ flags** — anything needing the operator's judgment or verification before the call.
Plus a 2-sentence scheduling email the operator can send to book the call.

## Language & edge cases
- Same plain-English rules as `monthly-report`: translate jargon, numbers beat adjectives,
  never inflate. This is a relationship conversation, not a sales ambush — at most lead with
  one growth idea; the review's job is trust first, upsell a distant second.
- **New client (< 1 quarter):** do a "first 90 days" version — onboarding baseline vs. now,
  and set expectations for the cadence ahead; don't force quarter-over-quarter trends you
  don't have yet.
- **Bad quarter (an incident, missed SLA):** address it head-on — what happened, what changed
  so it won't repeat. Owning it rebuilds more trust than burying it.
- **Store clients:** fold in the `ecommerce-care` view — checkout uptime, order-flow health,
  any commerce-plugin risks — since downtime there maps directly to lost revenue.
- The deliverable is a **draft for the operator**, never client-sent email and never a
  committed change. Recommendations are proposals; the operator and client decide.
