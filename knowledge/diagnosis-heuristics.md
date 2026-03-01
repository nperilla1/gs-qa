# Diagnosis Heuristics -- Test Bug vs App Bug

Decision tree and strategies for classifying test failures. When a test fails, the bug is either in the test itself (TEST BUG) or in the application code (APP BUG). Correctly classifying failures is critical -- fixing the wrong thing wastes time and can mask real bugs.

## Primary Decision Tree

```
Failure Type
├── ImportError / ModuleNotFoundError
│   └── TEST BUG: Wrong import path or missing dependency
│       Fix: Update import to match current module structure
│
├── AttributeError on mock/fixture object
│   └── TEST BUG: Mock misconfigured or fixture returns wrong type
│       Fix: Update mock spec or fixture return value
│
├── FixtureError / fixture not found
│   └── TEST BUG: Missing fixture, wrong scope, or conftest issue
│       Fix: Add fixture or fix conftest hierarchy
│
├── TypeError in test setup code
│   └── TEST BUG: Wrong arguments to constructor or helper
│       Fix: Update test to match current function signature
│
├── TypeError in application code
│   └── INVESTIGATE: Could be test passing wrong args OR app bug
│       Check: Does the function signature match the docstring/schema?
│       If yes → TEST BUG (test calling incorrectly)
│       If no → APP BUG (function signature is wrong)
│
├── AssertionError
│   ├── Expected value matches documented/specified behavior
│   │   └── APP BUG: Code does not match its spec
│   │       Fix: Fix the application code
│   │
│   ├── Expected value matches no known spec
│   │   └── TEST BUG: Wrong expectation in test
│   │       Fix: Update assertion to match actual spec
│   │
│   ├── Off-by-one or boundary issue
│   │   └── INVESTIGATE: Could be either
│   │       Check: What does the spec say about boundaries?
│   │       If spec is clear → fix whichever disagrees
│   │       If spec is ambiguous → flag as ambiguity
│   │
│   └── None/null where value expected (or vice versa)
│       └── INVESTIGATE:
│           Check: Is the function supposed to return None here?
│           If documented to return value → APP BUG
│           If edge case not documented → flag as ambiguity
│
├── Timeout
│   ├── In test setup (fixture, mock creation)
│   │   └── TEST BUG: Missing mock, hitting real external service
│   │       Fix: Add mock for the blocking call
│   │
│   ├── In application code (inside the function under test)
│   │   └── APP BUG: Infinite loop, deadlock, or performance issue
│   │       Fix: Debug the application code
│   │
│   └── Intermittent (sometimes passes, sometimes times out)
│       └── FLAKY TEST: Non-deterministic behavior
│           Fix: Add proper waits, mock time-dependent code, increase timeout
│
├── ConnectionError / ConnectionRefusedError
│   └── TEST BUG: Test hitting real service instead of mock
│       Fix: Mock the network call
│       Exception: Integration tests that intentionally hit services
│
├── FileNotFoundError
│   ├── In test code (reading test fixtures)
│   │   └── TEST BUG: Fixture file path wrong or file missing
│   │       Fix: Update path or add fixture file
│   │
│   └── In application code
│       └── APP BUG: Code assumes file exists without checking
│           Fix: Add existence check or handle FileNotFoundError
│
├── PermissionError
│   └── TEST BUG: Test environment setup issue
│       Fix: Use tmp_path fixture or fix file permissions
│
├── KeyError / IndexError
│   ├── In test code
│   │   └── TEST BUG: Test accessing wrong key/index in result
│   │       Fix: Update key/index to match actual response structure
│   │
│   └── In application code
│       └── APP BUG: Missing key check or array bounds check
│           Fix: Add defensive access (dict.get, bounds check)
│
├── ValueError in application code
│   └── INVESTIGATE:
│       Check: Is the test providing valid input per the spec?
│       If valid input → APP BUG (wrong validation)
│       If invalid input → TEST BUG (fix test data)
│
├── RuntimeError in application code
│   └── APP BUG: Unhandled error condition
│       Fix: Add error handling in application code
│
├── IntegrityError (database)
│   ├── Unique constraint violation
│   │   └── TEST BUG: Test data conflicts with existing data
│   │       Fix: Use unique test data or clean up before test
│   │
│   └── Foreign key violation
│       └── TEST BUG: Test inserting data without required references
│           Fix: Create referenced records first
│
└── asyncio errors (event loop, coroutine not awaited)
    └── TEST BUG: Missing async markers or incorrect async usage
        Fix: Add @pytest.mark.asyncio, ensure proper await
```

