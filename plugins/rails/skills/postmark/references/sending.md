# Sending Email — postmark-rails Reference

Verified against `postmark-rails` 0.22.1, `postmark` 1.25.1, ActionMailer 8.x,
and Postmark's developer docs.

---

## 1. Install

```ruby
# Gemfile
gem "postmark-rails"
```

`postmark-rails` depends on `actionmailer >= 3.0.0` and `postmark >= 1.21.3, < 2.0`.
There is no upper bound on ActionMailer, so it installs and works on Rails 7.1,
7.2, and 8.x — but note the README's official support list stops at Rails 7.0 and
the gem has had no release since June 2022. It works; it is just not advertised.

---

## 2. Configuration

### Credentials

```bash
bin/rails credentials:edit
```

```yaml
postmark:
  api_token: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Use the **Server API Token** (Postmark → your server → API Tokens). It is sent as
the `X-Postmark-Server-Token` header. The Account API Token is a different thing
and is only for managing domains, signatures, and servers — `Postmark::ApiClient`
cannot use it.

Per-environment credentials keep the environments separate:

```bash
bin/rails credentials:edit --environment production
bin/rails credentials:edit --environment staging
```

### Environment files

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

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method       = :postmark
config.action_mailer.postmark_settings     = { api_token: "POSTMARK_API_TEST" }
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options   = { host: "localhost", port: 3000 }
```

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method     = :test
config.action_mailer.default_url_options = { host: "www.example.com" }
```

### Every `postmark_settings` key

The hash is passed straight to `Postmark::ApiClient.new` after `:api_token` is
removed.

| Key | Default | Notes |
|-----|---------|-------|
| `:api_token` | `ENV["POSTMARK_API_TOKEN"]` | Also accepts the legacy `:api_key` |
| `:max_retries` | **`0`** | Retries on timeouts and 5xx. Off by default. |
| `:max_batch_size` | `500` | Chunk size for `deliver_messages` |
| `:http_open_timeout` | `60` | Seconds |
| `:http_read_timeout` | `60` | Seconds |
| `:secure` | `true` | HTTPS |
| `:host` | `api.postmarkapp.com` | |
| `:proxy_host` / `:proxy_port` / `:proxy_user` / `:proxy_pass` | — | |
| `:return_response` | falsy | Makes `deliver!` return the API response |

### The two settings that silently break sending

**`max_retries` defaults to `0`.** A transient timeout or a Postmark 500 drops
the message with no retry. Set it to 3.

**`raise_delivery_errors = false` swallows everything.** The suppression happens
in the `mail` gem, not in postmark-rails:

```ruby
# mail/message.rb
def do_delivery
  begin
    delivery_method.deliver!(self) if perform_deliveries
  rescue => e
    raise e if raise_delivery_errors
  end
end
```

With it off, `InactiveRecipientError`, `InvalidApiKeyError`, and every validation
failure vanish. The job reports success and nothing arrives. ActionMailer's own
default is `true`; some generated `development.rb` templates set it to `false`.

### Per-message token override

```ruby
mail(
  to: "alice@example.com",
  subject: "Hello",
  delivery_method_options: { api_token: other_token }
)
```

Useful for multi-tenant apps where each tenant has its own Postmark server.

---

## 3. Message Streams

A server has one default Transactional stream (`outbound`), optionally a
Broadcast stream (`broadcasts`), and at most one Inbound stream. Max 10 streams
per server. Stream IDs cannot start with `pm-`, and `all` is reserved.

| Stream type | For | Infrastructure |
|-------------|-----|----------------|
| Transactional | One-to-one, triggered by a user action: password resets, receipts, shipping | Dedicated transactional IPs |
| Broadcast | One-to-many: newsletters, announcements, policy updates | Separate IP ranges |
| Inbound | Receiving | — |

**Transactional and broadcast traffic never mix, including IP ranges.** Sending
bulk mail through the transactional stream is one of the documented ways to get
an account paused.

### Setting it

Per message:

```ruby
mail(to: user.email, subject: "Welcome", message_stream: "outbound")
```

As a class default:

```ruby
class NewsletterMailer < ApplicationMailer
  default message_stream: "broadcasts"
