---
name: skillify
version: 1.0.0
description: "Use when: user says 'skillify this', 'skillify', 'is this a skill?', 'make this proper', or wants to add tests and evals to a feature, or check skill completeness against the 10-item checklist (SKILL.md, tests, evals, resolver triggers)"
argument-hint: "skillify this, is this a skill?, check skill completeness, make this proper"
allowed-tools: Bash, Read, Write, Edit, Glob
---

# Skillify — The Meta Skill

## Contract

A feature is "properly skilled" when all ten checklist items are present:

1. `SKILL.md` — skill file with YAML frontmatter, triggers, contract, phases.
2. Code — deterministic script if applicable.
3. Unit tests — cover every branch of deterministic logic.
4. Integration tests — exercise live endpoints, not just in-memory shape.
5. LLM evals — quality/correctness cases if the feature includes any LLM call.
6. Resolver trigger — entry with the trigger patterns the user actually types,
   pointing to this skill.
7. Resolver trigger eval — test that feeds trigger phrases to the resolver
   and asserts they route to this skill.
8. Check-resolvable — validate the skill is reachable, MECE against siblings,
   no DRY violations.
9. E2E test — exercises the full pipeline from user turn to side effect.
10. Output filing — if the skill writes files or pages, they are discoverable
    and not orphaned.

## Trigger

- "skillify this" / "skillify" / "is this a skill?" / "make this proper"
- "add tests and evals for this"
- After building any new feature that touches user-facing behavior
- When you notice a script or tool with no SKILL.md next to it

## Phases

### Phase 1: Audit what exists

For the feature being skillified, answer:

- **Feature name**: what does it do in one line?
- **Code path**: where does the implementation live (file path)?
- **Checklist status**: go through the 10-item checklist manually and note
  which items are missing.

### Phase 2: Create missing pieces in order

Work the list top-down. Each earlier item constrains what later items look
like (the SKILL.md contract determines what tests assert; tests determine
what evals gate; the resolver entry determines what trigger-eval checks).

1. Write `SKILL.md` first. Frontmatter must include `name`, `version`,
   `description`, and `allowed-tools`. Body has at minimum Contract,
   Phases, and Output Format sections.
2. Extract deterministic code into a script if applicable.
3. Write unit tests for every branch of the script. Mock external calls
   (LLM, DB, network) so tests run fast and deterministic.
4. Add integration tests that hit real endpoints. These catch bugs the
   unit tests' mocks hide — reimplementation in tests lets production
   vulnerabilities slip through.
5. Add LLM evals if the feature includes any LLM call. Even a three-case
   eval (happy / edge / adversarial) is cheap insurance against prompt
   regressions.
6. Add the resolver trigger. Use the trigger patterns the user ACTUALLY
   types, not what you think they should type.
7. Add a resolver trigger eval that feeds those patterns in and asserts
   they route to the new skill.
8. Validate reachability: is the skill mentioned from the resolver? Does it
   duplicate an existing skill's trigger? Are there user intents that fall
   through with no match? Fix the skill (or extend an existing one) if so.
9. Add an E2E smoke test. Run a CLI invocation end-to-end and assert side
   effects.
10. Ensure outputs are discoverable — if the skill writes files or pages,
    they have a corresponding entry so they aren't orphaned.

### Phase 3: Verify

Run each of these and confirm green:

```bash
# Unit tests (adapt to project's test runner)
npm test / bun test / pytest ...

# Integration tests (when applicable)
npm run test:e2e

# Conformance — skill YAML + required sections
# (project-specific; skip if no conformance suite exists)
```

## Quality gates

A feature is NOT properly skilled until:

- All tests pass (unit + integration + evals).
- It is reachable from the resolver with accurate trigger patterns.
- The resolver trigger eval confirms patterns route to the new skill.
- No orphaned skills, no MECE overlaps, no DRY violations.
- If it writes output files, they are discoverable.

## Anti-Patterns

- Code with no SKILL.md — invisible; the agent will never run it.
- SKILL.md with no tests — untested contract; one prompt change regresses
  silently.
- Tests that reimplement production code — the reimplementation's bugs
  don't catch production's bugs.
- Resolver entry that uses internal jargon the user never types — trigger
  patterns must mirror real user language.
- Deterministic logic in LLM space — should be a script.
- LLM judgment in deterministic space — should be an eval.

## Output Format

A skillify run produces, in order:

1. An audit printout listing which of the 10 items exist and which are
   missing for the target feature.
2. The files created to close each gap (SKILL.md, test files, resolver
   entries).
3. A one-line summary of the resulting skill completeness score (N/10).

## Destination

A skill can exist in many places: 
- [ ] the current repository {pwd}/.claude/skills/*
- [ ] the system ~/.claude/skills/*
- [ ] the USER skills marketplace directory (print the actual directory name)

AskUserQuestion "Where should $skill-name go?"
