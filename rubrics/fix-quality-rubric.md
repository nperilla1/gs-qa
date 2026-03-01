# Fix Quality Rubric

Score bug fixes on a 1-10 scale across weighted dimensions. Used by the qa-healer agent to evaluate whether a fix is acceptable before committing it.

## Scoring Dimensions

| Dimension | Weight | 1 (Poor) | 5 (Acceptable) | 10 (Excellent) |
|-----------|--------|----------|-----------------|-----------------|
| Root Cause | 30% | Symptom fix only. Patches the output without understanding why it was wrong. Will likely recur. | Partially addresses the root cause. Fixes the specific case but misses related cases. | Fixes the actual root cause. Explains why the bug existed and why this fix prevents recurrence. |
| Minimality | 20% | Extensive unrelated changes. Refactoring mixed with bug fix. Touches files unrelated to the bug. | Some extra changes beyond the fix. Minor cleanup bundled with the fix. | Smallest possible change that fixes the bug. Every modified line is necessary for the fix. No unrelated changes. |
| Correctness | 25% | Introduces new bugs or regressions. Breaks other tests. Fix is logically wrong. | Works for the reported case but may miss related edge cases. No regressions. | Handles all related cases including edge cases. No regressions. Provably correct by the test suite. |
| Convention | 10% | Ignores project coding style. Different naming, patterns, or structure than surrounding code. | Mostly follows project conventions. Minor style deviations. | Perfect style match with surrounding code. Indistinguishable from code a project maintainer would write. |
| Testing | 15% | No test verification. Fix applied blindly without running tests. No confidence it works. | The failing test now passes. Other tests not checked. | Failing test passes, full test suite passes, and the fix is covered by the test. No regressions introduced. |

## Scoring Process

1. Read the original failing test and error message
2. Read the fix diff (what was changed)
3. Read any related code that might be affected
4. Score each dimension 1-10 based on the criteria above
5. Calculate weighted average: `score = sum(dimension_score * weight)`
6. Round to one decimal place

## Pass / Fail

| Score | Verdict | Action |
|-------|---------|--------|
| 8-10 | PASS (Excellent) | Apply fix and move on |
| 7-7.9 | PASS (Acceptable) | Apply fix with minor notes |
| 5-6.9 | FAIL (Needs work) | Reattempt fix with specific feedback |
| 1-4.9 | FAIL (Poor) | Reattempt from scratch with different approach |

**PASS threshold: 7.0/10**

**Maximum attempts: 3** -- if a fix fails quality gate 3 times, flag it for human review.

## Per-Dimension Scoring Guide

### Root Cause (30%)

The most important dimension. A fix that treats symptoms will lead to whack-a-mole debugging.

Questions to ask:
- WHY did the bug exist? Is that reason addressed?
- Could the same class of bug exist elsewhere in the code?
- Will the fix prevent the bug from recurring, or just mask it?
- Is there a systemic issue (missing validation, wrong assumption) behind this specific bug?

| Score | Evidence |
|-------|----------|
| 1-3 | "Changed the expected value in the test" or "added a try/except to swallow the error" |
| 4-6 | Fixed the immediate issue but did not address the pattern that caused it |
| 7-8 | Fixed the root cause and explained the reasoning |
| 9-10 | Fixed the root cause AND identified related code that might have the same issue |

### Minimality (20%)

Smaller fixes are easier to review, less likely to introduce regressions, and easier to revert if needed.

| Score | Evidence |
|-------|----------|
| 1-3 | Fix touches 5+ files or includes refactoring/cleanup unrelated to the bug |
| 4-6 | Fix touches 2-3 files with minor unrelated changes |
| 7-8 | Fix is contained to 1-2 files, all changes directly related |
| 9-10 | Fix changes the minimum possible lines. Every change is necessary. |

### Correctness (25%)

The fix must actually work, and must not break anything else.

| Score | Evidence |
|-------|----------|
| 1-3 | Fix introduces new test failures or is logically wrong |
| 4-6 | Failing test passes but edge cases not considered |
| 7-8 | Failing test passes, no regressions, handles the specific case well |
| 9-10 | Failing test passes, no regressions, and fix handles all related edge cases |

### Convention (10%)

The fix should look like it belongs in the codebase.

| Score | Evidence |
|-------|----------|
| 1-3 | Different naming style, imported new libraries unnecessarily, wrong error handling pattern |
| 4-6 | Mostly follows conventions with minor deviations |
| 7-8 | Follows conventions well |
| 9-10 | Indistinguishable from the project maintainer's code |

### Testing (15%)

Verify the fix with the test suite.

| Score | Evidence |
|-------|----------|
| 1-3 | Tests not run after fix. No verification at all. |
| 4-6 | The specific failing test was rerun and passes |
| 7-8 | Failing test passes and the full test suite was run |
| 9-10 | Failing test passes, full suite passes, and the fix is specifically covered by test assertions |

## Report Format

```
FIX QUALITY REVIEW
==================
Bug: BUG-001 (Scoring formula boundary error)
File: src/services/scoring.py:45
Attempt: 1/3

Dimension Scores:
  Root Cause:   8/10 (30%) = 2.40
  Minimality:   9/10 (20%) = 1.80
  Correctness:  7/10 (25%) = 1.75
  Convention:    8/10 (10%) = 0.80
  Testing:       7/10 (15%) = 1.05

Overall Score: 7.80/10 -- PASS

Summary: Fix correctly addresses the off-by-one in boundary
  comparison (>= instead of >). Minimal change, follows
  project conventions. Test passes with no regressions.

Notes:
- Consider if other scoring functions have the same boundary issue
```

## Red Flags (Automatic FAIL)

Regardless of score, automatically FAIL if:
- Fix modifies test assertions to match buggy behavior (masking, not fixing)
- Fix adds `# type: ignore` or `noqa` to suppress real errors
- Fix adds a try/except that swallows exceptions silently
- Fix reverts a previous intentional change without explanation
- Fix introduces a security vulnerability (SQL injection, XSS, etc.)
