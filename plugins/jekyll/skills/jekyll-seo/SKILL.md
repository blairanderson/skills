---
name: jekyll-seo
description: >
  Audits and improves SEO for Jekyll sites. Use when the user asks to audit,
  set up, or improve SEO on a Jekyll site, or mentions head metadata,
  structured data, JSON-LD, sitemaps, IndexNow, Open Graph images, schema
  endpoints, llms.txt, NLWeb, hreflang, jekyll-seo-tag, jekyll-sitemap,
  jekyll-feed, html-proofer, front matter validation, Cloudflare, Netlify, Vercel,
  or search engine indexing in a Jekyll project.
  Chains into `readability-check` for generated prose.
---

# Jekyll SEO

Audits and improves the SEO setup of a Jekyll site against the full stack described in [Astro SEO: the definitive guide](https://joost.blog/astro-seo-complete-guide/), ported to Jekyll. The skill covers nine areas — technical foundation, structured data, content, Open Graph images, sitemaps and indexing, agent discovery, performance, redirects, and build-time validation — and produces drop-in code for anything missing or weak.

The opinionated spine of this skill is [`jekyll-seo-tag`](https://github.com/jekyll/jekyll-seo-tag) (the official SEO plugin). Most head metadata routes through it. Where it falls short — linked `@graph` JSON-LD, per-collection sitemaps, OG image generation — the skill fills in with custom Liquid includes, `_plugins/` generators, and Rake tasks.

The assumed build model is **GitHub Actions**, which gives access to the full Gemfile and custom `_plugins/*.rb` generators. The deployment target varies — Cloudflare Pages/Workers, Netlify, and Vercel are the common hosts — and drives the syntax for redirects and cache headers. Phase 0 detects the host; Phase 2 branches on it.

## Workflow

1. **Detect the project** — confirm this is a Jekyll site and understand its shape.
2. **Audit** — score nine categories and produce actionable findings.
3. **Improve** — generate or modify files to close the gaps.
4. **Readability pass** — invoke `readability-check` on any prose the skill generated (titles, descriptions, schema `description` fields, FAQ entries).
5. **Verify** — run the build, check validations pass, remind the user about non-file tasks (Search Console, Bing Webmaster Tools, IndexNow key verification).

---

## Phase 0: Detect the project

Confirm the basics before auditing:

- `_config.yml` exists.
- `Gemfile` has `jekyll` as a dependency.
- **`url:` is set in `_config.yml`** — canonicals, sitemaps, OG image URLs, and feed item links all derive from this. If it's missing, empty, or `http://localhost:4000`, flag it as a blocking issue before anything else. This is the Jekyll equivalent of Astro's missing `site:` and the single most common misconfiguration. A missing `url:` causes `jekyll-seo-tag` to emit relative canonical links (which Google ignores) and `jekyll-sitemap` to produce a sitemap with relative `<loc>` values (which violates the sitemaps spec).
- `baseurl:` — check if the site is hosted at a sub-path (e.g., `/blog`). If `baseurl` is non-empty, remind the user to use the `relative_url` / `absolute_url` Liquid filters consistently.
- **Content shape** — determine where content lives:
  - `_posts/` — standard dated blog posts.
  - `_pages/` or markdown files at root — static pages.
  - Custom collections in `_config.yml` under `collections:` (e.g., `_projects/`, `_docs/`). Enumerate them with `grep -A 20 "^collections:" _config.yml`.
- **Deployment target** — determine the host by reading these files in order. Record it; Phase 2 branches on it for redirect and header syntax:
  - **Cloudflare Pages** — `cloudflare/pages-action` in a workflow YAML, or `wrangler.toml` with `pages_build_output_dir`. Uses `_redirects` (plain text, Netlify-compatible format) and `_headers` (plain text).
  - **Cloudflare Workers** — `wrangler.toml` with `[site]` block or `main =` pointing to a Worker script. Redirects and headers are set in the Worker script, not in flat files.
  - **Netlify** — `netlify.toml` present. Uses `_redirects` and `_headers` (same format as Cloudflare Pages) or equivalent `[[redirects]]` / `[[headers]]` blocks in `netlify.toml`.
  - **Vercel** — `vercel.json` present. Uses a `redirects` array and a `headers` array in `vercel.json` — no flat files.
  - **Unknown** — ask the user.
- **Is `jekyll-seo-tag` already installed?** Grep `Gemfile` and `_config.yml` `plugins:` list. If yes, check `_config.yml` for `title:`, `description:`, `twitter.username:`, `social:` block, and `author:`. Also check `_layouts/` for `{% seo %}`. If the tag is called but `url:` is missing, flag that first.
- **Check `jekyll-seo-tag` version** with `bundle exec gem list jekyll-seo-tag`. The gem is at 2.8.0 and in maintenance mode; flag any version below 2.8.0.
- **Is the site multilingual?** Check `_config.yml` for `languages:` / `lang:`, or multiple locale directories (`_i18n/`, `_posts/en/`, `_posts/fr/`). If yes, hreflang matters; if no, skip it.

Ask only what you can't detect. Don't ask the user what the site is about — read `_config.yml` and the homepage (`index.md`, `index.html`, or `_pages/home.md`).

---

## Phase 1: Audit

Score each category out of 10. For each, give 2–4 specific findings that quote the actual code or config. Within each category, checks are tiered:

- **Must** — ship blockers. A failure here causes visible SEO regression.
- **Should** — standard practice. Skipping costs reach.
- **Nice** — forward-looking or situational. Useful but not baseline for every site.

Skip **Nice** checks for small personal blogs unless the user asks for the full treatment.

### 1. `jekyll-seo-tag` and head metadata (/10)

- **Must** — `{% seo %}` called exactly once inside `<head>` in the base layout (usually `_layouts/default.html` or `_layouts/base.html`), not scattered across multiple layouts.
- **Must** — `url:` in `_config.yml` is set to the production origin (`https://example.com`, no trailing slash).
- **Must** — canonical URLs are absolute. `jekyll-seo-tag` derives the canonical from `site.url + page.url` — only works when `url:` is set correctly. Check that `site.url` is never `http://localhost:4000` in the production build (common when developers set `url:` to the dev server and forget to override it in CI).
- **Must** — canonical omitted when `noindex: true` is in front matter. `jekyll-seo-tag` does not do this automatically — canonical suppression must be handled in the layout (see Phase 2).
- **Must** — fallback chain for missing SEO fields: `page.title → site.title`; `page.description → page.excerpt → site.description`. `jekyll-seo-tag` does not extract a first-paragraph fallback — pages with no `description` and no `site.description` emit an empty meta description. Implement via `_config.yml` `defaults:` (see Phase 2).
- **Should** — `robots` meta includes `max-snippet:-1, max-image-preview:large, max-video-preview:-1`. `jekyll-seo-tag` passes through whatever `robots:` value is set; it does not add these directives by default.
- **Should** — Twitter tags suppressed when they duplicate Open Graph. If `twitter.username:` is absent from `_config.yml`, the cards are already suppressed. If it's present but content is identical to OG, the duplication is harmless but adds head weight.
- **Should** — `hreflang` alternates on multilingual sites. `jekyll-seo-tag` has no built-in hreflang support; must be hand-rolled in the layout using `page.lang` and a Liquid include.
- **Nice** — `_config.yml` has `author:`, `social:`, and `logo:` populated for richer JSON-LD output from `jekyll-seo-tag`.

### 2. Structured data / JSON-LD graph (/10)

- **`jekyll-seo-tag`'s built-in JSON-LD** is a single flat object per page — not a linked `@graph`. For posts it outputs `BlogPosting`; for the home page it outputs `WebSite`. Entities are not cross-referenced via `@id`.
- **Must** — a linked `@graph` with at least `Organization` (or `Person`), `WebSite`, `WebPage`, and `BlogPosting` (for posts), all connected via `@id` references. If `jekyll-seo-tag`'s flat output is all that exists, score this low and generate the `_includes/schema-graph.html` partial in Phase 2.
- **Should** — `WebSite`, `WebPage`, `Organization`/`Person`, `BlogPosting`/`Article`, `BreadcrumbList`, `ImageObject` all present where relevant.
- **Should** — trust signals on the `Organization`/`Person` entity: `publishingPrinciples`, `copyrightHolder`, `copyrightYear`, `knowsAbout`, and `WebSite.potentialAction` of `SearchAction` if the site has search.
- **Should** — `dateModified` populated from `page.last_modified_at` (set by the `_plugins/git_lastmod.rb` hook), not from `page.date` (which is the publish date and never changes after first publish).
- **Should** — validates in [Rich Results Test](https://search.google.com/test/rich-results) and [ClassySchema](https://classyschema.org/Visualisation).

### 3. Content front matter and schema (/10)

- **Must** — every post and page has `title:` and `description:` in front matter.
- **Must** — `title:` length 5–120 chars; `description:` length 15–160 chars. Validate at build time via `rake seo:validate` (see Phase 2).
- **Must** — posts have a `date:` field (or use the filename date convention `YYYY-MM-DD-title.md`).
- **Should** — `image:` front matter field populated on posts (path or URL to the OG image). `jekyll-seo-tag` reads `page.image` for `og:image`; without it, there is no OG image.
- **Should** — `last_modified_at:` auto-populated by the `_plugins/git_lastmod.rb` hook so `dateModified` in JSON-LD and `<lastmod>` in the sitemap reflect actual freshness.
- **Should** — `_config.yml` `defaults:` block setting `robots:` for all posts and pages, so individual posts don't need to repeat it.

### 4. Open Graph images (/10)

- **Must** — every indexable post/page has an OG image. Many missing is a red flag.
- **Must** — 1200×675 (16:9 ratio, Google Discover minimum 1200px wide).
- **Must** — JPEG format. Facebook, Twitter/X, and LinkedIn do not reliably support WebP or AVIF for OG previews.
- **Should** — generated programmatically at build time via `jekyll-og-image` (requires libvips installed on the Actions runner) rather than authored by hand per post.
- **Should** — OG image URL derives from the slug, so it's predictable and cache-friendly. `jekyll-og-image` uses `page.slug` by default; verify the output path matches the `image:` field in front matter.
- **Nice** — `jekyll-og-image` background and font configured in `_config.yml` to match the site's brand.

### 5. Sitemaps and indexing (/10)

- **Must** — `jekyll-sitemap` installed and producing `/sitemap.xml` reachable at the production URL.
- **Must** — `robots.txt` references the sitemap: `Sitemap: https://example.com/sitemap.xml`.
- **Must** — RSS/Atom feed exists via `jekyll-feed`, advertised via `{% feed_meta %}` in `<head>`, and contains **full post content** (not truncated excerpts — set `excerpt_only: false` in `_config.yml`).
- **Should** — `<lastmod>` in the sitemap reflects actual git commit timestamps, not file system mtime or publish date. The `_plugins/git_lastmod.rb` hook (see Phase 2) populates `page.last_modified_at` from `git log`; `jekyll-sitemap` uses it automatically. Without this, `jekyll-sitemap` falls back to file system mtime, which is always the build time in CI and useless for signalling freshness to Google.
- **Should** — per-collection sitemap split: a `sitemap-index.xml` plus child `sitemap-posts.xml` and `sitemap-pages.xml`. `jekyll-sitemap` produces a single flat `sitemap.xml`; splitting requires hand-rolled Liquid templates (see Phase 2). Much easier to debug indexing in Google Search Console.
- **Should** — IndexNow integrated and submitting on each deploy, with the key verification file at `/<key>.txt`.

### 6. Agent discovery (/10)

- **Should** — `llms.txt` at the site root listing all indexable pages (title + description + URL) for LLM consumers. Implemented as a static Liquid file — no gem required.
- **Should** — schema endpoints (`/schema/posts.json`, `/schema/pages.json`) exposing corpus-wide JSON-LD for agents that can't render HTML. Implemented as a `Jekyll::Generator` plugin in `_plugins/`.
- **Should** — schema map at `/schemamap.xml` listing every endpoint, with `Schemamap:` directive in `robots.txt`.
- **Nice** — `<link rel="nlweb">` pointing to a conversational endpoint. NLWeb is early; the tag is one line in the layout and worth having, but it's not a scoring blocker in 2026.

### 7. Performance (/10)

- **Must** — static HTML output (Jekyll's default).
- **Must** — CSS minified. Jekyll has built-in Sass support; set `style: compressed` under `sass:` in `_config.yml`.
- **Should** — HTML minified via `jekyll-compress-html` (a pure Liquid layout wrapper, zero dependencies).
- **Should** — content images use `loading="lazy" decoding="async"` attributes. If using `jekyll_picture_tag` (requires libvips), responsive `<picture>` elements with WebP + JPEG srcsets are generated automatically.
- **Should** — primary web font preloaded in woff2: `<link rel="preload" href="{{ '/assets/fonts/Inter.woff2' | relative_url }}" as="font" type="font/woff2" crossorigin="anonymous">` in the `<head>`.
- **Should** — host-appropriate headers serving `Cache-Control: public, max-age=31536000, immutable` on static assets and `No-Vary-Search` stripping UTM parameters from the CDN cache key. Syntax varies by host (see Phase 2).

### 8. Redirects and error handling (/10)

- **Must** — a `_redirects` file with an entry for every URL that ever existed and moved. Cloudflare Pages serves server-side 301s from this file with no additional configuration.
- **Must** — **301** for permanent moves, not 302.
- **Must** — `404.html` at the repo root. Cloudflare Pages serves this file with a proper HTTP 404 status for unmatched paths.
- **Should** — fuzzy suggestion on the 404 page: client-side JS that fetches `/sitemap.xml`, computes Levenshtein distance against all known paths, and surfaces a "Did you mean…" link. There is no server-side fuzzy redirect in a static deployment; a Cloudflare Worker can upgrade this to a true redirect if needed.

### 9. Build-time validation and content quality (/10)

- **Must** — `rake seo:validate` (custom task; see Phase 2) runs in CI and asserts `title` (5–120 chars), `description` (15–160 chars), and `date` on every post and page. Fails the build if any file is non-conforming.
- **Must** — `html-proofer` (v5) runs after `jekyll build` in CI: checks all internal links resolve, all images have `alt` attributes, and `og:image` URLs are absolute.
- **Should** — broken external link check: `html-proofer` with `disable_external: false` on a weekly scheduled Actions run — catches link rot without slowing the push-triggered build.
- **Should** — content audited for readability (lead sentences, sentences under 20 words, transitions). Phase 2.5 chains this in via `readability-check`.

---

## Phase 2: Improve

Based on the audit, produce the concrete code. Always ask before overwriting.

**Branch on the Phase 0 findings.** If `jekyll-seo-tag` is already installed and `url:` is set correctly, skip those steps and focus on wiring the features the audit flagged as missing (linked `@graph`, sitemap lastmod, IndexNow, schema endpoints, `llms.txt`, build validation). If the user has a hand-rolled head metadata setup that already satisfies the **Must** checks in category 1, don't rip it out — add only what's missing.

### Install or upgrade the core stack

```ruby
# Gemfile
gem "jekyll-seo-tag"       # head metadata, OG, Twitter, basic JSON-LD
gem "jekyll-sitemap"       # /sitemap.xml
gem "jekyll-feed"          # /feed.xml (Atom)
gem "jekyll-compress-html" # HTML minification (Liquid-based)
gem "jekyll-og-image"      # build-time OG image generation (requires libvips)
gem "html-proofer", "~> 5" # build validation
```

```yaml
# _config.yml — plugins list
plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-feed
  - jekyll-compress-html
  - jekyll-og-image
```

`jekyll-last-modified-at` was archived in August 2024. Use the `_plugins/git_lastmod.rb` hook instead (see sitemap section) — it does the same thing with no gem dependency.

If a gem is already installed, check the version against rubygems.org before auditing feature gaps — outdated versions are a plausible cause of any audit finding.

### GitHub Actions build and Cloudflare Pages deploy

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # required for git-based lastmod

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install libvips (for jekyll-og-image)
        run: sudo apt-get install -y libvips

      - name: Validate front matter
        run: bundle exec rake seo:validate

      - name: Build Jekyll
        run: bundle exec jekyll build
        env:
          JEKYLL_ENV: production

      - name: Run html-proofer
        run: bundle exec rake test

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: my-jekyll-site
          directory: _site
          gitHubToken: ${{ secrets.GITHUB_TOKEN }}
```

### `_config.yml` — base SEO configuration

```yaml
# _config.yml
url: "https://example.com"   # production origin — no trailing slash
baseurl: ""                  # sub-path if site lives at /blog; empty for root

title: "Site Name"
description: "One-sentence site description (15–160 chars)."
author:
  name: "Author Name"
  url: "https://example.com/about"

logo: "/assets/images/logo.png"

social:
  name: "Site Name"
  links:
    - https://twitter.com/handle
    - https://linkedin.com/company/...

twitter:
  username: handle

defaults:
  - scope:
      path: ""
      type: "posts"
    values:
      layout: "post"
      robots: "index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1"
  - scope:
      path: ""
      type: "pages"
    values:
      layout: "page"
      robots: "index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1"

feed:
  excerpt_only: false   # full content in <content> tag, not truncated excerpts

compress_html:
  clippings: all
  comments: all
  endings: all
  ignore:
    envs: [development]

og_image:
  output_dir: "assets/og"
  collections:
    - posts
    - pages
  width: 1200
  height: 675

sass:
  style: compressed
```

### `_layouts/default.html` — head metadata

```liquid
<!DOCTYPE html>
<html lang="{{ page.lang | default: site.lang | default: 'en' }}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">

  {%- if page.noindex %}
  <meta name="robots" content="noindex, nofollow">
  {%- else %}
  {% seo %}
  {%- endif %}

  {% feed_meta %}
  <link rel="preload" href="{{ '/assets/fonts/Inter.woff2' | relative_url }}" as="font" type="font/woff2" crossorigin="anonymous">

  {% include schema-graph.html %}

  <link rel="stylesheet" href="{{ '/assets/css/main.css' | relative_url }}">
</head>
<body>
  {{ content }}
</body>
</html>
```

Key points:
- `{% seo %}` is suppressed entirely when `noindex: true` — this also suppresses the canonical, which is the correct behavior (Google recommends omitting canonical on noindex pages).
- `{% include schema-graph.html %}` provides the linked `@graph` JSON-LD. To avoid duplicate JSON-LD from `jekyll-seo-tag`, copy the gem's built-in template into your project's `_includes/jekyll-seo-tag.html` and remove the `<script type="application/ld+json">` block — your copy takes precedence over the gem's.
- `{% feed_meta %}` outputs the `<link rel="alternate" type="application/atom+xml">` discovery tag automatically.

### `_includes/schema-graph.html` — linked `@graph` JSON-LD

`jekyll-seo-tag` outputs a flat single-object JSON-LD. Replace it with a linked `@graph` partial:

```liquid
<!-- _includes/schema-graph.html -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": "{{ site.url }}/#organization",
      "name": "{{ site.title | escape }}",
      "url": "{{ site.url }}/",
      "logo": {
        "@type": "ImageObject",
        "@id": "{{ site.url }}/#logo",
        "url": "{{ site.url }}{{ site.logo }}"
      },
      "publishingPrinciples": "{{ site.url }}/editorial-policy",
      "sameAs": [
        {% for link in site.social.links %}"{{ link }}"{% unless forloop.last %},{% endunless %}{% endfor %}
      ]
    },
    {
      "@type": "WebSite",
      "@id": "{{ site.url }}/#website",
      "url": "{{ site.url }}/",
      "name": "{{ site.title | escape }}",
      "publisher": { "@id": "{{ site.url }}/#organization" }{% if site.search_enabled %},
      "potentialAction": {
        "@type": "SearchAction",
        "target": "{{ site.url }}/search?q={query}",
        "query-input": "required name=query"
      }{% endif %}
    },
    {
      "@type": "WebPage",
      "@id": "{{ page.url | absolute_url }}#webpage",
      "url": "{{ page.url | absolute_url }}",
      "name": "{{ page.title | default: site.title | escape }}",
      "description": "{{ page.description | default: page.excerpt | default: site.description | strip_html | escape }}",
      "isPartOf": { "@id": "{{ site.url }}/#website" }
    }
    {% if page.layout == "post" or page.collection == "posts" %}
    ,{
      "@type": "BlogPosting",
      "@id": "{{ page.url | absolute_url }}#article",
      "headline": "{{ page.title | escape }}",
      "datePublished": "{{ page.date | date_to_xmlschema }}",
      "dateModified": "{{ page.last_modified_at | default: page.date | date_to_xmlschema }}",
      "description": "{{ page.description | default: page.excerpt | strip_html | truncate: 160 | escape }}",
      "author": { "@id": "{{ site.url }}/#organization" },
      "publisher": { "@id": "{{ site.url }}/#organization" },
      "mainEntityOfPage": { "@id": "{{ page.url | absolute_url }}#webpage" }{% if page.image %},
      "image": {
        "@type": "ImageObject",
        "url": "{{ page.image | absolute_url }}"
      }{% endif %}
    }
    {% endif %}
  ]
}
</script>
```

To suppress `jekyll-seo-tag`'s own JSON-LD:

```sh
bundle info jekyll-seo-tag --path
# Copy _includes/jekyll-seo-tag.html from that path into your project's _includes/
# Remove the <script type="application/ld+json">...</script> block from the copy.
```

### Front matter validation Rake task

```ruby
# Rakefile
require "yaml"

namespace :seo do
  desc "Validate SEO front matter on all posts, pages, and collection documents"
  task :validate do
    errors = []
    patterns = ["_posts/**/*.{md,markdown}", "_pages/**/*.{md,markdown}"]

    config = YAML.safe_load(File.read("_config.yml")) rescue {}
    (config["collections"] || {}).each_key { |col| patterns << "_#{col}/**/*.{md,markdown}" }

    Dir.glob(patterns).each do |file|
      content = File.read(file)
      next unless content.start_with?("---")
      fm_text = content.split("---", 3)[1]
      next if fm_text.nil?

      data = YAML.safe_load(fm_text) || {}
      title = data["title"].to_s.strip
      description = data["description"].to_s.strip

      errors << "#{file}: title missing" if title.empty?
      errors << "#{file}: title < 5 chars (#{title.length})" if title.length.positive? && title.length < 5
      errors << "#{file}: title > 120 chars (#{title.length})" if title.length > 120
      errors << "#{file}: description missing" if description.empty?
      errors << "#{file}: description < 15 chars (#{description.length})" if description.length.positive? && description.length < 15
      errors << "#{file}: description > 160 chars (#{description.length})" if description.length > 160
      errors << "#{file}: no date field" if data["date"].nil? && file.include?("_posts")
    end

    abort("Front matter validation failed:\n" + errors.join("\n")) if errors.any?
    puts "OK — #{Dir.glob(patterns).size} files validated"
  end
end

desc "Build and run html-proofer"
task :test do
  sh "bundle exec jekyll build"
  require "html-proofer"
  HTMLProofer.check_directory("./_site", {
    checks: ["Links", "Images", "Scripts"],
    disable_external: true,
    ignore_urls: [/localhost/, /0\.0\.0\.0/],
    ignore_missing_alt: false
  }).run
end
```

### OG image generation

**`jekyll-og-image` gem** (requires libvips on the Actions runner):

```yaml
# _config.yml
og_image:
  output_dir: "assets/og"
  collections:
    - posts
    - pages
  width: 1200
  height: 675
  font: "/assets/fonts/Inter-Bold.ttf"
  background: "/assets/images/og-bg.jpg"
```

After building, each post gets an OG image at `assets/og/<slug>.jpg`. `jekyll-og-image` sets `page.image` automatically, which `jekyll-seo-tag` picks up for `og:image`. Override per-post:

```yaml
---
title: "My Post"
og_image:
  title: "Custom OG title for this post"
---
```

**Fallback — static pre-made image:**

```yaml
---
title: "My Post"
image: /assets/og/my-post.jpg   # 1200×675 JPEG placed manually
---
```

### Sitemap with git `lastmod` and per-collection split

**git-based `lastmod` hook** (replaces the archived `jekyll-last-modified-at` gem):

```ruby
# _plugins/git_lastmod.rb
Jekyll::Hooks.register [:pages, :posts, :documents], :post_init do |doc|
  next unless doc.respond_to?(:path) && File.exist?(doc.path.to_s)
  next unless system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
  ts = `git log -1 --format=%cI -- "#{doc.path}" 2>/dev/null`.strip
  doc.data["last_modified_at"] ||= ts unless ts.empty?
end
```

Requires `fetch-depth: 0` in the Actions checkout step (already in the deploy workflow above).

**Per-collection sitemap index** — `jekyll-sitemap` produces one flat `sitemap.xml`. For a sitemap index with per-collection child sitemaps:

```liquid
---
layout: null
permalink: /sitemap-index.xml
sitemap: false
---
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>{{ site.url }}/sitemap-posts.xml</loc>
    <lastmod>{{ site.time | date_to_xmlschema }}</lastmod>
  </sitemap>
  <sitemap>
    <loc>{{ site.url }}/sitemap-pages.xml</loc>
    <lastmod>{{ site.time | date_to_xmlschema }}</lastmod>
  </sitemap>
</sitemapindex>
```

```liquid
---
layout: null
permalink: /sitemap-posts.xml
sitemap: false
---
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  {% for post in site.posts %}{% unless post.noindex or post.sitemap == false %}
  <url>
    <loc>{{ post.url | absolute_url }}</loc>
    <lastmod>{{ post.last_modified_at | default: post.date | date_to_xmlschema }}</lastmod>
    <changefreq>weekly</changefreq>
  </url>
  {% endunless %}{% endfor %}
</urlset>
```

Repeat the pattern for `sitemap-pages.xml`. Set `sitemap: false` on these template files so `jekyll-sitemap` doesn't include them in its own output.

`robots.txt` in the repo root:

```text
User-agent: *
Allow: /

Sitemap: https://example.com/sitemap-index.xml
Schemamap: https://example.com/schemamap.xml
```

### RSS/Atom feed (`jekyll-feed`)

```yaml
# _config.yml
feed:
  path: feed.xml
  excerpt_only: false
  collections:
    - posts
```

`jekyll-feed` generates `/feed.xml` automatically. Advertise it in the layout via `{% feed_meta %}`.

### IndexNow

Generate the key:

```sh
ruby -e "require 'securerandom'; puts SecureRandom.hex(16)"
```

Store in GitHub Actions secrets as `INDEXNOW_KEY`. Place the key file in the repo root (Jekyll copies it to `_site/` verbatim):

```text
# a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4.txt
a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
```

Submit to IndexNow after each successful deploy by adding a step at the end of `deploy.yml`:

```yaml
      - name: Submit to IndexNow
        run: |
          curl -s -X POST "https://api.indexnow.org/indexnow" \
            -H "Content-Type: application/json" \
            -d '{
              "host": "example.com",
              "key": "${{ secrets.INDEXNOW_KEY }}",
              "keyLocation": "https://example.com/${{ secrets.INDEXNOW_KEY }}.txt",
              "urlList": ["https://example.com/sitemap-index.xml"]
            }'
