---
name: statusline-health
description: "Use when: user wants to add a health check to their Claude Code status line, wants to monitor website uptime in the statusline, wants to set up HEALTH= in .claude-statusline, wants a JOBS badge showing background queue health (failed jobs count), or wants the statusline to show (up) or a red alert when a site goes down"
allowed-tools: Bash, Read, Write, Edit
argument-hint: "https://mysite.com/up"
version: "1.2.0"
---

# Skill: statusline-health

Add a cached uptime indicator, CI status badge, and background-jobs queue badge to your Claude Code status line. The statusline polls your health URL every 5 minutes and shows:

- Green `(up)` after the website URL when healthy
- Full red alert `WEBSITE IS DOWN. I REPEAT <url> IS DOWN` replacing the entire status line when the check fails
- Dim `(!health)` reminder when a project has `WEBSITE=` but no `HEALTH=`
- `✓CI` / `✗CI` / `⋯CI` badge next to the git branch showing the last GitHub Actions run result
- `✓JOBS` / `✗JOBS(N)` / `?JOBS` badge next to CI showing per-project background queue health (optional, requires a per-project hook script)

## What this skill sets up

| File | Purpose |
|---|---|
| `.claude-statusline` in project root | Stores `HEALTH=<url>` (and `website=`) — gitignored, personal config |
| `.claude/statusline-jobs.sh` in project root | Per-project hook for the JOBS badge — emits failed-job count (optional) |
| `~/.claude/statusline-command.sh` | Main statusline script — patched with health check, CI, and JOBS logic |

---

## Step 1 — Determine the health URL

If arguments were passed to the skill, use that as the health URL.

Otherwise:
1. Check if `.claude-statusline` exists in the current project root
2. If it has a `WEBSITE=` line, propose `<website_url>/up` as the default
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
WEBSITE=https://mysite.com
HEALTH=https://mysite.com/up
```

Rules:
- `WEBSITE=` is the display URL (shown in cyan in the statusline)
- `HEALTH=` is the URL to poll (can differ from `WEBSITE=`, e.g. `/up` endpoint)
- If `WEBSITE=` is already present, keep it — only add/update `HEALTH=`
- If neither is present, add both (derive `WEBSITE=` from the health URL base)

After writing `.claude-statusline`, ensure it is gitignored. This is personal config — production URLs should not be committed:

```bash
gitignore_file="${project_root}/.gitignore"
if ! grep -qF '.claude-statusline' "$gitignore_file" 2>/dev/null; then
  echo '.claude-statusline' >> "$gitignore_file"
  echo "→ Added .claude-statusline to .gitignore (personal config, not for git)"
fi
```

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

**If health check logic is missing**, make these two targeted edits to `~/.claude/statusline-command.sh`:

### Edit A — Replace the website-reading comment and loop

Find:
```bash
# Website from .claude-statusline config file in project root or cwd
website=""
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
for lookup_dir in "$project_dir" "$cwd"; do
  config_file="$lookup_dir/.claude-statusline"
  if [ -n "$lookup_dir" ] && [ -f "$config_file" ]; then
    website=$(grep -E '^WEBSITE=' "$config_file" | head -1 | cut -d= -f2-)
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
    website=$(grep -E '^WEBSITE=' "$config_file" | head -1 | cut -d= -f2-)
    health_url=$(grep -E '^HEALTH=' "$config_file" | head -1 | cut -d= -f2-)
    [ -n "$website" ] && break
  fi
done

# Health check with 5-minute cache
health_status=""
if [ -n "$health_url" ]; then
  cache_key=$(echo "$health_url" | (md5 2>/dev/null || md5sum) | cut -c1-8)
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
    suffix=$(printf ' \033[2m(!health)\033[0m')
  else
    suffix=""
  fi
  printf '\n  %s%s' "$cyan_website" "$suffix"
