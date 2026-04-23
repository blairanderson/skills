# Rails Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install rails@blairanderson-skills 
```

This plugin adds four skills for Rails development.

---

## `/rails-authentication`

End-to-end authentication setup using Rails 8's built-in generator.

Walks through the full auth stack in phases:

1. **Discovery** — clarifies requirements before touching code (sign-up flow, email verification, organizations, roles, OAuth, 2FA)
2. **Generator** — runs `bin/rails generate authentication` and explains what it creates
3. **Sign-up** — adds `RegistrationsController` and the registration form (the generator omits this)
4. **Email verification** — `generates_token_for :email_verification` with configurable access gating
5. **Accounts / Organizations** — `Account` + `Membership` join model for multi-tenant B2B apps
6. **Roles & Permissions** — role stored on `Membership`, with guidance on when to reach for Pundit
7. **Invitations** — signed token invite flow for existing and new users
8. **OAuth / Social Login** — OmniAuth + `ConnectedAccount` model

Reference docs are included for 2FA, API tokens, session management, rate limiting, and account settings.

---

## `/rails-seo`

Audits and improves SEO for Ruby on Rails applications.

Covers nine areas against Joost de Valk's SEO framework, ported to Ruby:

| Concern | Gem / technique |
|---|---|
| Head metadata | `meta-tags` |
| Structured data | `schema_dot_org` + custom `Seo::Graph` helper |
| Sitemaps | `sitemap_generator` |
| Open Graph images | `grover` + `image_processing` + Active Storage |
| IndexNow | Custom Faraday client in a Solid Queue job |
| llms.txt & schema endpoints | Custom controllers |
| Agent discovery | `.well-known/` endpoints, MCP server card |

Works for both Sitepress content sites (`app/content/pages/`) and standard ActiveRecord apps.

---

## `/rails-conductor-setup-config`

Configures a Rails app to work inside [Conductor](https://conductor.sh) workspaces.

Creates or merges the minimum set of files needed so each workspace boots on its own assigned port:

- `conductor.json` — tells Conductor which scripts to run
- `bin/conductor-setup` — symlinks `.env`, credentials, storage, and `.bundle` from the repo root
- `script/server` — starts the dev server with `CONDUCTOR_PORT` → `PORT` → `3000` fallback
- `config/initializers/default_host.rb` — makes URL generation and mailer links respect `PORT`
- `config/puma.rb` — merges in the port binding if missing

All edits are additive — existing working configs are never replaced wholesale.

---

## `/pgsync`

Sets up `bin/pgsync-tunnel` to sync production Postgres data to your local dev database via an SSH tunnel. Designed for apps hosted on [Hatchbox.io](https://hatchbox.io).

Creates four files:

| File | Committed | Purpose |
|---|---|---|
| `bin/pgsync-tunnel` | yes | SSH tunnel + pgsync wrapper |
| `.pgsync.yml` | yes | Tables and groups to sync (no secrets) |
| `.env.pgsync.example` | yes | Template for teammates |
| `.env.pgsync` | no (gitignored) | Real credentials |

Usage after setup:

```sh
bin/pgsync-tunnel              # sync everything in .pgsync.yml
bin/pgsync-tunnel users        # one table
bin/pgsync-tunnel group:core   # a named group
```

The tunnel opens automatically before pgsync runs and closes when it finishes.
