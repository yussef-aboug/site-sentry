---
name: ecommerce-care
description: >
  Maintain WooCommerce (and other) online stores safely — the Total Care "required for
  online stores" promise. Use for ANY work on a store: updating a site that runs WooCommerce,
  "update the shop", checkout/order problems, the WooCommerce database update, or store
  health checks. Stores have live money and customer data moving through them, so this
  overrides the plain safe-update flow with order-safety guarantees.
---

# E-commerce Care Runbook

A brochure site that breaks for an hour loses some visits. A **store** that breaks for an
hour loses *orders, payments, and trust* — and a botched database step can lose order
records permanently. Everything here exists to make store maintenance boring and reversible.

Non-negotiables for any store:
- **Stores are Total Care.** If a site runs WooCommerce and isn't `plan: total-care`, flag
  it to the operator before servicing (pricing/scope).
- **Payments, tax, shipping, and checkout config are Tier 3** — never change them
  autonomously. You maintain the store's software; you don't reconfigure its commerce rules.
- **The order tables are sacred.** Under HPOS these are `wp_wc_orders` /
  `wp_wc_order_items` (legacy: `wp_posts`/`wp_postmeta` with `shop_order`), plus
  `wp_users`/`wp_usermeta` for customers. Never overwrite, truncate, or "clean" them; never
  push a staging database over live (you'd erase real orders placed since the copy).

## Phase 0 — Store preflight (read-only)
1. Read `sites/<slug>.md`: confirm `total-care`, maintenance_window, staging, fragile_plugins.
2. Identify the stack over SSH (from wp_path):
   ```
   wp plugin list --status=active --fields=name,version | grep -iE 'woocommerce|stripe|paypal|square|subscriptions|bookings|memberships'
   wp wc --info 2>/dev/null; wp wc hpos status 2>/dev/null   # HPOS on? sync pending?
   ```
3. `health-check.sh` on homepage **and** a product page, cart, and checkout. Baseline must
   PASS — a store that's already erroring is `downtime-triage` first.
4. **Confirm store is quiet:** check for in-progress orders / active carts if possible, and
   respect the maintenance_window. Never update mid-sale/peak.

## Phase 1 — Backup, with orders explicitly captured (Law 1, hard requirement)
- Fresh full backup (`backup-restore`) confirmed **today**, off-site. For a store this is
  non-optional and must include the order + customer tables.
- Note the exact restore point. Record current versions of WooCommerce + every payment/
  commerce plugin (your rollback map).
- If HPOS shows orders pending sync, note it — don't start a migration you didn't plan.

## Phase 2 — Maintenance mode, briefly
- Put the store in **"Coming soon"/maintenance mode** for the update window so no customer
  checks out mid-update (a transaction landing during a DB update can be lost). WooCommerce/
  hosts offer this; prefer a store-aware maintenance mode over a blunt one.
- Keep the window as short as possible; schedule in the lowest-traffic hours per the site file.

## Phase 3 — Update, store-aware, one at a time (staging first if it exists)
Order matters even more than usual:
1. **Payment gateways and WooCommerce extensions first is WRONG — do WooCommerce core-plugin
   compatibility carefully:** update **WooCommerce itself** and its extensions as a coordinated
   set, because extensions pin to Woo versions. Check each extension's compatibility with the
   target Woo version *before* updating (changelogs / the site's WooCommerce → Status screen).
2. Update **one plugin at a time**, most-critical last is not the rule here — **update
   WooCommerce, then immediately run the DB update, then test checkout, before touching
   anything else:**
   ```
   wp plugin update woocommerce
   wp wc update          # applies pending WooCommerce database updates (REQUIRED after a Woo update)
   wp wc hpos status     # confirm still healthy / no unexpected sync state
   ```
   Then test checkout end-to-end (Phase 4) before updating the next plugin.
3. Update remaining extensions one at a time, checkout-testing after any that touch cart,
   checkout, payment, tax, or shipping.
4. Themes, then core, last — per `safe-update` ordering — each followed by a checkout test.
5. **Never** batch-update a store to "save time." The whole point is knowing exactly which
   change broke checkout the instant it does.

## Phase 4 — Verify the money path (the test that matters)
After each risky update and before leaving maintenance mode:
- `health-check.sh` on homepage, a product, cart, checkout, my-account.
- **Place a real test order** through to the payment step using the gateway's test/sandbox
  mode (or a 100%-off coupon the operator provides) — add to cart → checkout → order
  confirmation → order appears in admin with correct totals/tax. Refund/cancel the test order.
- Confirm order emails send (to an operator address), and that HPOS order counts are
  unchanged except for your test order.
- Only when the money path is verified do you take the store **out** of maintenance mode.

## Rollback (fastest first)
- A single extension broke checkout: revert just it —
  `wp plugin install <ext> --version=<previous> --force`, `wp wc update` if it touched the DB,
  re-test.
- WooCommerce core update broke it: revert Woo to the recorded version, `wp wc update`,
  re-test; if the DB update already ran and the revert can't reconcile, **restore the Phase 1
  backup** — do not experiment on a live store's order data.
- Keep the store in maintenance mode while rolling back; only lift it after checkout verifies.
- After any rollback: freeze the offending item, log it, tell the operator which update is
  held pending investigation. Never retry the same failed store update in the same session.

## Close-out & edge cases
- Journal: versions old→new for every commerce plugin, DB update run (y/n), test-order result,
  restore point, maintenance-window duration, anything frozen.
- Client line (reassuring, no jargon): "Updated your store's software and ran a full test
  order afterward — checkout, payment, and order emails all confirmed working. Your shop was
  in a brief 'be right back' mode for ~10 minutes during the update."
- **Subscriptions / Bookings / Memberships:** these have their own scheduled actions and data
  — extra caution, test their specific flows, and never update them blind. Recurring-payment
  breakage is severe.
- **Action Scheduler backlog:** a huge `wp action-scheduler` pending queue can indicate a
  stuck store; note it, don't purge it blind.
- **Suspected compromise on a store** (card-skimmer scripts, rogue admin, unknown gateway):
  STOP — `security-hardening` STOP protocol, and treat it as urgent; skimmed stores leak
  customer card data. Do not clean autonomously.
- **PCI/payment scope:** you never store, log, or handle card data or gateway secrets. Gateway
  credentials live in the store's own settings, entered by the operator/client.
