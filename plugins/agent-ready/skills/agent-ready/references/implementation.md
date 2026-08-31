# Implementation Recipes (Framework-Agnostic)

Drop-in files and configs for every check in the combined rubric. Ordered by effort. Rails apps: prefer the Rails-native versions in `rails:rails-seo` → `references/agent-ready.md`.

## 1. robots.txt — AI bot rules + Content-Signal + Sitemap

Static file at the web root. Ask the user for their AI-training policy first.

```text
User-agent: *
Allow: /

# AI crawlers — explicit allow (or Disallow: / to block)
User-Agent: GPTBot
Allow: /

User-Agent: ClaudeBot
Allow: /

User-Agent: Google-Extended
Allow: /

User-Agent: CCBot
Allow: /

User-Agent: Anthropic-AI
Allow: /

User-Agent: PerplexityBot
Allow: /

Content-Signal: ai-train=no, ai-input=yes, search=yes

Sitemap: https://example.com/sitemap.xml
```

Content-Signal values: `search` (search indices), `ai-input` (real-time AI answers), `ai-train` (model training). `ai-train=no, ai-input=yes` allows AI answers but blocks training harvest.

To block training entirely, switch CCBot and GPTBot to `Disallow: /`.

## 2. llms.txt — agent site guide

Static markdown file at `/llms.txt`:

```markdown
# Example Site

> One-sentence description of what this site is.

## Main pages

- [Docs](https://example.com/docs): Product documentation
- [Pricing](https://example.com/pricing): Plans and pricing
- [API](https://example.com/openapi.json): OpenAPI specification

## Machine-readable

- Sitemap: https://example.com/sitemap.xml
- MCP server card: https://example.com/.well-known/mcp/server-card.json
```

## 3. Link headers for discovery

Send on the homepage (at minimum):

```text
Link: </llms.txt>; rel="ai-readiness", </sitemap.xml>; rel="sitemap", </.well-known/mcp/server-card.json>; rel="mcp-server"
```

Per-server config:

- **Nginx**: `add_header Link '</llms.txt>; rel="ai-readiness", </sitemap.xml>; rel="sitemap"';`
- **Cloudflare**: Rules → Transform Rules → Modify Response Header.
- **Netlify** (`_headers` file):
  ```text
  /*
    Link: </llms.txt>; rel="ai-readiness", </sitemap.xml>; rel="sitemap"
  ```
- **Vercel** (`vercel.json`): `"headers": [{ "source": "/(.*)", "headers": [{ "key": "Link", "value": "</llms.txt>; rel=\"ai-readiness\"" }] }]`

## 4. Well-known endpoints

Serve as static JSON files under `/.well-known/` (works on any static host) or as routes.

### `/.well-known/mcp/server-card.json`

```json
{
  "protocol_version": "2025-03-26",
  "name": "Example Site MCP",
  "description": "Machine-readable access to Example Site content and APIs.",
  "tools": [],
  "resources": [
    { "uri": "https://example.com/posts.json", "description": "All posts as JSON" }
  ],
  "auth": "none"
}
```

If the site runs a real MCP server, point at it and list its tools. If not, a resource-only card still scores.

### `/.well-known/agent-skills/index.json`

```json
{
  "skills": [
    { "name": "search", "description": "Search content by query", "endpoint": "https://example.com/search.json?q={query}" }
  ]
}
```

### `/.well-known/api-catalog` (RFC 9727)

Content-Type must be `application/linkset+json`:

```json
{
  "linkset": [
    {
      "anchor": "https://example.com/",
      "item": [
        { "href": "https://example.com/openapi.json", "type": "application/json", "title": "OpenAPI spec" },
        { "href": "https://example.com/sitemap.xml", "type": "application/xml", "title": "Sitemap" },
        { "href": "https://example.com/feed.xml", "type": "application/rss+xml", "title": "RSS Feed" }
      ]
    }
  ]
}
```

### OAuth discovery (only if the site has authenticated APIs)

- `/.well-known/oauth-authorization-server` (RFC 8414)
- `/.well-known/oauth-protected-resource` (RFC 9728)
- Optional `/auth.md` — human/agent-readable auth instructions.

Skip these when there is no API auth; both scorers treat them as conditional.

## 5. Markdown content negotiation

Serve `text/markdown` when the request has `Accept: text/markdown`. Always include:

```text
Vary: Accept
Content-Type: text/markdown; charset=utf-8
x-markdown-tokens: <length/4 estimate>
```

`Vary: Accept` is mandatory — without it a CDN caches HTML and serves it to markdown requests. `x-markdown-tokens` (rough 4-chars-per-token) lets agents budget context before fetching.

Static-site shortcut: publish a parallel `.md` file next to each page and link it with `<link rel="alternate" type="text/markdown" href="page.md">`.

## 6. HTTP correctness (is-agentic essentials)

- **404s must be 404** — no soft-404 (200 with "not found" body). Test: `curl -o /dev/null -w "%{http_code}" https://example.com/nope-$(date +%s)`.
- **Redirects**: single hop, 301/308 for permanent moves. No redirect chains or loops.
- **Server-rendered content**: the initial HTML response must contain the page content. JS-only shells fail agents that do not execute JavaScript. Use SSR, SSG, or prerendering.
- **Error recovery**: error pages should link back to working navigation and search.
- **Document structure**: one `<h1>`, semantic `<main>/<nav>`, JSON-LD structured data where applicable.

## 7. Commerce protocols (only for sites that sell)

Emerging, low-adoption; implement only if the user asks:

- **x402** — HTTP 402-based agent payments.
- **ACP** (Agentic Commerce Protocol) — OpenAI/Stripe checkout for agents.
- **UCP** (Universal Commerce Protocol), **MPP** — declare in the well-known/api-catalog surface when supported.

## Verification

```sh
D=https://example.com
curl -s $D/robots.txt | grep -E "GPTBot|Content-Signal|Sitemap"
curl -s $D/llms.txt | head -5
curl -sI $D/ | grep -i '^link:'
curl -s $D/.well-known/mcp/server-card.json | python3 -m json.tool
curl -s $D/.well-known/api-catalog | python3 -m json.tool
curl -sI -H "Accept: text/markdown" $D/ | grep -iE "content-type|vary"
curl -s -o /dev/null -w "%{http_code}\n" $D/definitely-missing-404
npx is-agentic <domain>
```

Then paste the URL at https://isitagentready.com for the official five-dimension score.
