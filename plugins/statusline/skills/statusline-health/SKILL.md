---
name: statusline-health
description: "Use when: user wants to add a health check to their Claude Code status line, wants to monitor website uptime in the statusline, wants to set up HEALTH= in .claude-statusline, or wants the statusline to show (up) or a red alert when a site goes down"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "https://mysite.com/up"
version: "1.0.0"
---

# Skill: statusline-health

Add a cached uptime indicator to your Claude Code status line. The statusline polls your health URL every 5 minutes and shows:

- Green `(up)` after the website URL when healthy
- Full red alert `WEBSITE IS DOWN. I REPEAT <url> IS DOWN` replacing the entire status line when the check fails
- Dim `(add HEALTH= to .claude-statusline)` reminder when a project has `website=` but no `HEALTH=`

## What this skill sets up

| File | Purpose |
|---|---|
| `.claude-statusline` in project root | Stores `HEALTH=<url>` (and `website=`) |
| `~/.claude/statusline-command.sh` | Main statusline script — patched with health check logic |

---

## Step 1 — Determine the health URL

If arguments were passed to the skill, use that as the health URL.

Otherwise:
1. Check if `.claude-statusline` exists in the current project root
2. If it has a `website=` line, propose `<website_url>/up` as the default
3. If no suggestion is possible, use AskUserQuestion to ask the user for the URL

The health URL should return HTTP 200 when the site is healthy (e.g. `/up`, `/health`, `/healthz`).

---

## Step 2 — Verify or create the health endpoint

Test whether the health URL already responds with HTTP 200:

```bash
curl -sf --max-time 5 "<health_url>" && echo "✓ endpoint responding" || echo "✗ not responding"
```

**If it responds with 200**, skip to Step 3.

**If the endpoint does not exist or returns non-200**, create it.

### Rails apps

> **Rails 7.1+** already includes a built-in `/up` endpoint. Check `config/routes.rb` for:
> ```ruby
> get "/up" => "rails/health#show"
> ```
> If it's there, just use that URL and skip to Step 3.

Otherwise, create `app/controllers/health_controller.rb`:

```ruby
# frozen_string_literal: true

class HealthController < ActionController::Base
  rescue_from(Exception) { render_down }

  def show
    respond_to do |format|
      format.html { render html: html_body }
      format.json { render json: json_body }
    end
  end

  def render_down
    render html: %(<!DOCTYPE html><html><body style="background-color: red"></body></html>).html_safe, status: 500
  end

  def revision
    ENV["HATCHBOX_REVISION"]&.first(7) || "unknown"
  end

  def release_time
    raw = ENV["HATCHBOX_RELEASE"]
    return nil if raw.blank?
    Time.parse(raw)
  rescue ArgumentError
    nil
  end

  def html_body
    time = release_time
    release_str = time ? "#{time} (#{helpers.time_ago_in_words(time)} ago)" : "unknown"
    %(<!DOCTYPE html><html><body style="background-color: green; color: white; font-family: monospace; padding: 2rem; font-size: 1.2rem;"><p>REVISION: #{revision}</p><p>RELEASE: #{release_str}</p></body></html>).html_safe
  end

  def json_body
    time = release_time
    {
      status: "OK",
      revision: revision,
      release: ENV["HATCHBOX_RELEASE"],
      released_at: time ? helpers.time_ago_in_words(time) : "unknown"
    }
  end
end
```

Add the route in `config/routes.rb`:

```ruby
get "/up", to: "health#show"
```

Restart the dev server, then confirm the endpoint returns 200:

```bash
curl -sf --max-time 5 "http://localhost:3000/up" && echo "✓ endpoint up"
```

### Astro (static site on Cloudflare Pages)

For a fully static Astro build, there is no server — the health check just proves the CDN deployed successfully. Create a static file:

```html
<!-- public/up/index.html -->
<!DOCTYPE html><html><body style="background-color:green;color:white;font-family:monospace;padding:2rem">OK</body></html>
```

Cloudflare Pages serves it at `/up` with HTTP 200. Use `https://yoursite.com/up` as the `HEALTH=` URL.

> **Tip:** If you'd rather not add a file, any existing page (e.g. the homepage) returning 200 is a valid `HEALTH=` value. The statusline only checks the status code.

### Astro (SSR on Cloudflare Pages)

If your `astro.config.mjs` uses `output: 'server'` or `output: 'hybrid'`, create an API endpoint:

```ts
// src/pages/up.ts
export function GET() {
  return new Response(JSON.stringify({ status: "OK" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
}
```

Astro serves this at `/up`. Confirm locally:

```bash
curl -sf --max-time 5 "http://localhost:4321/up" && echo "✓ endpoint up"
```

