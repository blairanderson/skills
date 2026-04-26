# CSRF Token Issues Behind Cloudflare

## How Rails CSRF Works

1. Rails generates a CSRF token and stores it in the session
2. The token is embedded in HTML forms as a hidden field (`authenticity_token`)
3. On POST/PATCH/PUT/DELETE, Rails verifies:
   a. The submitted token matches the session token
   b. The request `Origin` header matches `request.base_url` (Rails 5+)

Both checks must pass. Cloudflare can break both.

## Failure Mode 1: Flexible SSL (Most Common)

**Symptom**: `ActionController::InvalidAuthenticityToken` on every form submission.

**Cause**: Under Flexible SSL, the browser sees `https://yourdomain.com` (HTTPS origin),
but Rails sees the request as HTTP (`request.base_url == "http://yourdomain.com"`).

```
browser origin:   https://yourdomain.com
request.base_url: http://yourdomain.com  ← mismatch → CSRF fails
```

**Fix**: Switch Cloudflare to Full (Strict) SSL mode. See `references/ssl-modes.md`.

After fixing SSL, also set:
```ruby
config.assume_ssl = true   # Rails 7.1+
config.force_ssl  = true
```

## Failure Mode 2: Email Obfuscation Corrupts Tokens

**Symptom**: CSRF token invalid intermittently, not on every request.

**Cause**: Cloudflare's "Email Obfuscation" feature scans HTML responses for email
addresses and rewrites them to obfuscated JavaScript. This transformation can corrupt
content adjacent to the email address, including CSRF token hidden fields.

**Fix** in Cloudflare dashboard:
Speed → Optimization → Content Optimization → **Email Obfuscation → Off**

Also consider disabling "Rocket Loader" (can interfere with form JS).

## Failure Mode 3: Custom Domain / Subdomain Origin Mismatch

**Symptom**: CSRF fails after adding a custom domain or Cloudflare-proxied subdomain.

**Cause**: Rails' `request.base_url` is based on `Host` header. If Cloudflare changes
or normalizes the host, origin checking fails.

**Fix**: Set `config.hosts` correctly:
```ruby
# config/environments/production.rb
config.hosts = [
  "yourdomain.com",
  "www.yourdomain.com",
  /.*\.yourdomain\.com/   # if you use customer subdomains
]
```

Or if you need to disable origin checking (only if you fully trust your proxy):
```ruby
# config/environments/production.rb
config.action_controller.forgery_protection_origin_check = false
```

## Failure Mode 4: Turbo / Ajax Requests Missing CSRF Header

**Symptom**: CSRF fails on Turbo Drive navigations or Stimulus fetch calls, not on
traditional form submissions.

**Cause**: Turbo sends the CSRF token in the `X-CSRF-Token` header, not a form field.
Some Cloudflare WAF rules can strip custom headers.

**Diagnose**: Check Cloudflare WAF → Security Events for blocked requests.

**Fix**: In Cloudflare → Security → WAF → Custom Rules, whitelist `X-CSRF-Token` header.
Or in Firewall Rules, bypass WAF for requests with `X-CSRF-Token` present.

## Diagnosis Checklist

```bash
# 1. Check Rails logs for the exact error
# Look for: ActionController::InvalidAuthenticityToken

# 2. Check what SSL mode is active
# Cloudflare Dashboard → SSL/TLS → Overview

# 3. Verify request protocol as seen by Rails
# Add a debug log: Rails.logger.info "SSL: #{request.ssl?} Base URL: #{request.base_url}"

# 4. Check Cloudflare Security Events for blocked/challenged requests
# Dashboard → Security → Events

# 5. Test CSRF from a clean session
curl -c /tmp/cookies.txt -b /tmp/cookies.txt \
  -H "X-CSRF-Token: $(curl -sc /tmp/cookies.txt https://yourdomain.com/login | grep csrf | head -1)" \
  -X POST https://yourdomain.com/login \
  -d "session[email]=test@example.com&session[password]=test"
```

## Quick Reference

| Symptom | Root Cause | Fix |
|---|---|---|
| 422 on every POST | Flexible SSL | Switch to Full (Strict) |
| 422 intermittently | Email obfuscation | Disable CF email obfuscation |
| 422 on Turbo/Ajax | WAF stripping header | Whitelist X-CSRF-Token in WAF |
| 422 after new domain | Host mismatch | Set config.hosts |
| 422 + assume_ssl missing | Protocol mismatch | Add assume_ssl: true |
