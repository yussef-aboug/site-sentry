# Client Onboarding — operator checklist

The one job of onboarding: by the end, the agent can act on the new client's site **and only
that site**, with zero ambiguity about which site, what plan, and what it's allowed to do.
Work top to bottom. Don't skip ahead — the agent will refuse to service a site until it's
`status: active` with its identity bound.

This is the **human** half (collecting access + setting up accounts). The agent's half is the
`site-onboarding` skill, which you trigger at step 6.

---

## Before you connect anything — collect (from the client)
- [ ] **Business name** → decide the **slug** now: lowercase, hyphenated, unique across
      `sites/` (e.g. "Sunrise Bakery" → `sunrise-bakery`). This name is the site's identity
      everywhere. `ls sites/` to confirm it's not taken; never reuse an offboarded slug.
- [ ] **Canonical URL** — the single address the site lives at (note www vs non-www, http→https).
- [ ] **Plan sold**: essentials | peace-of-mind | total-care. Any WooCommerce/store → **must**
      be total-care (see CADENCE.md). Write down the monthly edit/dev budgets for that tier.
- [ ] **Hosting provider + login owner** (who holds the host account) and their status-page URL.
- [ ] **DNS registrar** (for expiry checks — the agent never changes DNS).
- [ ] **Primary contact** name + email (the agent drafts client emails; you send them).
- [ ] **Maintenance window** — when changes are least disruptive for this business.

## Set up access the secure way (never share the client's personal login)

> **This is the step that stalls onboarding.** A website address alone gives the agent nothing
> but public read access — it cannot log in or change anything. Getting real access differs on
> every host, so the detail lives in **[`ACCESS-PLAYBOOK.md`](ACCESS-PLAYBOOK.md)**: a
> ready-to-send client email, how to identify the host, host-by-host SSH instructions
> (managed WP, cPanel, VPS, Cloudflare), what to do when there is no SSH, and how to test the
> connection yourself before the agent uses it.
- [ ] Client creates a **new dedicated admin account** for SiteSentry in wp-admin (its own
      email, strong password). You never log in as the client.
- [ ] Get **SSH access** from the host and add a **key-based alias** to `~/.ssh/config` named
      exactly the slug:
      ```
      Host <slug>
        HostName <host>
        User <user>
        Port <port>
        IdentityFile ~/.ssh/id_ed25519
      ```
      Then prove it works yourself: `ssh <slug> "wp option get home"` returns the site's URL.
      (No SSH on cheap shared hosting? That client runs in advisory mode — WP Umbrella +
      wp-admin — note it in the site file's Host quirks.)
- [ ] Confirm **no credentials** are going into the repo. SSH uses the key; monitoring API keys
      live in the tools' own dashboards, not in `sites/`.

## Stand up monitoring (so you're never the last to know it's down)
- [ ] **WP Umbrella** — install the plugin + API key, enable daily off-site backups.
- [ ] **UptimeRobot** — 5-minute monitor on the canonical URL → alerts to your email + phone.
- [ ] (Night Watch already covers after-hours diagnosis once the site file exists.)

## Hand off to the agent
- [ ] From `maintenance-agent/`, open Claude Code and say:
      **"Run the site-onboarding skill for the new client `<slug>` at `<url>`, plan `<plan>`."**
      The agent will: create `sites/<slug>.md` (`status: onboarding`) + `logs/<slug>.md`,
      **bind the site's identity** (proves the SSH alias lands on the right box before touching
      anything), take the permanent baseline backup, inventory + checksum the install, install
      the approved plugin stack, run baseline hardening, then flip `status: active` and draft
      the launch report.
- [ ] **Read the launch report** before sending it. You're signing your name to it.
- [ ] Confirm the site now shows correctly in `scripts/roster.sh` — that's your proof it's in
      the cadence and the agent knows it.

## Done means
- [ ] `sites/<slug>.md` complete: `slug`, `status: active`, `url`, `ssh_alias`, `wp_path`,
      identity anchors filled and matching, `plan`, `is_store`, budgets, verification targets.
- [ ] Baseline restore point exists and is recorded. Monitoring is live. First report drafted.

---

## Ongoing roster hygiene (so "which site?" is never a question)
- **One slug, forever.** Don't rename or recycle slugs. If a business rebrands, keep the slug
  and note the new name in the file.
- **Pausing a client:** set `status: paused` → agent goes read-only, site drops out of the
  "what's due" roster. **Leaving:** set `status: offboarded` → the agent will not connect or
  act; remove the `~/.ssh/config` alias and revoke the SiteSentry admin account. Keep the file
  for records.
- Anytime the agent connects and the live site's `home`/`siteurl`/`hostname` don't match the
  recorded anchors, it STOPS and tells you — that's the wrong-site guardrail working. Re-check
  the alias and DNS before overriding it.
