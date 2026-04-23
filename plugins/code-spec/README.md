# Code Spec Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install code-spec@blairanderson-skills
```

This plugin adds one skill for reverse-engineering structured specifications from existing application code.

---

## `/code-spec`

Reverse-engineer a feature or project specification from existing application code and related tests. Converts your system, feature, or application into a portable `SPEC.md` or `FEATURE-SPEC.md`.

Use when you want to:
- Extract a bounded feature from a large app
- Document the actual contract of an existing module
- Generate a spec from implementation evidence
- Produce a portable spec another agent can rebuild in a different language or stack

Trigger phrases: `"/code-spec Product Videos"`, `"write a FEATURE-SPEC.md from this code"`, `"extract this feature into its own app"`, `"document the real behavior of this part of the system"`.

The skill traces outward from the named anchor (class, route, model, job, screen) through entrypoints, implementation, data/state, relationships, behavior evidence, failure handling, performance paths, and configuration. It builds an internal evidence map before drafting the final document.

**Scope options:**
- `FEATURE-SPEC.md` — one bounded feature (recommended default)
- `SPEC.md` — a major subsystem
- `SPEC.md` — the whole project

Output is a single numbered-section markdown file saved to `/specs/`, written as a normative contract a future implementation could satisfy — not a code summary.
