---
name: wrangler
description: >
  Audits and improves Cloudflare Workers projects. Use when the user asks to
  audit, set up, configure, or deploy a Cloudflare Workers project, or mentions
  Wrangler, Workers AI, D1 databases, KV storage, R2 buckets, Durable Objects,
  edge functions, wrangler.toml, Cloudflare deployment, or local Workers
  development. Produces drop-in configuration and deployment workflows.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Cloudflare Workers / Wrangler Setup

Audits and improves Cloudflare Workers projects — Wrangler CLI setup, `wrangler.toml` configuration, bindings (KV, D1, R2, Durable Objects, Workers AI), secrets management, local development with `wrangler dev`, and deployment workflows with CI/CD examples.

The skill follows a phase-based workflow: detect the project type, audit configuration against best practices, improve with opinionated defaults, and verify deployment readiness.

## Workflow

1. **Detect the project** — confirm this is a Workers project and understand its shape.
2. **Audit** — score eight categories and produce actionable findings.
3. **Improve** — generate or modify files to close the gaps.
4. **Verify** — run dry-run deployment, test locally, remind about manual tasks.

---

## Phase 0: Detect the project

Confirm the basics before auditing:

- `wrangler.toml` exists (or needs to be created for a new project).
- Check if `wrangler` CLI is installed: `npx wrangler --version` (or `wrangler --version` if globally installed).
- Detect project type:
  - **Worker**: `wrangler.toml` with `main` entry point
  - **Pages Functions**: `functions/` directory
  - **D1-focused**: D1 bindings in config
  - **Hybrid**: Multiple features combined
- Check authentication status: `npx wrangler whoami` (if not authenticated, note this for Phase 2).
- Detect existing bindings in `wrangler.toml`:
  - KV namespaces (`kv_namespaces`)
  - D1 databases (`d1_databases`)
  - R2 buckets (`r2_buckets`)
  - Durable Objects (`durable_objects`)
  - Workers AI (`ai`)
  - Service bindings (`services`)
- Check for environment-specific configuration (`[env.production]`, `[env.staging]`).
- Look for deployment scripts in `package.json`.

Ask only what you can't detect. Don't ask what the Worker does — read the code.

---

## Phase 1: Audit

Score each category out of 10. For each, give 2–4 specific findings that quote the actual code or config. Within each category, checks are tiered:

- **Must** — blocking issues. A failure here prevents deployment or causes runtime errors.
- **Should** — standard practice. Skipping costs maintainability or security.
- **Nice** — forward-looking or situational. Useful but not baseline for every project.

Skip **Nice** checks for simple single-Worker projects unless the user asks for the full treatment.

### 1. Wrangler CLI and authentication (/10)

- **Must** — `wrangler` CLI installed (via npm or globally).
- **Must** — authenticated via `wrangler login` or API token.
- **Should** — using Wrangler v3 (latest stable, not legacy v2).
- **Should** — `wrangler` in `package.json` devDependencies for version pinning.
- **Nice** — project uses `npx wrangler` consistently (not mixing global and local).

### 2. `wrangler.toml` configuration (/10)

- **Must** — `name` field set (Worker name).
- **Must** — `main` entry point exists and is correct (`src/index.ts`, `src/worker.js`, etc.).
- **Must** — `compatibility_date` set to a recent date (within last 6 months).
- **Should** — `compatibility_flags` used if needed for specific features.
- **Should** — `node_compat = true` if using Node.js APIs.
- **Should** — environment-specific config for production vs staging (`[env.production]`).
- **Nice** — `workers_dev = false` in production (uses custom routes, not `*.workers.dev`).

### 3. Bindings configuration (/10)

