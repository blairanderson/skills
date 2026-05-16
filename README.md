# Claude Code Skills by Blair

A curated marketplace of skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Install the whole collection or pick individual skills to supercharge your development workflow.

## Quick Start

### 1. Add the marketplace

```shell
/plugin marketplace add blairanderson/skills
```

### 2. Browse available skills

```shell
/plugin search @blairanderson-skills
```

### 3. Install a skill

Install a skill by name:

```shell
/plugin install code-spec@blairanderson-skills
```

### 4. Use it

Once installed, skills activate automatically based on context. You can also invoke them directly:

```
/code-spec ProductVideos
```

## Available Skills

| Skill | Category | Description |
|-------|----------|-------------|
| `code-spec` | Planning | Reverse-engineer a feature or project into a portable, implementation-ready specification |
| `rails` → `rails-seo` | Rails | Audit and improve SEO for Ruby on Rails apps — head metadata, JSON-LD, sitemaps |
| `rails` → `rails-authentication` | Rails | End-to-end Rails authentication — OAuth, 2FA, sessions |
| `rails` → `rails-conductor-setup-config` | Rails | Set up Conductor workspaces and config for Rails projects |
| `rails` → `pgsync` | Rails | Sync production Postgres data to local dev via pgsync + SSH tunnel |
| `rails` → `ralph` | Rails | Bootstrap Geoffrey Huntley's Ralph autonomous agent loop in a sibling git worktree, Rails-tailored (zeitwerk:check, bin/rails test, rubocop, slug-prefix commits) |
| `hotfix` | Git | Stay on master, commit, pull with rebase, push, and watch GitHub workflows |
| `todo` | Productivity | Universal TODO and task tracker — manages tasks as markdown files in .tasks/ |
| `fix-last-run` | Git | Check the last GitHub Actions workflow run and fix failures |
| `blue-ocean` | Planning | Blue Ocean Strategy framework — stop competing, start creating uncontested market space |
| `document-feature` | Productivity | Post-ship marketing documentation and page generation workflow |
| `organizer` | Productivity | Organize files across Desktop, Downloads, and Documents with business-aware routing |
| `app-onboarding-questionnaire` | Planning | Design and build a high-converting questionnaire-style app onboarding flow modelled on top subscription apps |
| `diff-review` | Git | Adversarial git diff reviewer — finds bugs, performance issues, and correctness problems |
| `app-distribution-guide` | Planning | Design and build a multi-surface distribution layer — MCP server, OAuth, Claude/ChatGPT connectors, REST API/SDK, and open source strategy |
| `astro` | Astro | Audit and improve SEO for Astro sites — structured data, sitemaps, IndexNow, Open Graph, hreflang (vendored from [jdevalk/skills](https://github.com/jdevalk/skills), MIT) |
| `jekyll` | Jekyll | Audit and improve SEO for Jekyll sites — jekyll-seo-tag, linked @graph JSON-LD, sitemaps, IndexNow via GitHub Actions, OG images, llms.txt, and agent discovery |
| `backlinks` | SEO | Find all domains linking to any domain using CommonCrawl hyperlinkgraph data and DuckDB |
| `open-graph` | Productivity | Convert HTML/SVG designs or URLs into OG Shot TemplateDef JSON blobs — paste into the admin UI's JSON tab |
| `skillify` | Productivity | The meta skill — audit any feature against the 10-item skill completeness checklist and fill in missing pieces |
| `statusline` → `statusline-health` | Productivity | Add a cached uptime indicator to Claude Code's status line — polls your health URL every 5 minutes, shows green `(up)` or a full red alert |

## How Skills Work

Each skill is a `SKILL.md` file with YAML frontmatter that tells Claude Code when and how to use it:

```markdown
---
name: my-skill
description: When to activate this skill
---

# Instructions for Claude

Steps, rules, and context go here.
```

When you install a skill, Claude Code reads the description to decide when to activate it automatically. No manual triggering required — just work normally and the right skill kicks in.

## Contributing

Want to add your own skills to this marketplace?

1. Fork this repository
2. Create a new directory with a `SKILL.md` inside it
3. Add a `.claude-plugin/plugin.json` with name, description, and version
4. Add an entry to `.claude-plugin/marketplace.json`
5. Submit a pull request

See the [Agent Skills standard](https://agentskills.io) for the full `SKILL.md` spec.

## License

MIT — see [LICENSE](LICENSE) for details.
