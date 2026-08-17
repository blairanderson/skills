# Testing

Four layers: unit tests with no network, local end-to-end against a running app,
safe live sends against Postmark, and production verification.

---

## 1. Test Environment

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method     = :test
config.action_mailer.perform_deliveries  = true
config.action_mailer.default_url_options = { host: "www.example.com" }
```

`postmark-rails` does nothing special here — `ActionMailer::Base.deliveries`,
`assert_emails`, and `have_enqueued_mail` all work unchanged.

Never point CI at a real Postmark server. If you want CI to validate the request
shape against the real API, use the literal token `POSTMARK_API_TEST` — see §3.

---

## 2. Mailer Tests

```ruby
class UserMailerTest < ActionMailer::TestCase
  test "welcome sets the transactional stream and tag" do
    mail = UserMailer.welcome(users(:alice))

    assert_equal ["alice@example.com"], mail.to
    assert_equal "Welcome", mail.subject
    assert_equal "outbound", mail["message-stream"].to_s
    assert_equal "welcome", mail["tag"].to_s
  end
end
```

Postmark-specific `mail()` options land as headers before conversion, so you can
assert on them directly. The reserved header names are lowercased and dasherized:
`message-stream`, `tag`, `track-opens`, `track-links`,
`postmark-template-alias`.

Assert that bulk mail is on the right stream — it is the assertion most likely to
catch a real incident:

```ruby
test "newsletter never uses the transactional stream" do
  mail = NewsletterMailer.weekly(users(:alice))
  assert_equal "broadcasts", mail["message-stream"].to_s
end
```

### Testing suppression handling

Do not try to construct `Postmark::InactiveRecipientError` by hand — its
constructor takes a parsed API response, and the shape is not part of the public
contract. Stub the reader you actually use instead:

```ruby
test "marks a user undeliverable on an inactive recipient" do
  error = Postmark::InactiveRecipientError.allocate
  error.define_singleton_method(:recipients) { ["alice@example.com"] }

  DeliverEmailJob.new.send(:handle_inactive, error)   # or whatever your handler is

  assert_not users(:alice).reload.email_deliverable
end
```

Better still, extract the suppression logic into a plain object and test that
directly. The exception class is Postmark's concern; marking a user
undeliverable is yours.

---

## 3. Live Sends — Three Safe Targets

| Target | Sends | In Activity | Counts against quota | Use for |
|--------|-------|-------------|---------------------|---------|
| `POSTMARK_API_TEST` (a token value) | No | **No** | No | Validating request shape in CI |
| `test@blackhole.postmarkapp.com` | Dropped at Postmark | **Yes** | **Yes** | Confirming the token and config work end to end |
| `hardbounce@bounce-testing.postmarkapp.com` | Real bounce | Yes | Yes | Exercising the bounce webhook |

```ruby
# Dry run against the real API without sending anything
config.action_mailer.postmark_settings = { api_token: "POSTMARK_API_TEST" }
```

The response `Message` comes back as `"Test job accepted"` instead of `"OK"`.
You cannot simulate a bounce with this token.

Bounce-testing addresses are case-insensitive and tolerate underscores
(`Hard_Bounce@bounce-testing.postmarkapp.com`). Hard bounces from this domain do
land on the stream's suppression list — but they do not count toward bounce
limits or affect reputation.

**Never send test mail from a production domain to fake or dead addresses.** It
damages the domain's sending reputation. Use `blackhole.postmarkapp.com`.

### Sandbox servers

A Sandbox server behaves exactly like a live one — Activity, webhooks, API — but
delivery goes to a black hole. Messages appear as "Delivered". They **do** count
toward monthly volume. The type is fixed at creation and cannot be changed.

Use one for `development` and `staging`.

---

## 4. Inbound Testing

### Layer 1 — the conductor (fastest loop)

Development only.

1. Go to `/rails/conductor/action_mailbox/inbound_emails/sources/new`.
2. Paste raw RFC 822 source.
3. Iterate on the mailbox, then click **"Route again"** on the show page after
   every change.

Or use the compose form at `/rails/conductor/action_mailbox/inbound_emails/new`,
which has a dedicated **X-Original-To** field — that is how you simulate
Postmark's `OriginalRecipient` behaviour locally.

A sample raw message to paste:

```
From: Alice <alice@example.com>
To: replies+abc123@example.com
Subject: Re: Your ticket
Date: Mon, 15 Jan 2024 12:00:00 -0500
Message-ID: <test-001@example.com>
In-Reply-To: <original@example.com>
Content-Type: multipart/alternative; boundary="b1"
MIME-Version: 1.0

--b1
Content-Type: text/plain; charset=UTF-8

Thanks, that fixed it.

--b1
Content-Type: text/html; charset=UTF-8

<p>Thanks, that fixed it.</p>

