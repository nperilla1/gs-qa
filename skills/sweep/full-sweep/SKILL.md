---
name: full-sweep
description: "Run a complete autonomous QA sweep across all projects in the workspace. Executes the full 11-phase pipeline: intent discovery, static analysis, test planning, test generation, quality gate, execution, mutation testing, bug fixing, review, visual QA, and reporting. Use when asked to 'run QA', 'full sweep', 'test everything', 'qa sweep', 'qa:sweep', or 'comprehensive testing'."
allowed-tools: Agent, Read, Grep, Glob, Bash, Write, Edit, TaskCreate, TaskUpdate, TaskList, AskUserQuestion
---

# Full QA Sweep

You are running a complete, autonomous QA sweep across all projects in the workspace. This is the full 11-phase pipeline coordinated by the qa-orchestrator pattern.

## Target
$ARGUMENTS
(If no specific target given, discover and sweep all projects in the workspace)

## Phase 0: Stack Detection and Project Discovery

First, detect what you're working with:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh
```

If this is a monorepo or multi-project workspace, identify all project directories:
```bash
# Look for pyproject.toml, package.json, or similar in subdirectories
find . -maxdepth 2 -name "pyproject.toml" -o -name "package.json" | grep -v node_modules
```

Create tracking tasks for overall progress:

```
Task: "Phase 0: Stack Detection"         → no blockers
Task: "Phase 1: Intent Discovery"        → blocked by Phase 0
Task: "Phase 2: Static Analysis"         → blocked by Phase 0
Task: "Phase 3: Test Planning"           → blocked by Phase 1
Task: "Phase 4: Test Generation"         → blocked by Phase 3
Task: "Phase 5: Quality Gate"            → blocked by Phase 4
Task: "Phase 6: Test Execution + Healing"→ blocked by Phase 5
Task: "Phase 7: Mutation Testing"        → blocked by Phase 6
Task: "Phase 8: Bug Fixing"             → blocked by Phase 6
Task: "Phase 9: Review"                  → blocked by Phase 6, 7, 8
Task: "Phase 10: Reporting"             → blocked by Phase 9
```

## Phase 1: Intent Discovery

Spawn an intent discovery agent for each project:

```
Agent (subagent_type: researcher):
  "Perform intent discovery for <project> at <path>.
   Stack info: <stack detection output>.
   Read CLAUDE.md, README, all route files, all model files, all service files, existing tests.
   Write intent-map.json to <project_root>/intent-map.json.
   Follow the intent-discovery skill protocol."
```

If multiple projects, spawn agents in parallel.

Wait for all intent maps to be written.

## Phase 2: Static Analysis

Run static analysis tools auto-detected from the stack:

### Python
```bash
# Lint with ruff
ruff check <project_path> --output-format json 2>/dev/null || echo "ruff not available"

# Type check with mypy
mypy <project_path> --no-error-summary 2>/dev/null || echo "mypy not available"
```

### TypeScript/JavaScript
```bash
# Lint with biome or eslint
npx biome check <project_path> 2>/dev/null || npx eslint <project_path> --format json 2>/dev/null || echo "no linter available"

# Type check
npx tsc --noEmit 2>/dev/null || echo "tsc not available"
```

Record all findings. Static analysis issues are free test cases — they tell you where bugs likely hide.

## Phase 3: Test Planning

Spawn a test planner agent:

```
Agent (subagent_type: researcher):
  "Create a test plan based on the intent map at <path>/intent-map.json.
   Stack: <stack info>.
   Static analysis found <N> issues in these files: <list>.
   Prioritize: critical intents first, modules with static analysis issues second.
   Write test-plan.json to <project_root>/test-plan.json.
   Include: which test file to create, which intents it covers, estimated test count."
```

## Phase 4: Test Generation

Read `test-plan.json`. Spawn test writing agents based on what's needed:

### Backend Tests
```
Agent (subagent_type: coder):
  "Write backend tests for <project> based on this test plan: <relevant section>.
   Stack: <stack info>.
   Follow the backend-testing skill patterns.
   Write tests to: <test file paths from plan>.
   Use existing fixtures from conftest.py if present.
   Each test should be named: test_<behavior>_<scenario>_<expected>."
```

### Frontend Tests
```
Agent (subagent_type: coder):
  "Write frontend E2E tests for <project> based on this test plan: <relevant section>.
   Stack: <stack info>.
   Follow the frontend-testing skill patterns.
   Use Page Object Model.
   Use accessible selectors (getByRole, getByLabel, getByText).
   Write tests to: <test file paths from plan>."
