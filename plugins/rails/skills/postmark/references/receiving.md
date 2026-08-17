# Receiving Email — Action Mailbox + Postmark Ingress

Verified against the Rails source (`actionmailbox/`, 6.0 → main) and Postmark's
inbound documentation.

**Ignore Postmark's 2017 blog post** that parses the inbound JSON in a
hand-written `ResponsesController`. Rails has shipped a Postmark ingress since
6.0. The blog approach loses idempotency, storage, routing, retries, bounce
handling, and incineration.

---

## 1. Install

```bash
bin/rails action_mailbox:install
bin/rails db:migrate
```

The generator does exactly three things:

1. Creates `app/mailboxes/application_mailbox.rb` — **an empty stub with no
   routes**.
2. Appends a **commented-out** `# config.action_mailbox.ingress = :relay` to
   `config/environments/production.rb`. Not `:postmark`, and not active. You must
   edit it.
3. Installs migrations from both `active_storage` and `action_mailbox`.

The Action Mailbox table:

```ruby
create_table :action_mailbox_inbound_emails do |t|
  t.integer :status, default: 0, null: false
  t.string  :message_id, null: false
  t.string  :message_checksum, null: false
  t.timestamps
  t.index [:message_id, :message_checksum], unique: true   # ← idempotency
end
```

### Active Storage is a hard dependency

`InboundEmail` stores the raw message as an attachment:

```ruby
has_one_attached :raw_email, service: ActionMailbox.storage_service
```

The engine requires `active_storage/engine`, `active_record/railtie`,
`active_job/railtie`, and `action_controller/railtie`. You need a working
`config/storage.yml` and `config.active_storage.service` set in the receiving
environment. `config.action_mailbox.storage_service` only *overrides* the
default; leave it `nil` to use the app's default service.

### Generating a mailbox

```bash
bin/rails generate mailbox replies
```

Creates `app/mailboxes/replies_mailbox.rb` plus a test stub. A trailing
`_mailbox` in the name is stripped, so `generate mailbox replies_mailbox` gives
the same file.

---

## 2. Configuration

```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :postmark
```

Set it in **every environment that receives a webhook**, including staging. The
installer does not do this for you.

```bash
bin/rails secret          # generate a password
bin/rails credentials:edit
```

```yaml
action_mailbox:
  ingress_password: <the generated value>
```

The lookup is:

```ruby
Rails.application.credentials.dig(:action_mailbox, :ingress_password) ||
  ENV["RAILS_INBOUND_EMAIL_PASSWORD"]
```

**Credentials always win.** A stale value in credentials silently shadows the env
var, which is a genuinely confusing failure on a platform where you set the env
var and expect it to take effect.

### The webhook URL

```
https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/postmark/inbound_emails
```

The route is drawn by the engine automatically. You never add a `mount` line.
The named helper is `rails_postmark_inbound_emails_url`.

The username is hardcoded as `actionmailbox`. URL-encode the password if it
contains `@`, `:`, or `/`. Generating it with `bin/rails secret` avoids the issue
entirely — the output is hex.

**HTTPS is not optional.** Basic auth over plain HTTP hands the ingress password
to anyone on the path.

### Postmark side

Server → Inbound Stream → Settings:

- **Webhook** — the URL above.
- **Include raw email content in JSON payload** — **tick it.** Off by default
  (`RawEmailEnabled: false`). The ingress reads only `RawEmail`; without this
  every delivery 422s.
- **Inbound Domain** — optional; see `dns.md`.
- **SpamAssassin threshold** — optional blocking.

---

## 3. What the Ingress Actually Does

```ruby
class Ingresses::Postmark::InboundEmailsController < ActionMailbox::BaseController
  before_action :authenticate_by_password
  param_encoding :create, "RawEmail", Encoding::ASCII_8BIT

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! mail
  rescue ActionController::ParameterMissing, MalformedEmailError, MalformedOriginalRecipientError
    head :unprocessable_entity
  end

  private

  def mail
    params.require("RawEmail").tap do |raw_email|
      raise MalformedEmailError unless raw_email.is_a?(String)
      raw_email.prepend("X-Original-To: ", original_recipient, "\n") if params.key?("OriginalRecipient")
    end
  end
end
```

**It reads two fields and ignores everything else.**

