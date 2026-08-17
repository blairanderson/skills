---
name: postmark
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
  - AskUserQuestion
description: |
  Set up, audit, and debug Postmark email in a Rails app — both outbound sending
  (postmark-rails, ActionMailer, message streams, templates, bounce handling) and
  inbound receiving (Action Mailbox Postmark ingress, MX records, mailbox routing).
  Trigger when the user mentions: Postmark, postmark-rails, POSTMARK_API_TOKEN,
  Action Mailbox, inbound email, "receive email in Rails", "reply by email",
  ingress_password, InboundHookUrl, RawEmail, MailboxHash, DKIM, Return-Path,
  pm-bounces, spf.mtasv.net, DMARC for a Rails app, "email not sending",
  "emails go to spam", "inbound webhook 401/404/422", InactiveRecipientError,
  or asks to swap SendGrid/Mailgun/SES for Postmark.
argument-hint: "audit | send | receive | dns | webhooks | test | troubleshoot"
---

# Rails + Postmark — Sending and Receiving

Complete setup and audit guide for Postmark on Rails 7/8. Covers outbound email
through the Postmark API and inbound email through Action Mailbox.

**Read the reference file for the phase you are in. Do not guess API shapes.**

| File | Covers |
|------|--------|
| `references/sending.md` | postmark-rails, config, message streams, templates, tags, metadata, errors |
| `references/receiving.md` | Action Mailbox install, Postmark ingress, routing, mailboxes, incineration |
| `references/dns.md` | DKIM, Return-Path, SPF, DMARC, inbound MX, account approval |
| `references/webhooks.md` | Bounce, spam complaint, delivery, open, click handlers in Rails |
| `references/testing.md` | Test tokens, blackhole, bounce simulation, conductor, RSpec/Minitest |
| `references/troubleshooting.md` | Symptom → cause table for every common failure |

Run `scripts/postmark-doctor.sh` to check a live app. See "The Doctor Script" below.

---

## Before You Start

Read what the app already has. Do not ask the user questions the code answers.

```bash
grep -rn "postmark\|delivery_method\|action_mailbox" Gemfile config/ app/ --include="*.rb" | head -40
ls app/mailboxes/ 2>/dev/null
ls app/mailers/
grep -n "action_mailbox\|active_storage" config/environments/*.rb
bin/rails runner 'puts Rails.version' 2>/dev/null
```

Facts you need before writing any code:

1. **Rails version.** Inbound behaviour changes at 7.1, 8.0, and 8.1. See `references/receiving.md` § Version differences. Rails **8.0+** is needed for Postmark's `OriginalRecipient` to reach the router.
2. **Does the app already send mail?** Through which adapter?
3. **Is Active Storage configured?** Action Mailbox cannot work without it.
4. **Is there a background job backend?** Inbound routing is asynchronous.
5. **Does the user control DNS for the sending domain?**

---

## Phase 0: Decide the Scope

Ask the user only this, and only if the answer is not obvious:

- Sending only, receiving only, or both?
- Which domain sends the mail?
- If receiving: a custom inbound domain (needs an MX record), or the
  `hash@inbound.postmarkapp.com` address with a forward from an existing mailbox?

Then follow the phases below in order. Do not skip Phase 1 — a Postmark server
and a verified domain are prerequisites for everything else.

---

## Phase 1: Postmark Account and Servers

Postmark's object model, in the order it matters:

```
Account
└── Server            ← owns one Server API Token; one per environment
    ├── Message Stream (Transactional)  id: "outbound"    ← default, cannot be changed
    ├── Message Stream (Broadcast)      id: "broadcasts"
    └── Message Stream (Inbound)        ← max 1 per server; owns the inbound webhook
```

Create **one server per environment**, not one server for everything:

| Rails env | Postmark server | Type |
|-----------|-----------------|------|
| development | `MyApp — Development` | Sandbox |
| test / CI | none — use the `:test` delivery method or the `POSTMARK_API_TEST` token | — |
| staging | `MyApp — Staging` | Sandbox (or Live if it mails real people) |
| production | `MyApp — Production` | Live |

Each server has its own **Server API Token**, which maps cleanly onto
per-environment Rails credentials. Sandbox servers black-hole delivery but still
show activity and still fire webhooks — and they **do** count against the monthly
volume.

A server's type is fixed at creation. You cannot convert Sandbox to Live.

