# Rails + React + Bun (Importmap-pinned)

This pattern bundles React apps with Bun and serves them via importmap — no webpack, no Vite.

Reference: https://github.com/rails/importmap-rails?tab=readme-ov-file#selectively-importing-modules

## Architecture

- React apps live in `frontend/<AppName>/` (PascalCase), bundled by Bun into `vendor/javascript/apps/<AppName>/index.js`
- Those bundles are pinned in `config/importmap.rb` and mounted via a thin JS file in `app/javascript/`
- Plain ES modules (Stimulus controllers, etc.) live in `app/javascript/` and are served directly via importmap

## Directory Structure

```
frontend/
  <AppName>/
    index.jsx            # exports mount(el)
    <AppName>.jsx        # default React component
```

## index.jsx Pattern

```jsx
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./<AppName>.jsx";

export function mount(el) {
  createRoot(el).render(<App />);
}
```

## Build Scripts (package.json)

Add each new app folder to both `dev` and `build`:

```json
{
  "scripts": {
    "dev": "bun build frontend/CostCalculatorModal frontend/YardAreaCalculator --outdir=vendor/javascript/apps --target=browser --format=esm --minify --watch",
    "build": "bun build frontend/CostCalculatorModal frontend/YardAreaCalculator --outdir=vendor/javascript/apps --target=browser --format=esm --minify"
  }
}
```

Dev runs via `Procfile.dev`: `js: bun install && bun run dev`

## Importmap Pin

```ruby
# config/importmap.rb
pin "apps/<alias>", to: "apps/<AppName>/index.js"
```

Example:
```ruby
pin "apps/yard_area_calculator", to: "apps/YardAreaCalculator/index.js"
```

## Mount File (app/javascript/appname.js)

```js
import * as YardArea from "apps/yard_area_calculator";

function mountYardArea() {
  const el = document.getElementById("yard-area-calculator");
  if (el) YardArea.mount(el);
}

// Call immediately AND on turbo:load — Turbo may fire before the module loads on first visit
document.addEventListener("turbo:load", mountYardArea);
mountYardArea();
```

Pin the mount file too:
```ruby
pin "yardareacalc", to: "yardareacalc.js", preload: false
```

## ERB Template

```erb
<div id="yard-area-calculator"></div>
<%= javascript_import_module_tag "yardareacalc" %>
```

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| `frontend/` folder | PascalCase | `YardAreaCalculator` |
| importmap alias | `apps/kebab-or-snake` | `apps/yard_area_calculator` |
| mount file | lowercase | `yardareacalc.js` |
| DOM element id | kebab-case | `yard-area-calculator` |

## Dependencies

- React 19 (`react`, `react-dom`). Keep dependencies minimal; prefer standard DOM APIs.
- Tailwind classes available via Rails pipeline — no extra CSS config needed inside React apps.

## Adding a New App (Checklist)

1. Create `frontend/<AppName>/index.jsx` (exports `mount(el)`) and `frontend/<AppName>/<AppName>.jsx`
2. Add the folder to `package.json` `dev` and `build` scripts
3. Pin the bundle: `pin "apps/<alias>", to: "apps/<AppName>/index.js"` in `config/importmap.rb`
4. Create mount file `app/javascript/<mountname>.js` — import and mount on a unique element id
5. Pin the mount file: `pin "<mountname>", to: "<mountname>.js", preload: false`
6. Add `<div id="<element-id>"></div>` to the relevant `.html.erb`
7. Add `<%= javascript_import_module_tag "<mountname>" %>` to the same template
