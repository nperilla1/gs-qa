---
name: targeted-sweep
description: "Test only files that have changed since the last commit or between branches. Uses git diff to identify changed files, discovers their intent, and generates targeted tests. Use when asked to 'test changes', 'test diff', 'test what changed', 'targeted sweep', 'test my changes', 'qa:targeted', or 'test since last commit'."
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, AskUserQuestion
---

# Targeted Sweep

You are running a targeted QA sweep that only tests files that have changed. This is faster than a full sweep because it focuses on what's actually been modified.

## Target
$ARGUMENTS
(If no arguments, test changes since the last commit on the current branch)

## Phase 1: Identify Changed Files

Determine what has changed based on the target:

### Since Last Commit (default)
```bash
# Unstaged changes
git diff --name-only

# Staged changes
git diff --cached --name-only

# Combined (all uncommitted changes)
git diff HEAD --name-only
```

### Between Branches
```bash
# Changes relative to main/master
git diff main...HEAD --name-only 2>/dev/null || git diff master...HEAD --name-only
```

### Since Specific Commit
```bash
git diff <commit_hash>...HEAD --name-only
```

Filter to only source files (exclude tests, configs, docs unless specifically relevant):
```bash
# Python source files
git diff HEAD --name-only -- '*.py' | grep -v test | grep -v __pycache__

# TypeScript source files
git diff HEAD --name-only -- '*.ts' '*.tsx' | grep -v test | grep -v spec | grep -v __tests__
```

## Phase 2: Understand the Changes

For each changed file, read the diff to understand WHAT changed:

```bash
git diff HEAD -- <file_path>
```

Categorize each change:
- **New function/method**: Needs new tests
- **Modified function signature**: Existing tests may need updating + new edge cases
- **Bug fix**: Need regression test
- **Refactor (same behavior)**: Existing tests should still pass — just verify
- **New file**: Full intent discovery + test generation
- **Deleted file**: Check if tests reference it

## Phase 3: Impact Analysis

Determine the blast radius — what else might be affected by these changes:

```bash
# Find files that import the changed module
grep -rn "from <module> import\|import <module>" --include="*.py" .
grep -rn "from '<module>'\|from \"<module>\"" --include="*.ts" .
```

Build an impact list:
1. **Direct changes**: Files in the diff
2. **Direct dependents**: Files that import changed modules
3. **Transitive dependents**: Files that import the direct dependents (1 level only)

## Phase 4: Find Existing Tests

For each changed file, find its corresponding test file:

```bash
# Common patterns
# src/services/auth.py → tests/services/test_auth.py
# src/api/routes/users.py → tests/api/test_users.py
# src/components/Button.tsx → src/components/Button.test.tsx
```

If an existing test file exists:
1. Read it to understand current coverage
2. Identify what NEW tests are needed for the changes
3. Do NOT regenerate tests that already exist

If no test file exists:
1. This is a coverage gap — generate tests for the changed functionality

## Phase 5: Intent Discovery (Scoped)

For each changed function/class, extract intent from:
1. The function's docstring
2. Type hints
3. Existing tests (if any)
4. The git commit message that introduced the change
5. The PR description (if available)

This is a focused version of intent-discovery — only for changed code.

## Phase 6: Generate Targeted Tests

Write tests ONLY for:
1. New functions/methods that have no tests
2. Modified behavior that existing tests don't cover
3. Bug fixes that need regression tests
4. Edge cases exposed by the changes

Do NOT write tests for:
- Unchanged code
- Refactored code where behavior is identical
- Deleted code

### Test Naming Convention
```
test_<changed_function>_<new_scenario>_<expected>
```

### Placement
- Add to existing test files when possible
- Create new test files only when there is no corresponding test file

## Phase 7: Run Affected Tests

Run only the tests that are relevant to the changes:

### Python
```bash
# Run specific test files
python -m pytest <test_file_1> <test_file_2> -v --tb=short

# Or use pytest markers if the project uses them
python -m pytest -m "not slow" <test_paths> -v
```

### TypeScript
```bash
# Run specific test files
npx jest <test_file_1> <test_file_2>
npx playwright test <test_file_1>
```

## Phase 8: Heal Failures

For each failing test:
1. Is it a NEW test that's wrong? → Fix the test (max 3 attempts)
2. Is it an EXISTING test broken by the change? → This is a regression
   - If the change is intentional, update the test
   - If the change is unintentional, flag it as a bug
3. Is it an unrelated failure? → Note it but don't fix

## Phase 9: Report

Output a concise report:

```
## Targeted Sweep Report

### Changes Analyzed
- <N> files changed
- <N> functions added/modified/deleted

### Tests Generated
- <N> new tests written
- <N> existing tests updated

### Results
- <N> passing
- <N> failing
- <N> skipped

### Issues Found
- <list of bugs or regressions>

### Coverage Delta
- Before: <existing test count for changed modules>
- After: <new test count>
```

## Rules

- Only test what changed — do not boil the ocean
- Prefer adding to existing test files over creating new ones
- If a change has no testable behavior (e.g., comment-only, type-only), skip it
- Regression tests for bug fixes are HIGH priority — always write them
- If unsure whether a behavior change is intentional, ask the user
- Keep the scope tight — a targeted sweep should be fast (minutes, not hours)
