# Service Cadence — what each plan gets, and how often

This is the source of truth that turns the plans sold on the landing page into a delivery
schedule. The `maintenance-cycle` skill and `scripts/roster.sh` both read the rules here.
Every site's `plan:` field (in `sites/<slug>.md`) selects its column.

One agent delivers all three tiers — the tier only changes **frequency, quantity, and
priority**, never the safety discipline. Backups, staging-tested updates, and verification
are identical whether a client pays $129 or $399.

## The matrix

| Service | Essentials ($129) | Peace of Mind ($229) | Total Care ($399+) |
|---|---|---|---|
| Security/software updates | **Monthly** | **Weekly** | **Weekly** |
| Off-site backups | Nightly (WP Umbrella) | Nightly | Nightly |
| Backup verified by agent | Weekly | Weekly | Weekly |
| Restore drill | Monthly | Monthly | Monthly |
| Uptime monitoring | 24/7, 5-min | 24/7, 5-min | 24/7, 5-min |
| Malware / security scan | Monthly | Monthly | Monthly |
| Client content edits | — | ≤ 60 min/mo | ≤ 60 min/mo |
| Broken-link & error check | — | Monthly | Monthly |
| Performance check | — | Monthly | Monthly |
| Development time | — | — | ≤ 2 hr/mo |
| Speed optimization | — | — | Quarterly (measure monthly) |
| E-commerce care (if store) | — | — | Every update cycle |
| Quarterly strategy review | — | — | Quarterly |
| Monthly report | Monthly | Monthly | Monthly + quarterly review |
| Support response (operator SLA) | Standard | Same business day | Same day + 7-day emergency |

## Cadence thresholds (days) — used by roster.sh to compute due/overdue

```
updates:        essentials=30  peace-of-mind=7   total-care=7
backup_verify:  all=7
restore_drill:  all=30
malware_scan:   all=30
link_check:     peace-of-mind=30  total-care=30           # essentials: n/a
perf_check:     peace-of-mind=30  total-care=30           # essentials: n/a
report:         all=30
speed_opt:      total-care=90                              # measured monthly via perf_check
quarterly_review: total-care=90
```

A service is **DUE** at the threshold and **OVERDUE** at 1.5× the threshold (e.g. weekly
updates: due at 7 days, overdue at ~11). Overdue on a production site is a priority signal,
not a routine note.

## Rules the agent must honor

1. **Tier is read from the site file, never assumed.** A site with no `plan:` field is a
   configuration error — stop and ask the operator; do not guess a tier.
2. **Higher tier = superset.** Total Care gets everything Peace of Mind gets, plus its own
   rows. Never give a lower tier weaker *safety* (backups/verification) to cut cost — only
   the frequency/quantity rows in the matrix change.
3. **Budgets are ceilings, tracked per calendar month.** `edit_minutes_used_this_month` and
   `dev_hours_used_this_month` reset on the 1st. At the ceiling, stop and let the operator
   decide (goodwill / roll / quote) — see the `small-edits` skill.
4. **Operator-SLA rows are human promises, not agent actions.** "Same business day" and
   "7-day emergency" describe when *you* reply; the agent triages fast and drafts, but does
   not send client email (Tier 3).
5. **E-commerce forces Total Care.** Any site with WooCommerce (or another store plugin)
   must be `plan: total-care`; run the `ecommerce-care` skill on every update cycle. A store
   found on a lower tier is a pricing/scope flag for the operator.
6. **When cadence and safety conflict, safety wins.** "Updates are due" never overrides "no
   verified backup" or "site is currently down." Fix health first, then service.