```

### `llms.txt`

```liquid
---
layout: null
permalink: /llms.txt
sitemap: false
---
# {{ site.title }}

> {{ site.description }}

## Posts

{% for post in site.posts %}{% unless post.noindex %}
- [{{ post.title }}]({{ post.url | absolute_url }}): {{ post.description | default: post.excerpt | strip_html | strip_newlines | truncate: 160 }}
{% endunless %}{% endfor %}

## Pages

{% for page in site.pages %}{% unless page.sitemap == false or page.url contains '/assets' or page.url contains '/feed' or page.url contains '/sitemap' %}{% if page.title %}
- [{{ page.title }}]({{ page.url | absolute_url }}){% if page.description %}: {{ page.description }}{% endif %}
{% endif %}{% endunless %}{% endfor %}
```

Save as `llms.txt` in the repo root.

### Schema endpoints and schema map

```ruby
# _plugins/schema_generator.rb
require "json"

class SchemaEndpointGenerator < Jekyll::Generator
  safe true
  priority :low

  def generate(site)
    base = site.config["url"]

    posts_graph = site.posts.docs.reject { |p| p.data["noindex"] }.map do |post|
      {
        "@type" => "BlogPosting",
        "@id" => "#{base}#{post.url}#article",
        "headline" => post.data["title"],
        "description" => (post.data["description"] || strip_html(post.excerpt.to_s)).slice(0, 160),
        "datePublished" => post.date.iso8601,
        "dateModified" => (post.data["last_modified_at"] || post.date).to_time.iso8601,
        "url" => "#{base}#{post.url}",
        "author" => { "@id" => "#{base}/#organization" }
      }
    end

    add_page(site, "schema/posts.json", JSON.pretty_generate({
      "@context" => "https://schema.org", "@graph" => posts_graph
    }))

    add_page(site, "schemamap.xml", <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <schemamapindex>
        <schemamap>
          <loc>#{base}/schema/posts.json</loc>
          <type>BlogPosting</type>
        </schemamap>
      </schemamapindex>
    XML
  end

  private

  def add_page(site, path, content)
    dir, file = File.split(path)
    page = Jekyll::PageWithoutAFile.new(site, site.source, dir, file)
    page.data["layout"] = nil
    page.data["sitemap"] = false
    page.content = content
    site.pages << page
  end

  def strip_html(html)
    html.gsub(/<[^>]+>/, "").gsub(/\s+/, " ").strip
  end
end
```

### Redirects and fuzzy 404

Pick the syntax matching the deployment target detected in Phase 0.

**Cloudflare Pages / Netlify — `_redirects`** (server-side 301, plain text):

```text
/old-path    /new-path    301
/blog/:slug  /posts/:slug  301
```

Place `_redirects` in the repo root. Add to `_config.yml` so Jekyll copies it to `_site/`:

```yaml
include:
  - _redirects
  - _headers
```

**Cloudflare Workers** — set redirects in the Worker script. If using an Assets binding for static files, add a fetch handler that checks the request URL against a hard-coded map before falling through to the asset:

```js
// src/index.js
const REDIRECTS = {
  "/old-path": "/new-path",
  "/blog/:slug": null,   // handled by pattern match below
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const dest = REDIRECTS[url.pathname];
    if (dest) return Response.redirect(new URL(dest, url.origin), 301);
    return env.ASSETS.fetch(request);
  }
};
```

**Vercel — `vercel.json`**:

```json
{
  "redirects": [
    { "source": "/old-path", "destination": "/new-path", "permanent": true },
    { "source": "/blog/:slug", "destination": "/posts/:slug", "permanent": true }
  ]
}
```

**Seeding the redirect table from scratch:** if migrating from WordPress or another CMS, export the old URL list (WP-CLI `wp post list`, database dump, or the old sitemap via Wayback Machine), diff old URLs against the current sitemap, and commit the table once. Maintain it whenever you change a slug.

**`404.html` with client-side fuzzy suggestion:**

```html
---
layout: null
permalink: /404.html
---
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>404 — Page not found — {{ site.title }}</title>
</head>
<body>
  <h1>Page not found</h1>
  <p id="suggestion"></p>
  <p><a href="/">Return home</a></p>
  <script type="module">
    import { closest, distance } from 'https://cdn.jsdelivr.net/npm/fastest-levenshtein@1.0.16/esm/mod.js';
    const path = window.location.pathname;
    fetch('/sitemap.xml')
      .then(r => r.text())
      .then(xml => {
        const locs = Array.from(new DOMParser().parseFromString(xml, 'application/xml').querySelectorAll('loc'))
          .map(el => new URL(el.textContent).pathname);
        const best = closest(path, locs);
        const dist = distance(path, best);
        if (best && dist <= Math.floor(path.length * 0.25)) {
          document.getElementById('suggestion').innerHTML =
            `Did you mean <a href="${best}">${best}</a>?`;
        }
      })
      .catch(() => {});
  </script>
