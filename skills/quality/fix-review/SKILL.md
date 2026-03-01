---
name: fix-review
description: "Review bug fixes with fresh context for correctness, completeness, and regression risk. Evaluates fixes against the fix-quality-rubric. Use when asked to 'review fix', 'check fix quality', 'is this fix good', 'review bug fix', or after qa-bug-fixer completes work."
allowed-tools: Read, Grep, Glob, Bash
---

# Fix Review

You are reviewing bug fixes with a fresh perspective. Your job is to evaluate whether each fix is correct, minimal, and safe — catching issues that the bug-fixer might have missed due to tunnel vision.

## Target
$ARGUMENTS
(Should include the fix report from qa-bug-fixer, or a list of changed files)

## Phase 1: Gather Context

Read all relevant materials before evaluating:

### 1a. Read the Fix Report
Extract:
- What bug was fixed
- What the root cause was
- What files were changed
- How many attempts it took

### 1b. Read the Changed Files
Read the full files that were modified (not just the diff) to understand the surrounding context:

```bash
# If git is available, see the diff
git diff <file_path>

# Read the full file
```

### 1c. Read the Failing Test
Understand what the test expects and verify the fix addresses it correctly.

### 1d. Read the Original Bug Report
Understand the expected behavior that was violated.

## Phase 2: Correctness Check

Ask these questions about each fix:

### Does it fix the root cause?
- [ ] The fix addresses WHY the bug happens, not just WHERE it manifests
- [ ] The fix would prevent the same class of bug, not just this specific instance
- [ ] If the inputs change slightly, the fix still works

**Red flag**: Fix only handles the exact case from the test without addressing the general problem.

### Does it match the specification?
- [ ] The fix aligns with the docstring/spec/documentation
- [ ] The fix doesn't change documented behavior
- [ ] Edge cases are handled consistently with the spec

**Red flag**: Fix makes the test pass but contradicts documentation.

### Is the logic correct?
- [ ] All code paths are handled (if/else branches, error cases)
- [ ] Boundary conditions are correct (off-by-one, inclusive/exclusive)
- [ ] Type handling is correct (null checks, type conversions)
- [ ] Error handling is complete (no swallowed exceptions)

**Red flag**: Fix introduces a new unhandled code path.

## Phase 3: Minimality Check

### Is the fix minimal?
- [ ] Only the necessary lines were changed
- [ ] No unrelated refactoring was included
- [ ] No new features were added beyond the fix
- [ ] No cosmetic changes (whitespace, formatting) mixed in

**Red flag**: More than 20 lines changed for a single bug fix.

### Is the approach the simplest one?
- [ ] There isn't a simpler way to achieve the same fix
- [ ] The fix doesn't introduce unnecessary abstractions
- [ ] The fix doesn't add dependencies that could be avoided

**Red flag**: Fix introduces a new utility function for a one-time operation.

## Phase 4: Regression Risk Assessment

### What could this fix break?

Read callers of the modified function:
```bash
grep -rn "<function_name>" --include="*.py" .
```

Check:
- [ ] All callers of the modified function are compatible with the change
- [ ] The function's return type hasn't changed unexpectedly
- [ ] The function's error behavior hasn't changed unexpectedly
- [ ] Side effects haven't been added or removed

### Are there similar patterns elsewhere?
```bash
# Find similar code that might have the same bug
grep -rn "<pattern from the bug>" --include="*.py" .
```

Check:
- [ ] If the same bug pattern exists elsewhere, it's noted (even if not fixed here)
- [ ] The fix is consistent with how similar code works elsewhere

### Database impact
If the fix changes database operations:
- [ ] Transaction boundaries are correct
- [ ] Index usage hasn't degraded
- [ ] Data integrity constraints are respected

## Phase 5: Test Coverage

### Is the fix adequately tested?
- [ ] The original failing test now passes
- [ ] Edge cases of the fix are tested
- [ ] Error paths introduced by the fix are tested

### Is the test suite stable?
Run the full test suite to verify:
```bash
python -m pytest <test_dir> -v --tb=short 2>&1
```

- [ ] No new failures introduced
- [ ] No flaky tests introduced (run twice if suspicious)

## Phase 6: Security Check

Quick security scan of the fix:
- [ ] No new SQL injection vectors (raw string interpolation in queries)
- [ ] No new command injection vectors (unsanitized input in shell commands)
- [ ] No sensitive data exposed in error messages or logs
- [ ] No authentication/authorization bypasses introduced
- [ ] No hardcoded secrets or credentials

## Phase 7: Verdict

Score each fix on these dimensions (1-5 scale):

| Dimension | Score | Notes |
|-----------|-------|-------|
| Correctness | /5 | Does it fix the actual bug? |
| Minimality | /5 | Is it the smallest possible change? |
| Safety | /5 | Does it avoid regressions? |
| Completeness | /5 | Are edge cases handled? |
| Code Quality | /5 | Does it follow project conventions? |
| **Overall** | **/25** | |

### Verdict Criteria

| Score | Verdict | Action |
|-------|---------|--------|
| 20-25 | **APPROVE** | Fix is ready to merge |
| 15-19 | **APPROVE WITH NOTES** | Fix is acceptable but has minor issues to address |
| 10-14 | **NEEDS WORK** | Fix has significant issues — send back to bug-fixer |
| Below 10 | **REJECT** | Fix is incorrect or dangerous — needs complete redo |

### Output Format

```
## Fix Review: <bug description>

### Files Changed
- <file_path>: <N lines changed>

### Correctness: X/5
<analysis>

### Minimality: X/5
<analysis>

### Safety: X/5
<analysis>

### Completeness: X/5
<analysis>

### Code Quality: X/5
<analysis>

### Regression Risk
- <risk 1>
- <risk 2>

### Similar Bug Patterns Found
- <location>: <same pattern, may need same fix>

### Verdict: APPROVE / APPROVE WITH NOTES / NEEDS WORK / REJECT

### Action Items
1. <what needs to change, if anything>
```

## Rules

- Review with FRESH EYES — pretend you've never seen this code before
- Be skeptical but constructive — explain WHY something is a concern
- A fix that introduces a regression is worse than no fix at all
- Don't just check if the test passes — check if the fix is CORRECT
- Note but don't block on style issues — focus on correctness and safety
- If you find the same bug pattern elsewhere, note it even if it's out of scope
- Read the FULL changed file, not just the diff — context matters