Score based on what the project needs (if no D1, don't penalize for missing D1 config):

- **Must** — all bindings referenced in code are defined in `wrangler.toml`.
- **Must** — binding names are consistent between config and code (`env.MY_KV`, not `env.myKv` vs `MY_KV` in config).
- **Should** — KV namespaces created and bound correctly.
- **Should** — D1 databases created with migrations directory if using D1.
- **Should** — R2 buckets created and bound if using R2.
- **Should** — Durable Objects class bindings and migrations if using DO.
- **Should** — Workers AI binding if using AI features.
- **Nice** — service bindings for Worker-to-Worker communication if applicable.

### 4. Secrets management (/10)

- **Must** — no secrets in `wrangler.toml` or committed code.
- **Must** — secrets documented (README or `.env.example` listing required secrets).
- **Should** — secrets set via `wrangler secret put` for each environment.
- **Should** — `.env` in `.gitignore` if using local env files.
- **Nice** — CI/CD uses GitHub Secrets or equivalent for automated deployments.

### 5. Local development setup (/10)

- **Must** — `wrangler dev` works without errors.
- **Should** — local bindings configured for development (`.dev.vars` for secrets).
- **Should** — `package.json` has `dev` script: `"dev": "wrangler dev"`.
- **Should** — hot reload working (Wrangler watches for file changes).
- **Nice** — local D1 database seeded with test data if using D1.
- **Nice** — Miniflare configuration for advanced local testing.

### 6. Build configuration (/10)

- **Must** — build succeeds without errors (`wrangler deploy --dry-run`).
- **Should** — TypeScript configured correctly if using TS (`tsconfig.json`).
- **Should** — bundler configuration appropriate for project (esbuild default is usually fine).
- **Should** — `node_modules` and build artifacts in `.gitignore`.
- **Nice** — source maps enabled for debugging (`[build]` section with sourcemaps).

### 7. Deployment workflow (/10)

- **Must** — `wrangler deploy` command works.
- **Should** — deployment script in `package.json`: `"deploy": "wrangler deploy"`.
- **Should** — environment-specific deploy commands (`deploy:production`, `deploy:staging`).
- **Should** — CI/CD workflow for automated deployments (GitHub Actions example).
- **Nice** — deployment includes health check or smoke test.
- **Nice** — rollback strategy documented.

### 8. Testing and validation (/10)

- **Should** — unit tests for Worker logic (Vitest or similar).
- **Should** — integration tests with Miniflare.
- **Nice** — E2E tests hitting deployed Worker.
- **Nice** — type checking in CI (`tsc --noEmit` for TypeScript projects).
- **Nice** — linting configured (ESLint).

---

## Phase 2: Improve

Based on the audit, produce the concrete code. Always ask before overwriting existing files.

### Install or upgrade Wrangler

If not installed:

```sh
npm install -D wrangler
```

If installed but outdated (v2 or old v3):

```sh
npm install -D wrangler@latest
```

### Authenticate

If `wrangler whoami` fails:

```sh
npx wrangler login
```

This opens a browser for OAuth authentication. For CI/CD, use API tokens instead (see CI/CD section).

### Create or fix `wrangler.toml`

**New project** — minimal starter:

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-15"  # Use current date

# Uncomment if using Node.js APIs
# node_compat = true

# KV namespace example
# [[kv_namespaces]]
# binding = "MY_KV"
# id = "your-kv-namespace-id"

# D1 database example
# [[d1_databases]]
# binding = "DB"
# database_name = "my-database"
# database_id = "your-database-id"

# R2 bucket example
# [[r2_buckets]]
# binding = "MY_BUCKET"
# bucket_name = "my-bucket"

# Workers AI example
# [ai]
# binding = "AI"
```

**Existing project** — fix common issues:

- Update `compatibility_date` to within last 6 months (use current date).
- Add `node_compat = true` if code uses Node.js APIs (`Buffer`, `crypto`, etc.).
- Fix binding names to match code usage.
- Add environment-specific config:

```toml
[env.production]
name = "my-worker-production"
# production-specific bindings

[env.staging]
name = "my-worker-staging"
# staging-specific bindings
```

### Set up KV namespaces

Create namespace:

```sh
npx wrangler kv:namespace create "MY_KV"
# Returns: id = "abc123..."

# For preview (local dev):
npx wrangler kv:namespace create "MY_KV" --preview
# Returns: preview_id = "def456..."
```

Add to `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "MY_KV"
id = "abc123..."
preview_id = "def456..."
```

Usage in Worker:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    await env.MY_KV.put("key", "value");
    const value = await env.MY_KV.get("key");
    return new Response(value);
  },
};
```

### Set up D1 databases

Create database:

```sh
npx wrangler d1 create my-database
# Returns: database_id = "xyz789..."
```

Add to `wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xyz789..."
```

Create migrations directory:

```sh
mkdir -p migrations
```

Create initial migration:

```sh
npx wrangler d1 migrations create my-database "initial_schema"
```

Edit the generated migration file:

```sql
-- migrations/0001_initial_schema.sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

Apply migrations:

```sh
# Local
npx wrangler d1 migrations apply my-database --local

# Remote (production)
npx wrangler d1 migrations apply my-database --remote
```

Usage in Worker:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const result = await env.DB.prepare(
      "SELECT * FROM users WHERE email = ?"
    ).bind("user@example.com").first();
    return Response.json(result);
  },
};
```

### Set up R2 buckets

Create bucket:

```sh
npx wrangler r2 bucket create my-bucket
```

Add to `wrangler.toml`:

```toml
[[r2_buckets]]
binding = "MY_BUCKET"
bucket_name = "my-bucket"
```

Usage in Worker:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    await env.MY_BUCKET.put("file.txt", "content");
    const object = await env.MY_BUCKET.get("file.txt");
    return new Response(await object?.text());
  },
};
```

### Set up Durable Objects

Define the Durable Object class:

```typescript
// src/counter.ts
export class Counter {
  state: DurableObjectState;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    let count = (await this.state.storage.get<number>("count")) || 0;
    count++;
    await this.state.storage.put("count", count);
    return new Response(`Count: ${count}`);
  }
}
```

Add to `wrangler.toml`:

```toml
[[durable_objects.bindings]]
name = "COUNTER"
class_name = "Counter"
script_name = "my-worker"  # Same as worker name

