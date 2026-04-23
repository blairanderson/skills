# Open Graph Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install open-graph@blairanderson-skills
```

This plugin adds one skill for converting HTML or SVG designs into OG Shot template JSON blobs.

---

## `/og-template`

Convert an HTML file, SVG, or live URL into a valid `TemplateDef` JSON blob ready to paste into the OG Shot admin's JSON tab.

```shell
/og-template @design.html
/og-template @https://example.com
```

Steps:

1. **Read the input** — reads a local file or fetches a URL (and its `og:image` if present) to extract layout, colors, font sizes, and text content
2. **Identify dynamic slots** — scans for anything that should be a parameter: headlines, descriptions, images, overridable colors
3. **Decide param roles** — classifies each param as required, optional with a default, or conditionally shown (`when`), then confirms with the user before generating
4. **Build the tree** — mirrors the design's layout hierarchy using `tw` (Tailwind) for layout and `style` for exact hex colors and pixel sizes; enforces mobile-first minimum text sizes (title 72–96px, subtitle 48px, labels 32px)
5. **Output the JSON** — produces a complete fenced `TemplateDef` JSON block ready to paste, plus a preview URL

Also covers the `render-inline` API for rendering a `TemplateDef` directly as a PNG without saving it to the admin — useful for iterating on a design before committing.
