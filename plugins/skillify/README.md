# Skillify Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install skillify@blairanderson-skills
```

This plugin adds one meta skill for auditing any feature against the skill completeness checklist.

---

## `/skillify`

Audit any feature against the 10-item skill completeness checklist and fill in the missing pieces. The meta skill — use it to make any feature "properly skilled".

Trigger phrases: `"skillify this"`, `"is this a skill?"`, `"make this proper"`, `"add tests and evals for this"`.

A feature is "properly skilled" when all ten checklist items are present:

| # | Item |
|---|------|
| 1 | `SKILL.md` with YAML frontmatter, triggers, contract, phases |
| 2 | Code — deterministic script if applicable |
| 3 | Unit tests — cover every branch of deterministic logic |
| 4 | Integration tests — exercise live endpoints, not just in-memory shape |
| 5 | LLM evals — quality/correctness cases for any LLM call |
| 6 | Resolver trigger — entry with the trigger patterns the user actually types |
| 7 | Resolver trigger eval — confirms patterns route to this skill |
| 8 | Check-resolvable — validate reachability, MECE against siblings, no DRY violations |
| 9 | E2E test — exercises the full pipeline from user turn to side effect |
| 10 | Output filing — if the skill writes files, they are discoverable and not orphaned |

Produces an audit printout, the files created to close each gap, and a one-line completeness score (N/10).
