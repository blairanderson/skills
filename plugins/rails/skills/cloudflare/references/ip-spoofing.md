# IP Spoofing & Real Client IP Behind Cloudflare

## The Problem

All traffic through Cloudflare comes from Cloudflare's edge IPs (104.x.x.x, 172.x.x.x, etc.).
Without configuration, `request.remote_ip` in Rails returns one of these edge IPs.

Cloudflare sends the real client IP in `CF-Connecting-IP` and `X-Forwarded-For` headers.
But Rails' `ActionDispatch::RemoteIp` middleware trusts `X-Forwarded-For` from anyone by
default — meaning an attacker who knows your origin IP can forge this header and spoof
any client IP.

## Consequences of Wrong remote_ip

- **Rack::Attack rate limiting fails** — all traffic appears to come from the same IP
- **IP-based allowlists/denylists don't work** — wrong IP checked
- **Geo-targeting breaks** — MaxMind or similar sees CF edge IP
- **Audit logs show wrong IPs** — compliance problem
- **IP spoofing attack** — attacker bypasses rate limiting by forging X-Forwarded-For

## The Fix: cloudflare-rails Gem

```ruby
# Gemfile
gem 'cloudflare-rails'
```

```ruby
# config/application.rb  (or config/initializers/cloudflare.rb)
require 'cloudflare/rails'
```

That's it. The gem:
1. Fetches Cloudflare's published IP ranges at app boot (IPv4 + IPv6)
2. Patches `Rack::Request::Helpers` and `ActionDispatch::RemoteIp`
3. Only trusts `X-Forwarded-For` when the TCP connection originates from a Cloudflare IP
4. Falls back to the actual TCP remote address when not from Cloudflare
5. Auto-refreshes the IP list via Cloudflare's published API (no restart needed for CF IP changes)

## Manual Config (without the gem)

Manually maintain Cloudflare's IP ranges in `config/application.rb`:

```ruby
# Fragile — you must update this list whenever Cloudflare changes their IPs
cloudflare_ips = %w[
  103.21.244.0/22
  103.22.200.0/22
  103.31.4.0/22
  104.16.0.0/13
  104.24.0.0/14
  108.162.192.0/18
  131.0.72.0/22
  141.101.64.0/18
  162.158.0.0/15
  172.64.0.0/13
  173.245.48.0/20
  188.114.96.0/20
  190.93.240.0/20
  197.234.240.0/22
  198.41.128.0/17
]

config.action_dispatch.trusted_proxies = cloudflare_ips.map { |ip| IPAddr.new(ip) } + ActionDispatch::RemoteIp::TRUSTED_PROXIES
```

**Prefer the gem** — it handles IP list updates automatically.

## Rack::Attack Integration

With `cloudflare-rails` installed, `request.remote_ip` returns the real client IP.
Rack::Attack uses `request.remote_ip` by default — no special config needed.

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle("requests by ip", limit: 100, period: 60) do |req|
  req.remote_ip  # returns real client IP, not Cloudflare edge IP
end
```

If you were using `req.ip` before, switch to `req.remote_ip` — `req.ip` is the
raw TCP socket IP (Cloudflare's edge), while `req.remote_ip` is the resolved client IP.

## Verifying Real IP is Correct

```bash
# Check Rails logs after a request — should see your real IP, not 104.x.x.x
# Or add a temporary debug endpoint:
# get '/debug/ip', to: -> (env) { [200, {}, ["#{ActionDispatch::Request.new(env).remote_ip}"]] }

# Cloudflare sends real IP in CF-Connecting-IP header — compare with what Rails sees
curl -sI https://yourdomain.com/debug/ip
```

## Cloudflare Load Balancing + Session Affinity

If you use Cloudflare Load Balancing (not just DNS proxy), Cloudflare's edge IPs
can change between requests (different edge nodes). This breaks IP-based session affinity.

Fix: Use **Cookie-based session affinity** in Cloudflare Load Balancing settings,
not IP-based. With cookie affinity, the same client always hits the same origin.
