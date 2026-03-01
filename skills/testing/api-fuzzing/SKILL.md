---
name: api-fuzzing
description: "Fuzz-test API endpoints using Schemathesis to find crashes, validation bypasses, and edge cases automatically from OpenAPI/Swagger specs. Use when asked to 'fuzz API', 'test API edge cases', 'schemathesis', 'api fuzzing', 'property based testing API', or 'find API crashes'."
allowed-tools: Read, Grep, Glob, Bash, Write
---

# API Fuzzing

You are running automated fuzz testing against API endpoints using Schemathesis. This tool generates hundreds of test cases from the OpenAPI schema to find crashes, validation bypasses, and edge cases that manual testing misses.

## Target
$ARGUMENTS
(If no specific target, fuzz all endpoints discovered from the OpenAPI schema)

## Phase 1: Locate the OpenAPI Schema

### FastAPI (auto-generated)
```bash
# FastAPI serves OpenAPI at /openapi.json by default
# Find the FastAPI app to determine the base URL
grep -rn "FastAPI()" --include="*.py" .
grep -rn "app = FastAPI" --include="*.py" .
```

The schema URL is typically: `http://localhost:<port>/openapi.json`

### Manual Schema Files
```bash
# Look for static schema files
find . -name "openapi*" -o -name "swagger*" | grep -v node_modules
```

### Express/NestJS
```bash
# Look for swagger setup
grep -rn "swagger\|openapi" --include="*.ts" --include="*.js" -l .
```

## Phase 2: Install and Verify Schemathesis

```bash
# Check if installed
schemathesis --version 2>/dev/null || pip install schemathesis

# Verify it can parse the schema
schemathesis run --dry-run <schema_url_or_path>
```

## Phase 3: Start the Application

The API must be running for fuzz testing. Check if it's already running:

```bash
# Check if the port is in use
lsof -i :<port> 2>/dev/null
```

If not running:
```bash
# Python/FastAPI
cd <project_root> && python -m uvicorn <app_module>:app --port <port> &
APP_PID=$!

# Wait for startup
sleep 3
curl -s http://localhost:<port>/openapi.json > /dev/null && echo "App ready"
```

## Phase 4: Run Schemathesis

### Basic Fuzzing (all endpoints)
```bash
schemathesis run http://localhost:<port>/openapi.json \
  --checks all \
  --stateful=links \
  --max-response-time=5000 \
  --hypothesis-max-examples=100 \
  2>&1 | tee /tmp/schemathesis-results.txt
```

### Targeted Fuzzing (specific endpoints)
```bash
schemathesis run http://localhost:<port>/openapi.json \
  --endpoint="/api/v1/items" \
  --checks all \
  --hypothesis-max-examples=200 \
  2>&1
```

### With Authentication
```bash
schemathesis run http://localhost:<port>/openapi.json \
  --header="Authorization: Bearer <test_token>" \
  --checks all \
  2>&1
```

### Schemathesis Checks

| Check | What It Detects |
|-------|----------------|
| `not_a_server_error` | 500 responses (crashes) |
| `status_code_conformance` | Undocumented status codes |
| `content_type_conformance` | Wrong content-type headers |
| `response_schema_conformance` | Response doesn't match schema |
| `response_headers_conformance` | Missing required headers |
| `use_after_free` | Stateful: deleted resources still accessible |
| `ensure_resource_availability` | Stateful: created resources not accessible |

## Phase 5: Analyze Results

Parse Schemathesis output and categorize findings:

### Server Errors (CRITICAL)
Any 500 response is a crash. Extract:
- The endpoint and method
- The request payload that caused it
- The error message (if returned)

### Validation Bypasses (HIGH)
Cases where invalid data was accepted:
- Required fields omitted but request succeeded
- Out-of-range values accepted
- Wrong types accepted (string where int expected)
- Oversized payloads accepted

### Schema Mismatches (MEDIUM)
Response doesn't match the documented schema:
- Extra fields in response
- Missing fields in response
- Wrong types in response
- Missing required response headers

### Performance Issues (LOW)
Endpoints that exceed response time thresholds:
- Responses over 5 seconds
- Endpoints that slow down under varied input

## Phase 6: Generate Reproducible Test Cases

For each finding, create a reproducible test case:

```python
"""Regression tests generated from Schemathesis fuzzing."""
import pytest
from httpx import AsyncClient

class TestFuzzFindings:
    """Tests for issues discovered by API fuzzing."""

    async def test_items_post_empty_name_returns_422(self, client):
        """Fuzz finding: empty name was accepted (should be rejected).

        Found by Schemathesis run on 2026-03-01.
        """
        response = await client.post("/api/v1/items", json={
            "name": "",
            "quantity": 1
        })
        assert response.status_code == 422  # Was returning 201

    async def test_items_post_negative_quantity_returns_422(self, client):
        """Fuzz finding: negative quantity caused 500 error.

        Found by Schemathesis run on 2026-03-01.
        """
        response = await client.post("/api/v1/items", json={
            "name": "Test",
            "quantity": -1
        })
        assert response.status_code == 422  # Was returning 500

    async def test_items_get_oversized_limit_handled(self, client):
        """Fuzz finding: limit=999999999 caused OOM.

        Found by Schemathesis run on 2026-03-01.
        """
        response = await client.get("/api/v1/items?limit=999999999")
        assert response.status_code in (200, 422)  # Should cap or reject
```

## Phase 7: Report

Output a fuzzing report:

```
## API Fuzzing Report

### Summary
- Endpoints tested: N
- Test cases generated: N
- Findings: N (X critical, Y high, Z medium)

### Critical Findings (Server Errors)
1. [CRITICAL] POST /api/v1/items — 500 when name is null
   - Payload: {"name": null, "quantity": 1}
   - Response: 500 Internal Server Error

### High Findings (Validation Bypasses)
1. [HIGH] POST /api/v1/items — Accepts empty string for name
   - Payload: {"name": "", "quantity": 1}
   - Response: 201 Created (expected 422)

### Medium Findings (Schema Mismatches)
1. [MEDIUM] GET /api/v1/items — Response missing "total" field
   - Schema says required, but not present in response

### Regression Tests Generated
- <file path>: N tests covering N findings
```

## Cleanup

```bash
# Stop the application if we started it
kill $APP_PID 2>/dev/null
```

## Rules

- Always start with `--dry-run` to verify the schema parses correctly
- Use `--hypothesis-max-examples=100` for initial runs, increase for thorough testing
- Never fuzz production endpoints — only local or staging
- Create reproducible test cases for every finding
- Categorize findings by severity: CRITICAL (crashes) > HIGH (bypasses) > MEDIUM (mismatches) > LOW (performance)
- If the API requires authentication, provide a valid test token
- Stop the application after testing if you started it