---

## Step 3 — Update .claude-statusline

The config file lives at `<project_root>/.claude-statusline`. Create it if missing, or append to it.

Required format:
```
website=https://mysite.com/
HEALTH=https://mysite.com/up
```

Rules:
- `website=` is the display URL (shown in cyan in the statusline)
- `HEALTH=` is the URL to poll (can differ from `website=`, e.g. `/up` endpoint)
- If `website=` is already present, keep it — only add/update `HEALTH=`
- If neither is present, add both (derive `website=` from the health URL base)

---

## Step 4 — Ensure ~/.claude/statusline-command.sh has health check logic

Check if the script exists:
```bash
[ -f ~/.claude/statusline-command.sh ]
```

**If the script does NOT exist:** Inform the user that `~/.claude/statusline-command.sh` is missing. They need to run `/statusline` first to configure their statusline, then re-run this skill. Stop here.

**If the script exists:** Check if health check logic is already present:
```bash
grep -q 'health_url' ~/.claude/statusline-command.sh
```

If already present, skip to Step 5.

**If health check logic is missing**, make these three targeted edits to `~/.claude/statusline-command.sh`:

### Edit A — Replace the website-reading comment and loop

Find:
```bash
# Website from .claude-statusline config file in project root or cwd
website=""
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
for lookup_dir in "$project_dir" "$cwd"; do
  config_file="$lookup_dir/.claude-statusline"
  if [ -n "$lookup_dir" ] && [ -f "$config_file" ]; then
    website=$(grep -E '^website=' "$config_file" | head -1 | cut -d= -f2-)
    [ -n "$website" ] && break
  fi
done
```

Replace with:
```bash
# Website and health URL from .claude-statusline config file in project root or cwd
website=""
health_url=""
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
for lookup_dir in "$project_dir" "$cwd"; do
  config_file="$lookup_dir/.claude-statusline"
  if [ -n "$lookup_dir" ] && [ -f "$config_file" ]; then
    website=$(grep -E '^website=' "$config_file" | head -1 | cut -d= -f2-)
    health_url=$(grep -E '^HEALTH=' "$config_file" | head -1 | cut -d= -f2-)
    [ -n "$website" ] && break
  fi
done

# Health check with 5-minute cache
health_status=""
if [ -n "$health_url" ]; then
  cache_key=$(echo "$health_url" | md5 | cut -c1-8)
  cache_file="/tmp/statusline-health-${cache_key}.cache"
  cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
  if [ ! -f "$cache_file" ] || [ "$cache_age" -gt 300 ]; then
    if curl -sf --max-time 3 "$health_url" > /dev/null 2>&1; then
      echo "up" > "$cache_file"
    else
      echo "down" > "$cache_file"
    fi
  fi
  health_status=$(cat "$cache_file" 2>/dev/null)
fi

# If site is down, replace entire statusline with red alert
if [ "$health_status" = "down" ]; then
  printf '\033[1;31mWEBSITE IS DOWN. I REPEAT %s IS DOWN\033[0m' "${website:-$health_url}"
  exit 0
fi
```

### Edit B — Replace the website display block

Find:
```bash
# Show website on a second line if configured
if [ -n "$website" ]; then
  cyan_website=$(printf '\033[0;36m%s\033[0m' "$website")
  printf '\n  %s' "$cyan_website"
fi
```

Replace with:
```bash
# Show website on a second line if configured
if [ -n "$website" ]; then
  cyan_website=$(printf '\033[0;36m%s\033[0m' "$website")
  if [ "$health_status" = "up" ]; then
    suffix=$(printf ' \033[0;32m(up)\033[0m')
  elif [ -z "$health_url" ]; then
    suffix=$(printf ' \033[2m(add HEALTH= to .claude-statusline)\033[0m')
  else
    suffix=""
  fi
  printf '\n  %s%s' "$cyan_website" "$suffix"
fi
```

---

## Step 5 — Verify

Run the statusline script with the current project as context:

```bash
echo "{\"workspace\":{\"current_dir\":\"$(pwd)\",\"project_dir\":\"$(pwd)\"}}" \
  | bash ~/.claude/statusline-command.sh
```

Expected output contains the website URL followed by green `(up)` if the health check passes.

If the output shows the red alert, the health URL is returning a non-200 status — check the URL is correct.

Force a cache refresh at any time:
```bash
rm -f /tmp/statusline-health-*.cache
```

---

## Checklist

- [ ] Health endpoint returns HTTP 200 (`curl -sf <url>`)
- [ ] `.claude-statusline` has `HEALTH=<url>`
- [ ] `~/.claude/statusline-command.sh` has `health_url` variable
- [ ] Verification run shows `(up)` after the website URL