fi
```

---

## Step 5 — Ensure ~/.claude/statusline-command.sh has GH Actions CI badge

Check if GH Actions logic is already present:
```bash
grep -q 'gh_status' ~/.claude/statusline-command.sh
```

If already present, skip to Step 6.

**If CI logic is missing**, make these two targeted edits:

### Edit C — Add GH Actions cache block after the health check block

Find the line:
```bash
health_status=$(cat "$cache_file" 2>/dev/null)
```

After that block (after the "If site is down" exit block), insert:

```bash
# GH Actions last run with 5-minute cache (only for projects with .claude-statusline configured)
gh_status=""
if [ -n "$website" ] && command -v gh >/dev/null 2>&1 && git -C "$cwd" remote get-url origin >/dev/null 2>&1; then
  _gh_repo_key=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null | (md5 2>/dev/null || md5sum) | cut -c1-8)
  _gh_cache="/tmp/statusline-gh-${_gh_repo_key}.cache"
  _gh_age=$(($(date +%s) - $(stat -f %m "$_gh_cache" 2>/dev/null || stat -c %Y "$_gh_cache" 2>/dev/null || echo 0)))
  if [ ! -f "$_gh_cache" ] || [ "$_gh_age" -gt 300 ]; then
    _cur_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    _conclusion=$(gh run list --limit 1 --branch "$_cur_branch" --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "")
    echo "${_conclusion:-unknown}" > "$_gh_cache"
  fi
  gh_status=$(cat "$_gh_cache" 2>/dev/null)
fi
```

### Edit D — Add CI badge to the assemble block

Find:
```bash
# Assemble line — no trailing $ per statusLine conventions
if [ -n "$git_info" ]; then
  printf '%s %s' "$git_info" "$bold_yellow_path"
else
  printf '%s' "$bold_yellow_path"
fi
```

Replace with:
```bash
# CI badge from GH Actions
case "$gh_status" in
  success)            ci_badge=$(printf ' \033[0;32m✓CI\033[0m') ;;
  failure)            ci_badge=$(printf ' \033[0;31m✗CI\033[0m') ;;
  cancelled)          ci_badge=$(printf ' \033[2m~CI\033[0m') ;;
  in_progress|queued) ci_badge=$(printf ' \033[0;33m⋯CI\033[0m') ;;
  *)                  ci_badge="" ;;
esac

# Assemble line — no trailing $ per statusLine conventions
if [ -n "$git_info" ]; then
  printf '%s%s %s' "$git_info" "$ci_badge" "$bold_yellow_path"
else
  printf '%s' "$bold_yellow_path"
fi
```

---

## Step 6 — JOBS badge for background queue monitoring (optional, per-project)

The JOBS badge is the third per-branch indicator, sitting next to the CI badge. Unlike CI — which uses the `gh` CLI universally — every app inspects its background queue differently (SolidQueue, Sidekiq, Resque, GoodJob, a custom CLI, an admin HTTP endpoint). The statusline dispatches to a per-project hook script and renders the result.

States:
- `✓JOBS` (green) — queue is clean (hook prints `0` or empty)
- `✗JOBS(N)` (red) — `N` failed jobs in the queue (hook prints a positive integer)
- `?JOBS` (dim) — hook is broken or unreachable (hook exits non-zero)
- Nothing rendered — project has no `.claude/statusline-jobs.sh`

Check if JOBS dispatcher logic is already in `~/.claude/statusline-command.sh`:

```bash
grep -q 'jobs_badge' ~/.claude/statusline-command.sh
```

If already present, skip to "Per-project hook" below.

**If JOBS logic is missing**, make these two targeted edits:

### Edit E — Insert the JOBS dispatcher after the CI badge case

Find the CI badge case statement (added in Edit D):
```bash
case "$gh_status" in
  success)            ci_badge=$(printf ' \033[0;32m✓CI\033[0m') ;;
  failure)            ci_badge=$(printf ' \033[0;31m✗CI\033[0m') ;;
  cancelled)          ci_badge=$(printf ' \033[2m~CI\033[0m') ;;
  in_progress|queued) ci_badge=$(printf ' \033[0;33m⋯CI\033[0m') ;;
  *)                  ci_badge="" ;;