end
```

A per-`mail()` value wins over the class default. Omitting it entirely sends no
`MessageStream` field at all, and Postmark falls back to the server's default
transactional stream.

The header `message-stream` is *reserved* — it becomes the API field and is not
re-emitted as a raw email header.

Error 1235 means the stream does not exist on that server. Error 1236 means the
stream does not accept sending (e.g. you aimed at an Inbound stream).

---

## 4. Every Postmark-specific `mail()` Option

| Mailer API | Postmark API field |
|------------|--------------------|
| `from:` / `to:` / `cc:` / `bcc:` / `subject:` | `From` / `To` / `Cc` / `Bcc` / `Subject` |
| `reply_to:` | `ReplyTo` |
| `message_stream:` | `MessageStream` |
| `tag:` | `Tag` |
| `track_opens:` | `TrackOpens` |
| `track_links:` | `TrackLinks` |
| `metadata["key"] = value` (inside the action) | `Metadata` |
| `postmark_template_alias:` | `TemplateAlias` |
| `self.template_model = {...}` | `TemplateModel` |
| any other `"X-Foo" => "bar"` | appended to `Headers[]` |
| `attachments[...]` | `Attachments[]` |

### Full example

```ruby
class OrderMailer < ApplicationMailer
  def shipped(order)
    @order = order
    metadata["order_id"]  = order.id.to_s
    metadata["tenant_id"] = order.tenant_id.to_s

    mail(
      to:             order.user.email,
      reply_to:       "support@example.com",
      subject:        "Your order has shipped",
      message_stream: "outbound",
      tag:            "order-shipped",
      track_opens:    true,
      track_links:    "HtmlAndText"
    )
  end
end
```

### track_opens

Only works on HTML email — Postmark injects an invisible pixel, and there is
nowhere to put one in a plain-text message. Boolean `true` works on modern Rails;
the gem wiki recommends the string `"true"` as legacy-Rails caution. Both are
accepted by the converter.

### track_links

`:html_only`, `:text_only`, `:html_and_text`, `:none` — or the strings
`"HtmlOnly"`, `"TextOnly"`, `"HtmlAndText"`, `"None"`. Tracked links are rewritten
through `click.pstmrk.it` unless you configure a custom tracking domain.

Link tracking is unavailable until the account is approved.

### tag

One tag per message, max 1000 characters. Tags are the primary filter in
Activity and in the stats API. Use a stable, low-cardinality name
(`"order-shipped"`), never an ID.

### metadata

Set inside the action, not as a `mail()` key:

```ruby
def welcome(user)
  metadata["user_id"] = user.id.to_s
  mail(to: user.email, subject: "Welcome")
end
```

Limits: **10 fields per message, names ≤ 20 chars, values ≤ 80 chars.** All
values come back as strings in webhook payloads. Keys differing only in case are
rejected.

This is the mechanism that ties a bounce webhook back to a local record. Put the
user ID in metadata and the bounce handler needs no lookup table.

### Attachments

Standard ActionMailer:

```ruby
def invoice(order)
  attachments["invoice-#{order.number}.pdf"] = order.invoice_pdf
  attachments.inline["logo.png"] = File.read(Rails.root.join("app/assets/images/logo.png"))
  mail(to: order.user.email, subject: "Invoice")
end
```

Inline attachments get their `ContentID` set automatically. Limits: 10 MB per
message on `/email`, 50 MB on `/email/batch`. Exceeding it returns HTTP 413.
Forbidden attachment types return error 411.

### Reading the Postmark MessageID back

```ruby
message = UserMailer.welcome(user).deliver_now
message["X-PM-Message-ID"].to_s   # => "cadba131-f6d6-4cfc-9892-16ee738ba54c"
```

Note it is `X-PM-Message-ID`, not `Message-ID`. The header only exists **after**
delivery. Store it if you want to correlate a local record with an Activity row
or a later webhook.

---

## 5. Postmark Templates

Templates live on Postmark's servers; Rails sends only an alias and a model.

```ruby
require "postmark-rails/templated_mailer"

class TemplatedMailer < PostmarkRails::TemplatedMailer
  def welcome(user)
    self.template_model = { name: user.name, product_name: "MyApp" }
    mail(to: user.email)          # alias defaults to the action name: "welcome"
  end

  def receipt(order)
    self.template_model = { total: order.total }
    mail(to: order.user.email, postmark_template_alias: "order-receipt")
  end