[[migrations]]
tag = "v1"
new_classes = ["Counter"]
```

Export the class in your Worker:

```typescript
// src/index.ts
export { Counter } from "./counter";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const id = env.COUNTER.idFromName("global");
    const stub = env.COUNTER.get(id);
    return stub.fetch(request);
  },
};
```

### Set up Workers AI

Add to `wrangler.toml`:

```toml
[ai]
binding = "AI"
```

Usage in Worker:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await env.AI.run("@cf/meta/llama-2-7b-chat-int8", {
      prompt: "What is the capital of France?",
    });
    return Response.json(response);
  },
};
```

### Manage secrets

**Never** put secrets in `wrangler.toml` or commit them to git.

Set secrets via CLI:

```sh
# Production
npx wrangler secret put API_KEY

# Staging
npx wrangler secret put API_KEY --env staging
```

For local development, use `.dev.vars`:

```sh
# .dev.vars (add to .gitignore)
API_KEY=local-dev-key
DATABASE_URL=http://localhost:5432
```

Document required secrets in README:

```markdown
## Required Secrets

Set these via `wrangler secret put <NAME>`:

- `API_KEY` — Third-party API key
- `DATABASE_URL` — External database connection string
```

### Local development setup

Add dev script to `package.json`:

```json
{
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "deploy:staging": "wrangler deploy --env staging",
    "deploy:production": "wrangler deploy --env production"
  }
}
```

Create `.dev.vars` for local secrets (add to `.gitignore`).

Run local dev server:

```sh
npm run dev
```

This starts Wrangler dev server with hot reload. Access at `http://localhost:8787`.

### CI/CD with GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloudflare Workers

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    name: Deploy
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Deploy to Cloudflare Workers
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**Set up GitHub Secrets:**

1. Create Cloudflare API token at https://dash.cloudflare.com/profile/api-tokens
   - Use "Edit Cloudflare Workers" template
   - Scope to specific account and zones
2. Add to GitHub repo secrets:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID` (find in Cloudflare dashboard URL)

**Multi-environment setup:**

```yaml
jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          environment: 'staging'

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          environment: 'production'
```

### Testing setup

Install Vitest and Miniflare:

```sh
npm install -D vitest @cloudflare/vitest-pool-workers
```

Create `vitest.config.ts`:

```typescript
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
      },
    },
  },
});
```

Create test file:

```typescript
// src/index.test.ts
import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';
import worker from './index';

