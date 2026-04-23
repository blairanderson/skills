# Astro Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install astro@blairanderson-skills
```

This plugin adds one skill for auditing and improving SEO on Astro sites.

---

## `/astro-seo`

Audits and improves the SEO setup of an Astro site against the full stack from Joost de Valk's definitive guide. Covers nine areas and produces drop-in code for anything missing or weak.

The opinionated spine is [`@jdevalk/astro-seo-graph`](https://github.com/jdevalk/seo-graph) — most fixes route through it.

| Concern | Gem / technique |
|---|---|
| Head metadata | `@jdevalk/astro-seo-graph` `<Seo>` component |
| Structured data | Linked `@graph` JSON-LD with `WebSite`, `WebPage`, `BlogPosting`, `Organization` |
| Content collections | Zod `seoSchema` with build-time title/description length validation |
| Open Graph images | Satori + Sharp, 1200×675 JPEG |
| Sitemaps | `@astrojs/sitemap` with per-collection splits and git-based `lastmod` |
| RSS feed | `@astrojs/rss` with full post content |
| IndexNow | Submits on each build via `seoGraph()` integration |
| Agent discovery | Schema endpoints, schema map, `llms.txt` |
| Performance | Cache headers, `No-Vary-Search`, `<ClientRouter>` prefetch |
| Redirects | `_redirects` + `FuzzyRedirect` on 404 |
| Broken links | Lychee GitHub Actions workflow |

Works for both Sitepress content sites and standard content collection apps. Chains into `readability-check` for generated prose.