end
```

To keep shared `ApplicationMailer` code, use the mixin instead of the base class:

```ruby
class TemplatedMailer < ApplicationMailer
  include PostmarkRails::TemplatedMailerMixin
end
```

Rules:

- **The action name is the default template alias.** A mailer method named
  `welcome` targets the template aliased `welcome`. If it does not exist you get
  error 1101, "Template not found".
- `body`, `content_type`, and `subject` are read-only. Passing any of them to
  `mail()` or `default` raises
  `ArgumentError: Overriding '<h>' header in a templated mailer is not allowed.`
- A templated message sends no `Subject`, `HtmlBody`, or `TextBody` — the
  template supplies them.
- Templated sends route to `POST /email/withTemplate`.

### Previewing templates locally

Without an interceptor, a mailer preview renders a stub describing the alias and
model. To render the real template, register the interceptor:

```ruby
# config/initializers/postmark_templates.rb
if ActionMailer::Base.postmark_settings[:api_token].present?
  ActionMailer::Base.register_preview_interceptor(PostmarkRails::PreviewInterceptor)
end
```

It calls the Postmark API to pre-render, and raises
`Postmark::InvalidTemplateError` when the template does not validate.

---

## 6. Error Handling

### The exception hierarchy

```
StandardError
└── Postmark::Error
    ├── Postmark::HttpClientError              retry? => true
    ├── Postmark::TimeoutError                 retry? => true
    ├── Postmark::InvalidTemplateError
    ├── Postmark::MailAdapterError
    ├── Postmark::UnknownMessageType
    └── Postmark::HttpServerError              #status_code #body #parsed_body
        ├── Postmark::InvalidApiKeyError            HTTP 401
        ├── Postmark::InternalServerError           HTTP 500
        ├── Postmark::UnexpectedHttpResponseError   any other non-200 (incl. 429)
        └── Postmark::ApiInputError                 HTTP 422, #error_code
            ├── Postmark::InvalidEmailRequestError  ErrorCode 300
            └── Postmark::InactiveRecipientError    ErrorCode 406, #recipients
```

Deprecated aliases you may see in old code:

| Old name | Real class |
|----------|-----------|
| `Postmark::DeliveryError` | `Postmark::Error` |
| `Postmark::InvalidMessageError` | `Postmark::ApiInputError` |
| `Postmark::UnknownError` | `Postmark::UnexpectedHttpResponseError` |
| `Postmark::InvalidEmailAddressError` | `Postmark::InvalidEmailRequestError` |

### API error codes worth branching on

| Code | Meaning | Retryable |
|------|---------|-----------|
| 300 | Invalid email request — validation failed | No |
| 400 | Sender Signature not found | No |
| 401 | Sender signature not confirmed | No |
| 403 | Invalid request field | No |
| 405 | Not allowed to send — out of credits | No |
| **406** | **Inactive recipient** — hard bounced, complained, or suppressed | No |
| 410 | Too many batch messages (> 500) | No |
| 411 | Forbidden attachment type | No |
| 412 / 413 | Account pending approval / may not send | No |
| 1101 | Template not found | No |
| 1235 | MessageStream does not exist on this server | No |
| 1236 | Sending not supported on that stream | No |

Watch the collision: HTTP **401** (bad API token → `InvalidApiKeyError`) is not
the same as ErrorCode **401** (unconfirmed sender signature, delivered inside a
422 → `ApiInputError`).

### Job-level handling

```ruby
class DeliverEmailJob < ApplicationJob
  queue_as :mailers

  retry_on Postmark::TimeoutError,
           Postmark::InternalServerError,
           Postmark::HttpClientError,
           wait: :polynomially_longer, attempts: 5

  # Narrower handler must come first — InactiveRecipientError < ApiInputError
  discard_on Postmark::InactiveRecipientError do |_job, error|
    User.where(email: error.recipients).update_all(email_deliverable: false)
    Rails.logger.warn("Postmark suppressed: #{error.recipients.join(', ')}")
  end

  discard_on Postmark::ApiInputError do |_job, error|
    Rails.logger.error("Postmark rejected (ErrorCode #{error.error_code}): #{error.message}")
  end

  discard_on Postmark::InvalidApiKeyError

  def perform(mailer, action, *args)
    mailer.constantize.public_send(action, *args).deliver_now
  end
