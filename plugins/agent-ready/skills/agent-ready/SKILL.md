---
name: agent-ready
description: "Use when: the user wants to audit or improve a website's AI-agent readiness, mentions isitagentready.com, is-agentic.com, agent-ready, agentic readiness, Content-Signal, llms.txt, MCP server card, well-known endpoints for agents, AI bot rules in robots.txt, markdown content negotiation, x402/ACP/UCP commerce protocols, or asks 'is my site agent ready?' or 'score my site for AI agents'. Works on any site/framework; for Rails-specific drop-in code it chains to rails:rails-seo."
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
argument-hint: "example.com | audit https://example.com | make my site agent-ready"
---

# Agent-Ready — Combined AI-Agent Readiness Audit

One skill covering both public scoring standards:

| Scorer | Model | Focus |
|--------|-------|-------|
| [isitagentready.com](https://isitagentready.com) | 5 dimensions: Discoverability, Content Accessibility, Bot Access Control, Protocol Discovery, Commerce | Files, headers, and protocol artifacts (robots.txt, Content-Signal, MCP server card, llms.txt, well-known endpoints, x402/ACP) |
| [is-agentic.com](https://is-agentic.com) | Essential checks (80-pt pool) + Recommended checks (20-pt pool) + up to 5 bonus points for emerging signals | Behavior: server-rendered content, correct HTTP status codes, clear document structure, recoverable errors, usable controls; conditional checks for API, OAuth, GraphQL, MCP, developer portal, commerce |

The two overlap heavily. This skill audits once against the **union** of both rubrics, then reports per-scorer.

## Workflow

### Step 1 — Identify the target

Ask for the domain if not given. Determine whether you also have the site's codebase locally (then you can fix findings, not just report them).

### Step 2 — Run the automated scan (is-agentic CLI)

```sh
npx is-agentic <domain>
```

This returns the is-agentic.com report (scores, evidence, recommendations). If npx is unavailable or fails, fall back to the API:

```sh
curl -s "https://is-agentic.com/api/v1/report?url=https://<domain>" | python3 -m json.tool
```

isitagentready.com has no CLI — cover its rubric with the manual probes in Step 3, and tell the user to paste the URL at https://isitagentready.com for the official score.

### Step 3 — Manual probes (union checklist)

Run each probe with curl. Record pass/fail.

```sh
D=https://example.com

# --- Discoverability ---
curl -s $D/robots.txt                                  # exists? valid? Sitemap: line?
curl -s $D/sitemap.xml -o /dev/null -w "%{http_code}"  # or sitemap.xml.gz
curl -sI $D/ | grep -i '^link:'                        # discovery Link headers
curl -s $D/llms.txt -o /dev/null -w "%{http_code}"

# --- Bot Access Control ---
curl -s $D/robots.txt | grep -iE "GPTBot|ClaudeBot|Google-Extended|CCBot|PerplexityBot"
curl -s $D/robots.txt | grep -i "Content-Signal"

# --- Content Accessibility ---
curl -sI -H "Accept: text/markdown" $D/ | grep -iE "content-type|vary|x-markdown"
curl -s $D/ | head -c 2000                             # server-rendered HTML? (not an empty JS shell)

# --- HTTP correctness (is-agentic essentials) ---
curl -s $D/definitely-missing-404 -o /dev/null -w "%{http_code}\n"   # must be 404, not 200
curl -sI $D | grep -i "^HTTP\|location"                # sane redirects, no chains

# --- Protocol Discovery ---
curl -s $D/.well-known/mcp/server-card.json -o /dev/null -w "%{http_code}\n"
curl -s $D/.well-known/agent-skills/index.json -o /dev/null -w "%{http_code}\n"
curl -s $D/.well-known/api-catalog -o /dev/null -w "%{http_code}\n"          # RFC 9727
curl -s $D/.well-known/oauth-protected-resource -o /dev/null -w "%{http_code}\n"  # RFC 9728
curl -s $D/.well-known/oauth-authorization-server -o /dev/null -w "%{http_code}\n"
curl -s $D/openapi.json -o /dev/null -w "%{http_code}\n"

# --- Structure ---
curl -s $D/ | grep -icE "<h1|<main|<nav|application/ld\+json"   # semantic structure + JSON-LD
```

Commerce checks (only if the site sells anything): look for x402 payment headers, ACP (Agentic Commerce Protocol), UCP, or MPP endpoints. Most sites score N/A here — both scorers exclude non-applicable checks.

### Step 4 — Report

Produce one table with a row per check, columns: Check | Result | isitagentready dimension | is-agentic layer | Fix effort (S/M/L). Lead with the quick wins.

### Step 5 — Fix (if codebase available)

Read `references/implementation.md` for drop-in fixes ordered by effort. For a Rails app, prefer the `rails:rails-seo` skill (its `references/agent-ready.md` has Rails-native controllers, routes, and concerns for the same endpoints).

### Step 6 — Verify

Re-run Step 2 and Step 3 after deploy. Tell the user to confirm at both scorers:

```sh
npx is-agentic <domain>
open https://isitagentready.com
```

## Quick wins (highest score per effort, both rubrics)

1. **AI bot rules in robots.txt** — explicit `User-Agent:` blocks for GPTBot, ClaudeBot, Google-Extended, CCBot, PerplexityBot, with `Allow:` or `Disallow:` matching the user's content policy. Ask before choosing allow vs block for training bots.
2. **Content-Signal directive** in robots.txt: `Content-Signal: ai-train=no, ai-input=yes, search=yes` (adjust to policy).
3. **llms.txt** at the root — markdown site guide for agents.
4. **Sitemap** referenced from robots.txt.
5. **Link headers** on the homepage pointing at llms.txt, sitemap, and the MCP server card.
6. **Correct 404s** — a missing page must return HTTP 404, not a 200 soft-404. This is an is-agentic essential.
7. **Server-rendered content** — the homepage HTML must contain real content without JavaScript execution.

Only ~4% of sites implement Content Signals and markdown negotiation; the quick wins alone move a site ahead of ~96% of the web.

## References

- `references/implementation.md` — framework-agnostic drop-in files and header configs for every check
- Rails apps: use `rails:rails-seo` → `references/agent-ready.md`
