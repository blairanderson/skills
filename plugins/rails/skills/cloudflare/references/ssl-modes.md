# Cloudflare SSL Modes & Rails

## The Three Modes (and why Flexible Breaks Rails)

| Mode | Browser→CF | CF→Origin | Rails sees |
|---|---|---|---|
| **Flexible** | HTTPS | HTTP ❌ | `request.ssl? == false` |
| **Full** | HTTPS | HTTPS (self-signed OK) | `request.ssl? == true` |
| **Full (Strict)** | HTTPS | HTTPS (valid cert required) ✅ | `request.ssl? == true` |

**Always use Full (Strict).** Flexible is a legacy option that breaks Rails in multiple ways.

## What Breaks Under Flexible SSL

1. **Session cookie `Secure` flag not set** — Rails only marks cookies `Secure` when
   `request.ssl?` is true. Under Flexible, that's false, so cookies lack the Secure flag.
   Some browsers refuse to send non-Secure cookies on HTTPS pages.

2. **CSRF InvalidAuthenticityToken** — Rails 5+ checks that `request.origin` matches
   `request.base_url`. Under Flexible, origin is HTTPS (from browser) but base_url is
   HTTP (what Rails sees). These don't match → 422 on every form POST.

3. **`config.force_ssl` redirect loop** — Rails redirects to HTTPS, CF sends HTTPS to
   the browser, but CF sends HTTP to Rails → Rails redirects again → infinite loop.

4. **HSTS not set** — `Strict-Transport-Security` header is only sent when Rails is in
   SSL mode. Under Flexible, HSTS is never sent.

## Switching to Full (Strict)

Requirements:
- Your origin server must have a valid TLS certificate
- Hatchbox: included automatically (Let's Encrypt via Kamal or Hatchbox-managed cert)
- Heroku: included on all dynos
- Render, Fly.io, Railway: included

Steps in Cloudflare:
1. SSL/TLS → Overview → Select **Full (Strict)**
2. SSL/TLS → Edge Certificates → Enable **Always Use HTTPS**
3. SSL/TLS → Edge Certificates → Enable **HSTS** (optional but recommended for SaaS)

## config.assume_ssl (Rails 7.1+)

Even with Full SSL, some setups send HTTP from the load balancer to the app container.
`config.assume_ssl = true` tells Rails to treat all incoming connections as HTTPS,
regardless of the protocol header. This ensures:
- `request.ssl? == true` always
- Session cookies always get `Secure: true`
- `force_ssl` works correctly
- CSRF origin checking uses HTTPS base_url

```ruby
# config/environments/production.rb
config.assume_ssl = true
config.force_ssl  = true
```

## Rails 7.0 and Earlier (no assume_ssl)

Use `X-Forwarded-Proto` header approach. In Cloudflare → Transform Rules → Modify Request Header,
add: `X-Forwarded-Proto: https`

Rails reads this via `ActionDispatch::SSL` and `request.ssl?` returns true.

Or use `ActionDispatch::SSL` middleware directly:
```ruby
# config/environments/production.rb
config.force_ssl = true
# AND ensure your proxy sets X-Forwarded-Proto: https
```

## Verifying SSL Mode is Correct

```bash
# Should redirect to HTTPS, not loop
curl -sv http://yourdomain.com/ 2>&1 | grep "< HTTP\|Location"

# Session cookie should have Secure flag
curl -sI https://yourdomain.com/login | grep -i set-cookie
# Expected: ...secure; HttpOnly; SameSite=Lax

# No CSRF errors — submit a form, check for 422
```
