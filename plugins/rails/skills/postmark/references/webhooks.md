# Webhooks — Bounces, Complaints, and Engagement

Inbound email uses Action Mailbox (see `receiving.md`). This file covers the
*outbound* webhooks: what Postmark sends back about mail you sent.

---

## 1. Security

**Postmark does not sign webhooks.** There is no HMAC, and there is no
`X-Postmark-Signature` header — despite some sample code on Postmark's own site
that implies otherwise. Their prose states it plainly:

> Postmark does not currently support HMAC webhook signature verification. The
> recommended approach to protect your webhook endpoint is HTTP Basic
> Authentication combined with allowlisting Postmark's IP ranges.

Do not write a signature verifier. It would verify nothing.

### What to do instead

1. **HTTP Basic auth**, either inline in the URL or — for outbound webhooks only
   — via the structured `HttpAuth` object in the Webhooks API.
2. **HTTPS**, always.
3. **IP allowlist** as defense in depth. Postmark's webhook origin IPs:

   ```
   3.134.147.250
   50.31.156.6
   50.31.156.77
   18.217.206.57
   ```

   Postmark warns the origin IP can change per attempt, so treat this as a second
   layer, never the primary control.

4. **Validate the payload structure** in the handler.

Note the asymmetry: outbound webhooks support a structured `HttpAuth` object and
up to 30 custom headers through the Webhooks API. **Inbound has neither** — it is
a Message Stream setting, so inbound Basic auth must be inline in the URL.

---

## 2. The Six Event Types

Up to 10 webhooks per stream, any combination of:

| Event | `RecordType` | Available on Broadcast streams |
|-------|--------------|-------------------------------|
| Bounce | `Bounce` | No |
| Spam Complaint | `SpamComplaint` | No |
| Delivery | `Delivery` | Yes |
| Open | `Open` | Yes |
| Click | `Click` | Yes |
| Subscription Change | `SubscriptionChange` | Yes |

Branch on `RecordType`. All outbound timestamps are ISO 8601. (Inbound payloads
carry **no** `RecordType` field — do not branch on it there.)

**Wire Bounce and SpamComplaint at minimum.** The rest are optional analytics.

---

## 3. Payloads

### Bounce

```json
{
  "RecordType": "Bounce",
  "MessageStream": "outbound",
  "ID": 4323372036854775807,
  "Type": "HardBounce",
  "TypeCode": 1,
  "Name": "Hard bounce",
  "Tag": "welcome",
  "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
  "Metadata": { "user_id": "42" },
  "ServerID": 23,
  "Description": "The server was unable to deliver your message.",
  "Details": "...",
  "Email": "john@example.com",
  "From": "sender@example.com",
  "BouncedAt": "2019-11-05T16:33:54.9070259Z",
  "Inactive": true,
  "CanActivate": true,
  "Subject": "Welcome"
}
```

| Field | Use |
|-------|-----|
| `TypeCode` | **1 = hard bounce → suppress the address** |
| `Email` | The address that bounced |
| `Inactive` | Whether this deactivated the address on the stream |
| `CanActivate` | Whether reactivation is possible |
| `Metadata` | Your own fields — the cheapest way to find the local record |
| `ID` | Use with the Bounce API to fetch or reactivate |

Spam complaints, unsubscribes, and manual deactivations are **not** delivered on
the Bounce webhook.

### SpamComplaint

Same shape as Bounce, with `TypeCode` **512** and `CanActivate: false` — Postmark
will not let you reactivate a complainer, ever.

### Delivery

```json
{
  "RecordType": "Delivery",
  "MessageStream": "outbound",
  "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
  "Recipient": "john@example.com",
  "DeliveredAt": "2019-11-05T16:33:54.9070259Z",
  "Tag": "welcome",
  "Metadata": { "user_id": "42" }
}
```

### SubscriptionChange

```json
{
  "RecordType": "SubscriptionChange",
  "MessageID": "883953f4-6105-42a2-a16a-77a8eac79483",
  "MessageStream": "outbound",
  "ChangedAt": "2020-02-01T10:53:34.416071Z",
  "Recipient": "john@example.com",
  "Origin": "Recipient",
  "SuppressSending": true,
  "SuppressionReason": "HardBounce",
  "Tag": "newsletter"
}
```

`Origin` is `Recipient` (they unsubscribed) or `Customer` (you suppressed them).

---

## 4. A Rails Handler

```ruby
# config/routes.rb
post "/webhooks/postmark", to: "webhooks/postmark#create"
```

```ruby
# app/controllers/webhooks/postmark_controller.rb
module Webhooks
  class PostmarkController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods

    before_action :authenticate

    def create
      case params[:RecordType]
      when "Bounce"             then handle_bounce
      when "SpamComplaint"      then handle_spam_complaint
      when "SubscriptionChange" then handle_subscription_change
      when "Delivery"           then handle_delivery
      end

      head :ok
    rescue => e
      Rails.logger.error("Postmark webhook error: #{e.message}")
      head :ok   # swallow — a non-200 triggers 10 retries of a payload we cannot process
    end

    private

    def authenticate
      authenticate_or_request_with_http_basic("Postmark") do |user, pass|
        ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("POSTMARK_WEBHOOK_USER")) &
          ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("POSTMARK_WEBHOOK_PASSWORD"))
      end
    end

    def handle_bounce
      return unless params[:Inactive]

      EmailSuppression.upsert(
        {
          email:            params[:Email].downcase,
          reason:           params[:Type],
          reactivatable:    params[:CanActivate],
          postmark_bounce_id: params[:ID],
          suppressed_at:    params[:BouncedAt]
        },
        unique_by: :email
      )
    end

    def handle_spam_complaint
      EmailSuppression.upsert(
        { email: params[:Email].downcase, reason: "SpamComplaint", reactivatable: false,
          suppressed_at: params[:BouncedAt] },
        unique_by: :email
      )
      User.find_by(email: params[:Email])&.update(marketing_opt_in: false)
    end

    def handle_subscription_change
      user = User.find_by(email: params[:Recipient])
      user&.update(marketing_opt_in: !params[:SuppressSending])
    end

    def handle_delivery
      return if params.dig(:Metadata, :message_record_id).blank?

      MessageRecord.where(id: params[:Metadata][:message_record_id])
                   .update_all(delivered_at: params[:DeliveredAt])
    end
  end
end
```

