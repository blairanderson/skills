# DNS and Deliverability

Every record Postmark needs, and why.

---

## 1. Sender Signature vs Verified Domain

| | Sender Signature | Verified Domain |
|---|---|---|
| Scope | One From address | Every address on the domain |
| Proof | Click a link in a confirmation email | DNS records |
| Needs a real mailbox | Yes | No |
| Needs DNS access | No | Yes |

**Production Rails apps should verify the domain.** An app typically sends from
`noreply@`, `support@`, and `notifications@` at minimum, and domain verification
covers all of them at once. It is also the only path to DKIM and an aligned
Return-Path.

Sender Signatures are the fallback when the user does not control DNS.

You must control the domain. Sending as `@gmail.com` through Postmark is
spoofing and will be blocked.

---

## 2. The Complete Record Set

For a domain `example.com`:

| # | Type | Host | Value | Priority | Required |
|---|------|------|-------|----------|----------|
| 1 | TXT | *from Postmark*, e.g. `20240115120000pm._domainkey` | *from Postmark* | — | Yes |
| 2 | CNAME | `pm-bounces` | `pm.mtasv.net` | — | Strongly recommended |
| 3 | TXT | `_dmarc` | `v=DMARC1; p=none; pct=100; rua=mailto:...; sp=none; aspf=r;` | — | Recommended |
| 4 | TXT | `@` | Your existing SPF, unchanged | — | Not needed for Postmark |
| 5 | CNAME | *from Postmark* | *from Postmark* | — | Optional (branded link tracking) |
| 6 | MX | `inbound` | `inbound.postmarkapp.com` | `10` | Only when receiving |

Records 2 and 4 must not share a name — a CNAME and a TXT cannot coexist on the
same hostname.

---

## 3. DKIM

| Field | Value |
|-------|-------|
| Type | TXT |
| Host | `pm._domainkey.example.com` **or** `<timestamp>pm._domainkey.example.com` |
| Value | `k=rsa; p=MIGfMA0GCS...` |
| Key length | 1024-bit |

**Read the selector from Postmark. Do not assume it.** Postmark uses two forms:
older domains have a plain `pm._domainkey` (verified live on `postmarkapp.com`
and `wildbit.com`), while newer ones get a unique timestamped selector such as
`20240115120000pm._domainkey` or `jan2013pm._domainkey`. Which one you get
depends on when the domain was added.

Get the exact host from Postmark's DNS Settings page for that domain, or from the
Domains API fields `DKIMHost` and `DKIMTextValue`. Never copy a selector from
another domain — the key is different.

Some DNS providers append the zone name automatically. If you end up with
`...pm._domainkey.example.com.example.com`, enter only the selector portion.

Verification is automatic within 48 hours, or immediate with the **Verify**
button.

### Rotation

Rotate at least once every 3 months.

1. Postmark → Sender Signatures → the domain → DNS Settings → **Generate New**.
2. Add the new TXT record with its **new selector**. Keep the old record.
3. Click **Verify**. Postmark revokes the old key on success.
4. Delete the old TXT record a few days later.

Both keys stay valid during the overlap, so rotation causes no downtime. The
Domains API exposes `DKIMPendingHost` / `DKIMPendingTextValue` and a rotate
endpoint if you want to automate it.

---

## 4. Return-Path (Custom Bounce Domain)

| Field | Value |
|-------|-------|
| Type | CNAME |
| Host | `pm-bounces.example.com` |
| Value | `pm.mtasv.net` |

The hostname `pm-bounces` is the default and is configurable, but it must be a
subdomain of the sending domain for alignment to work.

### Why it matters

Without it, the Return-Path is a Postmark-owned domain. SPF still *passes* — but
it does not *align* with your From domain, so **SPF contributes nothing to
DMARC**. Only DKIM carries the DMARC pass, and DKIM breaks on some forwarding
paths.

With it, the Return-Path becomes `pm_bounces@pm-bounces.example.com`. That shares
an organizational domain with `example.com`, so relaxed SPF alignment succeeds and
DMARC passes on both mechanisms.

### Traps

- **Trailing dot.** Some providers append the zone, giving
  `pm.mtasv.net.example.com`. Fix by entering `pm.mtasv.net.` with the dot.
- **Cloudflare proxy.** Set this record to **DNS-only** (grey cloud). Proxying
  breaks verification.
- Verify with `dig pm-bounces.example.com CNAME +short`.

---

## 5. SPF

**Postmark does not require an SPF record on your domain.**

SPF is evaluated against the Return-Path domain, which Postmark controls — either
its own domain, or your `pm-bounces` subdomain, which inherits Postmark's records
through the CNAME. Either way the check passes without any change to your apex
record.

If you want it anyway, the mechanism is `include:spf.mtasv.net`. It is optional,
and it does nothing for DMARC alignment on its own.

**Do not add a TXT record on `pm-bounces`.** The CNAME already resolves to
Postmark's SPF record, and a CNAME plus a TXT on the same name is a DNS
violation that breaks verification.

Leave your apex SPF alone — it still needs to cover your other senders:

