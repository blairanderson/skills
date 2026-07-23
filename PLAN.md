# Implementation Plan: `cf` Plugin with Cloudflare/Wrangler Skill

## Overview
Add a new `cf` plugin to the skills marketplace that provides Cloudflare Workers and Wrangler development tools. This plugin will help developers audit, configure, and deploy Cloudflare Workers projects.

## Repository Structure Analysis

Based on the existing plugins, the standard structure is:
- `plugins/<plugin-name>/.claude-plugin/plugin.json` - Plugin metadata
- `plugins/<plugin-name>/README.md` - Plugin documentation
- `plugins/<plugin-name>/skills/<skill-name>/SKILL.md` - Skill instructions
- `plugins/<plugin-name>/skills/<skill-name>/references/*.md` - Optional reference docs
- `.claude-plugin/marketplace.json` - Registry entry

## Files to Create

### 1. `plugins/cf/.claude-plugin/plugin.json`
```json
{
  "name": "cf",
  "description": "Cloudflare Workers developer tools — Wrangler setup, deployment, bindings, D1 databases, KV, R2, and Workers AI",
  "version": "1.0.0"
}
```

### 2. `plugins/cf/README.md`
Plugin overview with:
- Installation instructions (marketplace add + plugin install)
- List of skills (initially just `/wrangler` or `/cf-setup`)
- Brief description of what each skill does
- Usage examples

### 3. `plugins/cf/skills/wrangler/SKILL.md`
Main skill file with YAML frontmatter and comprehensive instructions covering:

**Frontmatter:**
- `name: wrangler` (or `cf-setup`)
- `description:` - Trigger phrases (Cloudflare Workers, Wrangler, deploy to Cloudflare, Workers AI, D1, KV, R2, etc.)
- `allowed-tools:` - Bash, Read, Write, Edit, Glob, Grep

**Content sections:**
1. **Phase 0: Detect the project**
   - Check for `wrangler.toml`
   - Verify `wrangler` CLI installation (`npx wrangler --version`)
   - Detect project type (Worker, Pages, D1, etc.)
   - Check authentication status (`wrangler whoami`)

2. **Phase 1: Audit**
   - Score categories (similar to astro-seo pattern):
     - Wrangler configuration (routes, compatibility dates, bindings)
     - Environment setup (dev vs production)
     - Bindings (KV, D1, R2, Durable Objects, Service bindings)
     - Secrets management
     - Build configuration
     - Testing setup
     - Deployment pipeline
     - Local development setup
   - Provide specific findings with code quotes

3. **Phase 2: Improve**
   - Install/upgrade wrangler if needed
   - Configure `wrangler.toml` properly
   - Set up bindings (KV namespaces, D1 databases, R2 buckets)
   - Configure secrets via `wrangler secret put`
   - Set up local development with `wrangler dev`
   - Add deployment scripts
   - Configure CI/CD (GitHub Actions example)

4. **Phase 3: Verify**
   - Run `wrangler deploy --dry-run`
   - Test locally with `wrangler dev`
   - Verify bindings are accessible
   - Check deployment logs
   - Remind about manual tasks (API tokens, account setup)

**Key principles:**
- Opinionated defaults (latest compatibility date, recommended patterns)
- Security-first (secrets not in config, proper token scoping)
- Local-first development (wrangler dev before deploy)
- Clear error messages and troubleshooting

### 4. `plugins/cf/skills/wrangler/references/` (optional)
Consider adding reference docs for:
- `bindings.md` - KV, D1, R2, Durable Objects, Service bindings
- `secrets.md` - Secret management best practices
- `deployment.md` - CI/CD patterns, staging vs production
- `local-dev.md` - Wrangler dev, miniflare, testing

### 5. Update `.claude-plugin/marketplace.json`
Add entry to the `plugins` array:
```json
{
  "name": "cf",
  "source": "./plugins/cf",
  "description": "Cloudflare Workers developer tools — Wrangler setup, deployment, bindings configuration, D1 databases, KV storage, R2 buckets, and Workers AI integration",
  "author": {
    "name": "Blair Anderson"
  },
  "category": "cloudflare",
  "tags": [
    "cloudflare",
    "workers",
    "wrangler",
    "edge",
    "serverless",
    "d1",
    "kv",
    "r2",
    "durable-objects",
    "workers-ai",
    "deployment"
  ]
}
```