--b1--
```

Use a multipart message, not a plain one. Single-part test mail hides the
`mail.decoded` crash that real Postmark traffic will trigger.

### Layer 2 — the real ingress, locally

```bash
scripts/postmark-doctor.sh inbound
```

Or by hand:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  -u actionmailbox:"$RAILS_INBOUND_EMAIL_PASSWORD" \
  -F "RawEmail=</tmp/sample.eml" \
  -F "OriginalRecipient=replies+abc123@inbound.postmarkapp.com" \
  http://localhost:3000/rails/action_mailbox/postmark/inbound_emails
```

Expect `204`. Anything else maps to a specific misconfiguration — see
`troubleshooting.md`.

### Layer 3 — Postmark reaching your laptop

```bash
ngrok http 3000
```

Set the inbound webhook to
`https://actionmailbox:PASSWORD@<subdomain>.ngrok.io/rails/action_mailbox/postmark/inbound_emails`
and send a real email to the inbound address. Remember to allow the ngrok host:

```ruby
# config/environments/development.rb
config.hosts << /.*\.ngrok\.io/
```

### Layer 4 — the Check button

The inbound stream settings screen has a **Check** button. It POSTs a sample
inbound webhook to your live URL and reports whether it got a 200. It is the
fastest way to confirm the URL, the password, and the environment config are all
right in production.

Note the sample payload it sends does **not** include `RawEmail`, so a 422 from
the Check button does not necessarily mean the checkbox is unticked. Confirm with
a real email.

---

## 5. Mailbox Tests

```ruby
class RepliesMailboxTest < ActionMailbox::TestCase
  test "appends a message to the conversation" do
    conversation = conversations(:support_ticket)

    assert_difference -> { conversation.messages.count }, 1 do
      receive_inbound_email_from_mail(
        to:      "replies+#{conversation.reply_token}@example.com",
        from:    users(:alice).email,
        subject: "Re: Your ticket",
        body:    "Thanks, that fixed it."
      )
    end

    assert_equal "Thanks, that fixed it.", conversation.messages.last.body.strip
  end

  test "handles multipart mail" do
    conversation = conversations(:support_ticket)

    receive_inbound_email_from_mail do
      to      "replies+#{conversation.reply_token}@example.com"
      from    users(:alice).email
      subject "Re: Your ticket"
      text_part { body "plain version" }
      html_part { body "<p>rich version</p>" }
    end

    assert_equal "plain version", conversation.messages.last.body.strip
  end

  test "bounces an unknown reply token" do
    inbound = receive_inbound_email_from_mail(
      to: "replies+nonsense@example.com", from: users(:alice).email, body: "hi"
    )

    assert_predicate inbound, :bounced?
    assert_enqueued_emails 1
  end

  test "stores attachments" do
    conversation = conversations(:support_ticket)

    inbound = receive_inbound_email_from_fixture("reply_with_attachment.eml")

    assert_predicate inbound, :delivered?
    assert_equal 1, conversation.messages.last.documents.count
  end
end
```

Fixtures go in `test/fixtures/files/` as `.eml`.

Three behaviours to remember:

1. The default status is `:processing`, not `:pending` — deliberately, so that
   creating a test email does not enqueue a `RoutingJob`.
2. `receive_*` routes **synchronously**. Your mailbox runs inline in the test.
3. `bounce_with` uses `deliver_later` → `assert_enqueued_emails`, or wrap in
   `perform_enqueued_jobs` and use `assert_emails`. `bounce_now_with` uses
   `deliver_now` → `assert_emails` directly.

### RSpec

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include ActionMailbox::TestHelper, type: :mailbox
end
```

```ruby
RSpec.describe RepliesMailbox, type: :mailbox do
  it "appends a message" do
    conversation = create(:conversation)

    expect {
      receive_inbound_email_from_mail(
        to: "replies+#{conversation.reply_token}@example.com",
        from: conversation.user.email,
        body: "ok"
      )
    }.to change { conversation.messages.count }.by(1)
  end
end
```

---

## 6. What to Assert in CI

A short list that catches real incidents:

- [ ] Every mailer sets an explicit `message_stream`
- [ ] Bulk mailers use a broadcast stream
- [ ] The mailbox handles multipart bodies (test with a multipart fixture)
- [ ] The mailbox bounces or backstops unknown senders instead of raising
- [ ] The bounce webhook creates a suppression record and returns 200
- [ ] A suppressed address is never enqueued for delivery
- [ ] `ApplicationMailbox` has a `:all => :backstop` route

---

## 7. Verifying Production

After deploying, in order:

```bash
# 1. Token works and inbound is configured correctly
POSTMARK_SERVER_TOKEN=xxx scripts/postmark-doctor.sh api

# 2. Outbound works end to end
POSTMARK_SERVER_TOKEN=xxx POSTMARK_FROM=noreply@example.com \
  scripts/postmark-doctor.sh send test@blackhole.postmarkapp.com

# 3. DNS is verified
scripts/postmark-doctor.sh dns example.com
```

Then send a real email to the inbound address and watch:

- Postmark → Inbound → the message should show a successful webhook
- Your job queue → the `RoutingJob` should run
- `ActionMailbox::InboundEmail.last.status` should be `delivered`

If the webhook shows success but nothing happened in the app, the problem is in
routing or the job queue, not in the ingress. That distinction is the whole
reason to check both places.