esac
```

Immediately after it (and before the assemble block), insert:

```bash
# JOBS badge — per-project hook via .claude/statusline-jobs.sh in project root
jobs_badge=""
_jobs_script="${project_dir}/.claude/statusline-jobs.sh"
if [ -n "$project_dir" ] && [ -f "$_jobs_script" ]; then
  _jobs_repo_key=$(echo "$project_dir" | (md5 2>/dev/null || md5sum) | cut -c1-8)
  _jobs_cache="/tmp/statusline-jobs-${_jobs_repo_key}.cache"
  _jobs_age=$(($(date +%s) - $(stat -f %m "$_jobs_cache" 2>/dev/null || stat -c %Y "$_jobs_cache" 2>/dev/null || echo 0)))
  if [ ! -f "$_jobs_cache" ] || [ "$_jobs_age" -gt 60 ]; then
    _jobs_out=$(bash "$_jobs_script" 2>/dev/null)
    _jobs_exit=$?
    if [ $_jobs_exit -ne 0 ]; then
      echo "unknown" > "$_jobs_cache"
    elif [ -z "$_jobs_out" ] || [ "$_jobs_out" = "0" ]; then
      echo "0" > "$_jobs_cache"
    else
      echo "$_jobs_out" > "$_jobs_cache"
    fi
  fi
  _jobs_val=$(cat "$_jobs_cache" 2>/dev/null)
  case "$_jobs_val" in
    0)       jobs_badge=$(printf ' \033[0;32m✓JOBS\033[0m') ;;
    unknown) jobs_badge=$(printf ' \033[2m?JOBS\033[0m') ;;
    *)       jobs_badge=$(printf ' \033[0;31m✗JOBS(%s)\033[0m' "$_jobs_val") ;;
  esac
fi
```

Cache TTL is 60s (shorter than the 5min health/CI caches — failed jobs need faster feedback). Cache file: `/tmp/statusline-jobs-<repo-hash>.cache`.

### Edit F — Add `$jobs_badge` to the assemble line

Find:
```bash
# Assemble line — no trailing $ per statusLine conventions
if [ -n "$git_info" ]; then
  printf '%s%s %s' "$git_info" "$ci_badge" "$bold_yellow_path"
else
  printf '%s' "$bold_yellow_path"
fi
```

Replace with:
```bash
# Assemble line — no trailing $ per statusLine conventions
if [ -n "$git_info" ]; then
  printf '%s%s%s %s' "$git_info" "$ci_badge" "$jobs_badge" "$bold_yellow_path"
else
  printf '%s' "$bold_yellow_path"
fi
```

### Per-project hook: `.claude/statusline-jobs.sh`

Each project that wants the JOBS badge needs an executable script at `<project_root>/.claude/statusline-jobs.sh`. The contract:

| Exit code | stdout | Statusline renders |
|-----------|--------|--------------------|
| 0 | `0` or empty | green `✓JOBS` |
| 0 | positive integer `N` | red `✗JOBS(N)` |
| non-zero | (ignored) | dim `?JOBS` |

Caching is handled by the statusline (60s TTL per project), so the hook can be a synchronous call — but **keep it fast**. The statusline blocks on the hook once per minute when the cache expires. A 4+ second hook means a 4+ second prompt hang.

#### Concrete example: Rails app with an admin CLI wrapping a JSON ops API

Verified shape for a Rails 8 + SolidQueue project whose `bin/admin_api jobs --limit 1` returns `"N of M failed jobs (most recent first)"` as the first line. We extract `M` (the total).

```bash
#!/usr/bin/env bash
# Statusline JOBS hook — emits the count of failed background jobs.
#
# Contract:
#   exit 0 + integer  → that many failed jobs (0 = clean)
#   exit 0 + empty    → treated as 0
#   non-zero exit     → "unknown" (dim ?JOBS in statusline)

set -e
cd "$(dirname "$0")/.." || exit 1

