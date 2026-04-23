# Bootstrap 5.3 Cheatsheet

Complete reference for Bootstrap 5.3.x. Covers everything in 5.1 plus new features.

**CDN**:
```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
```

---

## New in 5.3 (not available in 5.1)

### Color Modes / Dark Mode

```html
<!-- Set on root for whole page -->
<html data-bs-theme="dark">

<!-- Or per-component -->
<div data-bs-theme="light">
  <div class="card">Always light</div>
</div>
```

Auto dark mode via CSS:
```css
@media (prefers-color-scheme: dark) {
  :root { --bs-theme: dark; }
}
```

### text-bg-* Combined Utilities

```html
<!-- New shorthand (5.2+) -->
<span class="badge text-bg-primary">Badge</span>
<div class="alert text-bg-warning">Alert</div>

<!-- Sets both background AND appropriate text color automatically -->
```

### Subtle Color Utilities

```html
<!-- Subtle backgrounds (adaptive to color mode) -->
<div class="bg-primary-subtle">Light primary background</div>
<div class="bg-danger-subtle">Light danger background</div>

<!-- Subtle borders -->
<div class="border border-primary-subtle">Subtle primary border</div>

<!-- Emphasis text -->
<p class="text-primary-emphasis">Stronger primary text</p>
<p class="text-danger-emphasis">Stronger danger text</p>
```

### New Utilities

```html
<!-- Font weight -->
<span class="fw-semibold">Semibold text</span>

<!-- Focus ring -->
<a class="focus-ring focus-ring-primary" href="#">Styled focus ring</a>

<!-- Icon link -->
<a class="icon-link" href="#">
  Link with icon <svg>...</svg>
</a>

<!-- Object fit (like CSS object-fit) -->
<img class="object-fit-cover" src="..." />
<img class="object-fit-contain" src="..." />
```

### Body Emphasis Colors

```html
<p class="text-body">Default body text</p>
<p class="text-body-secondary">Secondary body text (replaces text-muted)</p>
<p class="text-body-tertiary">Tertiary body text</p>
<p class="text-body-emphasis">Emphasized body text</p>
```

**Note**: `text-muted` still works but `text-body-secondary` is preferred in 5.3.

---

## Full Component Reference

Everything below works in both 5.1 and 5.3 unless noted.

## Typography

**Display**: `display-1` through `display-6`
**Headings**: `h1` through `h6` (as classes)
**Lead**: `lead` for emphasized paragraphs
**Lists**: `list-unstyled`, `list-inline` + `list-inline-item`

## Tables

**Base**: `table`
**Variants**: `table-striped`, `table-striped-columns` (5.3), `table-hover`, `table-bordered`, `table-borderless`, `table-sm`, `table-dark`
**Row colors**: `table-primary`, `table-secondary`, `table-success`, `table-danger`, `table-warning`, `table-info`, `table-light`

## Forms

**Controls**: `form-label`, `form-control`, `form-select`, `form-check-input`, `form-check-label`, `form-text`, `form-range`
**Sizing**: `form-control-lg`, `form-control-sm`
**Floating labels**: `form-floating` (input before label)
**Input groups**: `input-group` + `input-group-text`
**Switches**: `form-check form-switch` with `role="switch"`
**Validation**: `is-valid`, `is-invalid`, `valid-feedback`, `invalid-feedback`
**Color picker**: `form-control form-control-color`

## Buttons

**Colors**: `btn btn-primary`, `btn-secondary`, `btn-success`, `btn-danger`, `btn-warning`, `btn-info`, `btn-light`, `btn-dark`
**Outline**: `btn-outline-primary`, etc.
**Sizing**: `btn-sm`, `btn-lg`
**Groups**: `btn-group`, `btn-toolbar`, `btn-group-vertical`

## Alerts

```html
<div class="alert alert-warning alert-dismissible fade show">
  Message
  <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
</div>
```

## Badges

```html
<!-- 5.3 way (preferred) -->
<span class="badge text-bg-primary">Badge</span>
<span class="badge text-bg-danger rounded-pill">12</span>

<!-- 5.1 compatible way -->
<span class="badge bg-primary">Badge</span>
```

## Cards

```html
<div class="card">
  <div class="card-header">Header</div>
  <div class="card-body">
    <h5 class="card-title">Title</h5>
    <p class="card-text">Text</p>
  </div>
  <div class="card-footer text-body-secondary">Footer</div>
</div>
```

## Dropdowns

```html
<div class="dropdown">
  <button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-bs-toggle="dropdown">Actions</button>
  <ul class="dropdown-menu">
    <li><a class="dropdown-item" href="#">Edit</a></li>
    <li><hr class="dropdown-divider"></li>
    <li><a class="dropdown-item text-danger" href="#">Delete</a></li>
  </ul>
</div>
```

## Modals

```html
<div class="modal fade" id="myModal" tabindex="-1">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Title</h5>
        <button class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body">Content</div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
        <button class="btn btn-primary">Save</button>
      </div>
    </div>
  </div>
</div>
```
Sizes: `modal-sm`, `modal-lg`, `modal-xl`, `modal-fullscreen`

