---
name: frontend-rails
description: |
  Expert frontend design for Ruby-on-Rails ERB templates.
  Framework-agnostic: supports Bootstrap 5.1, Bootstrap 5.3, and Tailwind CSS v4.
  MUST trigger whenever editing, creating, or reviewing any .html.erb file, any file in app/views/, any file in app/helpers/, any CSS/SCSS file in app/assets/stylesheets/,
  or when the user mentions anything about views, templates, forms, tables, layouts, Bootstrap, Tailwind, styling, UI, or frontend HTML work.
  Also trigger when the user asks about CSS classes, form helpers, or view patterns.
---

# Frontend Rails — ERB + CSS Framework Expert

You are working in a Ruby on Rails app. This skill ensures every ERB template you write or edit uses the correct CSS framework for the project.

## Step 1: Detect the CSS Framework

Before writing any markup, determine which framework the project uses:

```bash
# Check for Tailwind
grep -r "tailwindcss" Gemfile package.json app/assets/stylesheets/ 2>/dev/null
ls tailwind.config.* 2>/dev/null
grep -r "@import.*tailwindcss" app/assets/stylesheets/ 2>/dev/null

# Check for Bootstrap — and which version
grep -r "bootstrap" Gemfile package.json 2>/dev/null
grep -r "bootstrap@" app/views/layouts/ 2>/dev/null
grep -r "bootstrap" yarn.lock package-lock.json Gemfile.lock 2>/dev/null | grep -o 'bootstrap@[0-9.]*'
```

**Use the detected framework exclusively.** Never mix frameworks. If both are present, ask the user which to use for the current work.

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

1. Using the correct CSS framework (don't mix Bootstrap and Tailwind)
2. Using the correct Bootstrap version classes (5.1 vs 5.3 differences matter)
3. Using project-specific view helpers where they exist
4. No `Time.now` / `Date.today` — use `Time.current` / `Date.current`
5. No `number_to_currency` if money-rails is present — use `humanized_money_with_symbol`
6. Forms use `simple_form_for` or `form_with` consistently with the project
7. Icons use the project's icon system (not a different library)
