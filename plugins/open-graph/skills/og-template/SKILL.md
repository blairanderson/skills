---
name: og-template
description: "Use when: the user wants to convert an HTML, SVG, or URL design into an OG Shot template JSON blob. Triggers on phrases like '/og:template @file.html', 'convert this design to a template', 'turn this HTML into an OG template', 'make an OG Shot template from this', 'build a template from this design', or any request to produce a TemplateDef JSON for the OG Shot admin. Always use this skill when the user references an @file or URL alongside template/OG/social card intent."
argument-hint: "@design.html  or  @https://example.com"
allowed-tools: Read, WebFetch, Bash, Write
---

# OG Template — Convert a Design to TemplateDef JSON

Your job is to read a design (HTML file, SVG, or live URL) and produce a valid **TemplateDef JSON blob** the user can paste directly into the OG Shot admin's JSON tab (`/app/templates/new?tab=json`).

## What TemplateDef JSON looks like

```json
{
  "name": "my-template",
  "defaultSize": { "w": 1200, "h": 630 },
  "required": ["title"],
  "defaults": { "eyebrow": "My Brand" },
  "sampleParams": {
    "title": "Example headline that shows off the layout",
    "eyebrow": "My Brand",
    "subtitle": "A short supporting line"
  },
  "paramTypes": { "avatar": "url", "bg_color": "color" },
  "tree": {
    "type": "div",
    "tw": "flex h-full w-full flex-col justify-center bg-slate-950 text-white px-20",
    "children": [
      { "type": "div", "tw": "text-2xl text-slate-400 mb-4", "text": "{{eyebrow}}", "when": "eyebrow" },
      { "type": "div", "tw": "text-7xl font-bold leading-tight", "text": "{{title}}" },
      { "type": "div", "tw": "text-4xl text-slate-300 mt-6", "text": "{{subtitle}}", "when": "subtitle" }
    ]
  }
}
```

## Step 1 — Read the input

**If given `@file.html` or `@file.svg`:** Read the file. Extract layout structure, background colors, font sizes, font weights, text content, and any image elements.

**If given a URL:** Fetch the page, look for the `og:image` meta tag URL, fetch that image URL too so you can see the actual rendered card. Use the page's brand colors, headline text, and structure as your reference.

**If given inline HTML/SVG:** Work directly from what was pasted.

## Step 2 — Identify all dynamic slots

Scan the design for anything that should be a parameter:
- Text that will change per-page (headlines, descriptions, labels, dates, stats)
- Images (avatars, logos, cover images)
- Colors that should be overridable (background, text, accent)

Name params clearly and specifically:
- `title` not `text1`, `repo` not `name`, `avatar` not `img`, `lang_color` for a color dot

## Step 3 — Decide param roles (make smart defaults, ask once)

Apply these rules first, then present your decisions to the user for a single confirmation pass:

| Situation | Decision |
|-----------|----------|
| Content that is meaningless without it (a repo name, page title) | `required` |
| Content that has a sensible brand fallback (eyebrow label, CTA text) | `defaults` with the fallback value |
| Content that enriches but isn't essential (subtitle, description, byline) | optional — use `when` to hide node if absent |
| A color extracted from the design | `defaults` with the hex value; add to `paramTypes` as `"color"` |
| An image URL | `paramTypes` as `"url"`; use `when` to hide if absent |

Present: "Here's my read on the params — confirm or adjust before I generate the JSON:"

```
REQUIRED (must be provided):
  title         — the main headline

OPTIONAL with defaults (used if not overridden):
  eyebrow       → "My Brand"
  bg_color      → "#0d0d0d"   (color picker)

OPTIONAL (hidden when absent):
  subtitle, avatar (url), byline
```

Wait for the user's go-ahead or corrections before generating.

## Step 4 — Build the tree

The tree mirrors the design's layout hierarchy. Always start with:

### Mobile-first text sizing (non-negotiable defaults)

OG images are most often seen as thumbnails on mobile screens. Default to these minimum sizes — do NOT start smaller and wait for the user to ask you to enlarge:

| Role | Minimum fontSize |
|------|-----------------|
| Eyebrow / label / badge | 32px |
| Title / headline | 72–96px |
| Subtitle / description | 48px |
| Footer / site / meta text | 32px |

If you derive sizes from a design that uses smaller values, scale them up to these minimums automatically before outputting the JSON. Only go below these if the user explicitly asks for a smaller size.

```json
{ "type": "div", "tw": "flex h-full w-full ...", "children": [...] }
```

**Use `tw` for layout**, `style` for exact hex colors and pixel sizes that don't map to clean Tailwind:

```json
{ "type": "div", "tw": "flex items-center", "style": { "backgroundColor": "#0d1117", "padding": "60px 72px" } }
```

**Important constraints:**
- `gap` in `style` may not render in Satori — use `marginRight`/`marginBottom` on individual children instead
- `borderRadius: "50%"` makes a circle
- `when` hides the entire subtree if that param is absent/empty
- `{{param}}` interpolation works in `text`, `src`, and string `style` values (e.g. `{ "backgroundColor": "{{bg_color}}" }`)
- Supported element types: `div span img p h1 h2 h3 h4 h5 h6`

**Common patterns:**

Circular avatar:
```json
{ "type": "img", "style": { "width": 96, "height": 96, "borderRadius": "50%", "marginRight": "24px" }, "src": "{{avatar}}", "when": "avatar" }
```

Color dot (e.g. language indicator):
```json
{ "type": "div", "style": { "width": 14, "height": 14, "borderRadius": "50%", "backgroundColor": "{{lang_color}}", "marginRight": "8px" } }
```

Badge / tag:
```json
{ "type": "div", "style": { "backgroundColor": "rgba(74,222,128,0.12)", "border": "1px solid rgba(74,222,128,0.25)", "borderRadius": "4px", "padding": "4px 12px", "color": "#4ade80", "fontSize": "13px", "fontWeight": "700" }, "text": "{{tag}}" }
```

Footer bar:
```json
{ "type": "div", "tw": "flex items-center", "style": { "borderTopWidth": "1px", "borderTopStyle": "solid", "borderTopColor": "#2a2a2a", "paddingTop": "24px" }, "children": [...] }
```

Two-column layout:
```json
{ "type": "div", "tw": "flex h-full w-full", "children": [
  { "type": "div", "tw": "flex flex-col justify-center", "style": { "width": "60%", "padding": "60px" }, "children": [...] },
  { "type": "div", "tw": "flex items-center justify-center", "style": { "width": "40%" }, "children": [...] }
]}
```

## Step 5 — Output the JSON

After the user confirms the param decisions, output the complete `TemplateDef` as a fenced JSON block, ready to paste:

```
Here's your template JSON — paste it into the admin's JSON tab (/app/templates/new?tab=json):

\`\`\`json
{
  "name": "...",
  ...
}
\`\`\`

Preview it at: /api/preview?template=<name>&title=...&<other_sample_params>
```

## Name derivation

If no name is specified, derive it from the filename (`my-design.html` → `my-design`) or hostname (`vercel.com` → `vercel`). Name rules: lowercase, hyphens only, `[a-z0-9][a-z0-9-]{0,63}`. The word `new` is reserved.

## sampleParams

Fill `sampleParams` with realistic-looking values for every param — these show up in previews and documentation. Use actual brand names, real-sounding titles, plausible URLs. Never use "Lorem ipsum" or "test".

## Validation checklist (run before outputting)

- [ ] `name` matches `/^[a-z0-9][a-z0-9-]{0,63}$/` and isn't `new`
- [ ] `required` is an array of strings
- [ ] `sampleParams` has a value for every param
- [ ] Every `when` value is a known param name
- [ ] Every `{{param}}` reference appears in at least one of: `required`, `defaults`, `sampleParams`
- [ ] Root tree node has `"tw": "flex h-full w-full ..."`
- [ ] No `gap` in `style` objects (use margin instead)
- [ ] `img` nodes have `src`, not `text`
