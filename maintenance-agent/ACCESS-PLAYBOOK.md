# Getting Access — the practical playbook

`CLIENT-ONBOARDING.md` says "get SSH access." That one line is the hardest part of onboarding
and it works differently on every host. This is the detail behind it.

---

## First, the thing to be clear about

**A website address gives the agent nothing but public access.** With a URL it can run the
free health check — reading pages exactly as a visitor does. It cannot log in, read files, see
the database, install anything, or fix anything.

That's not a limitation to engineer around; it's how the web works, and it's the reason the
free audit is safe to run on strangers.

To actually service a site you need three things, and **only the client can start the process
for all three**:

| # | What | Who provides it | Used for |
|---|---|---|---|
| 1 | A **WordPress admin account** for SiteSentry | Client creates it in wp-admin | wp-admin work, plugin config, WP Umbrella |
| 2 | **SSH access + your public key installed** | The host, authorised by the client | WP-CLI: updates, backups, fixes, everything fast |
| 3 | **Hosting dashboard access** (or a responsive client who has it) | Client | Snapshots, PHP version, server-level rules |

You can deliver a reduced service with only #1 (see *Advisory mode* below). #2 is what makes
the agent genuinely useful.

---

## Step 1 — Send the client this email

This is the actual unlock. Most onboarding stalls here for days because the client doesn't know
what's being asked. Be specific and make it feel small.

> **Subject:** Getting started — two quick things I need
>
> Hi [Name],
>
> Great to have you on board. To start looking after [site], I need two things — both take
> about five minutes.
>
> **1. An admin account for me on your website**
> Please don't share your own login. Instead: log in to [site]/wp-admin → **Users → Add New**
> → username `sitesentry`, email `[your email]`, role **Administrator**, and tick "Send the new
> user an email". I'll set my own password from that email.
>
> **2. Access to your hosting account**
> This is where the website actually lives — separate from the website itself. It's usually
> whoever you pay for hosting (GoDaddy, Bluehost, SiteGround, WP Engine, etc.).
>
> Whichever is easiest for you:
> - Add me as a user on the hosting account (most hosts allow this), **or**
> - Send me the hosting provider's name and I'll tell you exactly which setting to switch on
>   and send you a key to paste in, **or**
> - If you're not sure who hosts it, tell me and I'll find out from the website itself.
>
> If someone else built or manages the site, feel free to forward this to them.
>
> Thanks,
> [You]

**Why it's worded that way:** it never asks for their password, it gives them three ways to
say yes, and it pre-empts "I don't know who hosts it" — the single most common reply.

---

## Step 2 — Find out who the host is (you can usually do this yourself)

If they don't know:
```bash
# who owns the IP / who serves it
curl -sSI https://theirsite.com | grep -iE '^(server|x-powered-by|x-served-by|cf-ray)'
# the scan reports this too, under "Web server:"
bash scripts/prospect-scan.sh theirsite.com | grep -i 'web server'
```
`cf-ray` means Cloudflare sits in front — the real host is behind it. Nameservers usually give
it away; a WHOIS lookup on the domain shows the registrar (often, but not always, the host).

---

## Step 3 — Get SSH switched on, by host type

You need two things: **SSH enabled** on the account, and **your public key installed**.

Your public key is the safe half of your key pair — it is designed to be shared. Print it with:
```bash
cat ~/.ssh/id_ed25519.pub
```
Send that whole line. **Never send the file without `.pub`** — that one is the private key and
must never leave your machine.

### Managed WordPress hosts (Kinsta, WP Engine, Flywheel, Pressable, Rocket.net)
The easiest case. SSH is standard and there's a UI for keys.
- Kinsta: MyKinsta → site → **Info** shows SSH details; keys under **User settings → SSH keys**
- WP Engine: portal → **SSH keys** on the account, then site → **SFTP/SSH users**
- Usually the client must add *you* as a user on the account first, then you add your own key.
- These hosts often already have WP-CLI installed and working. Best case.

### cPanel shared hosting (Bluehost, HostGator, SiteGround, Namecheap, A2)
- cPanel → **SSH Access** → **Manage SSH Keys** → *Import Key* → paste your public key →
  then **Authorize** it (importing alone does nothing — the authorize step is the one people
  miss).
