---
name: small-edits
description: >
  Make client-requested content changes: text edits, image swaps, hours/menu/price updates,
  small layout tweaks. Use whenever the operator relays a client change request like "update
  their hours", "swap the header photo", "change the pricing on the services page". Enforces
  the care-plan scope so free edits don't become free development.
---

# Small Edits Runbook

## 0. Scope gate (protects the business model)
Check `sites/<slug>.md`: plan + `monthly_edit_budget_minutes` + minutes already logged this
month in the journal.
- Fits the "edit" definition (text, images, hours, prices, minor tweaks; ≤30 min per request)
  and budget remains → proceed.
- New pages, new features, redesigns, anything structural → NOT an edit. Draft a friendly
  scope note for the operator: what it is, rough hours, suggested quote. Do not build it.
- Budget exhausted → tell operator; they decide (goodwill freebie vs. next month vs. quote).
Log actual minutes spent on every edit — this data prices future plans.

## 1. Locate precisely
Find the exact page/post: `wp post list --post_type=page --fields=ID,post_title,post_name`.
Ambiguity about which text/image the client means → ask via operator; never guess on a
client's live wording.

## 2. Safety by risk level
- Plain text/image swap on a normal page: proceed on production (Tier 2 rules still apply:
  today's backup verified; edits are pre-approved as a category once the operator relays a
  client request — record who asked for what in the journal).
- Anything touching templates, page-builder structures, CSS/PHP, menus/navigation, or the
  homepage hero: do it on staging first, or snapshot + operator heads-up if no staging.
- Never edit theme/plugin PHP files directly on production (guard blocks most paths anyway);
  custom code lives in a child theme or snippet plugin, and that's a quoted job, not an edit.

## 3. Execute
- Text (simple): `wp post update <ID> --post_content="..."` for basic content; for page-builder
  pages, edit via wp-admin (operator's SiteSentry account) rather than raw content fields —
  builder data is fragile JSON/shortcodes; corrupting it is a rebuild.
- Images: upload via `wp media import <file-or-url> --post_id=<ID>` then attach/replace;
  compress first if >500KB.
- Hours/prices: search all occurrences (`wp db search "<old text>" --all-tables` read-only)
  so a price change doesn't miss the footer/FAQ copy of the same number.

## 4. Verify + close
- View the changed page (curl for presence of new text, absence of old), health check,
  cache flush if a caching layer exists (client will otherwise "still see the old version" —
  mention cache in the confirmation note).
- Journal: request origin, exact change, minutes spent, running monthly total.
- One-liner for operator to send: "Done — your Tuesday hours now show 9–5 everywhere on the
  site. May take a few minutes to appear if your browser cached the old page."
