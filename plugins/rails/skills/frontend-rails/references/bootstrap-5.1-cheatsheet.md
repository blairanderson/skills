# Bootstrap 5.1 Cheatsheet

Complete reference for Bootstrap 5.1.3 components and utilities.

**CDN**:
```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
```

---

## What's NOT Available in 5.1 (added in 5.2+)

- `text-bg-*` classes — use `bg-primary text-white` instead
- `fw-semibold` — use `fw-bold` or custom CSS
- Color modes / dark mode (`data-bs-theme`)
- `focus-ring` utilities
- `icon-link` component
- `*-bg-subtle`, `*-border-subtle`, `*-text-emphasis` utilities

---

## Typography

**Display**: `display-1` through `display-6`
**Headings**: `h1` through `h6` (as classes)
**Lead**: `lead` for emphasized paragraphs
**Lists**: `list-unstyled`, `list-inline` + `list-inline-item`
**Blockquotes**: `blockquote` + `blockquote-footer`

## Images

`img-fluid` (responsive), `img-thumbnail` (bordered)

## Tables

**Base**: `table`
**Variants**: `table-striped`, `table-hover`, `table-bordered`, `table-borderless`, `table-sm`, `table-dark`
**Row colors**: `table-primary`, `table-secondary`, `table-success`, `table-danger`, `table-warning`, `table-info`, `table-light`

## Forms

**Controls**: `form-label`, `form-control`, `form-select`, `form-check-input`, `form-check-label`, `form-text`, `form-range`
**Sizing**: `form-control-lg`, `form-control-sm`, `form-select-lg`, `form-select-sm`
**Floating labels**: `form-floating` (input before label)
**Input groups**: `input-group` + `input-group-text`
**Switches**: `form-check form-switch` with `role="switch"`
**Validation**: `is-valid`, `is-invalid`, `valid-feedback`, `invalid-feedback`

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
Colors: `primary`, `secondary`, `success`, `danger`, `warning`, `info`, `light`, `dark`

## Badges

```html
<span class="badge bg-primary">Text</span>
<span class="badge bg-danger rounded-pill">12</span>
```
**NOTE**: Use `bg-* text-white`, NOT `text-bg-*` (that's 5.2+).

## Cards

```html
<div class="card">
  <div class="card-header">Header</div>
  <div class="card-body">
    <h5 class="card-title">Title</h5>
    <p class="card-text">Text</p>
  </div>
  <div class="card-footer text-muted">Footer</div>
</div>
```
Card grid: `row row-cols-1 row-cols-md-2 g-4`

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
Directions: `dropend`, `dropup`, `dropstart`

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
Trigger: `data-bs-toggle="modal" data-bs-target="#myModal"`
Sizes: `modal-sm`, `modal-lg`, `modal-xl`, `modal-fullscreen`

## Navigation Tabs

```html
<ul class="nav nav-tabs">
  <li class="nav-item"><a class="nav-link active" data-bs-toggle="tab" href="#t1">Tab 1</a></li>
  <li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#t2">Tab 2</a></li>
</ul>
<div class="tab-content">
  <div class="tab-pane fade show active" id="t1">Content 1</div>
  <div class="tab-pane fade" id="t2">Content 2</div>
</div>
```
**Pills**: `nav-pills` instead of `nav-tabs`

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
<nav class="navbar navbar-expand-lg navbar-light bg-light">
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

## Pagination

```html
<nav>
  <ul class="pagination pagination-sm">
    <li class="page-item disabled"><a class="page-link" href="#">Previous</a></li>
    <li class="page-item active"><a class="page-link" href="#">1</a></li>
    <li class="page-item"><a class="page-link" href="#">Next</a></li>
  </ul>
</nav>
```

## Progress, Spinners, Toasts

```html
<!-- Progress -->
<div class="progress">
  <div class="progress-bar bg-success" style="width: 75%"></div>
</div>

<!-- Spinner -->
<div class="spinner-border text-primary" role="status">
  <span class="visually-hidden">Loading...</span>
</div>

<!-- Toast -->
<div class="toast" role="alert">
  <div class="toast-header">
    <strong class="me-auto">Title</strong>
    <button class="btn-close" data-bs-dismiss="toast"></button>
  </div>
  <div class="toast-body">Message</div>
</div>
```

## Tooltips & Popovers

`data-bs-toggle="tooltip" title="Tip text"`
`data-bs-toggle="popover" title="Title" data-bs-content="Content"`
Placement: `data-bs-placement="top|right|bottom|left"`

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
`d-none`, `d-block`, `d-inline`, `d-flex`, `d-grid`, `d-inline-flex`
Responsive: `d-md-none`, `d-lg-flex`, etc.
Print: `d-print-none`, `d-print-block`

### Flexbox
`flex-row`, `flex-column`, `flex-wrap`, `justify-content-{start|end|center|between|around}`, `align-items-{start|end|center|stretch}`, `flex-grow-1`, `flex-shrink-0`

### Text
`text-start`, `text-center`, `text-end`, `text-muted`, `text-truncate`, `text-nowrap`, `text-break`, `fw-bold`, `fw-normal`, `fst-italic`

### Colors
Text: `text-primary`, `text-secondary`, `text-success`, `text-danger`, `text-warning`, `text-info`, `text-muted`, `text-white`
Background: `bg-primary`, `bg-secondary`, `bg-success`, `bg-danger`, `bg-warning`, `bg-info`, `bg-light`, `bg-dark`, `bg-white`

### Borders
`border`, `border-0`, `border-top`, `border-bottom`, `border-start`, `border-end`
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

### Overflow
`overflow-auto`, `overflow-hidden`, `overflow-visible`, `overflow-scroll`
