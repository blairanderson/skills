# Jekyll Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install jekyll@blairanderson-skills
```

This plugin adds one skill for auditing and improving SEO on Jekyll sites.

---

## `/jekyll-seo`

Audits and improves the SEO setup of a Jekyll site. Covers nine areas and produces drop-in code, plugins, Rake tasks, and GitHub Actions workflows for anything missing or weak.

The opinionated spine is `jekyll-seo-tag` (the official SEO plugin), supplemented with custom `_includes/`, `_plugins/` generators, and Rake tasks where it falls short.

| Concern | Gem / technique |
|---|---|
| Head metadata | `jekyll-seo-tag` + `{% seo %}` in layout |
| Structured data | Custom `_includes/schema-graph.html` linked `@graph` JSON-LD |
| Content validation | `rake seo:validate` — enforces title (5–120) and description (15–160) at build time |
| Open Graph images | `jekyll-og-image` (requires libvips) — 1200×675 JPEG at build time |
| Sitemaps | `jekyll-sitemap` + hand-rolled sitemap index with per-collection splits |
| `lastmod` | `_plugins/git_lastmod.rb` hook (replaces archived `jekyll-last-modified-at` gem) |
| RSS/Atom feed | `jekyll-feed` with full post content |
| IndexNow | cURL POST in GitHub Actions after each deploy |
| Agent discovery | Liquid-templated `llms.txt`, `_plugins/schema_generator.rb` schema endpoints, `schemamap.xml` |
| Performance | `jekyll-compress-html`, font preload, host-appropriate cache headers |
| Redirects | `_redirects` / `vercel.json` / Workers; client-side fuzzy 404 with Levenshtein |
| Broken links | `html-proofer` in CI + weekly lychee scheduled run |

Detects deployment target (Cloudflare Pages, Netlify, Vercel, Cloudflare Workers) in Phase 0 and branches redirect/header syntax accordingly. Chains into `readability-check` for generated prose.