describe('Worker', () => {
  it('responds with hello world', async () => {
    const request = new Request('http://example.com');
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(await response.text()).toBe('Hello World!');
  });
});
```

Add test script to `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

---

## Phase 3: Verify

- Run `npx wrangler deploy --dry-run` to verify configuration without deploying.
- Run `npm run dev` and test locally at `http://localhost:8787`.
- If using bindings, verify they're accessible in local dev.
- Run tests: `npm test`.
- Check deployment logs after first deploy: `npx wrangler tail` (live logs).
- Remind the user about manual tasks:
  - Set secrets via `wrangler secret put` for each environment.
  - Configure custom domains in Cloudflare dashboard if not using `*.workers.dev`.
  - Set up GitHub Secrets for CI/CD (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`).
  - Review Cloudflare dashboard for Worker analytics and logs.

---

## Output format

```markdown
## Cloudflare Workers audit: [project name]

### Score
| Category                              | Score |
|---------------------------------------|------:|
| 1. Wrangler CLI and authentication    |  x/10 |
| 2. wrangler.toml configuration        |  x/10 |
| 3. Bindings configuration             |  x/10 |
| 4. Secrets management                 |  x/10 |
| 5. Local development setup            |  x/10 |
| 6. Build configuration                |  x/10 |
| 7. Deployment workflow                |  x/10 |
| 8. Testing and validation             |  x/10 |
| **Total**                             | xx/80 |

### Findings
[Grouped by category. Quote actual code/config. Be specific.]

### Files generated or changed
[List with short description of each.]

### Next steps
[Non-file tasks: secrets, custom domains, GitHub Secrets, dashboard review.]
```

---

## Key principles

- **Opinionated defaults over optionality.** Use latest compatibility date, standard binding patterns, security-first secrets management.
- **Security-first.** Never commit secrets. Use `wrangler secret put` for production, `.dev.vars` for local (gitignored).
- **Local-first development.** `wrangler dev` should work before any deployment. Test locally, deploy confidently.
- **Environment separation.** Use `[env.production]` and `[env.staging]` in `wrangler.toml` for multi-environment projects.
- **CI/CD by default.** Provide GitHub Actions workflow for automated deployments.
- **Type safety.** Prefer TypeScript for Workers projects. Provide proper type definitions for bindings.
- **Test coverage.** Unit tests with Vitest, integration tests with Miniflare, E2E tests for critical paths.
- **Clear error messages.** When something fails, explain why and how to fix it.

---

## Common issues and fixes

### "Error: No account_id found"

**Fix:** Add `account_id` to `wrangler.toml` or authenticate with `wrangler login`.

### "Error: A request to the Cloudflare API failed"

**Fix:** Check authentication (`wrangler whoami`). Re-authenticate if needed.

### "Binding not found in environment"

**Fix:** Verify binding name in `wrangler.toml` matches code usage (case-sensitive).

### "Module not found" during build

**Fix:** Check `main` entry point in `wrangler.toml` points to correct file.

### Local dev can't access bindings

**Fix:** Ensure preview bindings are configured (`preview_id` for KV, `--local` flag for D1).

### Secrets not available in Worker

**Fix:** Set secrets via `wrangler secret put <NAME>`. For local dev, add to `.dev.vars`.

### TypeScript errors about `env` types

**Fix:** Create `src/types.ts`:

```typescript
export interface Env {
  MY_KV: KVNamespace;
  DB: D1Database;
  MY_BUCKET: R2Bucket;
  AI: Ai;
  API_KEY: string;
}
```

Use in Worker:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // env is now fully typed
  },
};
```

### D1 migrations fail

**Fix:** Ensure migrations are applied in order. Check migration file syntax (SQL only, no comments with `--`).

### Worker exceeds size limit

**Fix:** Check bundle size with `wrangler deploy --dry-run`. Optimize imports, remove unused dependencies, consider code splitting.