### 6. Update `README.md`
Add row to the Available Skills table:
```markdown
| `cf` → `wrangler` | Cloudflare | Audit and configure Cloudflare Workers projects — Wrangler setup, bindings (KV, D1, R2), deployment, and local development |
```

## Implementation Approach

### Skill Scope Decision
**Option A: Single comprehensive skill** (`/wrangler` or `/cf-setup`)
- Covers full Workers development lifecycle
- Similar to `/rails-seo` or `/astro-seo` pattern
- Recommended for initial version

**Option B: Multiple focused skills**
- `/wrangler-setup` - Initial configuration
- `/wrangler-deploy` - Deployment workflows
- `/wrangler-bindings` - KV, D1, R2 setup
- Can be added later if needed

**Recommendation:** Start with Option A (single comprehensive skill)

### Key Features to Cover

1. **Wrangler CLI Setup**
   - Installation verification
   - Authentication (`wrangler login`)
   - Account/project selection

2. **Configuration (`wrangler.toml`)**
   - Worker name and routes
   - Compatibility date (use latest stable)
   - Environment variables
   - Bindings configuration

3. **Bindings**
   - KV namespaces (create + bind)
   - D1 databases (create + migrations)
   - R2 buckets (create + bind)
   - Durable Objects (class + migration)
   - Service bindings
   - Workers AI

4. **Secrets Management**
   - `wrangler secret put` workflow
   - Environment-specific secrets
   - Never commit secrets to config

5. **Local Development**
   - `wrangler dev` setup
   - Local bindings
   - Hot reload
   - Debugging

6. **Deployment**
   - `wrangler deploy` (formerly `wrangler publish`)
   - Environment-specific deploys
   - Rollback strategies
   - CI/CD integration (GitHub Actions)

7. **Testing**
   - Unit tests with Vitest
   - Integration tests with miniflare
   - E2E testing strategies

### Trigger Phrases
The skill should activate on:
- "Cloudflare Workers"
- "Wrangler"
- "deploy to Cloudflare"
- "Workers AI"
- "D1 database"
- "KV storage"
- "R2 bucket"
- "Durable Objects"
- "edge function"
- "wrangler.toml"
- "cloudflare deployment"

### Similar Patterns to Follow
- **Audit structure**: Follow `/astro-seo` pattern with scored categories
- **Phase-based workflow**: Detect → Audit → Improve → Verify
- **Reference docs**: Follow `/rails/skills/cloudflare/references/` pattern
- **CLI-first**: Similar to `/fix-failing-jobs` requiring proper tooling

### Edge Cases to Handle
- No wrangler.toml exists (new project)
- Wrangler v2 vs v3 differences
- Multiple environments (dev, staging, prod)
- Monorepo with multiple Workers
- Pages Functions vs Workers
- Legacy configuration migration

## Testing Strategy
After implementation:
1. Test with a fresh Workers project
2. Test with an existing project needing audit
3. Verify all wrangler commands work
4. Test binding creation and configuration
5. Verify deployment dry-run works
6. Test with different project types (Worker, Pages, D1)

## Documentation Requirements
- Clear installation instructions
- Example workflows for common tasks
- Troubleshooting section
- Links to official Cloudflare docs
- Migration guide from manual setup

## Success Criteria
- [ ] Plugin installs via marketplace
- [ ] Skill activates on trigger phrases
- [ ] Can audit existing Workers project
- [ ] Can set up new Workers project from scratch
- [ ] Can configure all major binding types
- [ ] Can deploy successfully
- [ ] Local development works
- [ ] CI/CD examples provided
- [ ] Reference docs are helpful
- [ ] Follows repository conventions

## Future Enhancements (Out of Scope for v1)
- Workers Analytics integration
- Tail logs analysis
- Performance optimization suggestions
- Cost estimation
- Multi-region deployment strategies
- Advanced Durable Objects patterns
- Hyperdrive configuration
- Vectorize setup
- Queue bindings
