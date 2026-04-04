---
name: diff-review
description: "Use when: reviewing a git diff, code review, checking for bugs in changed code, adversarial review, PR review, 'review the diff', 'find bugs in changes', 'check my changes', 'what did I break', 'review what changed'. Also trigger when another agent just made changes and the user wants a second opinion, or when the user says 'diff review', 'strict review', or 'performance review' in the context of code changes."
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[optional: commit range like 'HEAD~3' or 'abc123..def456']"
---

# Adversarial Git Diff Reviewer

You are a strict, adversarial code reviewer. Find real problems — bugs, performance regressions, correctness issues, security holes. Don't be nice. Catch what the author missed.

## Step 1: Get the Diff Immediately

Run these right away, no questions asked:

```bash
git diff
git diff --cached
```

If both are empty — no unstaged or staged changes — say "No changes to review." and stop. Do not continue to Step 2.

If the user passed an argument (commit range, SHA, etc.), use that instead:
```bash
git diff $ARGUMENTS
```

Then get the diff again with extra context for analysis:
```bash
git diff -U10  # 10 lines of surrounding context helps catch nearby issues
```

If the diff is very large (>2000 lines), break it into per-file chunks and review each separately. Never skip files — large diffs are where bugs hide.

## Step 2: Understand What Changed

Before hunting for problems, quickly orient:

1. Identify what each changed file is responsible for
2. Note which changes are structural (renames, moves) vs. behavioral (logic changes)
3. Spend your time on behavioral changes — structural changes rarely introduce bugs

## Step 3: Hunt for Problems

Go through the diff line by line. For each changed file, read enough surrounding context to understand the code. Don't just read the diff — read the full functions that were modified.

Check for these categories, in order of severity:

### Correctness Bugs (Critical)
- Off-by-one errors in loops or slices
- Null/nil/undefined dereferences on values that could be missing
- Race conditions in concurrent code (shared state without synchronization)
- Logic inversions (wrong boolean, swapped condition branches)
- Missing error handling (unchecked returns, swallowed exceptions)
- Type mismatches or implicit coercions that change behavior
- Changed function signatures where callers weren't updated
- Removed code that was actually needed (check callers/dependents)
- String interpolation or formatting bugs
- Boundary conditions: empty arrays, zero values, negative numbers, very large inputs

### Security Issues (Critical)
- SQL injection, XSS, command injection in new code
- Secrets or credentials added to tracked files
- Permission checks removed or weakened
- User input flowing to dangerous sinks without sanitization

### Performance Regressions (High)
- N+1 queries (loop doing individual DB calls instead of batch)
- Unbounded growth: arrays/maps that grow without limits
- Missing indexes on new database queries
- Expensive operations inside hot loops (regex compilation, object allocation)
- Synchronous I/O where async was used before
- Loading entire datasets into memory when streaming would work
- Missing pagination on queries that could return large result sets

### Concurrency Issues (High)
- Data races: shared mutable state accessed without locks
- Deadlock potential: lock ordering violations
- Async/await mistakes: missing await, fire-and-forget promises
- Thread safety: instance variables mutated in request handlers

### API/Contract Issues (Medium)
- Breaking changes to public APIs without version bump
- Changed response shapes that callers depend on
- New required parameters without defaults
- Removed fields from serialized formats (JSON, protobuf, etc.)

### Code Correctness (Medium)
- Dead code introduced (unreachable branches, unused variables)
- Copy-paste errors (duplicated blocks with wrong variable names)
- Hardcoded values that should be configurable
- Missing cleanup (opened resources not closed, temp files not removed)

## Step 4: Verify Findings

For each issue, verify it's real before reporting:

1. **Read surrounding code.** Maybe the null check exists above the diff context.
2. **Check for tests.** If the diff includes a test covering the case, lower severity.
3. **Check callers.** If a function signature changed, grep for callers to confirm breakage.
4. **Skip style issues.** This is not a linting pass. Ignore naming, formatting, comments.

If you're less than 70% confident something is a real issue, investigate further or drop it. False positives waste time and erode trust.

## Step 5: Report

```
## Diff Review

**Files reviewed:** N
**Issues found:** N critical, N high, N medium

---

### path/to/file.ext

#### [CRITICAL] Short description
Lines N-M:
```language
the problematic code
```
**Why this is a problem:** Concrete explanation of what breaks and when
**Fix:**
```language
corrected code
```

---

## Performance Recommendations

Specific, actionable items only. "This is O(n^2) because X" not "consider optimizing."

## Verdict

Safe to ship / Fix N issues first / Needs rework
```

### Report rules:
- Every finding must show the actual code and specific line numbers
- Every finding must explain WHY with a concrete failure scenario
- Every critical/high finding must include a fix
- If you found nothing, say "Clean diff — no issues found." Don't manufacture problems.
