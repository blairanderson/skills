---
name: frontend-rails
description: |
  Expert frontend engineer for Ruby on Rails apps. Auto-detects CSS framework (Bootstrap 5.1, Bootstrap 5.3, Tailwind CSS v4) and JavaScript setup (importmaps, Bun bundler, React) at load time — no guessing.
  Knows Rails ERB conventions: simple_form_for, form_with, content_for, money-rails, timezone-safe time helpers, and project-specific view helpers.
  Also knows the hybrid importmaps + Bun + React 19 pattern: React apps in frontend/<AppName>/, bundled by Bun, pinned via importmap, mounted in ERB with javascript_import_module_tag.
  Trigger whenever the user is: editing or creating .html.erb files, working in app/views/ or app/assets/stylesheets/, adding or wiring up a React component in a Rails app, asking about Bootstrap or Tailwind classes, building forms or tables, adding interactivity (Stimulus or React), or any UI/frontend/styling work in a Rails project.
---

# Frontend Rails — ERB + CSS Framework Expert

You are working in a Ruby on Rails app. This skill ensures every ERB template you write or edit uses the correct CSS framework and JavaScript setup for the project.

## Project Context (auto-detected at load time)

* IMPORTMAP_RB = !`ls config/importmap.rb 2>/dev/null && echo "present" || echo "absent"`
* IMPORTMAP_GEM = !`grep -s "importmap-rails" Gemfile || echo ""`
* BUNDLER_FILES = !`ls package.json bun.lockb yarn.lock package-lock.json 2>/dev/null || true`
* REACT_INSTALLED = !`grep -s '"react"' package.json || echo ""`
* TAILWIND_GEMFILE = !`grep -s "tailwindcss" Gemfile || echo ""`
* TAILWIND_CSS = !`grep -rls "@import.*tailwindcss" app/assets/stylesheets/ 2>/dev/null || echo ""`
* BOOTSTRAP_VERSION = !`grep -h "bootstrap" yarn.lock package-lock.json bun.lockb Gemfile.lock 2>/dev/null | grep -o 'bootstrap@[0-9.]*' | head -1 || echo ""`
* BOOTSTRAP_GEMFILE = !`grep -s "bootstrap" Gemfile || echo ""`

Use the values above — do not re-run these checks.

## Step 1: Detect the CSS Framework

From the auto-detected values above:

- **Tailwind**: `TAILWIND_GEMFILE` or `TAILWIND_CSS` is non-empty → use Tailwind CSS v4
- **Bootstrap**: check `BOOTSTRAP_VERSION` for `5.3` or `5.1`; if empty, check `BOOTSTRAP_GEMFILE`
- **Conflict**: if both are present, ask the user which to use for the current work

**Use the detected framework exclusively.** Never mix frameworks.

## Step 1b: Detect the JavaScript Setup

From the auto-detected values above:

- **Importmaps**: `IMPORTMAP_RB` is `present` or `IMPORTMAP_GEM` is non-empty
- **Bundler-based**: `BUNDLER_FILES` lists any files
- **React**: `REACT_INSTALLED` is non-empty (only relevant if bundler-based)

**If importmaps is detected:**
- The project does NOT use a Node.js bundler — there is no `npm install`, no build step, no JSX compilation
- Do NOT suggest React components, JSX, or npm packages
- JavaScript lives in `app/javascript/` as plain ES modules, mapped in `config/importmap.rb`
- For interactivity, use **Stimulus controllers** (`app/javascript/controllers/`)
- If the user wants something React-like, suggest Stimulus + ERB or ask whether they want to migrate to a bundler first — don't assume

**If a bundler + React is detected:**
- JSX/TSX components are valid; follow the project's existing component conventions
- Check `app/javascript/` for existing component structure before creating new ones
- If importmaps is also present (hybrid setup), read `references/rails-react-bun.md` — this describes the Bun-bundle-then-pin pattern used to serve React apps through importmap

**If neither is clear**, check the application layout for `javascript_importmap_tags` vs `javascript_include_tag "application"` vs a Vite/build tag, then ask the user if still ambiguous.

Read the appropriate reference file:
- **Bootstrap 5.1**: `references/bootstrap-5.1-cheatsheet.md`
- **Bootstrap 5.3**: `references/bootstrap-5.3-cheatsheet.md`
- **Tailwind CSS v4**: `references/tailwind4.md`

## Step 2: Follow Rails View Conventions

### Form Patterns

#### simple_form_for (preferred for model-backed forms)

```erb
<%= simple_form_for(@model) do |f| %>
  <%= f.input :name, placeholder: "Enter name" %>
  <%= f.input :category, as: :select, collection: Category.all %>
  <%= f.button :submit, class: "btn btn-primary" %>
<% end %>
```

#### form_with (Rails 5.1+ standard)

```erb
<%= form_with model: @model, local: true do |f| %>
  <%= f.label :name %>
  <%= f.text_field :name, class: "form-control" %>
  <%= f.submit class: "btn btn-primary" %>
<% end %>
```

#### Filter/search forms

```erb
<%= form_with url: search_path, method: :get, local: true do |f| %>
  <%= search_field_tag :q, params[:q], placeholder: "Search...", class: "form-control" %>
  <%= submit_tag "Search", class: "btn btn-primary" %>
<% end %>
```

### Layout Content Blocks

```erb
<%# Sidebar content %>
<% content_for(:sidebar) do %>
  <nav class="nav flex-column">
    <%= link_to "Section 1", "#section-1", class: "nav-link" %>
  </nav>
<% end %>

<%# Page-specific JavaScript %>
<% content_for(:javascript) do %>
  <script>
    // Page-specific JS
  </script>
<% end %>

<%# Inject into <head> %>
<% content_for(:head) do %>
  <meta name="robots" content="noindex">
<% end %>
```

### Money Formatting

If the app uses the `money-rails` gem, always use `humanized_money_with_symbol` — never `number_to_currency`.

```erb
<%= humanized_money_with_symbol(product.price) %>
```

### Time

Always use `Time.current` / `Date.current` — never `Time.now` / `Date.today` (timezone-aware).

## Step 3: Read Project Helpers

Before creating views, check for project-specific view helpers:

```bash
ls app/helpers/
grep -r "def " app/helpers/ | head -30
```

Use existing helpers rather than reinventing patterns. Common custom helpers to look for:
- Table wrappers (sortable columns, export buttons)
- Pagination helpers
- Icon systems
- Tooltip/popover wrappers
- Async rendering helpers
- Link helpers (outbound links, copy buttons)

## ERB Formatting

If the project uses `herb` for ERB formatting:
```bash
bun run herb:format        # Auto-format
bun run herb:format:check  # Check only
```

## Checklist: Before Submitting ERB Changes

1. Verified JS setup (importmaps vs bundler) — no React/JSX in importmaps projects
2. Using the correct CSS framework (don't mix Bootstrap and Tailwind)
2. Using the correct Bootstrap version classes (5.1 vs 5.3 differences matter)
3. Using project-specific view helpers where they exist
4. No `Time.now` / `Date.today` — use `Time.current` / `Date.current`
5. No `number_to_currency` if money-rails is present — use `humanized_money_with_symbol`
6. Forms use `simple_form_for` or `form_with` consistently with the project
7. Icons use the project's icon system (not a different library)