| Field | Use |
|-------|-----|
| `RawEmail` | Required. The full RFC 822 message. |
| `OriginalRecipient` | Optional. Prepended as an `X-Original-To:` header. **Rails 8.0+ only.** |

Every convenience field Postmark computes — `MailboxHash`, `StrippedTextReply`,
`TextBody`, `HtmlBody`, `Attachments`, `ToFull`, `FromFull`, the SpamAssassin
headers as parsed fields — is **thrown away**. Anything you want must be
re-derived from the raw message. (The SpamAssassin headers do survive, because
they are real headers inside `RawEmail`.)

### Response codes

| Status | Meaning |
|--------|---------|
| `204 No Content` | Recorded and enqueued for routing |
| `401 Unauthorized` | Bad or absent Basic auth credentials |
| `404 Not Found` | `config.action_mailbox.ingress` is not `:postmark` **in this environment** |
| `422 Unprocessable Entity` | `RawEmail` missing → the checkbox is unticked |
| `500 Server Error` | Ingress password not configured, or AR / Active Storage / Active Job unavailable |

`ensure_configured` runs **before** authentication, so a 404 means the wrong
environment config and a 401 means the wrong password. The two never overlap,
which makes debugging precise.

A blank or `nil` password raises `ArgumentError: Missing required ingress
credentials` → 500, not 401.

### Idempotency is built in

```ruby
def create_and_extract_message_id!(source, **options)
  message_checksum = OpenSSL::Digest::SHA1.hexdigest(source)
  message_id = extract_message_id(source) || generate_missing_message_id(message_checksum)
  create!(raw_email: ..., message_id:, message_checksum:, **options)
rescue ActiveRecord::RecordNotUnique
  nil
end
```

A Postmark retry that re-POSTs identical bytes is a silent no-op that still
returns 204. You do not need your own deduplication.

### Postmark's retry schedule

Non-200 responses are retried **10 times**: 1 min, 5 min, 10 min ×3, 15 min,
30 min, 1 hr, 2 hrs, 6 hrs. A **403 stops retries permanently**. Postmark waits
2 minutes for a response. After all retries the message shows as "Inbound Error"
on the Inbound page, and can be replayed with
`PUT /messages/inbound/{messageid}/retry`.

The ingress returns 204, and Postmark's docs say "200" — in practice the
integration is Postmark's own blessed one and 2xx is accepted.

---

## 4. Routing

```ruby
class ApplicationMailbox < ActionMailbox::Base
  # Regexp — matched against every recipient
  routing(/^replies\+/i => :replies)

  # String — exact, case-insensitive match
  routing("support@example.com" => :support)

  # Callable — receives the inbound_email record, not the Mail object
  routing(->(inbound_email) { inbound_email.mail.to.size > 2 } => :multiple_recipients)

  # Any object responding to #match?(inbound_email)
  routing(CustomAddress.new => :custom)

  # Catch-all — MUST be last
  routing(:all => :backstop)
end
```

### Matching semantics

```ruby
def match?(inbound_email)
  case address
  when :all    then true
  when String  then inbound_email.mail.recipients.any? { |r| address.casecmp?(r) }
  when Regexp  then inbound_email.mail.recipients.any? { |r| address.match?(r) }
  when Proc    then address.call(inbound_email)
  else              address.match?(inbound_email)
  end
end
```

`mail.recipients` is broader than `to`:

```ruby
def recipients
  Array(to) + Array(cc) + Array(bcc) +
    Array(header[:x_original_to]).map(&:to_s) +
    Array(header[:x_forwarded_to]).map(&:to_s)
end
```

`X-Original-To` participates — which is exactly how Postmark's `OriginalRecipient`
reaches the router on Rails 8.0+.

Routes are evaluated **in declaration order** (`routes.detect`). An early `:all`
swallows everything below it.

**No match** → the email is marked `bounced!` and `ActionMailbox::Router::RoutingError`
is raised inside `RoutingJob`. Nothing is sent to the sender. This surfaces as a
failed background job, never as a webhook error. Add a backstop mailbox unless
you want stray mail generating job failures.

Nested mailboxes work with a string target: `routing("x@y.com" => "nested/first")`
resolves to `Nested::FirstMailbox`.

### Plus-addressing without MailboxHash

