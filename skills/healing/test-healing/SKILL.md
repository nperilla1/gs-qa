---
name: test-healing
description: "Diagnose failing tests, determine if the failure is a test bug or app bug, and auto-fix test bugs. Uses decision tree heuristics to classify failures. Max 5 fix attempts per test. Use when asked to 'fix tests', 'heal tests', 'diagnose test failures', 'qa heal', 'qa:heal', 'why are tests failing', or 'make tests pass'."
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# Test Healing

You are diagnosing and fixing failing tests. Your primary job is to determine whether each failure is a **test bug** (the test is wrong) or an **app bug** (the application is wrong), then fix test bugs automatically and report app bugs for the bug-fixer.

## Target
$ARGUMENTS
(If no specific target, run all tests and heal failures)

## Phase 1: Run Tests and Capture Failures

### Python
```bash
python -m pytest <test_paths> -v --tb=long 2>&1 | tee /tmp/test-results.txt
```

### TypeScript
```bash
npx jest <test_paths> --verbose 2>&1 | tee /tmp/test-results.txt
npx playwright test <test_paths> 2>&1 | tee /tmp/test-results.txt
```

Parse the output to extract:
- Which tests failed
- The error type and message
- The full traceback/stack trace
- Expected vs actual values

## Phase 2: Classify Each Failure

Apply the diagnosis decision tree to each failure:

### Decision Tree

```
FAILURE
├── ImportError / ModuleNotFoundError
│   └── TEST BUG: Wrong import path
│       Fix: Find correct module path and update import
│
├── AttributeError
│   ├── On a mock object → TEST BUG: Mock misconfigured
│   │   Fix: Update mock to have the expected attribute/method
│   ├── On real object → Investigate
│   │   ├── Attribute exists in source → TEST BUG: Wrong attribute name
│   │   └── Attribute doesn't exist → APP BUG: Missing implementation
│   └── On fixture → TEST BUG: Fixture returns wrong type
│       Fix: Update fixture to return correct type
│
├── TypeError (wrong number of args)
│   ├── Function signature changed → TEST BUG: Outdated test
│   │   Fix: Update test to match new signature
│   └── Test passes wrong args → TEST BUG: Wrong test setup
│       Fix: Correct the arguments
│
├── AssertionError
│   ├── Expected value matches docstring/spec → APP BUG
│   │   Report: The app does not match its documented behavior
│   ├── Expected value contradicts docstring/spec → TEST BUG
│   │   Fix: Update expected value to match actual spec
│   ├── Expected value is reasonable, actual is clearly wrong → APP BUG
│   │   Report: The app produces incorrect output
│   └── Can't determine → Investigate further
│       Read the function being tested, its docstring, and any specs
│
├── FixtureError / fixture not found
│   └── TEST BUG: Missing or misnamed fixture
│       Fix: Create fixture or fix the name
│
├── ConnectionError / TimeoutError
│   ├── External service not mocked → TEST BUG: Missing mock
│   │   Fix: Add mock for external call
│   └── Test infrastructure issue → INFRA ISSUE
│       Report: Test needs running service (DB, Redis, etc.)
│
├── PermissionError / FileNotFoundError
│   └── TEST BUG: Test assumes specific file/directory exists
│       Fix: Create temp files in fixture or use tmp_path
│
├── DatabaseError / IntegrityError
│   ├── Test data conflicts → TEST BUG: Test data not isolated
│   │   Fix: Use unique test data or proper cleanup
│   └── Schema mismatch → APP BUG or MIGRATION ISSUE
│       Report: DB schema doesn't match model
│
└── Other / Unknown
    └── Read the full traceback, source code, and test code
        Make a judgment call based on context
```

## Phase 3: Fix Test Bugs

For each failure classified as a TEST BUG, apply the fix:

### Import Fixes
```python
# Find the correct import path
grep -rn "class ClassName" --include="*.py" src/
# Update the import in the test file
```

### Mock Fixes
```python
# Before (broken):
mock_service = MagicMock()
# Missing return_value for async method

# After (fixed):
mock_service = AsyncMock()
mock_service.get_item.return_value = {"id": "123", "name": "Test"}
```

### Assertion Fixes
```python
# Before (wrong expected value):
assert result.status == "active"  # But spec says new items start as "pending"

# After (correct expected value):
assert result.status == "pending"
```

### Fixture Fixes
```python
# Before (missing fixture):
def test_something(db_session):  # db_session not defined

# After (add to conftest.py or create inline):
@pytest.fixture
def db_session():
    ...
```

### Fix Protocol

For each fix:
1. Read the test file
2. Read the source code being tested
3. Read any relevant docstrings or specs
4. Make the minimal fix
5. Re-run ONLY that test to verify
6. If it still fails, try again (max 5 attempts)

```bash
# Run single test
python -m pytest <test_file>::<test_class>::<test_name> -v --tb=long 2>&1
```

## Phase 4: Report App Bugs

For each failure classified as an APP BUG, create a bug report:

```
## Bug Report

### Test
- File: <test_file>
- Test: <test_name>
- Status: APP BUG (confirmed)

### Expected Behavior
<What the test expects, backed by docstring/spec/documentation>

### Actual Behavior
<What the application actually does>

### Evidence
- Docstring says: "<quote>"
- Spec says: "<quote>"
- Test expects: <expected_value>
- App returns: <actual_value>

### Suggested Fix Location
- File: <source_file>
- Function: <function_name>
- Line: <approximate line>

### Reproduction
```bash
python -m pytest <test_file>::<test_name> -v
```
```

## Phase 5: Verify All Fixes

After fixing all test bugs, run the full test suite again:

```bash
python -m pytest <test_paths> -v --tb=short 2>&1
```

Verify:
- Previously failing tests now pass (test bugs fixed)
- No NEW failures introduced by fixes
- App bug tests still fail (expected — they need app fixes)

## Attempt Tracking

Track attempts per test to enforce the budget:

```
| Test | Attempt | Status | Action |
|------|---------|--------|--------|
| test_create_user | 1/5 | FIXED | Updated import path |
| test_auth_flow | 3/5 | STILL FAILING | Trying different mock setup |
| test_pipeline | 5/5 | UNFIXABLE | Escalating to human |
```

After 5 failed fix attempts, mark the test as UNFIXABLE and move on:
```
UNFIXABLE: test_pipeline
Attempts: 5/5
Last error: <error>
Reason: <why it can't be fixed automatically>
Recommendation: <what a human should look at>
```

## Output Summary

```
## Test Healing Report

### Results
- Total failures analyzed: N
- Test bugs fixed: N
- App bugs found: N
- Unfixable: N
- Total fix attempts: N

### Fixed Tests
1. <test_name> — <what was wrong> — fixed in <attempt>/5

### App Bugs (for bug-fixer)
1. <test_name> — <brief description>

### Unfixable (needs human)
1. <test_name> — <why it's unfixable after 5 attempts>

### Final Test Run
- Passing: N
- Failing: N (all should be confirmed app bugs)
- Skipped: N
```

## Rules

- Always read the source code before classifying a failure — do not guess
- Test bugs are MORE common than app bugs — most failures are from outdated or misconfigured tests
- Fix the TEST, not the APP — if it's a test bug, change the test
- Max 5 attempts per test — escalate after that
- Each fix should be minimal — change as little as possible
- After every fix, re-run the specific test to verify
- Never delete a failing test to "fix" it — understand why it fails first
- If a test is testing the wrong thing entirely, rewrite it rather than patching it
