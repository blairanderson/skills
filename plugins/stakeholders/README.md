# Stakeholders Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install stakeholders@blairanderson-skills
```

Different apps have different stakeholders. This plugin keeps a per-project stakeholder registry and drafts feature announcement emails for them.

---

## `/feature-draft`

Just shipped a feature? Drafts a readme-style announcement email for the project's stakeholders and **presents it inside Claude Code for review** — it never sends, and never touches your mail system's drafts folder.

```shell
/feature-draft                          # draft an email about the feature just built
/feature-draft vendor sku grouping      # name the feature explicitly
```

**First run per project:** interviews you for stakeholders (names + emails), whether they're **coworkers** (casual tone, emoji OK) or **clients** (professional, benefit-first, no internal jargon), and **which email CLI sends for this project** (`gws`, `gog`, or `olk` — each has its own sending skill). Persists to `.claude/stakeholders.json` in the project root; subsequent runs reuse the config without asking.

**Every run:**
1. Loads the stakeholder config (or creates it)
2. Gathers feature context from the session + git
3. Presents a framed draft in chat — To/Cc/Via/Subject header, "What's new", "The details that matter" bullets, try-it link — backed by `/tmp/feature-draft-<slug>.md`
4. Only on an explicit "send": hands off to the configured email CLI's skill (e.g. olk's signature-verifying `sigmail` wrapper)

Config is managed by a deterministic script (`skills/feature-draft/scripts/stakeholders.sh`) with `init`, `add`, `remove`, `get`, `recipients` (emits `--to/--cc` CLI flags), `email-cli` (get/set the sending CLI), and `check` subcommands. Tests in `skills/feature-draft/tests/`.