</body>
</html>
```

The user sees the suggestion but must click it — there is no automatic server-side redirect. To upgrade to a true server-side fuzzy redirect, implement edge-layer logic (a Cloudflare Worker, Netlify Edge Function, or Vercel Middleware) that intercepts unmatched requests, computes a Levenshtein match against the sitemap, and returns a 301 before the static 404 is served.

### Performance headers

Pick the syntax matching the deployment target detected in Phase 0.

**Cloudflare Pages / Netlify — `_headers`** (plain text, included via `_config.yml` above):

```text
/assets/*
  Cache-Control: public, max-age=31536000, immutable

/*
  No-Vary-Search: key-order, params=("utm_source" "utm_medium" "utm_campaign" "utm_content" "utm_term")
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
```

**Cloudflare Workers** — set headers in the fetch handler:

```js
// src/index.js
export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    const url = new URL(request.url);
    const headers = new Headers(response.headers);

    if (url.pathname.startsWith("/assets/")) {
      headers.set("Cache-Control", "public, max-age=31536000, immutable");
    }
    headers.set("No-Vary-Search", 'key-order, params=("utm_source" "utm_medium" "utm_campaign" "utm_content" "utm_term")');
    headers.set("X-Frame-Options", "DENY");
    headers.set("X-Content-Type-Options", "nosniff");

    return new Response(response.body, { status: response.status, headers });
  }
};
```

**Netlify — `netlify.toml`** (alternative to `_headers` if the project already uses `netlify.toml`):

```toml
[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*"
  [headers.values]
    No-Vary-Search = 'key-order, params=("utm_source" "utm_medium" "utm_campaign" "utm_content" "utm_term")'
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
```

**Vercel — `vercel.json`**:

```json
{
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        { "key": "No-Vary-Search", "value": "key-order, params=(\"utm_source\" \"utm_medium\" \"utm_campaign\" \"utm_content\" \"utm_term\")" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-Content-Type-Options", "value": "nosniff" }
      ]
    }
  ]
}
```

**`jekyll-compress-html`** — copy the single `compress.html` file from [penibelst/jekyll-compress-html](https://github.com/penibelst/jekyll-compress-html) into `_layouts/compress.html`, then set your `_layouts/default.html` front matter to `layout: compress`. This wraps the entire rendered output in the Liquid HTML compressor.

### Broken link checker in CI

```yaml
# .github/workflows/link-check.yml
name: Link Check
on:
  push:
    paths:
      - '_posts/**'
      - '_pages/**'
      - '**/*.md'
  schedule:
    - cron: '0 9 * * 1'   # Weekly, Mondays 09:00 UTC — catches link rot
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install libvips
        run: sudo apt-get install -y libvips

      - name: Build Jekyll
        run: bundle exec jekyll build
        env:
          JEKYLL_ENV: production

      - name: Run html-proofer with external links
        run: |
          bundle exec ruby -e "
            require 'html-proofer'
            HTMLProofer.check_directory('./_site', {
              checks: ['Links', 'Images', 'Scripts'],
              disable_external: false,
              ignore_urls: [/localhost/, /0\\.0\\.0\\.0/, /twitter\\.com/, /x\\.com/],
              typhoeus: { ssl_verifypeer: false, ssl_verifyhost: 0 }
            }).run
          "