line=$(bin/admin_api jobs --limit 1 2>/dev/null | head -1) || exit 1
count=$(printf '%s\n' "$line" | sed -nE 's/^[0-9]+ of ([0-9]+) failed jobs.*/\1/p')
[ -z "$count" ] && exit 1
echo "$count"
```

After writing, make it executable:
```bash
chmod +x .claude/statusline-jobs.sh
```

#### Sketches for other queue systems

The shape stays the same — print the count, exit 0. Substitute the count source for your queue. **Verify the command works before shipping** — none of these are pre-tested by this skill:

- **Sidekiq:** `Sidekiq::Stats.new.failed` via `bin/rails runner -e production`, or a redis probe (`redis-cli LLEN sidekiq:retry`), or the Sidekiq Web `/sidekiq/dashboard.json` endpoint behind HTTP basic auth
- **Resque:** `Resque.info[:failed]` via `bin/rails runner -e production`
- **GoodJob:** `GoodJob::Job.discarded.count` via rails runner, or the GoodJob Web dashboard JSON
- **Generic admin HTTP endpoint:** any JSON endpoint that returns `{"failed":N}` — pipe through `jq` to extract the count
- **Cron / no queue:** if there's no background queue at all, skip this step entirely (the badge stays hidden)

If your queue check requires production credentials, prefer fast auth paths over slow ones. For example, in this app `bin/admin_api` auths via `OPS_USERNAME` / `OPS_PASSWORD` env vars (~120ms HTTP call) when `.env` is populated, and falls back to `bin/rails runner -e production` (~4s) when not. Slow fallbacks turn into noticeable prompt hangs once a minute.

#### Gotchas

- **`.claude/` is often gitignored.** Many Rails projects (and others) put the entire `.claude/` directory in `.gitignore`, which means `.claude/statusline-jobs.sh` lives per-machine. If teammates want a shared hook, add an exception after the broader rule:
  ```
  .claude/
  !.claude/statusline-jobs.sh
  ```
- **Force-refresh:** delete `/tmp/statusline-jobs-*.cache` to skip the 60s cache.
- **Slow hook = slow prompt.** If the hook takes more than ~1s, consider backgrounding the actual check to a side-cache file and have the hook print whatever's in the side-cache instantly. The 60s statusline cache then renders that stale value, and a freshness daemon (or just a periodic `bin/admin_api jobs` in cron) keeps the side-cache current.
- **Idempotent on re-run.** The skill should detect the existing JOBS dispatcher (`grep -q 'jobs_badge'`) and not re-insert. The hook script is per-project — only create it if the user wants the badge for *that* project.

---

## Step 7 — Verify

Run the statusline script with the current project as context:

```bash
echo "{\"workspace\":{\"current_dir\":\"$(pwd)\",\"project_dir\":\"$(pwd)\"}}" \
  | bash ~/.claude/statusline-command.sh
```

Expected output:
- Git branch followed by `✓CI` (green) or `✗CI` (red) if this repo has GitHub Actions
- Followed by `✓JOBS` / `✗JOBS(N)` / `?JOBS` if `.claude/statusline-jobs.sh` exists
- Website URL followed by `(up)` (green) if the health check passes
- Red alert instead of all of the above if the site is down

Force a cache refresh at any time:
```bash
rm -f /tmp/statusline-health-*.cache /tmp/statusline-gh-*.cache /tmp/statusline-jobs-*.cache
```

---

## Checklist

- [ ] Health endpoint returns HTTP 200 (`curl -sf <url>`)
- [ ] `.claude-statusline` has `HEALTH=<url>`
- [ ] `.claude-statusline` is in `.gitignore`
- [ ] `~/.claude/statusline-command.sh` has `health_url` variable
- [ ] `~/.claude/statusline-command.sh` has `gh_status` variable
- [ ] `~/.claude/statusline-command.sh` has `jobs_badge` variable (if JOBS configured)
- [ ] `.claude/statusline-jobs.sh` is executable and emits a count or exits non-zero (optional, per project)
- [ ] Verification run shows `(up)` after the website URL
- [ ] Verification run shows `✓CI` or `✗CI` next to the git branch (if repo has GitHub Actions)
- [ ] Verification run shows `✓JOBS` or `✗JOBS(N)` next to the CI badge (if hook configured)
