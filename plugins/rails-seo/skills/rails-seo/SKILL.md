---
name: rails-seo
description: >
  Audits and improves SEO for Ruby on Rails applications. Use when the user asks
  to audit, set up, or improve SEO on a Rails app, or mentions head metadata,
  structured data, JSON-LD, sitemaps, IndexNow, Open Graph images, schema
  endpoints, `llms.txt`, NLWeb, hreflang, `meta-tags`, `schema_dot_org`,
  `sitemap_generator`, or search engine indexing in a Rails context. Produces
  drop-in code for both Sitepress (`app/content/pages/`) and dynamic
  ActiveRecord apps, and chains into `readability-check` for generated prose.
---

# Rails SEO

Audits and improves the SEO setup of a Ruby on Rails application against Joost de Valk's SEO framework from [Astro SEO: the definitive guide](https://joost.blog/astro-seo-complete-guide/), ported to Ruby. The skill covers nine areas — head metadata, structured data, content, Open Graph, sitemaps and indexing, agent discovery, performance, redirects, and build-time validation — and produces drop-in code for anything missing or weak.

There is **no Rails equivalent of `@jdevalk/astro-seo-graph`** (a single opinionated "spine" package). Instead, this skill recommends a **curated Rails stack** and glues it together with thin helpers:

| Concern | Gem / technique |
|---|---|
| Head metadata | [`meta-tags`](https://github.com/kpumuk/meta-tags) |
| Structured data | [`schema_dot_org`](https://github.com/public-law/schema-dot-org) + a custom `Seo::Graph` helper |
| Sitemaps | [`sitemap_generator`](https://github.com/kjvarga/sitemap_generator) |
| Open Graph images | [`grover`](https://github.com/Studiosity/grover) + `image_processing` + Active Storage |
| RSS | Rails built-in Builder (`feed.rss.builder`) |
| IndexNow | Custom Faraday client in a Solid Queue job |
| llms.txt & schema endpoints | Custom controllers |
| Redirects | `routes.rb` + `rack-rewrite` + `ErrorsController` with Levenshtein fallback |
| Analytics | `ahoy_matey` or Plausible/Fathom |

The skill supports two app shapes, often side-by-side in the same repo:

- **Sitepress** — static content under `app/content/pages/` with YAML frontmatter, rendered via `sitepress-rails`.
- **Dynamic** — ActiveRecord models (`Post`, `Article`, `Page`) rendered through normal controllers, optionally with `friendly_id`.

## Workflow

1. **Detect the project** — confirm this is Rails and determine its shape (Sitepress, dynamic, or hybrid).
2. **Audit** — score nine categories and produce actionable findings.
3. **Improve** — generate or modify files to close the gaps.
4. **Readability pass** — invoke `readability-check` on any prose the skill generated (titles, descriptions, schema `description` fields, FAQ entries).
5. **Verify** — boot the app, run `rake seo:audit`, remind the user about non-file tasks (Search Console, Bing Webmaster Tools, IndexNow key verification).

---

## Phase 0: Detect the project

Confirm the basics before auditing:

- `Gemfile` and `Gemfile.lock` exist; `rails` gem present.
- Rails version ≥ 7.1 (read from `Gemfile.lock`). Older Rails is supported, but some suggestions assume Propshaft, Solid Queue, or importmap defaults — call out the floor if you see Rails 6.x.
- **Production canonical origin** — check `config/environments/production.rb` for `Rails.application.routes.default_url_options[:host]`, `config.action_mailer.default_url_options[:host]`, `config.hosts`, or a `SITE_URL` / `APP_HOST` env var used by an initializer. If none is set, flag it as a **blocking issue** before anything else. Canonicals, sitemap URLs, and OG image URLs all derive from this — it is the single most common misconfiguration, and Rails' equivalent of Astro's missing `site:`.
- **App shape detection**:
  - Sitepress: `app/content/pages/` exists **or** `sitepress-rails` in Gemfile. If present, enumerate the resources via `Sitepress.sites.fetch("app/content").resources` during audit.
  - Dynamic: look for blog-like models (`app/models/post.rb`, `article.rb`, `page.rb`) and `friendly_id` usage.
  - Hybrid: both patterns coexist — audit and generate code for each.
- **Deployment target** — read `fly.toml`, `render.yaml`, `Procfile` (Heroku), `config/deploy.yml` (Kamal), `Dockerfile`, `netlify.toml`, `public/_headers`, or `config/nginx.conf` to determine the host. This drives redirect and header syntax in Phase 2.
- **Already installed?** Grep `Gemfile` and `Gemfile.lock` for `meta-tags`, `schema_dot_org`, `sitemap_generator`, `grover`, `ahoy_matey`, `rack-rewrite`, `friendly_id`. Record installed versions. Run `bundle outdated meta-tags schema_dot_org sitemap_generator grover` to check freshness. If a gem is behind, recommend an upgrade in Phase 2 before auditing feature gaps — outdated versions are a plausible cause of any audit finding.
- **Multilingual?** Check `config/application.rb` for `config.i18n.available_locales` with >1 locale, or `config/locales/` containing non-`en` files, or routes scoped under `scope "(:locale)"`. If yes, hreflang matters; if no, skip it.

Ask only what you can't detect. Don't ask the user what the site is about — read the homepage (`app/views/pages/home.html.erb`, Sitepress `app/content/pages/index.html.erb`, or the root route's view) and the `<title>` / H1.

---

## Phase 1: Audit

Score each category out of 10. For each, give 2–4 specific findings that quote the actual code or config. Within each category, checks are tiered:

- **Must** — ship blockers. A failure here causes visible SEO regression.
- **Should** — standard practice. Skipping costs reach.
- **Nice** — forward-looking or situational. Useful but not baseline for every site.

Skip **Nice** checks for small personal blogs unless the user asks for the full treatment.

### 1. `meta-tags` helper and head metadata (/10)

- **Must** — single source for head metadata: `<%= display_meta_tags %>` rendered once in `application.html.erb`, not scattered across `content_for :head` blocks in every view.
- **Must** — canonical origin (`default_url_options[:host]` or equivalent) is set to the production origin.
- **Must** — canonical URL derived from `request.original_url` with tracking params (`utm_*`, `fbclid`, `gclid`, `mc_cid`, `ref`) stripped.
- **Must** — canonical **omitted** when `noindex: true` is set (per Google's guidance).
- **Must** — fallback chain for missing fields: `set_meta_tags title: → MetaTags::Configuration.site`; `description: → excerpt → first paragraph of body`. Pages with blank titles or descriptions are the most common symptom of a broken fallback.
- **Should** — `robots` meta always includes `max-snippet:-1, max-image-preview:large, max-video-preview:-1`.
- **Should** — Twitter tags suppressed when they'd duplicate Open Graph (Twitter falls back to OG automatically; duplicate tags inflate head size).
- **Should** — `hreflang` alternates present on multilingual sites via `set_meta_tags alternate: { "en" => ..., "fr" => ... }`. Skip if monolingual.
- **Nice** — consolidated via a small `Seo::HeadDefaults` concern on `ApplicationController` rather than repeated per-action.

### 2. Structured data / JSON-LD graph (/10)

- **Must** — a single linked `@graph` JSON-LD block per page, not scattered `<script type="application/ld+json">` tags with duplicated data.
- **Must** — entities cross-reference via `@id` URIs (e.g. the `Article`'s `author` points to the site `Person`'s `@id`, not an inline duplicate).
- **Should** — the following entities are present where relevant: `WebSite`, `WebPage` or `Blog`, `Organization` or `Person`, `BlogPosting` / `Article`, `BreadcrumbList`, `ImageObject`.
- **Should** — trust signals on the `Organization`/`Person`: `publishingPrinciples`, `copyrightHolder`, `copyrightYear`, `knowsAbout`, and a `WebSite.potentialAction` of `SearchAction` if the site has search.
- **Should** — validates in [Rich Results Test](https://search.google.com/test/rich-results) and [ClassySchema](https://classyschema.org/Visualisation).
- **Nice** — JSON-LD assembled in a single `Seo::Graph` helper (`Seo::Graph.new(page).to_json_ld`) rather than hand-written per view, so the shape is consistent across pages.

### 3. Content schema and validation (/10)

**Sitepress apps:**
- **Must** — frontmatter linter (`rake seo:validate_frontmatter`) that asserts `title` (5–120 chars), `description` (15–160 chars), and `publish_date` on every resource under `app/content/pages/`.
- **Should** — `seo.og_image` frontmatter field populated (or auto-derived from the slug).
- **Should** — markdown-stripped `article_body` exposed to schema endpoints (up to ~10K chars, per Google's article body guidance).

**Dynamic apps:**
- **Must** — ActiveRecord length validations on the content model: `validates :title, length: 5..120`; `validates :description, length: 15..160`; `validates :slug, presence: true, uniqueness: true`.
- **Should** — `publish_date` or equivalent required for anything that should appear in the sitemap.
- **Should** — a `to_article_body` method that strips markdown/HTML for schema endpoints.

### 4. Open Graph images (/10)

- **Must** — every indexable page has an OG image. Many missing is a red flag.
- **Must** — 1200×675 (16:9, Google Discover minimum 1200px wide).
- **Must** — **JPEG**, not WebP or AVIF. Facebook, Twitter/X, and LinkedIn do not reliably support next-gen formats for OG previews.
- **Should** — generated programmatically from an ERB template via `grover` (headless Chromium) or similar, not authored by hand per post.
- **Should** — URL derives from the slug (`/og/#{slug}.jpg`), so the route is predictable and cacheable.
- **Should** — cached in Active Storage and regenerated in a Solid Queue job on post create/update, not on every request.

### 5. Sitemaps and indexing (/10)

- **Must** — `sitemap_generator` installed, `config/sitemap.rb` present, sitemap index at `/sitemap.xml.gz` (or `/sitemap.xml`) reachable in production.
- **Must** — `public/robots.txt` references the sitemap index (`Sitemap: https://example.com/sitemap.xml.gz`).
- **Must** — RSS feed exists (Rails `Builder` template at `app/views/feeds/index.rss.builder` or equivalent), advertised via `<link rel="alternate" type="application/rss+xml">`, and contains **full post content** (not truncated excerpts — truncated feeds frustrate readers and give LLM agents less to work with).
- **Should** — split per-collection via multiple `SitemapGenerator::Sitemap.create` calls with `group(filename: :posts)` / `group(filename: :pages)` — much easier to debug indexing in Google Search Console.
- **Should** — `lastmod` populated from `updated_at` (dynamic) or a git commit timestamp (Sitepress), **not** from frontmatter `publish_date` (which never changes).
- **Should** — IndexNow wired on each `after_commit`, with a key verification route at `/:key.txt`.

### 6. Agent discovery (/10)

- **Should** — schema endpoints (`/schema/posts.json`, `/schema/pages.json`) exposing corpus-wide JSON-LD for agents that can't render HTML.
- **Should** — schema map at `/schemamap.xml` listing every endpoint, with `Schemamap:` directive in `public/robots.txt`.
- **Should** — [`llms.txt`](https://llmstxt.org) at the site root listing indexable pages (title + description + URL) for LLM consumers. Generated dynamically from a controller that enumerates Sitepress resources and AR records.
- **Nice** — `<link rel="nlweb">` pointing to a conversational endpoint. NLWeb is early; the tag is one line and worth having, but it's not a scoring blocker in 2026.

### 7. Performance (/10)

- **Must** — `Cache-Control: public, max-age=31536000, immutable` on fingerprinted assets under `/assets/*` (Propshaft / Sprockets) and `/packs/*` (Webpacker, legacy). Rails sets this by default in production; verify it isn't overridden by a reverse proxy.
- **Should** — `image_tag @post.hero_image, loading: "lazy", decoding: "async"` on content images; Active Storage variants declared with `preprocessed: true` so they're generated on attach, not on first request.
- **Should** — primary web font preloaded in woff2: `<%= preload_link_tag asset_path("Inter.woff2"), as: "font", type: "font/woff2", crossorigin: "anonymous" %>`.
- **Should** — Turbo Drive prefetch enabled (default since Turbo 8) with `data-turbo-prefetch` on nav links or via the default viewport strategy.
- **Should** — `No-Vary-Search` response header stripping UTM parameters from cache key (via Rack middleware or CDN rule).
- **Nice** — heavy views fragment-cached (`cache @post`), Russian-doll style, so CDN misses are cheap.

### 8. Redirects and error handling (/10)

- **Must** — a redirect table for every URL that ever existed and moved. Maintained in `config/routes.rb` (`get "/old-path", to: redirect("/new-path", status: 301)`), or in a `config/initializers/rack_rewrite.rb` if bulk.
- **Must** — **301** (permanent), not 302, for permanent moves.
- **Must** — 404 page returns HTTP status `404`, not 200. Rails does this correctly by default when `config.exceptions_app = routes` — verify with `curl -I https://example.com/does-not-exist`.
- **Should** — fuzzy fallback in `ErrorsController#not_found`: compute Levenshtein distance (via the `levenshtein-ffi` gem) from the requested path against the cached known-URL set; if distance below threshold, 301 to the match; otherwise render the 404 page.

### 9. Build-time validation and content quality (/10)

- **Must** — `rake seo:audit` boots Rails, enumerates every URL in the sitemap, fetches each, and asserts: exactly one `<h1>`, non-empty `<title>` ≤ 60 chars, non-empty meta description 50–160 chars, no duplicate titles across pages, no duplicate descriptions, JSON-LD parses via the `json-ld` gem with no validation errors.
- **Should** — broken link checker in CI. A [lychee](https://github.com/lycheeverse/lychee-action) GitHub Action on push to content files + a weekly scheduled run catches dead links before they ship and detects link rot as external sites disappear.
- **Should** — content audited for readability (lead sentences, sentences under 20 words, transitions). Phase 2.5 chains this in via `readability-check`.

---

## Phase 2: Improve

Based on the audit, produce concrete code. Always ask before overwriting.

**Branch on the Phase 0 findings.** If `meta-tags` / `schema_dot_org` / `sitemap_generator` are already installed, skip the install step and focus on wiring the features the audit flagged as missing. If the user has a hand-rolled setup that already satisfies the **Must** checks in category 1, don't rip it out — add only what's missing. Replacement is a last resort.

### Install the stack

```ruby
# Gemfile
gem "meta-tags"
gem "schema_dot_org"
gem "sitemap_generator"
gem "grover"                      # headless Chromium for OG images (requires Chrome/Chromium on host)
gem "image_processing", ">= 1.2"  # libvips/ImageMagick wrapper for Active Storage
gem "faraday"                     # for IndexNow client (likely already present)
gem "levenshtein-ffi"             # for fuzzy 404 redirects
gem "ahoy_matey"                  # optional first-party analytics
gem "rack-rewrite", require: false  # optional bulk redirects
```

Then:

```sh
bundle install
bin/rails g meta_tags:install
bin/rails g sitemap:install
bin/rails g ahoy:install       # optional
```

Read each gem's CHANGELOG between the installed and latest version before upgrading — `meta-tags` and `sitemap_generator` have both shipped breaking changes at major versions.

### `application.html.erb` head block

Replace whatever head metadata the project has with a single `<%= display_meta_tags %>` call. The tag handles title, description, canonical, Open Graph, Twitter, and `extra_meta_tags` in one place.

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
<head>
  <%= display_meta_tags(
    site: Rails.application.config.site_name,
    reverse: true,
    separator: "—",
    og: { type: "website", locale: I18n.locale },
    twitter: { card: "summary_large_image" },
    robots: "index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1"
  ) %>
  <%= seo_graph_tag %>                  <!-- custom helper, below -->
  <%= preload_link_tag asset_path("Inter.woff2"), as: "font", type: "font/woff2", crossorigin: "anonymous" %>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag "application" %>
  <%= javascript_importmap_tags %>
</head>
<body>
  <%= yield %>
</body>
</html>
```

### `Seo::HeadDefaults` concern

Centralize canonical derivation and the `noindex` rule (which suppresses the canonical) on `ApplicationController`.

```ruby
# app/controllers/concerns/seo/head_defaults.rb
module Seo
  module HeadDefaults
    extend ActiveSupport::Concern

    TRACKING_PARAMS = %w[utm_source utm_medium utm_campaign utm_content utm_term
                         fbclid gclid mc_cid mc_eid ref].freeze

    included do
      before_action :set_canonical_default
    end

    private

    def set_canonical_default
      uri = URI.parse(request.original_url)
      stripped = Rack::Utils.parse_query(uri.query).except(*TRACKING_PARAMS)
      uri.query = stripped.any? ? URI.encode_www_form(stripped) : nil
      set_meta_tags canonical: uri.to_s
    end

    def noindex!
      set_meta_tags robots: "noindex, nofollow", canonical: nil
    end
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Seo::HeadDefaults
end
```

### `Seo::Graph` helper (linked `@graph` JSON-LD)

Ruby has no `astro-seo-graph` equivalent. Build thin glue on top of `schema_dot_org`:

```ruby
# app/helpers/seo_graph_helper.rb
module SeoGraphHelper
  def seo_graph_tag
    graph = Seo::Graph.for(page_context)
    content_tag(:script, raw(graph.to_json), type: "application/ld+json")
  end

  private

  def page_context
    { request:, controller: controller_name, action: action_name, instance: @post || @page }
  end
end

# app/lib/seo/graph.rb
module Seo
  class Graph
    ORG_ID    = ->(host) { "https://#{host}/#organization" }
    WEBSITE_ID = ->(host) { "https://#{host}/#website" }

    def self.for(context)
      new(context)
    end

    def initialize(context)
      @host = context[:request].host
      @url  = context[:request].original_url
      @instance = context[:instance]
    end

    def to_json
      { "@context" => "https://schema.org", "@graph" => entities }.to_json
    end

    private

    def entities
      [organization, website, webpage, *article_if_applicable, breadcrumbs]
    end

    def organization
      {
        "@type" => "Organization",
        "@id" => ORG_ID.call(@host),
        "name" => Rails.application.config.site_name,
        "url" => "https://#{@host}/",
        "logo" => { "@type" => "ImageObject", "url" => "https://#{@host}/logo.png" },
        "publishingPrinciples" => "https://#{@host}/editorial-policy"
      }
    end

    def website
      {
        "@type" => "WebSite",
        "@id" => WEBSITE_ID.call(@host),
        "url" => "https://#{@host}/",
        "publisher" => { "@id" => ORG_ID.call(@host) },
        "potentialAction" => {
          "@type" => "SearchAction",
          "target" => "https://#{@host}/search?q={query}",
          "query-input" => "required name=query"
        }
      }
    end

    def webpage
      {
        "@type" => "WebPage",
        "@id" => "#{@url}#webpage",
        "url" => @url,
        "isPartOf" => { "@id" => WEBSITE_ID.call(@host) }
      }
    end

    def article_if_applicable
      return [] unless @instance.respond_to?(:title) && @instance.respond_to?(:published_at)
      [{
        "@type" => "BlogPosting",
        "@id" => "#{@url}#article",
        "headline" => @instance.title,
        "datePublished" => @instance.published_at.iso8601,
        "dateModified" => @instance.updated_at.iso8601,
        "author" => { "@id" => ORG_ID.call(@host) },
        "mainEntityOfPage" => { "@id" => "#{@url}#webpage" }
      }]
    end

    def breadcrumbs
      # build a BreadcrumbList from the request path
      { "@type" => "BreadcrumbList", "@id" => "#{@url}#breadcrumbs", "itemListElement" => [] }
    end
  end
end
```

Expand `article_if_applicable` and `breadcrumbs` to match the app's models.

### Content schema

**Sitepress frontmatter schema** (documented convention for `app/content/pages/**/*.md`):

```yaml
---
title: "Clear page title (5–120 chars)"
description: "One-sentence description used for meta description and OG (15–160 chars)."
publish_date: 2026-04-13
seo:
  noindex: false
  og_image: /og/some-slug.jpg
---
```

Plus a validator:

```ruby
# lib/tasks/seo.rake
namespace :seo do
  desc "Validate Sitepress frontmatter for SEO requirements"
  task validate_frontmatter: :environment do
    site = Sitepress.sites.fetch("app/content")
    errors = []
    site.resources.each do |resource|
      data = resource.data || {}
      title = data["title"].to_s
      description = data["description"].to_s
      errors << "#{resource.request_path}: title must be 5–120 chars (got #{title.length})" unless (5..120).cover?(title.length)
      errors << "#{resource.request_path}: description must be 15–160 chars (got #{description.length})" unless (15..160).cover?(description.length)
      errors << "#{resource.request_path}: missing publish_date" unless data["publish_date"]
    end
    abort(errors.join("\n")) if errors.any?
    puts "OK — #{site.resources.count} resources validated"
  end
end
```

**Dynamic model validations:**

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates :title, length: { in: 5..120 }
  validates :description, length: { in: 15..160 }
  validates :slug, presence: true, uniqueness: true

  def article_body
    ActionController::Base.helpers.strip_tags(body.to_s).squish.truncate(10_000, omission: "")
  end
end
```

### Open Graph image generator (1200×675 JPEG)

```erb
<!-- app/views/og_images/show.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <style>
    body { margin: 0; font-family: Inter, system-ui, sans-serif; }
    .og { width: 1200px; height: 675px; padding: 80px; box-sizing: border-box;
          display: flex; flex-direction: column; justify-content: space-between;
          background: linear-gradient(135deg, #0f172a, #1e293b); color: white; }
    .title { font-size: 72px; font-weight: 800; line-height: 1.1; }
    .site { font-size: 28px; opacity: 0.7; }
  </style>
</head>
<body>
  <div class="og">
    <div class="title"><%= @title %></div>
    <div class="site"><%= Rails.application.config.site_name %></div>
  </div>
</body>
</html>
```

```ruby
# app/controllers/og_images_controller.rb
class OgImagesController < ApplicationController
  def show
    post = Post.friendly.find(params[:slug])
    @title = post.title
    html = render_to_string(action: :show, layout: false)
    jpeg = Grover.new(html, format: "jpeg", width: 1200, height: 675, quality: 85).to_jpeg
    send_data jpeg, type: "image/jpeg", disposition: "inline"
  end
end

# config/routes.rb
get "/og/:slug.jpg", to: "og_images#show", as: :og_image

# app/jobs/og_image_job.rb — regenerate and attach to Active Storage on create/update
class OgImageJob < ApplicationJob
  def perform(post)
    html = ApplicationController.render(template: "og_images/show", layout: false, assigns: { title: post.title })
    jpeg = Grover.new(html, format: "jpeg", width: 1200, height: 675, quality: 85).to_jpeg
    post.og_image.attach(io: StringIO.new(jpeg), filename: "#{post.slug}-og.jpg", content_type: "image/jpeg")
  end
end

# app/models/post.rb
has_one_attached :og_image
after_commit -> { OgImageJob.perform_later(self) }, on: [:create, :update]
```

### `config/sitemap.rb` (per-collection + `lastmod`)

```ruby
# config/sitemap.rb
SitemapGenerator::Sitemap.default_host = "https://#{Rails.application.config.site_host}"
SitemapGenerator::Sitemap.sitemaps_host = SitemapGenerator::Sitemap.default_host
SitemapGenerator::Sitemap.create_index = true

SitemapGenerator::Sitemap.create do
  group(filename: :posts, sitemaps_path: "sitemaps/") do
    Post.published.find_each do |post|
      add post_path(post), lastmod: post.updated_at, changefreq: "weekly"
    end
  end

  if defined?(Sitepress)
    group(filename: :pages, sitemaps_path: "sitemaps/") do
      Sitepress.sites.fetch("app/content").resources.each do |resource|
        next if resource.data&.dig("seo", "noindex")
        add resource.request_path, lastmod: git_lastmod(resource.asset.path)
      end
    end
  end
end

def git_lastmod(path)
  ts = `git log -1 --format=%cI -- "#{path}" 2>/dev/null`.strip
  ts.empty? ? Time.current : Time.iso8601(ts)
rescue ArgumentError
  Time.current
end
```

Schedule refreshes via Solid Queue recurring tasks (Rails 8) or `whenever`:

```yaml
# config/recurring.yml (Solid Queue)
production:
  sitemap_refresh:
    class: SitemapRefreshJob
    schedule: every day at 3am
```

Point `public/robots.txt`:

```text
User-agent: *
Allow: /

Sitemap: https://example.com/sitemap.xml.gz
Schemamap: https://example.com/schemamap.xml
```

### RSS feed

```erb
<!-- app/views/feeds/index.rss.builder -->
xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title Rails.application.config.site_name
    xml.link root_url
    xml.description "Latest posts"
    xml.language "en"
    xml.tag! "atom:link", href: feed_url, rel: "self", type: "application/rss+xml"

    @posts.each do |post|
      xml.item do
        xml.title post.title
        xml.link post_url(post)
        xml.guid post_url(post), isPermaLink: "true"
        xml.pubDate post.published_at.rfc822
        xml.description post.description
        xml.tag! "content:encoded" do
          xml.cdata! post.body.to_s   # full content, not truncated
        end
      end
    end
  end
end
```

```ruby
# app/controllers/feeds_controller.rb
class FeedsController < ApplicationController
  def index
    @posts = Post.published.order(published_at: :desc).limit(50)
    respond_to { |f| f.rss }
  end
end

# config/routes.rb
get "/feed.rss", to: "feeds#index", defaults: { format: :rss }, as: :feed
```

Advertise the feed from the layout:

```erb
<%= auto_discovery_link_tag :rss, feed_url, title: "#{Rails.application.config.site_name} — RSS" %>
```

### IndexNow

```ruby
# app/models/concerns/notifies_index_now.rb
module NotifiesIndexNow
  extend ActiveSupport::Concern
  included do
    after_commit :notify_index_now, on: [:create, :update]
  end

  private

  def notify_index_now
    IndexNowJob.perform_later(public_url)
  end
end

# app/jobs/index_now_job.rb
class IndexNowJob < ApplicationJob
  ENDPOINT = "https://api.indexnow.org/indexnow".freeze

  def perform(url)
    key = Rails.application.credentials.indexnow_key!
    response = Faraday.post(ENDPOINT) do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = {
        host: Rails.application.config.site_host,
        key: key,
        keyLocation: "https://#{Rails.application.config.site_host}/#{key}.txt",
        urlList: [url]
      }.to_json
    end
    Rails.logger.info("IndexNow #{response.status}: #{url}")
  end
end

# config/routes.rb — key verification route
get "/:key.txt", to: ->(env) {
  key = env["action_dispatch.request.path_parameters"][:key]
  expected = Rails.application.credentials.indexnow_key
  key == expected ? [200, { "Content-Type" => "text/plain" }, [key]] : [404, {}, ["not found"]]
}, constraints: { key: /[a-f0-9]{8,128}/ }
```

Generate the key once (`SecureRandom.hex(16)`) and commit it to Rails credentials.

### llms.txt

```ruby
# app/controllers/llms_txt_controller.rb
class LlmsTxtController < ApplicationController
  def show
    entries = []
    entries << "# #{Rails.application.config.site_name}"
    entries << ""
    entries << "## Posts"
    Post.published.find_each do |post|
      entries << "- [#{post.title}](#{post_url(post)}): #{post.description}"
    end
    if defined?(Sitepress)
      entries << ""
      entries << "## Pages"
      Sitepress.sites.fetch("app/content").resources.each do |resource|
        next if resource.data&.dig("seo", "noindex")
        data = resource.data || {}
        url = "https://#{Rails.application.config.site_host}#{resource.request_path}"
        entries << "- [#{data['title']}](#{url}): #{data['description']}"
      end
    end
    render plain: entries.join("\n"), content_type: "text/plain"
  end
end

# config/routes.rb
get "/llms.txt", to: "llms_txt#show"
```

### Schema endpoints and schema map

```ruby
# app/controllers/seo/schema_controller.rb
module Seo
  class SchemaController < ApplicationController
    def posts
      graph = Post.published.map { |post| Seo::Graph.for_article(post) }
      render json: { "@context" => "https://schema.org", "@graph" => graph },
             content_type: "application/ld+json"
    end

    def pages
      return head :not_found unless defined?(Sitepress)
      graph = Sitepress.sites.fetch("app/content").resources.reject { |r| r.data&.dig("seo", "noindex") }
                       .map { |r| Seo::Graph.for_sitepress(r) }
      render json: { "@context" => "https://schema.org", "@graph" => graph },
             content_type: "application/ld+json"
    end
  end
end

# config/routes.rb
namespace :schema, path: "schema", defaults: { format: :json } do
  get "posts", to: "seo/schema#posts"
  get "pages", to: "seo/schema#pages"
end

get "/schemamap.xml", to: "seo/schema#map", defaults: { format: :xml }
```

Add `Schemamap: https://example.com/schemamap.xml` to `public/robots.txt` (see sitemap example above).

### Redirects

**Small redirect table — `config/routes.rb`:**

```ruby
Rails.application.routes.draw do
  get "/old-path",   to: redirect("/new-path", status: 301)
  get "/blog/:slug", to: redirect("/posts/%{slug}", status: 301)
  # ...
end
```

**Bulk — `rack-rewrite`:**

```ruby
# config/initializers/rack_rewrite.rb
Rails.application.config.middleware.insert_before(Rack::Runtime, Rack::Rewrite) do
  r301 %r{^/legacy/(.*)$}, "/$1"
  r301 "/about-us", "/about"
  # load from a CSV if there are hundreds
  CSV.foreach(Rails.root.join("config/redirects.csv"), headers: true) do |row|
    r301 row["from"], row["to"]
  end
end
```

**Fuzzy fallback on 404:**

```ruby
# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  def not_found
    suggestion = fuzzy_match(request.path)
    if suggestion
      redirect_to suggestion, status: :moved_permanently
    else
      render status: :not_found
    end
  end

  private

  def fuzzy_match(path)
    known = Rails.cache.fetch("seo:known_urls", expires_in: 1.hour) do
      Post.published.pluck(:slug).map { |s| "/posts/#{s}" }
    end
    best, distance = known.map { |k| [k, Levenshtein.distance(path, k)] }.min_by { |_, d| d }
    best if distance && distance <= (path.length * 0.25)
  end
end

# config/application.rb
config.exceptions_app = routes

# config/routes.rb
match "/404", to: "errors#not_found", via: :all
match "*path", to: "errors#not_found", via: :all   # keep this LAST
```

Seeding the redirect table is the unpleasant part. If migrating from WordPress or another CMS, export the old URL list (WP-CLI `wp post list`, database dump, or the old sitemap via Wayback Machine), diff against the current sitemap, and commit the table once. Maintain it whenever you change a slug.

### Performance headers

Syntax depends on the host. Pick the one matching Phase 0's detected deployment target.

**Cloudflare Pages / Netlify / Fly (via `public/_headers`):**

```text
/assets/*
  Cache-Control: public, max-age=31536000, immutable

/*
  No-Vary-Search: key-order, params=("utm_source" "utm_medium" "utm_campaign" "utm_content" "utm_term")
```

Ensure `config.public_file_server.headers = { "Cache-Control" => "public, max-age=31536000, immutable" }` in `config/environments/production.rb` (Rails default, but verify).

**Heroku / Render / Rails-behind-a-CDN:**

Add a Rack middleware for `No-Vary-Search`:

```ruby
# app/middleware/no_vary_search.rb
class NoVarySearch
  def initialize(app); @app = app; end
  def call(env)
    status, headers, body = @app.call(env)
    headers["No-Vary-Search"] = %q(key-order, params=("utm_source" "utm_medium" "utm_campaign" "utm_content" "utm_term"))
    [status, headers, body]
  end
end

# config/application.rb
config.middleware.use NoVarySearch
```

**Self-hosted nginx:**

```nginx
location ~* ^/assets/ {
  expires 1y;
  add_header Cache-Control "public, max-age=31536000, immutable";
}
```

### Broken link checker in CI

Add a [lychee](https://github.com/lycheeverse/lychee-action) workflow at `.github/workflows/link-check.yml`:

```yaml
name: Link Check
on:
  push:
    paths:
      - 'app/content/**'
      - 'app/views/**'
      - '**/*.md'
  schedule:
    - cron: '0 9 * * 1'  # Weekly, Mondays 09:00 UTC — catches link rot
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lycheeverse/lychee-action@v2
        with:
          args: --no-progress './app/content/**/*.md' './app/views/**/*.erb' './**/*.md'
          fail: true
```

Push-triggered runs block broken links from shipping. The weekly run catches external link rot.

### `rake seo:audit` (build-time validation)

```ruby
# lib/tasks/seo.rake
namespace :seo do
  desc "Audit every sitemap URL for SEO regressions"
  task audit: :environment do
    require "net/http"
    require "nokogiri"
    require "json/ld"

    host = Rails.application.config.site_host
    urls = []
    Post.published.find_each { |p| urls << Rails.application.routes.url_helpers.post_url(p, host: host) }

    titles = {}
    descriptions = {}
    errors = []

    urls.each do |url|
      body = Net::HTTP.get(URI(url))
      doc = Nokogiri::HTML(body)
      title = doc.at_css("title")&.text.to_s.strip
      description = doc.at_css('meta[name="description"]')&.[]("content").to_s.strip
      h1_count = doc.css("h1").count
      jsonld = doc.css('script[type="application/ld+json"]').map(&:text).join

      errors << "#{url}: #{h1_count} H1 tags (want 1)" unless h1_count == 1
      errors << "#{url}: empty title" if title.empty?
      errors << "#{url}: title > 60 chars" if title.length > 60
      errors << "#{url}: description not 50–160 chars (#{description.length})" unless (50..160).cover?(description.length)
      errors << "#{url}: duplicate title (#{title})" if titles[title]
      errors << "#{url}: duplicate description" if descriptions[description]
      titles[title] = url
      descriptions[description] = url
      JSON.parse(jsonld) if jsonld.present?   # raises on invalid JSON
    rescue => e
      errors << "#{url}: #{e.class} #{e.message}"
    end

    abort(errors.join("\n")) if errors.any?
    puts "OK — #{urls.size} URLs audited"
  end
end
```

Wire it into CI so regressions block merges.

---

## Phase 2.5: Readability pass

Invoke the `readability-check` skill on every piece of prose the skill generated or modified: page titles, meta descriptions, schema `description` fields, FAQ entries, frontmatter `description` values, and any post bodies you wrote.

SEO titles and descriptions are short but consequential — a long passive opening sentence in a meta description wastes the ~160 characters Google shows in results. Apply the ⚠ and ✗ fixes directly. Skip the pass for technical strings (URLs, schema `@id` values, enum values).

If the project has a large content corpus in the database, note that the same `readability-check` skill can audit individual posts — mention this to the user as a follow-up, but don't audit the entire corpus yourself.

---

## Phase 3: Verify

- `bin/rails zeitwerk:check` — catches eager-load issues with the new helpers and controllers.
- `bin/rails server` and open the homepage; view source. The `<head>` should now contain one `<title>`, one canonical, Open Graph, Twitter card, and one `<script type="application/ld+json">` with a linked `@graph`.
- `bundle exec rake seo:audit` — the full validation pass (H1, duplicate meta, schema).
- `bundle exec rake sitemap:refresh:no_ping` — builds the sitemap index; open `/sitemap.xml.gz` locally.
- If Sitepress is present: `bundle exec rake seo:validate_frontmatter`.
- Submit the homepage to [Rich Results Test](https://search.google.com/test/rich-results) and [ClassySchema](https://classyschema.org/Visualisation).
- `curl -I https://example.com/does-not-exist` — confirm `HTTP/2 404`, not 200.
- If IndexNow is wired, `curl https://example.com/<key>.txt` should return the key.
- Remind the user about tasks that can't be automated:
  - Register the site in [Google Search Console](https://search.google.com/search-console) and [Bing Webmaster Tools](https://www.bing.com/webmasters).
  - Submit the sitemap index in both.
  - Generate an IndexNow key (`SecureRandom.hex(16)`) and store it in Rails credentials.
  - Verify Ahoy is recording visits (or install [Plausible](https://plausible.io/) / Fathom).

---

## Output format

```markdown
## Rails SEO audit: [site name]

### Score
| Category                                     | Score |
|----------------------------------------------|------:|
| 1. `meta-tags` helper and head metadata      |  x/10 |
| 2. Structured data / JSON-LD graph           |  x/10 |
| 3. Content schema and validation             |  x/10 |
| 4. Open Graph images                         |  x/10 |
| 5. Sitemaps and indexing                     |  x/10 |
| 6. Agent discovery                           |  x/10 |
| 7. Performance                               |  x/10 |
| 8. Redirects and error handling              |  x/10 |
| 9. Build-time validation and content quality |  x/10 |
| **Total**                                    | xx/90 |

### Findings
[Grouped by category. Quote actual code/config. Be specific.]

### Files generated or changed
[List with short description of each.]

### Next steps
[Non-file tasks: GSC, Bing Webmaster Tools, IndexNow key generation, analytics.]
```

---

## Key principles

- **Opinionated defaults over optionality.** Joost's guide picks a stack; this skill applies its Rails translation. Don't offer five gems when one works.
- **No Ruby "spine" gem exists.** Ruby has no `astro-seo-graph` equivalent. Build thin glue (`Seo::Graph` helper + `Seo::HeadDefaults` concern) on top of `meta-tags` + `schema_dot_org` rather than hand-rolling everything or searching for a missing silver bullet.
- **Topics, not keyphrases.** When reviewing content, focus on topical coverage and readability, not keyword density.
- **Cached HTML is the baseline.** Rails wasn't built static-first like Astro, but fragment caching + Russian-doll + a CDN in front gets to the same destination: HTML served from cache, not regenerated on every request.
- **Agent discovery matters now.** Schema endpoints, `/schemamap.xml`, `/llms.txt`, NLWeb tags — the crawler is no longer the only consumer, and Rails apps need to serve LLM consumers just as deliberately as static sites do.
