---
name: cloudflare
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
description: |
  Audit and configure a Rails app to work correctly behind Cloudflare's DNS proxy.
  Trigger when the user mentions: Cloudflare, CDN proxy, "secure flag missing",
  "Set-Cookie stripped", "CSRF invalid", "wrong IP in logs", "request.remote_ip wrong",
  "session broken behind proxy", "Rack::Attack not working", or asks about
  setting up Cloudflare with Rails. Also trigger proactively when you see
  `config.force_ssl` without `config.assume_ssl` in a Cloudflare-hosted Rails app.
argument-hint: "audit, ssl, ip, csrf, cookies, cache"
---

# Rails + Cloudflare — Best Practices

Full audit and configuration guide for running a Rails SaaS behind Cloudflare's DNS proxy.

## Before You Start

Check what the user already has. Run these reads before asking anything:

```bash
grep -r "force_ssl\|assume_ssl\|trusted_proxies\|cloudflare" config/ --include="*.rb" -l
grep "cloudflare" Gemfile
```

## Phase 1: Discover the Setup

Ask only what the code doesn't already answer:

- **Cloudflare SSL mode**: Is it set to Full (Strict), Full, or Flexible? (Flexible is broken for Rails — see `references/ssl-modes.md`)
- **Load balancing**: Are you behind Cloudflare Load Balancing, or just DNS proxy?
- **Cache Rules**: Do you have any "Cache Everything" or custom cache rules for HTML pages?
- **Rack::Attack / rate limiting**: Are you doing any IP-based rate limiting?
- **Rails version**: 7.0, 7.1, 7.2, or 8.x? (affects `config.assume_ssl` availability)

Save the answers — they determine which fixes are needed.

---

## Phase 2: Apply the Checklist

Work through each item in order. Each fix builds on the previous.

### ✅ Fix 1 — SSL Mode: Full (Strict)

**Problem**: Cloudflare Flexible SSL sends HTTPS to the browser but HTTP to your origin.
Rails sees `request.ssl? == false`, which breaks:
- Session cookie `Secure` flag (not set — browsers may reject cookies)
- CSRF origin validation (`InvalidAuthenticityToken` on every form POST)
- `config.force_ssl` redirect loops

**Fix in Cloudflare**: Set SSL/TLS → **Full (Strict)**. Your origin must have a valid TLS cert
(Hatchbox and most PaaS providers include this automatically).

See `references/ssl-modes.md` for full details and edge cases.

---

### ✅ Fix 2 — Tell Rails It's Behind TLS (assume_ssl)

**Problem**: Even with Full SSL, some proxy setups forward HTTP internally. Rails needs to
know it should treat all incoming connections as HTTPS.

**Fix in Rails** (`config/environments/production.rb`):

```ruby
# Rails 7.1+
config.assume_ssl = true   # treat all connections as HTTPS regardless of protocol header
config.force_ssl  = true   # redirect HTTP→HTTPS, set Secure on cookies, enable HSTS
```

For **Rails 7.0 and earlier**, `assume_ssl` doesn't exist. Use middleware instead:

```ruby
# config/application.rb
config.middleware.insert_before ActionDispatch::SSL, Rack::SSL
```

Or set `X-Forwarded-Proto: https` in your Cloudflare Worker/Transform Rule so Rails
reads `request.ssl? == true` via the forwarded header.

---

### ✅ Fix 3 — Fix request.remote_ip (cloudflare-rails gem)

**Problem**: `request.remote_ip` returns Cloudflare's edge IP, not the real client IP.
This breaks: Rack::Attack rate limiting, IP-based allow/denylists, geo-targeting, audit logs.

**Worse**: without this fix, an attacker who knows your origin IP can forge
`X-Forwarded-For` and spoof any client IP, bypassing Rack::Attack entirely.

**Fix**:

```ruby
# Gemfile
gem 'cloudflare-rails'
```

```ruby
# config/application.rb
require 'cloudflare/rails'
```

The gem fetches Cloudflare's published IP ranges at boot and only trusts
`X-Forwarded-For` when the TCP connection comes from a real Cloudflare edge IP.
If the request doesn't come via Cloudflare, the forged header is ignored.

See `references/ip-spoofing.md` for manual config and Rack::Attack integration.

---

### ✅ Fix 4 — Audit Cache Rules (Set-Cookie stripping)

**Problem**: Cloudflare can cache a response and strip `Set-Cookie` before delivering it
to the browser. The user hits your app, Rails sets the session, but the cookie never arrives.

