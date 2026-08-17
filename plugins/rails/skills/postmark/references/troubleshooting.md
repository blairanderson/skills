# Troubleshooting

Symptom → cause → fix. Start with the symptom the user reported.

---

## Outbound

### "The mailer runs but no email arrives"

In order of likelihood:

1. **`raise_delivery_errors = false`.** The Postmark error was swallowed by the
   `mail` gem. Set it to `true` and run the send again — the real error appears.
   This is the single most common cause.
2. **`perform_deliveries = false`** in that environment.
3. **Wrong token.** An Account API Token where a Server API Token belongs. Check
   with `scripts/postmark-doctor.sh api`.
4. **Delivered but filtered.** Check the server's Activity tab. If the message is
   there and shows "Delivered", the problem is on the receiving side — see "goes
   to spam" below.
5. **Suppressed recipient.** Activity shows the send was refused. See
   `InactiveRecipientError` below.

### `Postmark::InactiveRecipientError` (ErrorCode 406)

The address hard-bounced, complained, or was manually suppressed on that stream.
Postmark refuses to send to it.

- Do **not** blanket-reactivate. Repeatedly mailing dead addresses damages your
  reputation.
- Mark the address undeliverable locally and stop enqueuing.
- Reactivate one address only with real evidence it works again:

```ruby
client = Postmark::ApiClient.new(token)
bounce = client.bounces(emailFilter: email).first
client.activate_bounce(bounce[:id]) if bounce && bounce[:CanActivate]
```

- Spam complaints have `CanActivate: false` and can never be reactivated.

### `Postmark::InvalidApiKeyError` (HTTP 401)

The token is wrong, revoked, or from a different server. Note that ErrorCode 401
inside a 422 is a *different* problem: an unconfirmed sender signature.

### ErrorCode 400 / 401 — "Sender Signature not found / not confirmed"

The `From` address is not verified. Either verify the domain (preferred) or add
and confirm a Sender Signature for that exact address. Remember `default from:`
in `ApplicationMailer` — that is usually the address at fault, not the one in the
action.

### ErrorCode 1235 — "MessageStream does not exist"

The stream ID is wrong, or it exists on a different server than the token
belongs to. Stream IDs are per-server. Check the stream dashboard's top-right
corner for the real ID.

### ErrorCode 1236 — "Sending not supported on this stream"

You aimed at an Inbound stream. Use `outbound` or `broadcasts`.

### ErrorCode 1101 — "Template not found"

With `PostmarkRails::TemplatedMailer`, the **action name is the template alias**
unless you pass `postmark_template_alias:`. A mailer method named `welcome_email`
looks for a template aliased `welcome_email`. Also check you are on the right
server — templates are per-server.

### ErrorCode 405 / 412 / 413 — account state

Out of credits, pending approval, or not allowed to send. Before approval you may
only send to domains you have verified. Use
`test@blackhole.postmarkapp.com` while waiting.

### HTTP 413 — payload too large

Over 10 MB on `/email`, or 50 MB on `/email/batch`. Attach a link instead of the
file.

### HTTP 429 — rate limited

**The gem does not retry 429**, even with `max_retries` set — its retry predicate
only matches 5xx. Catch `Postmark::UnexpectedHttpResponseError` in your job and
back off, or throttle at the job level.

### Sends succeed but errors never raise

You are on SMTP. The protocol gives Postmark no way to return an error at send
time; failures arrive later as `SMTPApiError` bounces. Switch to
`delivery_method :postmark` if you want real exceptions.

### A batch send "succeeded" but some messages did not arrive

`/email/batch` returns HTTP 200 even when individual messages fail. Check each
result:

```ruby
messages.reject(&:delivered).each { |m| Rails.logger.error(m.postmark_response) }
```

### Emails go to spam

In order:

1. **Is DKIM verified?** `dig <selector>._domainkey.example.com TXT +short`
2. **Is the Return-Path CNAME verified?** Without it SPF passes but does not
   *align*, so DMARC leans entirely on DKIM.
3. **Is there a DMARC record?** Gmail and Yahoo's bulk-sender rules effectively
   require at least `p=none`.
4. **Is bulk mail going out on the transactional stream?** That is both a
   deliverability problem and a terms problem.
