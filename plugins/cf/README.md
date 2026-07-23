# Cloudflare Workers Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install cf@blairanderson-skills
```

This plugin adds one comprehensive skill for auditing and configuring Cloudflare Workers projects.

---

## `/wrangler`

Audits and improves Cloudflare Workers projects — Wrangler CLI setup, `wrangler.toml` configuration, bindings (KV, D1, R2, Durable Objects), secrets management, local development, and deployment workflows.

The skill follows a phase-based workflow: detect the project, audit configuration and setup, improve with opinionated defaults, and verify deployment readiness.

| Concern | Tool / technique |
|---|---|
| CLI setup | `wrangler` via npm, authentication via `wrangler login` |
| Configuration | `wrangler.toml` with latest compatibility date |
| KV storage | Namespace creation + binding configuration |
| D1 databases | Database creation + migrations + binding |
| R2 buckets | Bucket creation + binding configuration |
| Durable Objects | Class binding + migration configuration |
| Workers AI | AI binding configuration |
| Secrets | `wrangler secret put` (never in config files) |
| Local dev | `wrangler dev` with local bindings |
| Deployment | `wrangler deploy` with dry-run verification |
| CI/CD | GitHub Actions workflow examples |

Works for Workers, Pages Functions, and projects using any combination of Cloudflare's platform features. Provides security-first defaults and local-first development patterns.
