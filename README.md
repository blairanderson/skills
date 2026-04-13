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

Install everything:

```shell
/plugin install @blairanderson-skills
```

Or install a single skill by name:

```shell
/plugin install @blairanderson-skills/code-spec
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
| `rails-authentication` | Rails | End-to-end Rails 8 authentication setup with session management, OAuth, and 2FA |
| `hotfix` | Git | Stay on master, commit, pull with rebase, push, and watch GitHub workflows |
| `todo` | Productivity | Universal TODO and task tracker — manages tasks as markdown files in .tasks/ |
| `frontend-rails` | Rails | Expert frontend design for Rails ERB templates — Bootstrap 5.1, 5.3, and Tailwind CSS v4 |
| `fix-last-run` | Git | Check the last GitHub Actions workflow run and fix failures |
| `blue-ocean` | Planning | Blue Ocean Strategy framework — stop competing, start creating uncontested market space |
| `document-feature` | Productivity | Post-ship marketing documentation and page generation workflow |
| `organizer` | Productivity | Organize files across Desktop, Downloads, and Documents with business-aware routing |
| `rails-conductor-setup-config` | Rails | Configure a Rails project for Conductor workspaces — setup scripts, port handling, symlinks |
| `app-onboarding-questionnaire` | Planning | Design and build a high-converting questionnaire-style app onboarding flow modelled on top subscription apps |
| `diff-review` | Git | Adversarial git diff reviewer — finds bugs, performance issues, and correctness problems |
| `app-distribution-guide` | Planning | Design and build a multi-surface distribution layer — MCP server, OAuth, Claude/ChatGPT connectors, REST API/SDK, and open source strategy |
| `astro-seo` | SEO | Audit and improve SEO for Astro sites — structured data, sitemaps, IndexNow, Open Graph, hreflang (vendored from [jdevalk/skills](https://github.com/jdevalk/skills), MIT) |

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