**New accounts are manually reviewed** (usually under 24h on weekdays). Before
approval you may only send to domains you have verified, and link tracking is
disabled. `test@blackhole.postmarkapp.com` works during the pending period.

Tell the user which token to copy: the **Server API Token** (Server → API Tokens),
header `X-Postmark-Server-Token`. The Account Token is for domain and signature
management only, and Rails never needs it for sending.

---

## Phase 2: Sending

Full detail in `references/sending.md`. The minimum correct setup:

```ruby
# Gemfile
gem "postmark-rails"
```

```yaml
# bin/rails credentials:edit
postmark:
  api_token: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method       = :postmark
config.action_mailer.postmark_settings     = {
  api_token:   Rails.application.credentials.dig(:postmark, :api_token),
  max_retries: 3
}
config.action_mailer.raise_delivery_errors = true
config.action_mailer.perform_deliveries    = true
config.action_mailer.default_url_options   = { host: "example.com", protocol: "https" }
```

Three settings people get wrong. Check all three in an audit:

1. **`max_retries` defaults to `0`.** The gem ships retry logic that is off. A
   single timeout drops the email. Set it.
2. **`raise_delivery_errors = false` swallows every Postmark error silently.**
   Rails generates `false` in some environment templates. With it off, a bounced
   or suppressed recipient looks like a successful send and your job never
   retries. This is the number-one cause of "my mailer runs but nothing arrives".
3. **Use the API, not SMTP.** Over SMTP, Postmark cannot return an error at send
   time — failures arrive later as an `SMTPApiError` bounce. `delivery_method
   :postmark` gives you real exceptions. Use SMTP only when a firewall or a
   framework constraint forces it.

Then the mailer:

```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(
      to:             user.email,
      subject:        "Welcome",
      message_stream: "outbound",
      tag:            "welcome",
      track_opens:    true
    )
  end
end
```

**Always set `message_stream` explicitly.** Omitting it silently falls back to the
server's default transactional stream, which is fine until someone sends a
newsletter through it and the account gets paused. Bulk mail belongs on
`"broadcasts"`.

Verify: `scripts/postmark-doctor.sh send you@example.com`, then check the
server's Activity tab.

---

## Phase 3: Receiving

Full detail in `references/receiving.md`. Do **not** follow Postmark's 2017 blog
post that parses the JSON in a hand-rolled controller. Rails ships a Postmark
ingress. Use it.

```bash
bin/rails action_mailbox:install    # also installs Active Storage migrations
bin/rails db:migrate
bin/rails generate mailbox replies
```

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :postmark
```

```yaml
# bin/rails credentials:edit
action_mailbox:
  ingress_password: <generate with `bin/rails secret`>
```

The webhook URL to paste into Postmark (Server → Inbound Stream → Settings →
Webhook):

```
https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/postmark/inbound_emails
```

**Tick "Include raw email content in JSON payload" on that same screen.** It is
off by default. The ingress reads exactly one field, `RawEmail`. Without the
checkbox every delivery 422s and Postmark burns all ten retries.

Routing:

```ruby
# app/mailboxes/application_mailbox.rb
class ApplicationMailbox < ActionMailbox::Base
  routing(/^replies\+/i => :replies)
  routing(/^support@/i  => :support)
  routing(:all          => :backstop)   # must be declared last
end
```

```ruby
# app/mailboxes/replies_mailbox.rb
class RepliesMailbox < ApplicationMailbox
  before_processing :require_conversation

  def process
    conversation.messages.create!(
      author: sender,
      body:   mail.text_part&.body&.decoded || mail.body.decoded
    )
  end

  private

  def conversation
    @conversation ||= Conversation.find_by(reply_token: mailbox_hash)
  end

  # Postmark's parsed MailboxHash never reaches Action Mailbox — only RawEmail
  # does. Re-derive the plus-address token from the recipients.
  def mailbox_hash
    mail.recipients.lazy.filter_map { |r| r[/\+([^@]+)@/, 1] }.first
  end

  def sender
    User.find_by(email: mail.from_address&.address)
  end

  def require_conversation
    bounce_with(RepliesMailer.unknown_conversation(inbound_email)) if conversation.nil?
  end