```
v=spf1 a mx include:_spf.google.com ~all
```

---

## 6. DMARC

| Field | Value |
|-------|-------|
| Host | `_dmarc.example.com` |
| Type | TXT |
| Value | `v=DMARC1; p=none; pct=100; rua=mailto:you@example.com; sp=none; aspf=r;` |

| Tag | Meaning |
|-----|---------|
| `p=` | Policy for the domain |
| `sp=` | Policy for subdomains |
| `pct=` | Percentage of mail the policy applies to |
| `rua=` | Where aggregate reports go |
| `aspf=r` | Relaxed SPF alignment |

### The progression

1. **`p=none`** — monitoring only, no delivery impact. Start here. Gmail and
   Yahoo's bulk-sender rules require at least this.
2. **`p=quarantine`** — misaligned mail goes to spam.
3. **`p=reject`** — misaligned mail is blocked.

Stay at `none` until the reports show every legitimate sender aligned. Skipping
ahead silently breaks mail from systems you forgot about — billing, CRM, help
desk, Google Workspace.

### Reporting

- Free: <https://dmarc.postmarkapp.com/> — one domain, weekly human-readable
  email summaries. It issues an `rua` address like
  `randomhash+lv_96bXXQ9U@inbound.postmarkapp.com` to put in the `rua=` tag.
- Paid: DMARC Digests, $14 per domain per month, for multiple domains.

Postmark considers a domain complete when DKIM, custom Return-Path, and DMARC are
all verified.

---

## 7. Link and Open Tracking

By default, tracked links are rewritten through **`click.pstmrk.it`** over TLS.
Open tracking works by embedding an invisible pixel, so **it only works on HTML
email** — a plain-text-only message can never register an open.

A custom tracking domain is supported through a CNAME. Both the host and the
target are generated per-domain and appear only in your account's DNS Settings
page. **Do not guess these values.** Read them from Postmark and add the record;
verification behaves like DKIM (automatic within 48h, or the Verify button).

Enable tracking at the server level (Server settings → Link Tracking / Open
Tracking) or per message (`track_opens:` / `track_links:`).

**Link tracking is unavailable until the account is approved.**

---

## 8. Inbound MX

| Setup | Host | Priority | Value |
|-------|------|----------|-------|
| Subdomain (**recommended**) | `inbound` | `10` | `inbound.postmarkapp.com` |
| Root domain | `@` | `10` | `inbound.postmarkapp.com` |
| Wildcard | `*` | `10` | `inbound.postmarkapp.com` |

**Never point the inbound MX at a domain that receives your business mail.**
Postmark would take over all of it. Use `inbound.example.com`.

A wildcard makes `user@client1.example.com` and `user@client2.example.com` both
route to your webhook — useful for per-tenant addressing.

Full sequence:

1. Add the MX record.
2. Set the **Inbound Domain** on the Stream settings page (or `InboundDomain` via
   the Server API).
3. **Enable SMTP on the server's settings page.** This step is easy to miss and
   inbound silently fails without it.
4. Set the webhook URL.

Inbound domains are unique across all of Postmark and are stream-specific.

### The alternative: forward to the hash address

Every server has an inbound mailbox:

```
yourhash@inbound.postmarkapp.com
```

Find it on the Inbound Stream settings page, or via `GET /servers/:id` →
`InboundHash` / `InboundAddress`. Then set up a plain forward from any existing
mailbox — Gmail, Google Workspace, your host's mail — to that address. No DNS
change at all.

Use this for a quick start or when the user cannot touch DNS. Move to a custom
inbound domain later so users never see the `@inbound.postmarkapp.com` address.

---

## 9. Account Approval

Every new account is manually reviewed, usually within 24 hours on weekdays.

| | Before approval | After |
|---|---|---|
| Recipients | Only domains you have verified | Anyone |
| Link tracking | **Unavailable** | Available |
| API, SMTP, inbound, templates, webhooks | Work | Work |

`test@blackhole.postmarkapp.com` works during the pending period.

There is no numeric send cap while pending — the restriction is on recipient
domains, not volume.

### After approval

No daily send limit, conditional on:

1. Transactional mail on transactional streams, bulk on broadcast streams
2. Spam complaint rate **< 0.1%**
3. Bounce rate **< 10%**
4. Terms of Service compliance

Accounts that miss these are contacted by email and paused with messages queued.

---

## 10. Verification Commands

```bash
# DKIM — substitute the exact selector from Postmark
dig 20240115120000pm._domainkey.example.com TXT +short

# Return-Path
dig pm-bounces.example.com CNAME +short          # expect pm.mtasv.net.

# DMARC
dig _dmarc.example.com TXT +short

# Inbound MX
dig inbound.example.com MX +short                # expect 10 inbound.postmarkapp.com.

# Apex SPF (for reference — Postmark does not need it)
dig example.com TXT +short | grep spf1
```

`scripts/postmark-doctor.sh dns example.com` runs all of these and, with a
`POSTMARK_ACCOUNT_TOKEN` set, also reports Postmark's own verification state for
each record.
