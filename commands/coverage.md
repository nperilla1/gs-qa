---
name: qa:coverage
description: "Analyze test coverage gaps — compare existing tests against the Intent Map to find untested behaviors."
---

# /qa:coverage -- Coverage Gap Analysis

You are analyzing test coverage gaps by comparing existing tests against the Intent Map.

## Process

### Step 1: Intent Map Check

Look for an existing Intent Map:
```bash
ls -la intent-map.json 2>/dev/null
```

If not found, run intent discovery first:
- Announce: "No Intent Map found. Running intent discovery first..."
- Invoke the `intent-discovery` skill
- Continue with the generated `intent-map.json`

### Step 2: Existing Test Discovery

Find all existing test files:
- **Python**: `test_*.py`, `*_test.py` in `tests/` directory
- **TypeScript**: `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`
- **E2E**: Files in `e2e/` directory

For each test file, extract:
- Test function/method names
- What modules/functions they import and test
- Assertions made (what behaviors they verify)

### Step 3: Cross-Reference

For each intent in the Intent Map:
1. Check if any existing test covers it (by import, assertion, or naming)
2. Classify coverage:
   - **Covered**: A test directly verifies this intent
   - **Partially covered**: A test touches related code but does not assert this specific behavior
   - **Uncovered**: No test relates to this intent

### Step 4: Gap Report

```
COVERAGE GAP ANALYSIS
=====================
Project: [name]

Intent Coverage:
  Total intents:      X
  Fully covered:      X (Y%)
  Partially covered:  X (Y%)
  Uncovered:          X (Y%)

Uncovered by Priority:
  P0 (Critical):  X  <-- FIX THESE FIRST
  P1 (High):      X
  P2 (Medium):    X
  P3 (Low):       X

Top Uncovered Intents:
  1. [INT-XXX] [description] (P0, security)
  2. [INT-XXX] [description] (P0, data-integrity)
  3. [INT-XXX] [description] (P1, core-journey)
  ...

Files with No Test Coverage:
  - src/services/important_service.py
  - src/api/routes/critical_route.py
  ...
```

### Step 5: Recommendations

Based on the gaps, recommend:
1. Which intents to test first (P0 uncovered, then P1)
2. Which test files to create
3. Estimated effort (number of tests needed)

Ask the user if they want to:
1. Generate tests for uncovered P0 intents now
2. Generate a full test plan
3. Just save the gap analysis report

### Step 6: Output

Update the `intent-map.json` with coverage data:
- Set `tested: true/false` on each intent
- Populate `existing_tests` arrays
- Update `coverage_gaps` section

Save the gap analysis to `coverage-gaps.md`.

## Rules

- Be conservative in marking intents as "covered" -- a test must actually assert the behavior
- A test that imports a module but does not assert its behavior is "partial" at best
- Always prioritize P0/P1 uncovered intents in the report
- If the project has a coverage report (pytest-cov, istanbul), incorporate those numbers
- Do not generate tests in this command -- analysis only