Postmark splits `user+token@example.com` into a `MailboxHash` field — which the
ingress discards. Derive it yourself:

```ruby
class RepliesMailbox < ApplicationMailbox
  private

  def mailbox_hash
    mail.recipients.lazy.filter_map { |r| r[/\+([^@]+)@/, 1] }.first
  end
end
```

On Rails ≤ 7.2 there is no `X-Original-To` injection, so if Postmark forwards
from a custom domain into a hashed `@inbound.postmarkapp.com` address, the router
only sees the literal `To:` of the original message. **This is the single most
consequential version difference for Postmark.** On 7.2 and earlier, route on the
address the sender actually typed, not on the Postmark hash.

---

## 5. Writing a Mailbox

```ruby
class ForwardsMailbox < ApplicationMailbox
  before_processing :require_known_sender

  rescue_from(ActiveRecord::RecordInvalid) { bounced! }

  def process
    forward = sender.forwards.create!(
      subject: mail.subject,
      content: body_text
    )

    mail.attachments.each do |attachment|
      forward.documents.attach(
        io:           StringIO.new(attachment.body.decoded),
        filename:     attachment.filename,
        content_type: attachment.mime_type
      )
    end
  end

  private

  def sender
    @sender ||= User.find_by(email: mail.from_address&.address)
  end

  def require_known_sender
    bounce_with(BounceMailer.unknown_sender(inbound_email)) if sender.nil?
  end

  # mail.decoded raises NoMethodError on multipart messages
  def body_text
    if mail.multipart?
      mail.text_part&.body&.decoded || mail.html_part&.body&.decoded
    else
      mail.body.decoded
    end
  end
end
```

### API surface

| Member | Behaviour |
|--------|-----------|
| `mail` | A `Mail::Message` built from the raw source |
| `inbound_email` | The `ActionMailbox::InboundEmail` record |
| `bounced!` | Sets status `bounced` and halts. **Sends nothing.** |
| `bounce_with(message)` | `bounced!` + `message.deliver_later` |
| `bounce_now_with(message)` | `bounced!` + `message.deliver_now` |
| `delivered!` | Marks delivered; in a `before_processing` this is the "discard silently" pattern |
| `before_processing` / `after_processing` / `around_processing` | Callbacks |
| `rescue_from` | Standard `ActiveSupport::Rescuable` |

### Statuses

`pending → processing → delivered | failed | bounced`

- **pending** — received, scheduled for routing
- **processing** — a mailbox is running `process`
- **delivered** — processed successfully
- **failed** — an exception was raised
- **bounced** — rejected

The callback chain terminator is `delivered? || bounced?`. Calling `bounced!` or
`bounce_with` in a `before_processing` halts the chain, skips `process`, **and
skips `after_processing`**.

On an exception, `failed!` is written **before** `rescue_from` runs. A
`rescue_from { bounced! }` therefore produces two status writes.

An `ActiveSupport::Notifications` event `process.action_mailbox` is emitted with
`{ mailbox:, inbound_email: { id:, message_id:, status: } }` — useful for APM.

### Mail helpers Action Mailbox adds

```ruby
mail.from_address        # a single Mail::Address (mail.from is an Array of Strings)
mail.reply_to_address
mail.recipients_addresses
mail.to_addresses / cc_addresses / bcc_addresses
mail.x_original_to_addresses / x_forwarded_to_addresses
```

Prefer `mail.from_address&.address` over `mail.from`. The official guide's
`User.find_by(email_address: mail.from)` passes an Array and generates an
`IN (...)` query, which is rarely what you want.

### Attachments

`mail.attachments` is a flat list of `Mail::Part` objects, flattened across
nested MIME structures and even embedded `message/rfc822` parts.

```ruby
mail.attachments.each do |a|
  a.filename       # "invoice.pdf"
  a.mime_type      # "application/pdf"
  a.inline?        # true for embedded images
  a.body.decoded   # raw bytes
end
mail.attachments["invoice.pdf"]   # lookup by filename works
```

**Postmark does not store attachment bytes.** The full base64 content is POSTed
to your webhook once and is not retrievable later through the UI or the Messages
API. Persist attachments on receipt or lose them. Postmark's inbound cap is
**35 MB cumulative** across all attachments.

### Spam headers

SpamAssassin headers survive in the raw message:

