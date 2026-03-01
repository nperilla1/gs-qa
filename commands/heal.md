---
name: qa:heal
description: "Fix failing tests — diagnose whether failures are test bugs or app bugs, then auto-fix."
---

# /qa:heal -- Test Healing

You are diagnosing and fixing failing tests. For each failure, you determine whether the bug is in the test or in the application code, then apply the appropriate fix.

## Process

### Step 1: Run Test Suite

Execute the project's test suite and capture output:

**Python**:
```bash
python -m pytest --tb=long -v 2>&1
```

**TypeScript**:
```bash
npx vitest run 2>&1
# or: npx jest 2>&1
```

If all tests pass:
```
All tests passing. Nothing to heal.
```

### Step 2: Parse Failures

For each failing test, extract:
- Test file and function name
- Error type (ImportError, AssertionError, TypeError, etc.)
- Full traceback
- Expected vs actual values (if assertion failure)

### Step 3: Diagnose Each Failure

Use the diagnosis heuristics from `knowledge/diagnosis-heuristics.md`:

```
For each failure:
  1. Classify: TEST BUG or APP BUG
  2. Identify root cause
  3. Determine fix strategy
```

Display the diagnosis:
```
FAILURE DIAGNOSIS
=================

1. test_create_organization (test_crm.py:45)
   Error: ImportError: cannot import name 'OrganizationService'
   Diagnosis: TEST BUG -- import path changed
   Fix: Update import to match current module structure

2. test_calculate_score (test_scoring.py:112)
   Error: AssertionError: 85 != 90
   Diagnosis: APP BUG -- scoring formula off by boundary case
   Fix: Update scoring logic for edge case

3. test_api_auth (test_auth.py:23)
   Error: ConnectionError: localhost:5432
   Diagnosis: TEST BUG -- missing database mock
   Fix: Add mock for database connection
```

### Step 4: Fix Test Bugs

For failures classified as TEST BUGS:
1. Read the test file and understand the intent
2. Read the source code the test is targeting
3. Fix the test to correctly test the current code
4. Verify the fix by running just that test

Fixes must:
- Preserve the test's original intent
- Not weaken the assertion (do not just make it pass trivially)
- Follow project test conventions
- Score >= 7/10 on the test-quality-rubric

### Step 5: Report App Bugs

For failures classified as APP BUGS:
1. Create a bug report using the `bug-report.md` template
2. Save to `bug-reports/BUG-XXX.md`
3. Ask the user if they want to invoke the `bug-fixing` skill

### Step 6: Rerun and Report

After all test bug fixes are applied, rerun the test suite:

```
TEST HEALING RESULTS
====================
Before: X passing, Y failing
After:  X passing, Y failing

Test Bugs Fixed: X
  - test_create_organization: fixed import path
  - test_api_auth: added database mock
  ...

App Bugs Found: X
  - BUG-001: Scoring formula boundary error (test_scoring.py:112)
  ...

Remaining Failures: X
  - [list any unresolved failures with reason]
```

If app bugs were found, ask:
```
Found X app bugs. Would you like to:
1. Fix them now (/qa:heal --fix-app-bugs)
2. View the bug reports
3. Skip -- I'll fix these manually
```

## Rules

- Never weaken a test assertion to make it pass -- that hides real bugs
- If uncertain whether a failure is a test bug or app bug, investigate the git history
- Maximum 3 fix attempts per test before marking as unresolvable
- Always rerun the specific test after fixing to verify
- Do not modify application source code unless explicitly told to fix app bugs
- Save all bug reports to `bug-reports/` directory