```

Launch backend and frontend agents in PARALLEL if both are needed.

## Phase 5: Quality Gate (Sentinel)

After all test writing completes, audit every generated test file:

For each generated test file:
1. Read the file
2. Score against the test quality rubric at `${CLAUDE_PLUGIN_ROOT}/rubrics/test-quality-rubric.md`
3. Check for: meaningful assertions, proper isolation, no hardcoded values, proper cleanup, descriptive names

Scoring:
- **7-10**: Pass — proceed to execution
- **4-6**: Needs improvement — note issues for healer
- **Below 4**: Rewrite required — send back to test generation

## Phase 6: Test Execution + Healing

Run all tests and handle failures:

### Python
```bash
python -m pytest <test_paths> -v --tb=short 2>&1
```

### TypeScript
```bash
npx playwright test <test_paths> 2>&1
# or
npx jest <test_paths> 2>&1
```

For each failure, apply the test-healing diagnosis:
1. **ImportError / ModuleNotFoundError** → test bug (wrong import path) — fix automatically
2. **AttributeError on mock** → test bug (mock misconfigured) — fix automatically
3. **AssertionError where expected matches docstring** → app bug — create bug report
4. **AssertionError where expected contradicts any spec** → test bug — fix automatically
5. **Timeout** → investigate both possibilities

Maximum 5 fix attempts per test file. After 5 attempts, mark as unfixable and move on.

## Phase 7: Mutation Testing

Run mutation testing to validate test quality:

### Python
```bash
pip install mutmut 2>/dev/null
mutmut run --paths-to-mutate=<src_paths> --tests-dir=<test_paths> 2>&1
mutmut results 2>&1
```

### TypeScript
```bash
npx stryker run 2>&1
```

Analyze surviving mutants — these indicate tests that run code but don't actually verify it.

Target kill rates:
- Critical paths: 70%+
- Standard modules: 50%+

## Phase 8: Bug Fixing

For each confirmed app bug from Phase 6:

1. Read the bug report
2. Understand the intended behavior from the intent map
3. Make the minimal fix that resolves the issue
4. Run the failing test to verify
5. Run the full test suite to check for regressions
6. Maximum 3 attempts per bug

Spawn a bug-fixer agent for each bug:
```
Agent (subagent_type: coder):
  "Fix this confirmed application bug:
   Bug: <description>
   Failing test: <test file:test name>
   Intent: <from intent map>
   Make the minimal fix. Max 3 attempts.
   Verify with: <test command>"
```

Run bug fixers in parallel where bugs are in independent modules.

## Phase 9: Review

Spawn a fresh-context reviewer:

```
Agent (subagent_type: researcher):
  "Review the complete QA sweep results with fresh eyes.
   Generated test files: <list>
   Bug fixes applied: <list of diffs>
   Intent map: <path>
   Test plan: <path>
   Sentinel scores: <scores>

   Check:
   1. Do tests actually validate the intents they claim to cover?
   2. Are bug fixes minimal and correct?
   3. Are there any intents with no test coverage?
   4. Are there any test quality issues the sentinel missed?

   Provide APPROVE / NEEDS_WORK verdict for each test file and bug fix."
```

## Phase 10: Reporting

Generate the final QA report with these sections:

1. **Executive Summary**: Pass/fail, coverage metrics, critical findings
2. **Intent Coverage**: % of intents with tests, by priority level
3. **Test Results**: Total/passing/failing/skipped
4. **Mutation Score**: Kill rate by module
5. **Bugs Found**: List with severity and fix status
6. **Static Analysis**: Summary of linting/type issues
7. **Quality Scores**: Sentinel scores per test file
8. **Gaps**: Untested intents, surviving mutants, unfixed bugs
9. **Recommendations**: What to prioritize next

Write the report to `qa-report.md` in the project root.

## Budget Limits

| Phase | Max Attempts | On Exhaustion |
|-------|-------------|---------------|
| Intent Discovery | 1 | Ask user for clarification |
| Static Analysis | 1 | Report as-is |
| Test Planning | 1 | Ask user for priorities |
| Test Writing | 1 per module | Skip module, note in report |
| Quality Gate | 1 | Report scores as-is |
| Test Healing | 5 per test | Mark as unfixable |
| Mutation Testing | 1 | Report results as-is |
| Bug Fixing | 3 per bug | Mark as needs-human |
| Review | 1 | Report as-is |

## Rules

- Never skip the quality gate — quality over speed
- Never exceed the budget limits — prevent infinite loops
- Always ask the user before modifying application code (bug fixes)
- If a project has no frontend, skip frontend-related phases
- Report progress after each phase completes
- Create tasks for tracking and update them as you go
- Spawn agents in parallel where phase dependencies allow