Points that matter:

- **Return 200.** Any other status triggers Postmark's retry schedule (1 min,
  5 min, 10 min ×3, 15 min, 30 min, 1 hr, 2 hrs, 6 hrs — ten attempts). A **403
  stops retries permanently**, which is the right response only if you have
  decided you never want that payload.
- **Rescue and still return 200.** A malformed payload retried ten times is
  noise, not resilience.
- **Do the work in a job** if the handler is slow. Postmark waits 2 minutes.
- **CSRF is not an issue** on `ActionController::API`. On a `Base` controller
  you would need `skip_forgery_protection`.
- **`Metadata` values are always strings**, even if you set integers.

---

## 5. Closing the Loop with Sending

The bounce webhook and `Postmark::InactiveRecipientError` describe the same
event from two directions. Postmark suppresses the address on its side
regardless; your job is to stop *trying*.

Check before enqueuing — cheapest, and it keeps the decision in the caller:

```ruby
UserMailer.welcome(user).deliver_later unless user.email_suppressed?
```

For a guarantee that no code path can bypass, add an observer:

```ruby
# config/initializers/suppression.rb
class SuppressionInterceptor
  def self.delivering_email(message)
    message.perform_deliveries = false if EmailSuppression.exists?(email: Array(message.to))
  end
end

ActionMailer::Base.register_interceptor(SuppressionInterceptor)
```

An interceptor runs immediately before delivery and can cancel it by setting
`perform_deliveries = false` on the message.

If you skip this, every send to a suppressed address raises
`Postmark::InactiveRecipientError` (ErrorCode 406) and burns a job retry.

---

## 6. Reactivating an Address

Only for hard bounces where you have real evidence the mailbox is back — a
successful login, a support ticket, a corrected typo. Never automatically.

```ruby
client = Postmark::ApiClient.new(Rails.application.credentials.dig(:postmark, :api_token))
bounce = client.bounces(emailFilter: email).first
client.activate_bounce(bounce[:id]) if bounce && bounce[:CanActivate]
```

Spam complaints cannot be reactivated at all.

---

## 7. Testing Webhooks

- **Postmark's "Send test" button** on the webhook settings screen, with an
  event-type dropdown when several are enabled.
- **The bounce testing domain** — a real send that generates a real webhook
  without hurting your reputation:

  ```
  hardbounce@bounce-testing.postmarkapp.com
  blocked@bounce-testing.postmarkapp.com
  softbounce@bounce-testing.postmarkapp.com
  spamnotification@bounce-testing.postmarkapp.com
  ```

- **curl** against your own endpoint:

  ```bash
  curl -u user:pass -X POST http://localhost:3000/webhooks/postmark \
    -H "Content-Type: application/json" \
    -d '{"RecordType":"Bounce","TypeCode":1,"Type":"HardBounce",
         "Email":"test@example.com","Inactive":true,"CanActivate":true,
         "BouncedAt":"2024-01-01T00:00:00Z","ID":1}'
  ```

- **RequestBin** to inspect the real payload shape before writing the handler.
- **ngrok** when Postmark must reach your laptop.

A request-spec:

```ruby
RSpec.describe "Postmark webhooks" do
  let(:auth) { ActionController::HttpAuthentication::Basic.encode_credentials("u", "p") }

  it "suppresses a hard-bounced address" do
    expect {
      post "/webhooks/postmark",
        params: { RecordType: "Bounce", TypeCode: 1, Type: "HardBounce",
                  Email: "x@example.com", Inactive: true, CanActivate: true,
                  BouncedAt: "2024-01-01T00:00:00Z", ID: 1 }.to_json,
        headers: { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => auth }
    }.to change(EmailSuppression, :count).by(1)

    expect(response).to have_http_status(:ok)
  end
end
```

---

## 8. Inbound Blocking

Separate from webhooks, but the same operational concern — stopping unwanted
inbound mail before it reaches your app.

1. **Spam threshold.** Server → Inbound stream → Settings → SpamAssassin
   threshold slider (`InboundSpamThreshold` in the Servers API). Blocks anything
   scoring above it.
2. **Sender and domain rules.** Server → Settings → Inbound → Inbound rules. A
   rule is an email address or a bare domain.

```bash
# List
curl "https://api.postmarkapp.com/triggers/inboundrules" \
  -H "X-Postmark-Server-Token: $POSTMARK_SERVER_TOKEN"

# Block
curl "https://api.postmarkapp.com/triggers/inboundrules" -X POST \
  -H "Content-Type: application/json" \
  -H "X-Postmark-Server-Token: $POSTMARK_SERVER_TOKEN" \
  -d '{"Rule": "spammer.example.com"}'

# Unblock
curl "https://api.postmarkapp.com/triggers/inboundrules/15" -X DELETE \
  -H "X-Postmark-Server-Token: $POSTMARK_SERVER_TOKEN"
```

Blocked messages do not count toward monthly usage and are deleted after 10
days. A blocked message can be replayed with
`PUT /messages/inbound/{messageid}/bypass`.
