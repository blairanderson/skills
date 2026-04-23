# Tailwind CSS v4 Cheatsheet

Complete reference for Tailwind CSS v4 utility-first patterns.

**Note**: Tailwind v4 (released January 2025) uses CSS-first configuration. If you need v3 compatibility, `tailwind.config.js` is still supported.

---

## Setup

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";
```

Tailwind v4 auto-detects template files — no `content` configuration needed.

---

## Layout

### Flexbox

```html
<div class="flex items-center justify-between gap-4">
  <div class="flex-1">Content</div>
  <div class="shrink-0">Fixed</div>
</div>

<div class="flex flex-col gap-2">
  <div>Stacked item</div>
</div>
```

### Grid

```html
<div class="grid grid-cols-3 gap-4">
  <div>1</div>
  <div>2</div>
  <div>3</div>
</div>

<!-- Responsive grid -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
  <div>Card</div>
</div>
```

### Container

```html
<div class="container mx-auto px-4">Content</div>
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">Content</div>
```

### Positioning

```html
<div class="relative">
  <div class="absolute top-0 right-0">Badge</div>
</div>
<header class="sticky top-0 z-50 bg-white border-b">Nav</header>
```

---

## Spacing

```html
<div class="p-4 m-2">             <!-- padding: 1rem, margin: 0.5rem -->
<div class="px-6 py-4">           <!-- horizontal/vertical padding -->
<div class="mt-8 mb-4">           <!-- specific margins -->
<div class="space-y-4">           <!-- gap between children -->
```

---

## Typography

```html
<h1 class="text-4xl font-bold text-gray-900">Heading</h1>
<p class="text-base text-gray-600 leading-relaxed">Body text</p>
<span class="text-sm font-medium text-blue-600">Label</span>
<p class="text-xs text-gray-500 uppercase tracking-wide">Meta</p>

<!-- Truncation -->
<p class="truncate">Single line truncate...</p>
<p class="line-clamp-3">Max 3 lines with ellipsis</p>
```

---

## Colors

```html
<!-- Text -->
<p class="text-gray-900 dark:text-gray-100">Text</p>

<!-- Background -->
<div class="bg-blue-500 hover:bg-blue-600">Button</div>

<!-- Border -->
<div class="border border-gray-300">Box</div>

<!-- Arbitrary -->
<div class="bg-[#1da1f2]">Custom color</div>
```

---

## Responsive Design (Mobile-First)

Breakpoints: `sm` (640px), `md` (768px), `lg` (1024px), `xl` (1280px), `2xl` (1536px)

```html
<div class="w-full md:w-1/2 lg:w-1/3">Responsive width</div>
<h1 class="text-2xl md:text-4xl lg:text-6xl">Responsive text</h1>
<div class="hidden md:block">Visible on md+</div>
```

---

## State Variants

```html
<!-- Hover, focus, active -->
<button class="bg-blue-500 hover:bg-blue-600 active:bg-blue-700 focus:ring-2 focus:ring-blue-500">
  Button
</button>

<!-- Group hover -->
<div class="group">
  <img class="group-hover:opacity-75 transition-opacity" />
  <p class="group-hover:text-blue-600">Hover parent</p>
</div>

<!-- Disabled -->
<button class="disabled:opacity-50 disabled:cursor-not-allowed" disabled>Disabled</button>

<!-- First/last child -->
<div class="first:mt-0 last:mb-0">List item</div>
```

---

## Dark Mode

```html
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
  <h1 class="text-gray-900 dark:text-white">Title</h1>
  <p class="text-gray-600 dark:text-gray-400">Description</p>
</div>
```

---

## Component Patterns

### Buttons

```html
<button class="px-4 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 transition-colors">
  Primary
</button>

<button class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50">
  Secondary
</button>
```

### Cards

```html
<div class="bg-white rounded-lg shadow-md overflow-hidden">
  <img src="/image.jpg" class="w-full h-48 object-cover" />
  <div class="p-6">
    <h2 class="text-xl font-semibold mb-2">Title</h2>
    <p class="text-gray-600">Content</p>
  </div>