end
```

Two preconditions or none of this fires:

1. `raise_delivery_errors = true`.
2. With `deliver_later` and the default delivery job, the exception surfaces in
   `ActionMailer::MailDeliveryJob`, not in your own job. Either set
   `config.action_mailer.delivery_job` to a custom class, or use `rescue_from`
   in the mailer.

### Mailer-level handling

```ruby
class ApplicationMailer < ActionMailer::Base
  rescue_from Postmark::InactiveRecipientError, with: :record_suppression

  private

  def record_suppression(error)
    User.where(email: error.recipients).update_all(email_deliverable: false)
  end
end
```

Postmark's own wiki shows a variant that reactivates the bounce and retries
immediately. Do not copy it blindly — automatically re-sending to a hard-bounced
address damages your sending reputation. Reactivate only for addresses you have
reason to believe are now valid.

### 429 is not retried by the gem

`retry?` is implemented as `status_code / 100 == 5`, so a 429 rate-limit response
raises `UnexpectedHttpResponseError` and is *not* covered by `max_retries`. If
you send at volume, catch it in your job. Postmark publishes no numeric
requests-per-second ceiling for the Email API; for SMTP they ask for at most 10
concurrent connections per IP.

---

## 7. Batch Sending

`postmark-rails` has no batching ActionMailer API — one API call per message.
For bulk, build the messages and hand them to a client:

```ruby
client  = Postmark::ApiClient.new(Rails.application.credentials.dig(:postmark, :api_token))
messages = users.map { |u| DigestMailer.weekly(u) }

client.deliver_messages(messages)   # POST /email/batch, auto-chunked at 500

messages.all?(&:delivered)   # => true
```

- `deliver_messages(messages)` → `/email/batch`. Raises `ArgumentError` if any
  message is templated.
- `deliver_messages_with_templates(messages)` → `/email/batchWithTemplates`.
  Raises unless **all** are templated.
- Chunking is automatic, so passing more than 500 is fine.

**The batch endpoint returns HTTP 200 even when individual messages fail.**
Results are ordered to match the input. Check each one:

```ruby
messages.reject(&:delivered).each do |failed|
  Rails.logger.error(failed.postmark_response)
end
```

---

## 8. SMTP — Only If You Must

| Setting | Value |
|---------|-------|
| Host (transactional) | `smtp.postmarkapp.com` |
| Host (broadcast) | `smtp-broadcasts.postmarkapp.com` |
| Ports | 25, 2525, or 587 |
| TLS | STARTTLS. No implicit-TLS port. |
| Username | Server API Token |
| Password | Server API Token (same value) |

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:              "smtp.postmarkapp.com",
  port:                 587,
  user_name:            Rails.application.credentials.dig(:postmark, :api_token),
  password:             Rails.application.credentials.dig(:postmark, :api_token),
  authentication:       :plain,
  enable_starttls_auto: true
}
```

Headers replace the API fields:

| Header | Replaces |
|--------|----------|
| `X-PM-Message-Stream` | `message_stream:` |
| `X-PM-Tag` | `tag:` |
| `X-PM-Metadata-<key>` | `metadata[key]` |
| `X-PM-KeepID: true` | Preserves your own `Message-ID` |

**The reason to avoid SMTP:** the protocol gives Postmark no way to return an
error to the client. Validation failures, suppressed recipients, and bad streams
all appear to succeed and arrive later as an `SMTPApiError` bounce. Everything in
§6 stops working. Also remember SMTP access must be enabled on the message
stream's settings page.

---

## 9. Common Mistakes

1. Using the Account API Token instead of the Server API Token.
2. Leaving `max_retries` at its default of 0.
3. `raise_delivery_errors = false` in production.
4. Never setting `message_stream`, then sending a newsletter through the
   transactional stream.
5. Putting a user ID in `tag:` — tags are meant to be a small, fixed set.
6. Rescuing `Postmark::InvalidMessageError` (a deprecated alias) instead of
   `Postmark::ApiInputError`.
7. Assuming a batch send succeeded because the HTTP status was 200.
8. Using SMTP and then wondering why `InactiveRecipientError` never raises.
9. A templated mailer whose action name does not match any template alias.
10. Sending test mail from the production domain to fake addresses — it damages
    domain reputation. Use `blackhole.postmarkapp.com`.