```ruby
def spam?
  mail["X-Spam-Score"]&.value.to_f > 5.0
end
```

| Header | Example |
|--------|---------|
| `X-Spam-Status` | `No` |
| `X-Spam-Score` | `-0.1` (negative is better; > 5 is the usual spam threshold) |
| `X-Spam-Tests` | `DKIM_SIGNED,DKIM_VALID,SPF_PASS` |
| `Received-SPF` | `pass` / `neutral` / `softfail` / `fail` |

**Never assume these exist.** Postmark documents cases where the scan cannot run
and the headers are absent or incomplete. Always guard with `&.`.

---

## 6. Incineration

Defaults:

```ruby
config.action_mailbox.incinerate       = true
config.action_mailbox.incinerate_after = 30.days
config.action_mailbox.queues.incineration = :action_mailbox_incineration  # nil since load_defaults 6.1
config.action_mailbox.queues.routing      = :action_mailbox_routing       # nil since load_defaults 6.1
```

An `IncinerationJob` is scheduled with `set(wait: incinerate_after)` when the
status changes to a processed state. It destroys the `InboundEmail` and its blob.

Two subtleties:

- The due check is `updated_at < incinerate_after.ago.end_of_day`, so real
  retention overshoots the nominal window by up to a day.
- If the job fires while `due?` is false (the record was touched since), it does
  nothing and **is not rescheduled** — that record lives forever.

Far-future scheduling requires a queue backend that can hold a 30-day job. Solid
Queue and Sidekiq can. The `:async` adapter cannot; it loses everything on
restart.

To keep inbound mail permanently:

```ruby
config.action_mailbox.incinerate = false
```

Note this option is not documented in the Rails configuring guide, but it exists
and works.

### The queue trap

On any app with `load_defaults 6.1` or later, both queue names default to `nil`,
meaning jobs go to `config.active_job.default_queue_name` (usually `default`).
Copying an old Sidekiq config that lists `action_mailbox_routing` gives you a
worker listening to a queue nothing is ever enqueued to, and inbound mail sits at
`pending` forever.

Check what your app actually does:

```ruby
bin/rails runner 'puts ActionMailbox.queues.inspect'
```

---

## 7. Development — the Conductor

Mounted automatically, development only (`head :forbidden` elsewhere).

| Purpose | URL |
|---------|-----|
| List all inbound emails and statuses | `/rails/conductor/action_mailbox/inbound_emails` |
| Compose a test email (form) | `/rails/conductor/action_mailbox/inbound_emails/new` |
| Paste raw RFC 822 source | `/rails/conductor/action_mailbox/inbound_emails/sources/new` |
| Show one email | `/rails/conductor/action_mailbox/inbound_emails/:id` |
| Re-run routing | POST `/rails/conductor/action_mailbox/:id/reroute` |
| Force incinerate | POST `/rails/conductor/action_mailbox/:id/incinerate` |

The compose form exposes From, To, CC, BCC, **X-Original-To**, In-Reply-To,
Subject, Body, and multiple Attachments. The `X-Original-To` field is how you
simulate Postmark's `OriginalRecipient` locally.

The fastest inner loop: paste raw source once, then click **"Route again"** after
each code change. It resets the status to `pending` and re-enqueues `RoutingJob`.

From the console:

```ruby
ActionMailbox::InboundEmail.last.tap { |e| e.pending!; e.route }   # synchronous
```

Against the real ingress:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -u actionmailbox:PASSWORD \
  -F "RawEmail=</path/to/message.eml" \
  -F "OriginalRecipient=replies+abc123@inbound.postmarkapp.com" \
  http://localhost:3000/rails/action_mailbox/postmark/inbound_emails
