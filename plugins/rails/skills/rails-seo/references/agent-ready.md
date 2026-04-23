# Agent-Ready Rails: isitagentready.com Recipe

This reference covers the technical steps to improve your site's score on [isitagentready.com](https://isitagentready.com) — the five-dimension rubric (Discoverability, Content Accessibility, Bot Access Control, Protocol Discovery, Commerce) that measures readiness for AI agent crawlers, not just search engines.

Only ~4% of sites implement Content Signals and markdown negotiation. Adding even the Quick Wins section puts you ahead of 96% of the web.

---

## Quick Wins

### 1. AI Bot Rules in `public/robots.txt`

Existing robots.txt typically covers only search engines. AI crawlers have their own `User-Agent` strings. Add explicit `Allow` blocks (permitting crawling) or `Disallow` blocks (blocking) per crawler:

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

Sitemap: https://example.com/sitemap.xml.gz
Schemamap: https://example.com/schemamap.xml
```

If you want to block AI training (but allow search and real-time answers):

```text
User-Agent: CCBot
Disallow: /

User-Agent: GPTBot
Disallow: /
```

### 2. Content-Signal Directive

Content Signals declare how crawlers may use your content. Add this line to `public/robots.txt`:

```text
Content-Signal: ai-train=no, ai-input=yes, search=yes
```

Three values:
- `search` — building search indices (yes = allow, no = block)
- `ai-input` — feeding content into AI models for real-time answers (e.g. ChatGPT, Perplexity)
- `ai-train` — training or fine-tuning AI models

Set `ai-train=no, ai-input=yes` to allow real-time AI answers but block training data harvesting. Adjust to match your content policy.

### 3. HTTP Link Headers for Discovery

Agents benefit from `Link` headers that point to machine-readable resources without requiring HTML parsing. Add a `Seo::LinkHeaders` concern:

```ruby
# app/controllers/concerns/seo/link_headers.rb
module Seo
  module LinkHeaders
    extend ActiveSupport::Concern

    included do
      after_action :set_agent_link_headers
    end

    private

    def set_agent_link_headers
      links = [
        %(<#{root_url}llms.txt>; rel="ai-readiness"),
        %(<#{root_url}sitemap.xml.gz>; rel="sitemap"),
        %(<#{root_url}.well-known/mcp/server-card.json>; rel="mcp-server"),
      ]
      response.headers["Link"] = links.join(", ")
    end
  end
end

# app/controllers/application_controller.rb
include Seo::LinkHeaders
```

---

## Well-Known Endpoints

Rails serves static files from `public/` automatically. For dynamic well-known endpoints, use a single controller.

### `WellKnownController`

```ruby
# app/controllers/well_known_controller.rb
class WellKnownController < ApplicationController
  # No CSRF, no auth — these are public discovery endpoints
  skip_before_action :verify_authenticity_token, raise: false

  # GET /.well-known/mcp/server-card.json
  # Exposes Model Context Protocol capabilities.
  # See: https://modelcontextprotocol.io/specification
  def mcp_server_card
    render json: {
      protocol_version: "2025-03-26",
      name: "#{Rails.application.config.site_name} MCP",
      description: "Machine-readable access to #{Rails.application.config.site_name} content and APIs.",
      tools: [],
      resources: [
        { uri: schema_posts_url, description: "All posts as JSON-LD" },
        { uri: schema_pages_url, description: "All pages as JSON-LD" },
      ],
      auth: "none"
    }
  end

  # GET /.well-known/agent-skills/index.json
  # Lists callable skills/actions available on this site for AI agents.
  # See: https://agentskills.io/specification
  def agent_skills
    skills = []
    skills << { name: "search", description: "Search content by query", endpoint: search_url(format: :json) } if respond_to?(:search_url)
    skills << { name: "posts", description: "Browse published posts", endpoint: schema_posts_url }
    render json: { skills: skills }
  end

  # GET /.well-known/api-catalog
  # RFC 9727 Linkset format — machine-readable index of all APIs.
  # Only expose this if the app has a public JSON API surface.
  def api_catalog
    render json: {
      linkset: [
        {
          anchor: root_url,
          item: [
            { href: schema_posts_url, type: "application/ld+json", title: "Posts JSON-LD" },
            { href: schema_pages_url, type: "application/ld+json", title: "Pages JSON-LD" },
            { href: feed_url, type: "application/rss+xml", title: "RSS Feed" },
            { href: "#{root_url}sitemap.xml.gz", type: "application/xml", title: "Sitemap" },
          ]
        }
      ]
    }, content_type: "application/linkset+json"
  end
end
```

### Routes

```ruby
# config/routes.rb
scope "/.well-known" do
  get "mcp/server-card", to: "well_known#mcp_server_card", format: false,
      constraints: ->(req) { req.format == :json || req.format == Mime::ALL }
  get "agent-skills/index", to: "well_known#agent_skills", format: false
  get "api-catalog", to: "well_known#api_catalog", format: false
end
```

The `format: false` constraint prevents Rails from mangling the URL with a `.json` suffix — these endpoints must live at their exact well-known paths.

---

## Improve Markdown Content Negotiation

The existing `accepting-markdown.md` recipe covers the core pattern. Two additional HTTP headers are required for full agent compatibility:

### `Vary: Accept`

Required for HTTP caches (CDN, Varnish, Rails page cache) to correctly key responses by format. Without it, a CDN may serve a cached HTML response to a client requesting markdown.

Add to the markdown format block in each controller:

```ruby
def show
  @post = Post.friendly.find(params[:id])
  respond_to do |format|
    format.html
    format.md do
      response.headers["Vary"] = "Accept"
      render markdown: @post.to_markdown
    end
  end
end
```

Or add it globally in the `prioritize_markdown_format` before-action concern from `accepting-markdown.md`.

### `x-markdown-tokens` Header

Optional but increasingly supported by agent frameworks — signals the approximate token count so agents can estimate context window usage before fetching.

```ruby
format.md do
  markdown = @post.to_markdown
  response.headers["Vary"] = "Accept"
  response.headers["x-markdown-tokens"] = (markdown.length / 4).to_s  # rough 4-chars-per-token estimate
  render plain: markdown, content_type: "text/markdown; charset=utf-8"
end
```

---

## Verification Checklist

After implementing, verify each endpoint:

```sh
# Link headers present on homepage
curl -sI https://example.com/ | grep -i link

# AI bot rules in robots.txt
curl -s https://example.com/robots.txt | grep -A2 "GPTBot"

# Content-Signal directive
curl -s https://example.com/robots.txt | grep "Content-Signal"

# MCP Server Card
curl -s https://example.com/.well-known/mcp/server-card.json | python3 -m json.tool

# Agent Skills index
curl -s https://example.com/.well-known/agent-skills/index.json | python3 -m json.tool

# API Catalog (RFC 9727)
curl -s https://example.com/.well-known/api-catalog | python3 -m json.tool

# Markdown negotiation with Vary header
curl -sI -H "Accept: text/markdown" https://example.com/posts/your-slug | grep -i "content-type\|vary\|x-markdown"

# Paste your URL into the scorer
open https://isitagentready.com
```

Expected results:
- `Link` header contains llms.txt, sitemap, and mcp-server rel values
- `robots.txt` has explicit `User-Agent: GPTBot` block and `Content-Signal:` line
- Well-known endpoints return valid JSON (200 OK)
- Markdown response includes `Vary: Accept` and `Content-Type: text/markdown`