```

---

## Phase 2.5: Readability pass

Invoke the `readability-check` skill on every piece of prose the skill generated or modified: page titles, meta descriptions, schema `description` fields, FAQ entries, and any post `description` front matter values you wrote.

SEO titles and descriptions are short but consequential — a long passive opening sentence in a meta description wastes the 160 characters Google shows in results. Apply the ⚠ and ✗ fixes directly. Skip the pass for technical strings (URLs, schema `@id` values, enum values).

If the project has a large `_posts/` corpus, note that the same `readability-check` skill can audit individual posts — mention this to the user as a follow-up, but don't audit the entire corpus yourself.

---

## Phase 3: Verify

- Run `bundle exec jekyll build`. Surface any Jekyll warnings about missing `url:`, plugin issues, or YAML errors.
- Run `bundle exec rake seo:validate` — front matter validation across all posts and pages.
- Run `bundle exec rake test` — `html-proofer` internal link and image check.
- Spot-check the built HTML: open `_site/index.html` and one post. The `<head>` should have one `<title>`, one `<link rel="canonical">` (absolute URL), Open Graph tags, and one `<script type="application/ld+json">` with a linked `@graph`.
- Open `_site/sitemap-index.xml`. Confirm all `<loc>` values are absolute URLs with the production domain, and `<lastmod>` values reflect actual git timestamps (not the build time).
- Confirm `/feed.xml` renders valid Atom XML with full `<content>` bodies.
- Run the homepage through [Rich Results Test](https://search.google.com/test/rich-results) and [ClassySchema](https://classyschema.org/Visualisation).
- If IndexNow is wired, confirm `/<key>.txt` returns the key as plain text.
- `curl -I https://example.com/does-not-exist` — confirm `HTTP 404`, not 200.
- Remind the user about tasks that can't be automated:
  - Register the site in [Google Search Console](https://search.google.com/search-console) and [Bing Webmaster Tools](https://www.bing.com/webmasters).
  - Submit the sitemap index in both.
  - Generate an IndexNow key (`ruby -e "require 'securerandom'; puts SecureRandom.hex(16)"`) and add to GitHub Actions secrets.
  - Install [Plausible](https://plausible.io/) or equivalent privacy-friendly analytics.

---

## Output format

```markdown
## Jekyll SEO audit: [site name]

### Score
| Category                              | Score |
|---------------------------------------|------:|
| 1. `jekyll-seo-tag` and head          |  x/10 |
| 2. Structured data / JSON-LD graph    |  x/10 |
| 3. Content front matter and schema    |  x/10 |
| 4. Open Graph images                  |  x/10 |
| 5. Sitemaps and indexing              |  x/10 |
| 6. Agent discovery                    |  x/10 |
| 7. Performance                        |  x/10 |
| 8. Redirects and error handling       |  x/10 |
| 9. Build-time validation and content  |  x/10 |
| **Total**                             | xx/90 |

### Findings
[Grouped by category. Quote actual code/config. Be specific.]

### Files generated or changed
[List with short description of each.]

### Next steps
[Non-file tasks: GSC, Bing Webmaster Tools, IndexNow key, analytics.]
```

---

## Key principles

- **`jekyll-seo-tag` is the spine.** Route head metadata through it and supplement with a custom `_includes/schema-graph.html` for the linked `@graph`. Don't hand-roll both — hand-rolling is a last resort.
- **`url:` in `_config.yml` is the canonical origin.** Every SEO feature that produces an absolute URL — sitemaps, feeds, JSON-LD, OG tags — depends on it being set correctly. It is the Jekyll equivalent of Astro's `site:` config and the single most common misconfiguration.
- **No linked `@graph` out of the box.** `jekyll-seo-tag`'s JSON-LD is a single flat object. A full linked `@graph` requires a hand-rolled `_includes/schema-graph.html` partial and overriding the gem's built-in JSON-LD output. Generate the partial — don't leave the flat object in place.
- **Static means no server-side runtime in the Jekyll process.** IndexNow submissions happen in GitHub Actions after the deploy. OG image generation happens at build time. Fuzzy 404 redirects are client-side JS; upgrade to a true server-side redirect by adding a Cloudflare Worker if needed.
- **`_plugins/git_lastmod.rb` over `jekyll-last-modified-at`.** The gem was archived in August 2024. The custom hook does the same thing with no gem dependency and a smaller attack surface.
- **Topics, not keyphrases.** When reviewing content, focus on topical coverage and readability, not keyword density.
- **Agent discovery matters now.** `llms.txt`, schema endpoints, `/schemamap.xml` — these are low-effort Liquid files and the crawler is no longer the only consumer.
