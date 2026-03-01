---
name: qa:report
description: "Generate or view the QA report for the current project."
---

# /qa:report -- QA Report Viewer/Generator

You are viewing or generating a QA report for the current project.

## Process

### Step 1: Check for Existing Report

Look for an existing QA report:
```bash
ls -la qa-report.md 2>/dev/null
```

### Step 2A: Display Existing Report

If `qa-report.md` exists:
1. Read and display the full report
2. Highlight any critical issues or regressions
3. Show the overall health score prominently
4. Ask the user if they want to:
   - Regenerate the report (rerun the analysis)
   - View a specific section in detail
   - Export to a different format

### Step 2B: Generate New Report

If no report exists:
1. Check for QA artifacts that can inform the report:
   - `intent-map.json` -- intent discovery results
   - `test-plan.json` -- test planning results
   - Test result files (pytest output, coverage reports)
   - Any `bug-report-*.md` files
2. If artifacts exist, compile them into a report using the `qa-report.md` template
3. If no artifacts exist, offer to run a full sweep first (`/qa:sweep`)

### Step 3: Health Score Calculation

Calculate the overall health score (0-100) based on:

| Factor | Weight | Scoring |
|--------|--------|---------|
| Test pass rate | 30% | (passing / total) * 100 |
| Coverage | 20% | Line coverage percentage |
| Mutation score | 15% | Mutation kill rate |
| Static analysis | 15% | 100 - (issues * 2, min 0) |
| Intent coverage | 15% | (tested intents / total intents) * 100 |
| Visual regressions | 5% | 100 - (regressions * 10, min 0) |

### Step 4: Output

Display the report summary:

```
QA REPORT: [Project Name]
=========================
Generated: [timestamp]
Health Score: [X/100] [HEALTHY|NEEDS_ATTENTION|CRITICAL]

Quick Stats:
  Tests: X passing, X failing
  Coverage: X%
  Bugs: X found, X fixed
  Mutation Score: X%
```

Save the report to `qa-report.md`.

## Rules

- Always use the `qa-report.md` template for consistency
- If data is missing for a section, mark it as "Not analyzed" rather than omitting
- Health scores: 80+ = HEALTHY, 50-79 = NEEDS_ATTENTION, <50 = CRITICAL
- Include timestamps so users know how fresh the data is