- Some budget hosts require you to open a support ticket to enable SSH on the plan.
- Port is often non-standard (2222, 2083). cPanel shows it.
- WP-CLI is sometimes present as `wp`, sometimes needs a full path, sometimes absent.

### VPS / dedicated (DigitalOcean, Linode, Hetzner, AWS)
- You (or their developer) append your public key to `~/.ssh/authorized_keys` for the site's
  user — **append, never overwrite**, or you lock out whoever is already there.
- Confirm you're using the *site's* user, not root. Files created as root break WordPress.

### Site behind Cloudflare
Cloudflare proxies HTTP; SSH goes to the origin server directly. You need the origin host's
details, which the client's hosting account has.

### No SSH available at all (cheapest shared plans)
Some hosts genuinely don't offer it. This is **advisory mode**:
- WP Umbrella (backups, updates, monitoring) + wp-admin for changes
- The agent advises, drafts, and reviews; a human clicks
- Record `quirks: no SSH - advisory mode` in the site file
- Price accordingly, or make moving hosts part of the deal. Be honest with them that the
  cheap plan is what's limiting the service.

---

## Step 4 — Add the alias and test it YOURSELF

Add to `~/.ssh/config` (Windows: `C:\Users\<you>\.ssh\config`), named exactly the client's slug:

```
Host sunrise-bakery
  HostName ssh.theirhost.com
  User theiruser
  Port 22
  IdentityFile ~/.ssh/id_ed25519
```

Then prove it works before the agent ever touches it:
```bash
ssh sunrise-bakery "pwd && ls -la | head"
ssh sunrise-bakery "cd /path/to/wordpress && wp option get home"
```

That last command is the important one — it must print **their site's URL**. That's the value
that becomes the site file's identity anchor, and it's what stops the agent ever acting on the
wrong server.

**Common problems:**
- *Permission denied (publickey)* — key not authorised (cPanel: did you click Authorize?), or
  the wrong user.
- *Connection refused* — wrong port, or SSH not enabled on the plan.
- *`wp: command not found`* — WP-CLI isn't installed. Try `php wp-cli.phar`, ask the host, or
  fall back to advisory mode.
- *Hangs with no output* — the host may need a PTY. Add `RequestTTY force` to the config block
  (note: `scp` then stops working, so use the host's own snapshots for backups). This is what
  the InstaWP sandbox needs.

---

## Step 5 — Only now, hand it to the agent

```
Run the site-onboarding skill for the new client sunrise-bakery at
https://sunrisebakery.com, plan peace-of-mind.
```

The agent will create the registry entry, **bind the site's identity** (confirming the alias
lands on the right server), take the permanent baseline backup, inventory the install, harden
it, and flip `status: active`.

If you skip Step 4 and the alias doesn't work, the agent stops at the identity check — which
is correct behaviour, not a bug.

---

## Security rules (non-negotiable)

- **Never ask for, accept, or store the client's own password.** If they email you one anyway,
  tell them to change it and set up a proper account instead. You do not want to be the reason
  their password was in an inbox.
- **Never put a credential in this repo** — not in a site file, not in a log, not in a comment.
  SSH uses key aliases; API keys live in the tools' own dashboards.
- **The private key never leaves your machine.** Only ever send `id_ed25519.pub`.
- **Use a dedicated `sitesentry` admin account**, never a shared one. When an engagement ends,
  that account is deleted and the SSH alias removed — clean, provable offboarding.
- **One key per operator machine.** If a laptop is lost, you revoke that one key rather than
  re-keying every client.

---

## Quick reference

| Situation | What you can do |
|---|---|
| You have only a URL | Free health check. Nothing else. |
| WP admin account only | Advisory mode: updates via wp-admin, WP Umbrella backups |
| SSH + WP-CLI | Everything: fast updates, backups, fixes, hardening, recovery |
| SSH but no WP-CLI | File-level work; WordPress operations still via wp-admin |
| Client won't grant access | Not a client yet. Don't promise a service you can't deliver. |