end
```

Four traps, all covered in the reference:

- **`mail.decoded` raises `NoMethodError` on multipart mail.** Real inbound mail
  is nearly always multipart. Use `mail.text_part&.body&.decoded`.
- **Routing is asynchronous.** The webhook returns `204` before your mailbox
  runs. Mailbox exceptions never reach Postmark. Monitor failed jobs.
- **Queue names default to `nil` from `load_defaults 6.1` onward.** Workers
  configured to listen on `action_mailbox_routing` will listen to an empty queue
  and inbound mail will sit at `pending` forever.
- **`bounced!` sends nothing.** Only `bounce_with` / `bounce_now_with` deliver a
  reply.

---

## Phase 4: DNS

Full detail in `references/dns.md`. The complete record set for `example.com`:

| # | Type | Host | Value | Priority | When |
|---|------|------|-------|----------|------|
| 1 | TXT | *read from Postmark* — `pm._domainkey` or `<timestamp>pm._domainkey` | *read from Postmark* | — | Always (DKIM) |
| 2 | CNAME | `pm-bounces` | `pm.mtasv.net` | — | Always (Return-Path → DMARC alignment) |
| 3 | TXT | `_dmarc` | `v=DMARC1; p=none; pct=100; rua=mailto:...; sp=none; aspf=r;` | — | Strongly recommended |
| 4 | MX | `inbound` | `inbound.postmarkapp.com` | `10` | Only when receiving |

Non-obvious points:

- **Read the DKIM selector from Postmark; do not assume it.** Older domains use a
  plain `pm._domainkey`, newer ones a timestamped `<timestamp>pm._domainkey`.
  Take the exact host from the DNS Settings page or the Domains API.
- **Postmark does not need an SPF record on your domain.** SPF is evaluated
  against the Return-Path domain, which Postmark already controls. Adding
  `include:spf.mtasv.net` to your apex is optional and does nothing for DMARC
  alignment on its own. Do not add a TXT record on `pm-bounces` — a CNAME and a
  TXT cannot coexist on one name.
- **The Return-Path CNAME is what makes DMARC pass on SPF.** Without it, SPF
  passes but does not *align* with your From domain.
- **On Cloudflare, set the `pm-bounces` CNAME to DNS-only (grey cloud).**
  Proxying it breaks verification.
- **Never put the inbound MX on a domain that receives your business mail.** Use
  a dedicated subdomain such as `inbound.example.com`.

Verify with `scripts/postmark-doctor.sh dns example.com`.

---

## Phase 5: Webhooks and Suppression

Full detail in `references/webhooks.md`.

Postmark **does not sign webhooks**. There is no HMAC and no
`X-Postmark-Signature` header, whatever some sample code on their site implies.
The supported protections are HTTP Basic auth in the URL and IP allowlisting.
Action Mailbox's ingress already does Basic auth. Your own bounce endpoint must
do it too:

```ruby
class Webhooks::PostmarkController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_action :authenticate

  def create
    case params[:RecordType]
    when "Bounce"         then handle_bounce
    when "SpamComplaint"  then handle_spam_complaint
    when "SubscriptionChange" then handle_subscription_change
    end
    head :ok    # Postmark wants a 200. A 403 stops retries permanently.
  end

  # ...
end
```

Wire at least **Bounce** and **SpamComplaint**. A hard bounce (`TypeCode` 1)
means the address is now suppressed on that stream — keep sending to it and the
API starts raising `Postmark::InactiveRecipientError`.

---

## Phase 6: Test

Full detail in `references/testing.md`.

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method = :test
```

Outbound test targets:

- `POSTMARK_API_TEST` — a literal token value. Validates the request shape, sends
  nothing, appears nowhere in Activity.
- `test@blackhole.postmarkapp.com` — a real send that is dropped at Postmark's
  end but **does** appear in Activity and **does** count against your quota.
- `hardbounce@bounce-testing.postmarkapp.com` — generates a real bounce webhook
  without hurting your reputation. Also `blocked@`, `softbounce@`,
  `spamnotification@`.

Inbound test loop, fastest first:

1. `/rails/conductor/action_mailbox/inbound_emails/sources/new` — paste raw
   RFC 822 source, then hit "Route again" after each code change. Development
   only.
2. `scripts/postmark-doctor.sh inbound` — POSTs a real `.eml` to the local
   ingress with Basic auth and asserts `204`.
3. Postmark's **Check** button on the inbound stream settings — sends a sample
   payload to your live URL and reports the status code back.
4. `ngrok http 3000` when you want Postmark to reach your laptop for real.

Mailbox tests:

```ruby
class RepliesMailboxTest < ActionMailbox::TestCase
  test "records a reply on the conversation" do
    conversation = conversations(:one)

    assert_difference -> { conversation.messages.count } do
      receive_inbound_email_from_mail(
        to:      "replies+#{conversation.reply_token}@example.com",
        from:    users(:alice).email,
        subject: "Re: hello",
        body:    "Sounds good."
      )
    end
  end
end
```

`receive_inbound_email_from_mail` routes **synchronously**, so the mailbox runs
inline. Default status is `:processing`, which deliberately suppresses the
`route_later` callback.

---

## The Doctor Script

`scripts/postmark-doctor.sh` checks a real app and a real Postmark account.
Everything is read-only except `send`, which sends one email.

```bash
# From the Rails app root
POSTMARK_SERVER_TOKEN=xxxx ./postmark-doctor.sh all example.com

./postmark-doctor.sh app                    # Gemfile + config audit, no network
./postmark-doctor.sh dns example.com        # DKIM / Return-Path / DMARC / MX via dig
./postmark-doctor.sh api                    # verify the token, dump server + stream settings
./postmark-doctor.sh send you@example.com   # send one real test email
./postmark-doctor.sh inbound                # POST a sample .eml to the local ingress
```

Environment variables it reads:

| Variable | Used by | Purpose |
|----------|---------|---------|
| `POSTMARK_SERVER_TOKEN` | `api`, `send`, `inbound` | Server API Token |
| `POSTMARK_ACCOUNT_TOKEN` | `dns` | Optional — reads exact DKIM host and verification state |
| `POSTMARK_FROM` | `send` | Verified From address |
| `RAILS_INBOUND_EMAIL_PASSWORD` | `inbound` | Ingress password, if not in credentials |
| `APP_URL` | `inbound` | Defaults to `http://localhost:3000` |

The `api` check is the highest-value one. It reports, in one call, whether the
token works, whether `RawEmailEnabled` is on, what `InboundHookUrl` is set to,
and what the inbound address is — the four things that break inbound email.

---

## Audit Checklist

Run through this when the user says "audit" or reports a problem.

**Sending**

- [ ] `postmark-rails` in the Gemfile
- [ ] `delivery_method = :postmark` in every environment that sends
- [ ] Token in credentials or ENV, never committed
- [ ] `raise_delivery_errors = true`
- [ ] `max_retries` set (default is 0)
- [ ] `default_url_options` set per environment
- [ ] Every mailer sets `message_stream` explicitly
- [ ] Bulk mail is on a broadcast stream, not the transactional one
- [ ] `Postmark::InactiveRecipientError` is handled somewhere
- [ ] A separate Postmark server per environment

**Receiving**

- [ ] Active Storage configured and migrated
- [ ] `config.action_mailbox.ingress = :postmark` in the environment that receives
- [ ] `action_mailbox.ingress_password` in credentials
- [ ] Webhook URL includes `actionmailbox:PASSWORD@`
- [ ] "Include raw email content in JSON payload" is ticked
- [ ] `ApplicationMailbox` has a `routing :all => :backstop` fallback
- [ ] Mailboxes handle multipart bodies (`mail.text_part`, not `mail.decoded`)
- [ ] The job worker listens on the queue Action Mailbox actually uses
- [ ] `incinerate_after` matches the data-retention policy

**DNS**

- [ ] DKIM TXT verified in Postmark
- [ ] `pm-bounces` CNAME → `pm.mtasv.net` verified
- [ ] DMARC record present, at least `p=none`
- [ ] Inbound MX on a dedicated subdomain, if receiving

**Webhooks**

- [ ] Bounce and SpamComplaint webhooks point at the app
- [ ] The endpoint uses Basic auth and returns `200`
- [ ] Suppressed addresses are marked in the local database

---

## Migrating From Another Provider

Swapping SendGrid, Mailgun, or SES for Postmark is a three-line change plus
cleanup:

1. Replace the gem, set `delivery_method = :postmark`, remove the old
   `smtp_settings` or API initializer.
2. Move the DNS: add Postmark's DKIM and `pm-bounces` records **before**
   removing the old provider's records. Both can coexist.
3. Export the old provider's suppression list and import it into Postmark, or the
   first send will hard-bounce into addresses you already knew were dead.
4. If the old setup used a custom inbound route (SendGrid Inbound Parse, Mailgun
   Routes), replace the hand-rolled controller with Action Mailbox — see
   `references/receiving.md`.

Warn the user: sending reputation is tied to the IP and the domain. Moving
providers resets the IP reputation. Ramp volume up over a week rather than
switching 100% of traffic at once.
