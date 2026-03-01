# Test Quality Rubric

Score generated tests on a 1-10 scale across weighted dimensions. Used by the quality-sentinel agent to gate test output.

## Scoring Dimensions

| Dimension | Weight | 1 (Poor) | 5 (Acceptable) | 10 (Excellent) |
|-----------|--------|----------|-----------------|-----------------|
| Intent Alignment | 25% | Tests implementation details, not behavior. No clear connection to a requirement. | Tests some behaviors but misses key intents. Partial coverage of the spec. | Every test maps to a specific intent from the Intent Map. All P0/P1 intents covered. |
| Assertion Quality | 20% | No assertions, or tautological assertions that always pass. Tests existence, not correctness. | Basic equality checks (assert result == expected). Single assertion per test. | Comprehensive property checks: types, values, side effects, error messages. Uses pytest.approx, parametrize for boundaries. |
| Isolation | 15% | Shared mutable state between tests. Tests depend on execution order. Hits real services. | Some isolation but shared fixtures with side effects. Occasional order dependency. | Fully independent and hermetic. Each test creates its own state. All external calls mocked. Transaction rollback for DB. |
| Readability | 10% | Cryptic variable names (x, y, z). No structure. 100+ line test functions. Copy-paste duplication. | Readable names and structure. AAA pattern mostly followed. Some duplication. | Self-documenting test names describe behavior. Clean AAA structure. Fixtures and parametrize eliminate duplication. |
| Edge Cases | 15% | Happy path only. No null/empty/boundary testing. No error path testing. | Some boundary tests (empty input, max length). Basic error path testing. | Null, empty, boundary, overflow, negative, concurrent, and error cases all covered. Parametrize for boundary matrix. |
| Determinism | 10% | Uses time.time(), random(), or real network calls. Fails intermittently. | Mostly deterministic. Time frozen in most tests. Some flaky tests remain. | Fully reproducible on any machine. All time/random/network dependencies controlled. No flakiness. |
| Efficiency | 5% | Each test creates expensive resources from scratch. Full DB migration per test. Redundant setup. | Reasonable setup time. Some fixture reuse. | Session-scoped fixtures for expensive setup. Function-scoped for test isolation. Parallel-safe. Fast execution. |

## Scoring Process

1. Read each generated test file
2. Score each dimension 1-10 based on the criteria above
3. Calculate weighted average: `score = sum(dimension_score * weight)`
4. Round to one decimal place

## Pass / Fail

| Score | Verdict | Action |
|-------|---------|--------|
| 8-10 | PASS (Excellent) | Ship as-is |
| 7-7.9 | PASS (Acceptable) | Ship with minor notes |
| 5-6.9 | FAIL (Needs work) | Regenerate with specific feedback |
| 1-4.9 | FAIL (Poor) | Regenerate from scratch with different approach |

**PASS threshold: 7.0/10**

## Per-Dimension Scoring Guide

### Intent Alignment (25%)

Check each test against the Intent Map:
- Does the test name reference a specific behavior? (+1)
- Does the test verify a documented requirement? (+2)
- Does the test cover a P0 or P1 intent? (+2)
- Is there a clear traceability from test to intent? (+2)
- Are P0 intents all covered? (+3 if yes, -3 if any missing)

### Assertion Quality (20%)

Check assertions in each test:
- Are there actual assertions (not just "runs without error")? (+2)
- Do assertions check specific values, not just types? (+2)
- Are error messages checked, not just error types? (+1)
- Are side effects verified (DB writes, API calls, events)? (+2)
- Are boundary values tested with precision (pytest.approx)? (+1)
- Do assertions cover the full response, not just one field? (+2)

### Isolation (15%)

Check for independence:
- Does each test use its own fixtures (no shared mutable state)? (+3)
- Are external services mocked? (+2)
- Is database state rolled back after each test? (+2)
- Can tests run in any order? (+2)
- Can tests run in parallel without conflict? (+1)

### Readability (10%)

Check code quality:
- Do test names describe the behavior being tested? (+3)
- Is the AAA pattern clearly visible? (+2)
- Is there minimal duplication (parametrize used where appropriate)? (+2)
- Are fixtures clearly named and documented? (+1)
- Is the test file well-organized (related tests grouped)? (+2)

### Edge Cases (15%)

Check coverage:
- Null/None inputs tested? (+2)
- Empty string/list inputs tested? (+2)
- Boundary values tested (0, 1, max, min)? (+2)
- Invalid input types tested? (+1)
- Error paths tested (service failures, network errors)? (+2)
- Concurrent access tested (if applicable)? (+1)

### Determinism (10%)

Check for flakiness sources:
- No real time dependencies (frozen or mocked)? (+3)
- No random values without seeding? (+2)
- No real network calls? (+2)
- No file system dependencies on specific paths? (+1)
- No sleep-based waits? (+2)

### Efficiency (5%)

Check resource usage:
- Expensive setup shared via session/module fixtures? (+3)
- No redundant object creation between tests? (+2)
- Test execution is fast (< 1s per unit test, < 10s per integration)? (+3)
- Fixtures clean up after themselves? (+2)

## Report Format

```
TEST QUALITY REVIEW
===================
File: tests/test_organizations.py
Tests reviewed: 12

Dimension Scores:
  Intent Alignment:  8/10 (25%) = 2.00
  Assertion Quality: 7/10 (20%) = 1.40
  Isolation:         9/10 (15%) = 1.35
  Readability:       8/10 (10%) = 0.80
  Edge Cases:        6/10 (15%) = 0.90
  Determinism:       9/10 (10%) = 0.90
  Efficiency:        8/10  (5%) = 0.40

Overall Score: 7.75/10 -- PASS

Notes:
- Edge cases: Missing null input tests for create_organization
- Assertion quality: test_update_org only checks status code, not response body
```
