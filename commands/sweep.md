---
name: qa:sweep
description: "Full autonomous QA sweep — discovers intent, generates tests, runs quality gates, fixes bugs, and reports results."
---

# /qa:sweep -- Full Autonomous QA Sweep

You are running a complete QA sweep on the current project. This coordinates all QA phases from intent discovery through final reporting.

## Pre-Flight

1. Detect the project tech stack using `scripts/detect-stack.sh`
2. Verify the project has a valid structure (src directory, config files, dependencies)
3. Check for existing QA artifacts (intent-map.json, qa-report.md) and offer to reuse or regenerate

## Execution Plan

Run the full QA pipeline using the qa-orchestrator agent. Create tasks to track progress through each phase.

### Phase 0: Intent Discovery
- Invoke the `intent-discovery` skill
- Output: `intent-map.json` in the project root
- Gate: At least 5 intended behaviors discovered

### Phase 1: Static Analysis
- Run the project's linter (ruff for Python, biome for TypeScript)
- Auto-fix safe issues
- Report unfixable issues

### Phase 2: Test Planning
- Invoke the `test-planning` skill with the Intent Map
- Output: `test-plan.json` in the project root
- Gate: Every P0 and P1 intent has at least one planned test

### Phase 3: Test Generation
- Invoke the `test-generation` skill with the test plan
- Generate test files following project conventions
- Output: Test files in the project's test directory

### Phase 4: Quality Gate
- Score every generated test against the `test-quality-rubric`
- Tests scoring below 7/10 are regenerated (max 2 retries)
- Gate: All tests score >= 7/10

### Phase 5: Execution + Healing
- Run the test suite
- For failures, invoke the `test-healing` skill
- Classify failures as test bugs vs app bugs
- Fix test bugs automatically
- Report app bugs for later fixing

### Phase 6: Mutation Testing
- Generate code mutants for covered code
- Run tests against mutants
- Report mutation kill rate
- Gate: Kill rate >= 70% for P0 intents

### Phase 7: Bug Fixing
- For each discovered app bug, invoke the `bug-fixing` skill
- Score fixes against the `fix-quality-rubric`
- Fixes scoring below 7/10 are reattempted (max 3 attempts)

### Phase 8: Review
- Run a final review pass on all generated tests and fixes
- Check for anti-patterns from the `anti-patterns` knowledge doc
- Report any remaining issues

### Phase 9: Visual QA (frontend only)
- If a frontend is detected, invoke the `visual-testing` skill
- Compare against baselines if they exist
- Report visual regressions

## Reporting

After all phases complete, generate a QA report using the `qa-report.md` template. Display:

```
QA SWEEP COMPLETE
=================
Project: [name]
Duration: [time]
Health Score: [X/100]

Tests Generated:  X
Tests Passing:    X
Bugs Found:       X
Bugs Fixed:       X
Mutation Score:   X%

Full report: qa-report.md
```

## Rules

- Never modify source code without user confirmation (tests and configs are fine)
- If a phase fails catastrophically, skip it and continue with the next
- Report progress after each phase completes
- Save all artifacts to the project root
- If $ARGUMENTS contains a project path, use that instead of the current directory
