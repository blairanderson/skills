---
name: new-app-checklist
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
description: |
  Production readiness checklist for a new Rails app. Routes to the other Rails
  skills in dependency order — conventions, key backup, auth, Hatchbox, Cloudflare,
  Postmark, SEO, monitoring. Use when the user says "new app checklist", "I just
  ran rails new", "get this app production ready", "what's left before launch",
  "set up a new Rails app", "ship this app", "launch checklist", or asks what to
  configure first on a fresh Rails project. Also use when the user wants to audit
  an existing app for missing production setup.
argument-hint: "audit, next, all, skip <step>"
version: "1.0.0"
---

# New Rails App — Production Checklist

**This skill is a router. It does not do the work itself.** It finds what is
missing, then hands each step to the skill that owns it. Never re-implement a
step here — if a target skill is wrong, fix that skill.

## How to run it

1. Run Phase 0 and print the status table. Always. Do not skip to a step.
2. Walk the gates in order. Each gate is a dependency of the ones after it.
3. **Stop at each gate.** Show what is missing, name the skill, ask before invoking.
4. Never mark a gate done because you invoked a skill. Mark it done when the
   check passes.

## Phase 0 — Detect the current state

Run all of these. They are read-only.

```bash
# Identity
git remote get-url origin 2>/dev/null
grep -m1 "^ruby\|rails (" Gemfile.lock 2>/dev/null

# Gate 1 — conventions
ls CLAUDE.md 2>/dev/null

# Gate 2 — credentials
ls config/master.key config/credentials/production.key 2>/dev/null
grep -n "master.key" .gitignore 2>/dev/null

# Gate 3 — auth
ls app/models/user.rb app/controllers/sessions_controller.rb 2>/dev/null
grep -rn "has_secure_password" app/models/ 2>/dev/null

# Gate 4 — Hatchbox
command -v hatchbox >/dev/null && hatchbox apps list 2>/dev/null

# Gate 5 — Cloudflare
grep -n "assume_ssl\|force_ssl" config/environments/production.rb 2>/dev/null

# Gate 6 — email
grep -n "postmark\|delivery_method" Gemfile config/environments/production.rb 2>/dev/null

# Gate 7 — SEO
grep -n "meta-tags\|sitemap_generator\|schema_dot_org" Gemfile 2>/dev/null

# Gate 9 — prod data
ls bin/pgsync-tunnel 2>/dev/null
```

Then print this table, filled in. Use ✅ done, ⬜ missing, ⏭️ not applicable.

```
NEW APP CHECKLIST — <app name>
  1. ⬜ Conventions          CLAUDE.md
  2. ⬜ Credentials backed up master.key in 1Password / Tailscale
  3. ⬜ Authentication       users + sessions
  4. ⬜ Hatchbox             app, env, database, domain, auto-deploy
  5. ⬜ Cloudflare           assume_ssl, real IP, cookie flags
  6. ⬜ Email                Postmark outbound + inbound
  7. ⬜ SEO                  head tags, sitemap, OG images
  8. ⬜ Monitoring           uptime in the status line
  9. ⬜ Prod data locally    pgsync tunnel
```

## The gates

Work top to bottom. The order encodes real dependencies — gate 5 needs the
server IP from gate 4, gate 7 needs a live domain from gate 5.

### Gate 1 — Conventions → `/rails:claude-file`

**Do this first.** It sets the rules every later step is written under. Doing it
after the code exists means retrofitting.

Skip if `CLAUDE.md` exists and covers the Rails conventions.

### Gate 2 — Credentials backed up → `/op:sync` or `/ts-sync:sync`

**Do this the day the app is created.** A lost `master.key` makes
`config/credentials.yml.enc` permanently unreadable. There is no recovery.

Ask which one the user wants:

| Skill | Stores in | Pick it when |
|---|---|---|
| `/op:sync` | 1Password | You want the key on any machine, including new ones |
| `/ts-sync:sync` | Your own machines over SSH/Tailscale | You do not want a third party holding it |