</div>
```

### Form Inputs

```html
<div class="space-y-2">
  <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
  <input type="email" id="email"
    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
    placeholder="you@example.com" />
  <p class="text-sm text-gray-500">Helper text</p>
</div>
```

### Alerts

```html
<div class="p-4 rounded-md bg-yellow-50 border border-yellow-200">
  <p class="text-sm text-yellow-800">Warning message</p>
</div>

<div class="p-4 rounded-md bg-red-50 border border-red-200">
  <p class="text-sm text-red-800">Error message</p>
</div>
```

### Badges

```html
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Active
</span>
```

### Tables

```html
<div class="overflow-x-auto">
  <table class="min-w-full divide-y divide-gray-200">
    <thead class="bg-gray-50">
      <tr>
        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
      </tr>
    </thead>
    <tbody class="bg-white divide-y divide-gray-200">
      <tr class="hover:bg-gray-50">
        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">Content</td>
      </tr>
    </tbody>
  </table>
</div>
```

### Modal / Dialog

```html
<!-- Overlay -->
<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
  <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
    <div class="p-6">
      <h3 class="text-lg font-semibold">Title</h3>
      <p class="mt-2 text-gray-600">Content</p>
    </div>
    <div class="px-6 py-4 bg-gray-50 flex justify-end gap-3 rounded-b-lg">
      <button class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-md">Cancel</button>
      <button class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Confirm</button>
    </div>
  </div>
</div>
```

---

## Custom Values

### Arbitrary Values

```html
<div class="top-[117px]">             <!-- Custom position -->
<div class="bg-[#1da1f2]">            <!-- Custom color -->
<div class="grid-cols-[200px_1fr]">   <!-- Custom grid -->
<div class="w-[calc(100%-2rem)]">     <!-- Calc expression -->
```

### @apply (Use Sparingly)

```css
.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white font-medium rounded-md;
  @apply hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500;
}
```

---

## Configuration (v4 CSS-First)

```css
@import "tailwindcss";

@theme {
  --color-brand-50: #eff6ff;
  --color-brand-500: #3b82f6;
  --color-brand-900: #1e3a8a;
  --spacing-128: 32rem;
  --font-family-sans: 'Inter', sans-serif;
  --breakpoint-3xl: 1920px;
}
```

### v3 Config (Still Supported)

```javascript
// tailwind.config.js
module.exports = {
  content: ['./app/views/**/*.html.erb', './app/helpers/**/*.rb', './app/javascript/**/*.js'],
  theme: {
    extend: {
      colors: { brand: { 500: '#3b82f6' } },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

---

## Official Plugins

```html
<!-- @tailwindcss/forms — styled form elements -->
<input type="text" class="form-input rounded-md" />

<!-- @tailwindcss/typography — prose styling for rich content -->
<article class="prose lg:prose-xl">
  <h1>Article</h1>
  <p>Content with good typography defaults...</p>
</article>
```

---

## Common Layout Patterns

```html
<!-- Centered content -->
<div class="flex items-center justify-center min-h-screen">
  <div>Centered</div>
</div>

<!-- Sticky header + scrollable content -->
<div class="h-screen flex flex-col">
  <header class="sticky top-0 z-50 bg-white border-b px-4 py-3">Nav</header>
  <main class="flex-1 overflow-y-auto p-6">Content</main>
</div>

<!-- Sidebar layout -->
<div class="flex h-screen">
  <aside class="w-64 border-r bg-gray-50 p-4">Sidebar</aside>
  <main class="flex-1 overflow-y-auto p-6">Main</main>
</div>
```

---

## Performance Notes

- Tailwind v4: ~100ms full builds (3.5x faster than v3)
- Auto content detection — no `content` config needed
- Browser requirements: Safari 16.4+, Chrome 111+, Firefox 128+