```

Expect `204`. Requires `config.action_mailbox.ingress = :postmark` in
`development.rb`, otherwise you get 404. `scripts/postmark-doctor.sh inbound`
wraps this.

---

## 8. Testing

Six helpers, no more:

```ruby
create_inbound_email_from_fixture(name, status: :processing)
create_inbound_email_from_mail(status: :processing, **mail_options, &block)
create_inbound_email_from_source(source, status: :processing)
receive_inbound_email_from_fixture(...)   # create + route
receive_inbound_email_from_mail(...)      # create + route
receive_inbound_email_from_source(...)    # create + route
```

Three things that trip people up:

1. **The default status is `:processing`, not `:pending`** — deliberately, so
   creating a test email does not enqueue a `RoutingJob`.
2. `receive_*` routes **synchronously**. Your mailbox runs inline.
3. Fixtures live in `test/fixtures/files/` and are `.eml` files.

```ruby
class RepliesMailboxTest < ActionMailbox::TestCase
  test "records a reply" do
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

  test "bounces an unknown sender" do
    inbound = receive_inbound_email_from_mail(
      to: "replies+abc@example.com", from: "stranger@example.com", body: "hi"
    )

    assert_predicate inbound, :bounced?
    assert_enqueued_emails 1
  end
end
```

Multipart, block form:

```ruby
receive_inbound_email_from_mail do
  to "replies+abc@example.com"
  from "alice@example.com"
  subject "Re: hello"
  text_part { body "plain" }
  html_part { body "<p>rich</p>" }
end
```

`bounce_with` uses `deliver_later` → assert with `assert_enqueued_emails`, or
wrap in `perform_enqueued_jobs` and use `assert_emails`. `bounce_now_with` uses
`deliver_now` → `assert_emails` directly.

Status assertions: `assert_predicate inbound, :delivered?` / `:failed?` /
`:bounced?`.

---

## 9. Version Differences

| Change | First appears |
|--------|---------------|
| `param_encoding ... Encoding::ASCII_8BIT` — non-UTF-8 raw email | **7.1** |
| `OriginalRecipient` → `X-Original-To` header injection | **8.0** |
| Malformed `RawEmail` returns 422 instead of 500 | post-8.1 / main |
| `queues.*` default to `nil` | `load_defaults 6.1` |

Consequences:

- **Rails 6.0–7.0**: no `param_encoding`. Raw email with non-UTF-8 bytes can be
  mangled.
- **Rails ≤ 7.2**: `OriginalRecipient` is ignored entirely. Routes matching the
  Postmark hashed address will never fire.
- **Rails ≤ 8.1**: a malformed `RawEmail` (an Array instead of a String) reaches
  `OpenSSL::Digest::SHA1.hexdigest` and raises `TypeError` → 500 instead of 422.

---

## 10. Gotchas

**Configuration**

1. `config.action_mailbox.ingress` must be set in the environment receiving the
   webhook. A 404 almost always means this.
2. `ensure_configured` runs before authentication — 404 and 401 tell you exactly
   which problem you have.
3. Credentials beat `RAILS_INBOUND_EMAIL_PASSWORD`, always.
4. A blank password raises → 500, not 401.
5. Queue names default to `nil` from `load_defaults 6.1`.
6. HTTPS is mandatory — Basic auth in cleartext leaks the password.

**Postmark side**

7. "Include raw email content in JSON payload" is **off by default**.
8. Only `RawEmail` and `OriginalRecipient` are read. `MailboxHash`,
   `StrippedTextReply`, and parsed attachments are discarded.
9. One inbound webhook URL per Inbound Message Stream. You cannot fan out.
10. A 403 stops Postmark's retries permanently. The conductor returns 403 outside
    development — pointing a webhook at a conductor URL fails silently and
    unrecoverably.
11. Postmark stores messages up to 1 MB for UI and Messages-API purposes; larger
    ones are truncated there. The webhook payload is unaffected, but attachment
    bytes are never retrievable after the fact.

**Runtime**

12. Routing is asynchronous. The 204 is returned before your code runs. Mailbox
    exceptions are invisible to Postmark. Monitor failed jobs.
13. An unroutable address raises `RoutingError` **and** marks the email
    `bounced!` — with no bounce message sent.
14. `:all` must be declared last.
15. Duplicate POSTs are deduped silently and still return 204.
16. `bounced!` sends nothing. Only `bounce_with` / `bounce_now_with` deliver.
17. `failed!` is written before `rescue_from` runs.
18. **`mail.decoded` raises `NoMethodError` on multipart mail** — and real
    inbound mail nearly always is. The official Rails guide uses it anyway.
19. The guide has a typo: the method is `bounce_with`, not `bounced_with`.
20. `bounce_now_with` is real but undocumented in the guide.
21. Incineration `due?` uses `end_of_day`, so retention overshoots by up to a day.
