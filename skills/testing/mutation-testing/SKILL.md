---
name: mutation-testing
description: "Run mutation testing to validate test quality — measures whether tests actually catch bugs, not just run code. Uses mutmut (Python) or Stryker (TypeScript). Mutation score is more meaningful than line coverage for test effectiveness. Use when asked to 'mutation test', 'test quality', 'mutmut', 'stryker', 'validate tests', 'how good are my tests', or 'test effectiveness'."
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Mutation Testing

You are running mutation testing to validate how effective the existing tests are. Mutation testing works by introducing small bugs (mutants) into the source code and checking whether the tests catch them. A test suite with high coverage but low mutation kill rate is giving a false sense of safety.

## Target
$ARGUMENTS
(If no specific target, mutate the main source modules and run against all tests)

## How Mutation Testing Works

1. **Mutant generation**: The tool modifies source code with small changes (mutants)
2. **Test execution**: Tests run against each mutant
3. **Kill or survive**: If tests fail → mutant is "killed" (good). If tests pass → mutant "survived" (bad — tests missed a bug)

### Mutation Operators

| Operator | Original | Mutant | Tests Should Catch |
|----------|----------|--------|-------------------|
| Arithmetic | `a + b` | `a - b` | Calculations |
| Comparison | `a > b` | `a >= b` | Boundary conditions |
| Boolean | `True` | `False` | Logic branches |
| Negate | `if x:` | `if not x:` | Conditional logic |
| Remove | `return value` | `return None` | Return values |
| Constant | `timeout=30` | `timeout=31` | Configuration |
| Delete stmt | `log.info(...)` | (deleted) | Side effects |

## Phase 1: Detect Language and Install Tool

### Python (mutmut)
```bash
# Check if installed
mutmut --version 2>/dev/null || pip install mutmut

# Check project structure
ls src/ 2>/dev/null && echo "src/ layout" || echo "flat layout"
ls tests/ 2>/dev/null && echo "tests/ found"
```

### TypeScript (Stryker)
```bash
# Check if installed
npx stryker --version 2>/dev/null || npm install --save-dev @stryker-mutator/core @stryker-mutator/typescript-checker @stryker-mutator/jest-runner

# Check for stryker config
cat stryker.config.mjs 2>/dev/null || echo "No stryker config"
```

## Phase 2: Configure

### Python — mutmut setup.cfg
```bash
# Check for existing config
grep -A 10 "\[mutmut\]" setup.cfg 2>/dev/null || grep -A 10 "\[tool.mutmut\]" pyproject.toml 2>/dev/null
```

If no config exists, create a minimal one:
```ini
[mutmut]
paths_to_mutate=src/
tests_dir=tests/
runner=python -m pytest -x -q
```

### TypeScript — stryker.config.mjs
```javascript
export default {
  mutate: ['src/**/*.ts', '!src/**/*.test.ts', '!src/**/*.spec.ts'],
  testRunner: 'jest',
  reporters: ['clear-text', 'html'],
  coverageAnalysis: 'perTest',
};
```

## Phase 3: Run Mutation Testing

### Python
```bash
# Full run (can be slow — start with a subset)
mutmut run --paths-to-mutate=<src_path> --tests-dir=<test_path> 2>&1

# Run against specific module
mutmut run --paths-to-mutate=src/services/auth.py 2>&1

# Check results
mutmut results 2>&1
```

### TypeScript
```bash
npx stryker run 2>&1
```

### Interpreting Output

```
Mutant statuses:
- killed    — test caught the mutant (GOOD)
- survived  — test missed the mutant (BAD — need better test)
- timeout   — mutant caused infinite loop (usually killed)
- error     — mutant caused compilation error (not counted)
- skipped   — mutant not tested (check config)
```

## Phase 4: Analyze Surviving Mutants

For each surviving mutant, understand WHY the tests didn't catch it:

### Python (mutmut)
```bash
# Show a specific surviving mutant
mutmut show <mutant_id>

# Show all survivors
mutmut results | grep "survived"
```

### Common Survival Reasons

| Reason | Example | Fix |
|--------|---------|-----|
| No assertion on value | Function called but return value ignored | Add `assert result == expected` |
| Weak assertion | `assert result is not None` when mutant returns wrong non-None value | Assert specific value |
| Missing edge case | `a >= b` mutated to `a > b` — no test with `a == b` | Add boundary test |
| Dead code | Mutated code is never reached | Delete dead code or add test path |
| Equivalent mutant | Mutation produces same behavior (e.g., `x * 1` → `x * -1` where x is always 0) | Skip — this is a false positive |

## Phase 5: Generate Tests for Surviving Mutants

For each surviving mutant that is NOT an equivalent mutant, write a test that kills it:

```python
# Example: mutmut mutated `if score > threshold:` to `if score >= threshold:`
# This survived because no test uses score == threshold

def test_score_exactly_at_threshold_is_not_passing(self):
    """Kill mutant: '>' mutated to '>=' in score check.

    Mutation testing found that tests didn't cover the boundary
    where score equals threshold exactly.
    """
    result = evaluate_score(score=70, threshold=70)
    assert result.status == "below_threshold"  # exactly AT threshold should not pass
```

### Naming Convention
```
test_<function>_<boundary_or_condition>_kills_<operator>_mutant
```

## Phase 6: Re-run to Verify

After writing new tests, re-run mutation testing to confirm mutants are now killed:

```bash
# Python — run only against the previously surviving mutants
mutmut run --paths-to-mutate=<affected_file> 2>&1
mutmut results 2>&1
```

## Target Kill Rates

| Module Type | Target Kill Rate | Rationale |
|-------------|-----------------|-----------|
| Authentication/Security | 85%+ | Security-critical code must be thoroughly tested |
| Core business logic | 70%+ | Revenue/correctness-critical paths |
| API endpoints | 65%+ | User-facing behavior |
| Data access layer | 60%+ | Data integrity |
| Utility functions | 50%+ | Standard supporting code |
| Configuration/Setup | 40%+ | Less dynamic, lower risk |

## Report

Output a mutation testing report:

```
## Mutation Testing Report

### Summary
- Source files mutated: N
- Total mutants: N
- Killed: N (X%)
- Survived: N (Y%)
- Timeout: N
- Errors: N

### Kill Rate by Module
| Module | Mutants | Killed | Survived | Kill Rate |
|--------|---------|--------|----------|-----------|

### Surviving Mutants (need tests)
1. <file>:<line> — `<original>` → `<mutant>` — <why it survived>
2. ...

### Equivalent Mutants (false positives, skip)
1. <file>:<line> — <why it's equivalent>

### New Tests Written
- <test_file>: N tests killing N mutants

### Final Kill Rate: X% (target: Y%)
```

## Rules

- Start with a small subset of modules, then expand — mutation testing is CPU-intensive
- Use `-x` flag (fail fast) in the test runner for speed
- Skip equivalent mutants — not every surviving mutant is a real issue
- Focus on surviving mutants in critical/high-priority modules first
- Do not obsess over 100% kill rate — diminishing returns above 80%
- Each new test should be meaningful, not just written to kill a mutant
- Report both kill rate AND which specific behaviors the surviving mutants expose