Also confirm `config/master.key` is in `.gitignore`. If the key was ever
committed, say so plainly — it must be rotated, not just removed.

### Gate 3 — Authentication → `/rails:rails-authentication`

Do it before the schema fills up. Auth decides what a `User` is and what every
later table joins to. Retrofitting it means a migration through live data.

Skip if the app is genuinely public with no accounts.

### Gate 4 — Hatchbox → `/rails:hatchbox`

This one gate covers app creation, environment variables, `RAILS_MASTER_KEY`,
the Postgres database, the custom domain, and automatic deploys from GitHub —
they are one platform with one API token.

Two outputs from this gate feed later gates:

- the server's **public IP**, needed for the Cloudflare A record in gate 5
- a **live domain**, needed for gates 6, 7, and 8

Do not continue past this gate until a deploy log reaches `completed`.

### Gate 5 — Cloudflare → `/rails:cloudflare`

Two halves. Do not confuse them:

| Half | Where | Owner |
|---|---|---|
| A record → server IP, SSL mode `Full`, proxy status | Cloudflare dashboard | `/rails:hatchbox` gate 4 |
| `assume_ssl`, real client IP, cookie flags, CSRF | `config/environments/production.rb` | **this gate** |

The Rails half is the one people forget. Without `assume_ssl`, Rails sees plain
HTTP behind the proxy, drops the `secure` flag on cookies, and sessions break in
ways that look random.

### Gate 6 — Email → `/rails:postmark`

Needs a domain you control (gate 4) and DNS access (gate 5).

Covers outbound sending and inbound receiving. Run
`scripts/postmark-doctor.sh dns <domain>` from that skill to verify the records
rather than reading the dashboard by eye.

Do not skip this because "the app does not send email yet." Password reset is
email. Auth in gate 3 already depends on it.

### Gate 7 — SEO → `/rails:rails-seo`

Cheap now, painful later. Head metadata, JSON-LD, sitemaps, and OG images are
easy on an empty app and a retrofit on a full one. Needs a live domain for
canonical URLs and sitemap hosts.

### Gate 8 — Monitoring → `/statusline:statusline-health`

Puts the app's uptime in the Claude Code status line, reading `/up.json`. Do it
right after the first successful deploy — the point is to notice the *second*
deploy breaking.

### Gate 9 — Production data locally → `/rails:pgsync`

Last, because it needs a production database with real rows in it. Sets up
`bin/pgsync-tunnel` over SSH to the Hatchbox server.

## Optional — only if the user uses the tool

Ask before suggesting these. They are not part of a default setup.

| Skill | Add it when |
|---|---|
| `/rails:rails-conductor-setup-config` | The user runs Conductor workspaces |
| `/rails:worktrees` | The user works several branches in parallel and wants isolated databases |
| `/verification-skill:create` | The user wants a project-local QA skill that drives the app like a user |

## Ongoing — do not run these from the checklist

These repeat forever. They are not setup. List them once at the end so the user
knows they exist, then stop.

| Need | Skill |
|---|---|
| CI failed | `/fix:fix-last-run` |
| Background jobs failing | `/fix:fix-failing-jobs` |
| Ship a small fix to master | `/hotfix:hotfix` |
| Review changes for bugs | `/diff-review:diff-review` |
| Track tasks | `/issues:capture`, `plan`, `work`, `triage`, `done` |
| Product cadence | `/pm:pm` |
| Bump the Rails version | `/rails:rails-upgrade` |
| Announce a shipped feature | `/document-feature`, `/stakeholders:feature-draft` |
| Keep the QA skill honest | `/verification-skill:maintain` |
| Run an autonomous agent loop | `/rails:ralph` |

## Finish

Print the table again with the updated marks. Then state one of:

- **Ready to ship** — gates 1 to 8 pass.
- **Not ready** — list the open gates and the single next action.

Do not claim a gate passes without running its check.