5. **Complaint rate above 0.1% or bounce rate above 10%?** Postmark pauses
   accounts that exceed either.
6. Content: check the SpamAssassin score in the message's raw source.

### Open tracking shows nothing

Open tracking needs an HTML part — Postmark injects an invisible pixel and there
is nowhere to put one in plain text. Also confirm tracking is enabled at the
server or message level.

### Link tracking does nothing

Unavailable until the account is approved.

---

## Inbound

### The ingress returns 404

`config.action_mailbox.ingress` is not `:postmark` **in the environment that
received the request**. The installer writes a commented-out `:relay` line into
`production.rb` only; staging needs its own.

`ensure_configured` runs before authentication, so a 404 means this and nothing
else.

```ruby
bin/rails runner 'puts ActionMailbox.ingress.inspect'   # expect :postmark
```

### The ingress returns 401

Wrong password. The lookup order is:

```ruby
Rails.application.credentials.dig(:action_mailbox, :ingress_password) ||
  ENV["RAILS_INBOUND_EMAIL_PASSWORD"]
```

**Credentials win.** A stale credentials value silently shadows the env var you
just set on the host. Check what the app actually sees:

```ruby
bin/rails runner 'puts Rails.application.credentials.dig(:action_mailbox, :ingress_password).present?'
```

Also confirm the username in the URL is exactly `actionmailbox`, and that the
password is URL-encoded if it contains `@`, `:`, or `/`.

### The ingress returns 422

`RawEmail` is missing. **Tick "Include raw email content in JSON payload"** on
the inbound stream settings screen. It is off by default and the ingress reads
nothing else.

On Rails ≤ 8.1 a malformed `RawEmail` gives a 500 rather than a 422.

### The ingress returns 500

Either the ingress password is blank/`nil` — which raises `ArgumentError:
Missing required ingress credentials` — or Active Storage, Active Record, or
Active Job is unavailable. Check `config.active_storage.service` is set in that
environment and that the storage bucket is reachable.

### Postmark shows the webhook succeeded but nothing happened in the app

This is the most common inbound problem, and it is never an ingress problem.
Routing is asynchronous: the 204 is returned before any of your code runs.

Check, in order:

1. **Was a record created?**
   ```ruby
   ActionMailbox::InboundEmail.order(:created_at).last
   ```
   If not, the webhook did not really reach this app — check the URL host.
2. **What is its status?**
   - `pending` → the routing job never ran. Go to step 3.
   - `failed` → the mailbox raised. Find the exception in the job backend.
   - `bounced` → either your code bounced it, or **no route matched**.
   - `delivered` → the mailbox ran fine; the bug is in your `process` method.
3. **Is the worker listening on the right queue?**
   ```ruby
   bin/rails runner 'puts ActionMailbox.queues.inspect'
   ```
   From `load_defaults 6.1` onward both queue names default to `nil`, meaning
   jobs go to the Active Job default queue. A worker configured for
   `action_mailbox_routing` will wait forever on an empty queue.
4. **Re-run routing manually:**
   ```ruby
   ActionMailbox::InboundEmail.last.tap { |e| e.pending!; e.route }
   ```

### `ActionMailbox::Router::RoutingError`

No route matched. The email is marked `bounced!` and nothing is sent to the
sender. Add a backstop:

```ruby
routing(:all => :backstop)   # must be declared last
```

Common reasons a route does not match:

- The route expects the Postmark hashed address, but you are on **Rails ≤ 7.2**,
  where `OriginalRecipient` is ignored and no `X-Original-To` header is injected.
  Route on the address the sender actually typed instead.
- String routes are exact matches, not substrings.
- An earlier `routing(:all => ...)` swallowed everything below it.

Debug what the router actually sees:

```ruby
ActionMailbox::InboundEmail.last.mail.recipients
```

### `NoMethodError` from `mail.decoded`

`Mail::Message#decoded` raises on multipart messages, and real inbound mail
nearly always is multipart. The Rails guide's own example uses it.

```ruby
def body_text
  if mail.multipart?
    mail.text_part&.body&.decoded || mail.html_part&.body&.decoded
  else
    mail.body.decoded
  end
end
```

### `MailboxHash` is nil / not available

