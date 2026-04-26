# Session Cookies Behind Cloudflare

## Required Cookie Attributes for a Rails SaaS

A properly configured Rails + Cloudflare session cookie should look like:

```
Set-Cookie: _yourapp_session=<value>; path=/; secure; HttpOnly; SameSite=Lax
```

| Attribute | Value | Why |
|---|---|---|
| `secure` | ✅ present | Cookie only sent over HTTPS — requires `force_ssl: true` + Full SSL |
| `HttpOnly` | ✅ present | No JS access — Rails default, don't remove |
| `SameSite` | `Lax` | Default since Rails 6.1 — protects CSRF without breaking normal navigation |

## Verify Your Cookies

```bash
curl -sI https://yourdomain.com/login | grep -i set-cookie
```

Expected output:
```
Set-Cookie: _yourapp_session=abc123...; path=/; secure; HttpOnly; SameSite=Lax
```

If `secure` is missing → Cloudflare SSL mode is Flexible (see `references/ssl-modes.md`).

## The Set-Cookie Stripping Problem

**Symptom**: Users can't log in. The login POST succeeds (200 or redirect), but the
browser has no session cookie. The app behaves as if the session was never set.

**Cause**: Cloudflare cached a response and stripped the `Set-Cookie` header before
delivering it. Happens when:

1. A **Page Rule** with "Cache Everything" covers a dynamic path (like `/login`)
2. A **Cache Rule** with an Edge TTL override is set
3. A **Cache Response Rule** (March 2026+) strips Set-Cookie to allow caching

Cloudflare's default: bypass cache when `Set-Cookie` is present.
The above configurations override this default.

**Diagnose**:
```bash
# cf-cache-status should be BYPASS, not HIT
curl -sI https://yourdomain.com/login | grep -i "cf-cache-status\|set-cookie"
```

Expected:
```
CF-Cache-Status: BYPASS
Set-Cookie: _yourapp_session=...
```

Problem:
```
CF-Cache-Status: HIT
# no Set-Cookie header
```

**Fix**:
- Remove any "Cache Everything" Page Rule covering dynamic paths
- Add a Cache Rule: match `/` with path wildcard for app routes → **Bypass Cache**
- Check Cache Response Rules for Set-Cookie stripping
- Keep static asset paths (e.g., `/assets/*`, `/packs/*`) on cache — those are fine

## Rails #55477 — Cookies Sent on Asset Requests

A bug existed where Rails sent `Set-Cookie` on asset responses. This is a
**web cache deception** risk — if Cloudflare caches an asset, it caches the
session cookie with it, potentially exposing it to an attacker.

Status: Fixed in Rails 7.1.x / 7.2.x. Ensure you're on a patched version:
```bash
bundle exec rails -v
```

Check your app doesn't send session cookies on asset requests:
```bash
curl -sI https://yourdomain.com/assets/application.css | grep -i set-cookie
# Should return nothing
```

## SameSite: None vs Lax

**Don't** change SameSite to None unless you have a specific reason:
- Embedding your Rails app in a cross-origin iframe
- Cross-origin XHR that needs cookies (e.g., your API is on `api.domain.com`,
  your frontend is on `app.domain.com` with a different origin)

If you must use `SameSite=None`, it **must** be paired with `Secure: true`.
Without Secure, Chrome/Firefox silently drop the cookie.

```ruby
# config/initializers/session_store.rb
# Only change this if you have a cross-origin cookie requirement
Rails.application.config.session_store :cookie_store,
  key: '_yourapp_session',
  same_site: :none,
  secure: true   # REQUIRED with SameSite=None
```

## Cloudflare's Own Cookies

Cloudflare sets `cf_clearance` and other CF-prefixed cookies on the browser.
These are unrelated to your Rails session. They use `SameSite=None; Secure`.

You don't need to do anything with these — they're transparent to Rails.

## Cookie-Based Session Store vs Database-Backed

Rails default: cookie store (encrypted, signed). All session data in the cookie.
This works fine behind Cloudflare — the session is client-side, no server state.

If you're using `activerecord-session_store` (database-backed):
- Sessions are stored server-side; cookie only contains the session ID
- This is compatible with Cloudflare
- Be aware: if Cloudflare LB sends requests to different origins without session
  affinity, a database-backed session store handles this correctly (vs cookie store
  which is also fine since the full session is in the cookie)
