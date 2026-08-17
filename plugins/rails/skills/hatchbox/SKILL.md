---
name: hatchbox
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
  - AskUserQuestion
description: |
  Set up, configure, and deploy a Rails app on Hatchbox.io using the `hatchbox` CLI.
  Use when the user wants to: create a Hatchbox app, set environment variables,
  set RAILS_MASTER_KEY, provision or attach a Postgres database, add a custom
  domain with SSL, or turn on automatic deploys from GitHub. Also trigger on
  "hatchbox", "deploy to hatchbox", "set env vars on hatchbox", "my hatchbox
  deploy failed", "add a domain to hatchbox", "hatchbox database", or when you
  see HATCHBOX_REVISION, HATCHBOX_RELEASE, or HATCHBOX_SKIP_MIGRATE.
argument-hint: "setup, env, master-key, database, domain, deploy, auto-deploy"
version: "1.0.0"
---

# Rails on Hatchbox

Configure a Rails app on [Hatchbox.io](https://hatchbox.io) with the `hatchbox` CLI.

> **Hatchbox has no official CLI.** This skill uses `blairanderson/hatchbox-cli`,
> an open-source wrapper over the Hatchbox REST API. Do not use
> `ryanckulp/hatchbox_cli` — it is an unrelated bash function that only opens a
> console and tails logs.

## Safety rules

Follow these rules in every phase.

1. **Never print a token.** Do not echo `HATCHBOX_API_KEY`. Use `hatchbox config show` — it masks the token.
2. **Never print a database URI.** `databases get` returns live plaintext credentials. Pipe it to a check, not to the transcript.
3. **Confirm before you change production.** Ask the user before `env set`, `apps deploy`, `domains remove`, or `databases detach`.
4. **A deploy is queued, not done.** `apps deploy` returns a log id. Poll it. Do not report success until the log state is `completed`.

## Phase 0 — Prerequisites

Run these checks before anything else. Stop at the first failure.

```bash
hatchbox --version                 # CLI installed?
hatchbox config show               # token saved? (masked output)
hatchbox accounts list             # token valid + subscription active?
```

| Failure | Fix |
|---|---|
| `hatchbox: command not found` | `brew install blairanderson/tap/hatchbox` (needs ruby) |
| Empty or missing token | Create one at `https://hatchbox.io/api_tokens`, then export `HATCHBOX_API_KEY` |
| `401` | Token is wrong or revoked. Create a new one. |
| `402` | The account has no active subscription. Only `accounts list` works without one. The user must fix billing. |

The CLI reads the token from `--token`, then `HATCHBOX_API_KEY`, `HATCHBOX_TOKEN`,
`HATCHBOX_API_TOKEN`, then its config file (`hatchbox config path`).

Set the default account so later commands do not need `-a`:

```bash
hatchbox accounts list
hatchbox accounts use <account_id>   # skip if you have only one account
```

## Phase 1 — Find or create the app

**Always look first.** Creating a duplicate app is the most common mistake.

```bash
hatchbox apps list
```

If the app exists, save it as the default and skip to Phase 2:

```bash
hatchbox apps use <app_id>
```

If it does not exist, you need a cluster and a connected git provider:

```bash
hatchbox clusters list          # need a cluster with an active server
hatchbox git-providers list     # need the connected_account_id
hatchbox apps create --cluster-id <id> --name <name> \
  --repo-path <user/repo> --branch main --connected-account-id <id>
```

> **`apps create` does not provision servers.** It registers an app against a
> cluster that must already have an active server. If the cluster is empty, the
> app is created but every deploy fails with
> `No active servers available to deploy to`. Check `hatchbox clusters get <id>`
> and confirm at least one server has state `active` before you continue.

Ask the user to create the cluster in the Hatchbox UI if none exists. The CLI
cannot provision infrastructure.

## Phase 2 — Environment variables

### Set the master key first

A Rails app will not boot without it. Hatchbox does **not** inject it.

Run this from inside the Rails repo:

```bash
hatchbox master-key
```

It reads `git remote get-url origin`, finds the app whose `repo_path` matches,
reads `config/credentials/production.key` (or `config/master.key` if that is
absent), asks you to confirm, then sets `RAILS_MASTER_KEY`.

If the key is missing on this machine, stop and route the user to `/op:sync` or
`/ts-sync:sync` to restore it. Do not generate a new key — that makes the
existing credentials file unreadable.

> Symptom of a missing or wrong key:
> `ActiveSupport::MessageEncryptor::InvalidMessage` in the deploy log.

### Set the rest

```bash
hatchbox env list <app_id>                      # names only — values are never returned
hatchbox env set <app_id> RAILS_ENV=production RAILS_LOG_TO_STDOUT=true
hatchbox env unset <app_id> OLD_KEY
```

Rules to respect:

- Names are upcased and must match `[A-Z_][A-Z0-9_]*`.
- The API never returns values. `env list` shows names only. You cannot read a value back to verify it — set it again if in doubt.
- Changing an env var triggers a server update.

### Variables Hatchbox injects for you

Do not set these by hand:

| Variable | Value |
|---|---|
| `HATCHBOX_BRANCH` | Branch that was deployed |
| `HATCHBOX_RELEASE` | Release number |
| `HATCHBOX_REVISION` | Git commit SHA |

Hatchbox also writes a `REVISION` file containing the SHA.

> **Do not confuse these with deploy-script variables.** Inside a deploy or
> post-deploy script only, Hatchbox sets `$DIR`, `$RELEASE_DIR`, `$RELEASE`,
> `$REVISION`, `$LOG_ID`, `$BRANCH`, and `$ROLES`. These have **no**
> `HATCHBOX_` prefix and are not visible to the running app.

## Phase 3 — Database

Ask the user which path they are on. The two paths behave differently.

### Path A — Unmanaged (free, runs in your cluster)

Assign the `postgresql` role to a server in the cluster (Hatchbox UI). Hatchbox
installs the package. Then create the database and attach it:

```bash
hatchbox db-clusters list
hatchbox databases create <db_cluster_id> --name my_app_production
hatchbox databases attach <app_id> <db_id>
hatchbox databases app-list <app_id>
```

### Path B — Managed (DigitalOcean, RDS, Crunchy)

Create the database at the provider, then set the URL by hand:

```bash
hatchbox env set <app_id> DATABASE_URL='postgres://...'
```

### The attachment trap

**Attaching is what sets the env var.** Creating a database does not.

If `DATABASE_URL` is already taken, Hatchbox silently picks a colour-prefixed
name instead — `RED_DATABASE_URL`, then `BLUE_DATABASE_URL`. Read the actual
name back rather than assuming:

```bash
hatchbox databases app-list <app_id> --json    # read app_attachments[].env_var
```

If the name is not `DATABASE_URL`, the Rails app will not find the database.
Either detach and re-attach with `--env-var DATABASE_URL`, or point
`config/database.yml` at the name Hatchbox chose.

### Connection URIs

| Field | When present | Use |
|---|---|---|
| `private_connection_uri` | Every engine except SQLite | What the app should use. Private network, same cluster. |
| `public_connection_uri` | **Managed clusters only** | Omitted on unmanaged clusters — their "public" host is just the server IP. |

Hatchbox blocks public database access on unmanaged clusters. To reach the
database from a laptop you need an SSH tunnel to the server as user `deploy`,
with database host `127.0.0.1`. That is what `/rails:pgsync` sets up — route
there instead of hand-rolling it.

Clusters with SSL enabled append `?sslmode=require` to the URI.

## Phase 4 — Domain and SSL

```bash
hatchbox domains list <app_id>
hatchbox domains add <app_id> example.com
```

Then point DNS at the server:

```bash
hatchbox clusters get <cluster_id>    # read public_ip of the server whose roles include web
```

| Record | Value |
|---|---|
| **A** | The server's `public_ip` |

It is an **A record to the IPv4 address**, not a CNAME. Use the server with
state `active` whose roles include `web` — or `load_balancer` if the cluster has one.

Every app also gets a free `*.hatchboxapp.com` subdomain with SSL already working.

### SSL

Caddy requests a Let's Encrypt certificate automatically on the first HTTPS
request, and renews it. Adding the domain in Hatchbox does two jobs: it tells
Caddy which app to route to, and it gives Caddy the domain list for the
certificate.

### Behind Cloudflare

Two settings are documented by Hatchbox and are not optional:

1. **SSL mode must be `Full`.** `Flexible` causes an infinite redirect loop
   (`ERR_TOO_MANY_REDIRECTS`) because Caddy always redirects to HTTPS.
2. **Minimum TLS version 1.2.**

For a wildcard certificate (`*.example.com`), Caddy must solve a DNS-01
challenge. Give Hatchbox a Cloudflare **API Token** (not the global API Key)
with `Zone / Zone / Read` and `Zone / DNS / Edit`, in the Wildcard SSL Settings
section. Supported providers: Cloudflare, DigitalOcean, AWS Route53.

> **Precaution, not a documented Hatchbox rule.** Hatchbox's docs never mention
> the orange cloud. But a proxied record terminates TLS at Cloudflare's edge and
> strips the `acme-tls/1` ALPN, so Caddy's TLS-ALPN-01 challenge fails; the
> HTTP-01 fallback can also fail if "Always Use HTTPS" redirects the
> `/.well-known/acme-challenge/` request. Safest order: add the A record
> **DNS-only (grey cloud)**, load the site over HTTPS once to force issuance,
> then turn the proxy on. Tell the user this is a precaution, not a Hatchbox
> requirement.

For the Rails-side Cloudflare configuration — `assume_ssl`, real client IP,
cookie flags, CSRF — route to `/rails:cloudflare`. Do not repeat that work here.

If a firewall needs to allow Hatchbox itself: `138.197.51.75`,
`104.131.53.138`, `2604:a880:800:14::17a:1000`.

## Phase 5 — Automatic deploys from GitHub

First connect the repo: install the Hatchbox GitHub App from the app's
Connected Accounts page, grant it the org, then pick the repository. The CLI
cannot do this — it is an OAuth flow.

Then:

```bash
hatchbox apps auto-deploy enable <app_id>
hatchbox apps auto-deploy disable <app_id>
```

This registers a webhook on the git host. A `502` means the git host rejected
the webhook — usually the GitHub App is not installed on that repository.

### Alternative: deploy from GitHub Actions

Use this when you want tests to pass before a deploy.

```yaml
- uses: hatchboxio/github-hatchbox-deploy-action@v2
  with:
    deploy_key: ${{ secrets.HATCHBOX_DEPLOY_KEY }}
```

The action is a single `curl` to the deploy webhook. The token is on the app's
Repository page under "Trigger a deploy via webhook".

> The webhook host is `app.hatchbox.io`. The REST API host is `hatchbox.io`.
> They are different. Do not mix them.

### Migrations

Hatchbox runs `rails db:migrate` on deploy, but **only if a server in the
cluster holds the `cron` role**. The default Rails deploy script ends with:

```bash
[[ -n "${CRON}" ]] && bundle exec rails db:migrate
```

So if no server has the `cron` role, migrations silently never run and the app
boots against an old schema. Check the roles in `hatchbox clusters get <id>`.

Set `HATCHBOX_SKIP_MIGRATE=1` to turn the automatic migration off.

## Phase 6 — Deploy and verify

```bash
hatchbox apps deploy <app_id>              # returns a log id
hatchbox logs watch <log_id>               # poll until it finishes
```

Log states: `pending`, `processing`, `completed`, `failed`, `aborted`.

A `200` from deploy means **accepted**, not finished. Only report success on
`completed`.

```bash
hatchbox processes list <app_id>           # are the processes up?
hatchbox apps restart <app_id>             # if a process is wedged
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `402` on every call | No active subscription | Fix billing in the Hatchbox UI |
| `No active servers available to deploy to` | Cluster has no active server | Add a server, or pick another cluster |
| `ActiveSupport::MessageEncryptor::InvalidMessage` | `RAILS_MASTER_KEY` missing or wrong | `hatchbox master-key` from the repo |
| App cannot find the database | Attachment used a colour-prefixed env var | Read `app_attachments[].env_var`; re-attach with `--env-var DATABASE_URL` |
| Schema is stale after deploy | No server holds the `cron` role | Assign the role, or migrate by hand |
| `ERR_TOO_MANY_REDIRECTS` | Cloudflare SSL mode is `Flexible` | Set it to `Full` |
| Certificate never issues | Proxied record blocks the ACME challenge | Set the record DNS-only, force issuance, then proxy |
| `502` on `auto-deploy enable` | GitHub App not installed on the repo | Install it, then retry |
| Deploy "succeeded" but nothing changed | You read the queued response, not the log | `hatchbox logs watch <log_id>` |

## Related skills

| Need | Skill |
|---|---|
| Cloudflare proxy config in Rails | `/rails:cloudflare` |
| Pull production data to local | `/rails:pgsync` |
| Restore a missing `master.key` | `/op:sync` or `/ts-sync:sync` |
| Email sending and receiving | `/rails:postmark` |
| Uptime watch in the status line | `/statusline:statusline-health` |