Cloudflare BYPASSes cache when `Set-Cookie` is present **unless** you have:
- A Page Rule set to "Cache Everything"
- An Edge TTL override
- A Cache Response Rule that strips Set-Cookie (new March 2026 feature)

**Fix**:
1. In Cloudflare → Cache → Cache Rules, confirm no rule caches your dynamic HTML paths
2. Check Cloudflare → Cache → Configuration → Browser Cache TTL is not overriding origin headers
3. Verify with: `curl -sI https://yourdomain.com/login | grep -i "cf-cache-status\|set-cookie"`
   - You want: `CF-Cache-Status: BYPASS` and `Set-Cookie:` present

If you have a Cache Response Rule that strips Set-Cookie, remove it from paths that
serve authenticated responses.

Rails default: `Cache-Control: no-cache, no-store` on dynamic responses — this is correct
and Cloudflare should BYPASS. Only broken if you or Cloudflare override this.

See `references/session-cookies.md` for full cookie security checklist.

---

### ✅ Fix 5 — Verify Session Cookie Attributes

With Full SSL and `force_ssl: true`, Rails sets:
- `Secure: true` — cookie only sent over HTTPS
- `HttpOnly: true` — no JS access (default Rails behavior)
- `SameSite: Lax` — default since Rails 6.1 (correct for most SaaS)

**Confirm** in a production request:
```bash
curl -sI https://yourdomain.com | grep -i set-cookie
# Should show: Set-Cookie: _session_id=...; path=/; secure; HttpOnly; SameSite=Lax
```

If `Secure` is missing → Flexible SSL mode. Fix #1 first.
If `SameSite=None` without `Secure` → browsers silently drop the cookie.

**Don't** change SameSite to None unless you have a cross-origin iframe/embed use case.
If you do need None, it must have `Secure: true`.

---

### ✅ Fix 6 — CSRF Token Validation

With correct SSL setup, CSRF works automatically. The only common failure modes:

1. **Flexible SSL** → CSRF fails because request origin is HTTPS but base_url is HTTP.
   Fix: Use Full (Strict) SSL (Fix #1).

2. **Origin header mismatch** from a custom domain or CDN subdomain.
   Fix: Add the alternate origins to `config.action_controller.forgery_protection_origin_check`:
   ```ruby
   config.action_controller.forgery_protection_origin_check = false  # only if you trust your proxy 100%
   ```
   Or better: set `config.hosts` correctly so Rails accepts the right origins.

3. **Cloudflare Email Obfuscation** modifying response body → can corrupt embedded CSRF tokens.
   Fix in Cloudflare: Speed → Optimization → Content Optimization → **disable Email Obfuscation**.

---

## Verification Checklist

Run these after applying fixes:

```bash
# 1. Check SSL mode is Full (Strict) — verify no HTTP→HTTPS loop
curl -sv http://yourdomain.com/ 2>&1 | grep "< HTTP"

# 2. Verify Set-Cookie arrives with Secure flag
curl -sI https://yourdomain.com/login | grep -i "set-cookie\|cf-cache-status"

# 3. Verify real client IP (not Cloudflare edge IP) in logs
# Check your Rails logs after a request — remote_ip should be client IP, not 104.x.x.x

# 4. Submit a form — no InvalidAuthenticityToken
# Load a page, submit a form, verify no 422

# 5. Verify CF-Cache-Status on dynamic paths
curl -sI https://yourdomain.com/ | grep "CF-Cache-Status"
# Should be: BYPASS or DYNAMIC
```

---

## Quick Reference Table

| Item | Required Setting |
|---|---|
| Cloudflare SSL Mode | **Full (Strict)** |
| `config.assume_ssl` | `true` (Rails 7.1+) |
| `config.force_ssl` | `true` |
| Real client IP | `cloudflare-rails` gem |
| Session cookie `Secure` | Automatic with Full SSL + force_ssl |
| SameSite | `Lax` (default) — don't change unless needed |
| Cache Rules on dynamic paths | `BYPASS` |
| CF Email Obfuscation | **Disabled** |

---

## Reference Docs

- `references/ssl-modes.md` — Full vs Flexible SSL deep-dive
- `references/ip-spoofing.md` — cloudflare-rails gem + Rack::Attack integration
- `references/session-cookies.md` — cookie attributes, Set-Cookie stripping, SameSite
- `references/csrf.md` — CSRF token failures and fixes