## Navigation Tabs

```html
<ul class="nav nav-tabs">
  <li class="nav-item"><a class="nav-link active" data-bs-toggle="tab" href="#t1">Tab 1</a></li>
</ul>
<div class="tab-content">
  <div class="tab-pane fade show active" id="t1">Content</div>
</div>
```
Variants: `nav-pills`, `nav-underline` (5.3 new)

## Accordion

```html
<div class="accordion" id="acc">
  <div class="accordion-item">
    <h2 class="accordion-header">
      <button class="accordion-button" data-bs-toggle="collapse" data-bs-target="#c1" data-bs-parent="#acc">Title</button>
    </h2>
    <div id="c1" class="accordion-collapse collapse show">
      <div class="accordion-body">Content</div>
    </div>
  </div>
</div>
```

## Navbar

```html
<nav class="navbar navbar-expand-lg bg-body-tertiary">
  <div class="container-fluid">
    <a class="navbar-brand" href="#">Brand</a>
    <button class="navbar-toggler" data-bs-toggle="collapse" data-bs-target="#navContent">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navContent">
      <ul class="navbar-nav me-auto">
        <li class="nav-item"><a class="nav-link active" href="#">Link</a></li>
      </ul>
    </div>
  </div>
</nav>
```
**Note**: In 5.3, `navbar-light`/`navbar-dark` are deprecated. Use `data-bs-theme="dark"` on the navbar instead.

## Grid

```html
<div class="container-fluid">
  <div class="row">
    <div class="col-md-3 col-lg-2">Sidebar</div>
    <div class="col-md-9 col-lg-10">Main</div>
  </div>
</div>
```

## Utility Classes

### Spacing
`m-{0-5}`, `p-{0-5}`, `mt-`, `mb-`, `ms-`, `me-`, `mx-`, `my-`, `pt-`, `pb-`, `ps-`, `pe-`, `px-`, `py-`

### Display
`d-none`, `d-block`, `d-inline`, `d-flex`, `d-grid`, `d-inline-flex`, `d-inline-grid` (5.3)
Responsive: `d-md-none`, `d-lg-flex`
Print: `d-print-none`, `d-print-block`

### Flexbox
`flex-row`, `flex-column`, `flex-wrap`, `justify-content-{start|end|center|between|around|evenly}`, `align-items-{start|end|center|stretch}`, `flex-grow-1`, `flex-shrink-0`, `gap-{0-5}`

### Text
`text-start`, `text-center`, `text-end`, `text-truncate`, `text-nowrap`, `text-break`
`fw-bold`, `fw-semibold` (5.3), `fw-medium` (5.3), `fw-normal`, `fw-light`
`fst-italic`, `text-decoration-none`, `text-decoration-underline`

### Colors
Text: `text-primary`, `text-secondary`, `text-success`, `text-danger`, `text-warning`, `text-info`, `text-body`, `text-body-secondary` (5.3), `text-body-tertiary` (5.3), `text-body-emphasis` (5.3), `text-muted`, `text-white`
Emphasis: `text-primary-emphasis`, `text-danger-emphasis`, etc. (5.3)
Background: `bg-primary`, `bg-secondary`, `bg-success`, `bg-danger`, `bg-warning`, `bg-info`, `bg-light`, `bg-dark`, `bg-body`, `bg-body-secondary` (5.3), `bg-body-tertiary` (5.3)
Subtle BG: `bg-primary-subtle`, `bg-danger-subtle`, etc. (5.3)
Combined: `text-bg-primary`, `text-bg-danger`, etc. (5.2+)

### Borders
`border`, `border-0`, `border-top`, `border-bottom`, `border-start`, `border-end`
`border-primary`, `border-primary-subtle` (5.3)
`rounded`, `rounded-0`, `rounded-circle`, `rounded-pill`

### Sizing
`w-25`, `w-50`, `w-75`, `w-100`, `h-100`, `mw-100`

### Position
`position-relative`, `position-absolute`, `position-fixed`, `position-sticky`
`top-0`, `bottom-0`, `start-0`, `end-0`, `translate-middle`

### Visibility
`visible`, `invisible`, `visually-hidden`

### Shadow
`shadow-sm`, `shadow`, `shadow-lg`, `shadow-none`

### Object Fit (5.3)
`object-fit-contain`, `object-fit-cover`, `object-fit-fill`, `object-fit-scale`, `object-fit-none`

### Z-index (5.3)
`z-n1`, `z-0`, `z-1`, `z-2`, `z-3`

## 5.1 → 5.3 Migration Quick Reference

| 5.1 Pattern | 5.3 Replacement |
|---|---|
| `bg-primary text-white` | `text-bg-primary` |
| `text-muted` | `text-body-secondary` |
| `navbar-light` | remove (or `data-bs-theme="light"`) |
| `navbar-dark` | `data-bs-theme="dark"` on navbar |
| `fw-bold` (for semibold) | `fw-semibold` |
| manual dark mode CSS | `data-bs-theme="dark"` |