The ingress reads only `RawEmail` and `OriginalRecipient`. Every parsed Postmark
field — `MailboxHash`, `StrippedTextReply`, `TextBody`, `Attachments` — is
discarded. Re-derive from the raw message:

```ruby
mail.recipients.lazy.filter_map { |r| r[/\+([^@]+)@/, 1] }.first
```

### Attachments are missing from the app

Postmark posts attachment bytes **once** and does not store them. They are not
retrievable later through the UI or the Messages API. If your mailbox did not
persist them, they are gone. Attach them to Active Storage inside `process`.

Also check the 35 MB cumulative inbound cap.

### The same email is processed twice

It should not be. Action Mailbox deduplicates on `[message_id,
message_checksum]` with a unique index and silently returns 204 on a duplicate.

If you do see duplicates, the two messages differ — usually because a forwarding
hop rewrote a header. Add your own idempotency key based on a stable field.

### Inbound stopped working after a while

Check the Postmark Inbound page for "Inbound Error" entries. After ten failed
retries over roughly ten hours, Postmark gives up. Fix the cause, then replay:

```bash
curl "https://api.postmarkapp.com/messages/inbound/{messageid}/retry" -X PUT \
  -H "X-Postmark-Server-Token: $POSTMARK_SERVER_TOKEN"
```

Also check whether the message was blocked by the SpamAssassin threshold or an
inbound rule. Blocked messages are deleted after 10 days and can be released with
`PUT /messages/inbound/{messageid}/bypass`.

### Nothing reaches Postmark at all

1. `dig inbound.example.com MX +short` — expect `10 inbound.postmarkapp.com.`
2. Is **Inbound Domain** set on the stream settings page?
3. Is **SMTP enabled** on the server's settings page? This step is easy to miss
   and inbound fails silently without it.
4. If forwarding from Gmail instead of using MX, is the forward confirmed?

---

## DNS

### DKIM will not verify

- You guessed the selector. Postmark issues either `pm._domainkey` or a
  timestamped `<timestamp>pm._domainkey`, depending on when the domain was added.
  Read the exact host from Postmark's DNS Settings page — do not copy one from
  another domain.
- Your provider appended the zone name, producing
  `...pm._domainkey.example.com.example.com`. Enter only the selector portion.
- Fewer than 48 hours have passed. Click **Verify** to force a check.
- The TXT value was truncated. Long DKIM values sometimes need to be split into
  quoted chunks by the provider.

### Return-Path will not verify

- The value became `pm.mtasv.net.example.com`. Enter `pm.mtasv.net.` with a
  trailing dot.
- **Cloudflare proxy is on.** Set the record to DNS-only (grey cloud).
- You added a TXT record on `pm-bounces` as well. A CNAME and a TXT cannot share
  a name. Remove the TXT.

### DMARC reports show SPF failing

Expected, and usually harmless, if you have no custom Return-Path — SPF passes
but does not align. Add the `pm-bounces` CNAME to fix alignment. DKIM alignment
alone is enough for DMARC to pass, but two mechanisms survive forwarding better
than one.

---

## Quick Reference: Ingress Status Codes

| Code | Meaning | Fix |
|------|---------|-----|
| 204 | Success | — |
| 401 | Bad Basic auth | Check credentials vs env var; check the URL password |
| 404 | `ingress` not `:postmark` in this environment | Set it in that environment file |
| 422 | `RawEmail` missing | Tick the raw-email checkbox in Postmark |
| 500 | Password blank, or storage/AR/AJ unavailable | Set the password; check Active Storage |

## Quick Reference: Diagnostic Commands

```ruby
# What the app thinks
bin/rails runner 'puts ActionMailbox.ingress.inspect'
bin/rails runner 'puts ActionMailbox.queues.inspect'
bin/rails runner 'puts ActionMailer::Base.delivery_method.inspect'
bin/rails runner 'puts ActionMailer::Base.raise_delivery_errors.inspect'
bin/rails runner 'puts Rails.application.credentials.dig(:action_mailbox, :ingress_password).present?'

# What actually arrived
bin/rails runner 'e = ActionMailbox::InboundEmail.last; puts [e&.status, e&.message_id, e&.mail&.recipients].inspect'
```

```bash
# What Postmark thinks
scripts/postmark-doctor.sh api
scripts/postmark-doctor.sh dns example.com
```
