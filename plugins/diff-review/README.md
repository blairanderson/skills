# Diff Review Plugin

Install marketplace:

```shell
/plugin marketplace add blairanderson/skills
```

Install Skill:

```
/plugin install diff-review@blairanderson-skills
```

This plugin adds one skill for adversarial code review of git diffs.

---

## `/diff-review`

Strict, adversarial review of your staged and unstaged changes. Finds real problems — bugs, performance regressions, correctness issues, security holes — before they ship.

```shell
/diff-review           # reviews current staged + unstaged changes
/diff-review HEAD~3    # reviews a commit range
/diff-review abc123..def456
```

Hunts for problems in four severity tiers:

| Tier | Examples |
|---|---|
| **Critical — Correctness** | Off-by-one errors, null dereferences, race conditions, logic inversions, missing error handling, changed signatures with unchecked callers |
| **Critical — Security** | SQL injection, XSS, command injection, credentials in tracked files, weakened permission checks |
| **High — Performance** | N+1 queries, unbounded growth, missing indexes, expensive operations in hot loops |
| **High — Concurrency** | Data races, deadlocks, missing awaits, thread-unsafe instance variables |
| **Medium — API/Contract** | Breaking API changes, changed response shapes, removed serialized fields |
| **Medium — Correctness** | Dead code, copy-paste errors, hardcoded values, missing resource cleanup |

Findings are presented one at a time, ordered by severity. For each: the code, the failure scenario, a recommended fix, and the option to apply it immediately. Ends with a verdict: Safe to ship / Still has open issues.