## Secondary Signals

When the primary decision tree gives INVESTIGATE, use these secondary signals:

### Signal: Git History

```bash
git log --oneline -5 -- <file_that_changed>
```

- If the app code changed recently and the test did not → likely APP BUG (test caught a regression)
- If the test was just written → likely TEST BUG (new test has issues)
- If neither changed recently → likely FLAKY TEST (environmental)

### Signal: Other Tests

- If multiple tests for the same module fail → likely APP BUG (the module is broken)
- If only one test fails → could be either (investigate that specific test)
- If tests in unrelated modules also fail → likely environmental issue (TEST BUG)

### Signal: Error Message Specificity

- Generic error ("assertion failed") → need more investigation
- Specific error with data ("expected 5, got 4") → compare against spec
- Error mentions specific function → look at that function's contract

### Signal: Test Age

- Old test that suddenly fails → likely APP BUG (regression) or environmental change
- New test that fails on first run → likely TEST BUG

## Fix Strategies by Classification

### TEST BUG Fixes

| Root Cause | Strategy |
|-----------|----------|
| Wrong import | Find the correct module path, update import |
| Wrong assertion value | Check spec/docstring for correct expected value |
| Missing mock | Identify the external call, add appropriate mock |
| Wrong fixture | Check conftest hierarchy, fix scope or return type |
| Stale test data | Regenerate or update test data to match current schema |
| Missing async marker | Add `@pytest.mark.asyncio` and `async` keyword |
| Wrong function signature | Update test to match current function params |

### APP BUG Fixes

| Root Cause | Strategy |
|-----------|----------|
| Missing validation | Add input validation matching the schema/spec |
| Wrong calculation | Fix the formula/logic to match spec |
| Missing error handling | Add try/except for the failure case |
| Race condition | Add locking or make operation atomic |
| Missing null check | Add guard clause for None/null values |
| Schema mismatch | Update code to match the expected schema |

### FLAKY TEST Fixes

| Root Cause | Strategy |
|-----------|----------|
| Time dependency | Freeze time with `freezegun` or `time_machine` |
| Random data | Seed the random generator or use fixed test data |
| Network dependency | Mock all network calls |
| Order dependency | Make test self-contained with own fixtures |
| Resource contention | Use unique resources per test (tmp_path, unique DB names) |

## Confidence Levels

After diagnosis, report your confidence:

| Confidence | Meaning | Action |
|-----------|---------|--------|
| HIGH | Clear evidence points to one classification | Fix it |
| MEDIUM | Most evidence points one way, some ambiguity | Fix it, but note the ambiguity |
| LOW | Could genuinely be either | Flag for human review |

## Example Diagnosis Report

```
DIAGNOSIS: test_create_organization_duplicate_ein (test_crm.py:89)

Error: AssertionError: 409 != 201
  - Test sends POST /organizations with duplicate EIN
  - Expected: 409 (conflict)
  - Actual: 201 (created)

Classification: APP BUG (HIGH confidence)
Reasoning:
  1. The Pydantic schema has UniqueConstraint on EIN
  2. The test expectation (409) matches the documented behavior
  3. The API is returning 201, meaning the uniqueness check is missing
  4. The endpoint code has no check for existing EIN before insert

Fix strategy: Add EIN existence check in create_organization endpoint
  before database insert, return 409 if EIN already exists.
```
