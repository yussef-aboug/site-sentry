---
name: monthly-report
description: >
  Produce the monthly client report for a site — the plain-English summary of everything
  SiteSentry did, caught, and prevented. Use at month end, when the operator says "generate
  reports", or when a client asks "what am I paying for". This report is the #1 retention
  tool; it makes invisible work visible.
---

# Monthly Report Runbook

## Sources (gather, don't invent)
- `logs/<slug>.md` entries for the month (the ground truth — if it isn't in the journal, it
  didn't happen and does NOT go in the report).
- WP Umbrella: uptime %, backup count, updates applied, security scan status (operator
  exports/screenshots; you summarize).
- UptimeRobot: incidents, if any, with durations.

## Structure (one page, client-facing, zero jargon)
1. **Headline health line.** "Your website was online 100% of this month, fully backed up
   every night, and all software is up to date."
2. **What we did** — counts and outcomes, not process: "Applied 9 software updates (6 of them
   security patches) · 30 backups stored safely off your server · 8,640 uptime checks ·
   2 content updates you requested (new menu, holiday hours)."
3. **What we caught** — the money section; always include if anything exists: "One update
   failed our testing and was rolled back before it could affect your site — your visitors
   never saw a problem." Prevention framed as protection, never as drama.
4. **Anything for you** (only if true): domain renewal approaching, recommended improvement,
   scope items awaiting approval. One item max; this is a report, not a sales letter.
5. **Next month:** one line on cadence continuing.

## Language rules
- Translate every term: "plugin" → "software component", "SSL certificate" → "the padlock
  that keeps visitor connections secure", "uptime monitoring" → "we check your site every
  5 minutes."
- Numbers beat adjectives ("8,640 checks" > "constant monitoring").
- Never fabricate or round up. If uptime was 99.7% because of a 2-hour host outage, say so,
  plus what we did about it — trust compounds; getting caught inflating once ends the account.
- No scare tactics in reports; fear belongs on the marketing page, not in a paying
  relationship.

## Output
- Markdown draft → `logs/reports/<slug>-<YYYY-MM>.md` for the operator to convert/brand
  (or paste into WP Umbrella's white-label report as the summary).
- Subject-line suggestion + 2-sentence email body for the operator to send with it.
- Flag in the draft anything that needs operator verification before sending (marked ⚠).
