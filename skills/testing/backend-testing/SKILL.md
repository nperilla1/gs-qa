---
name: backend-testing
description: "Write backend tests using pytest. Covers unit tests, API endpoint tests, database tests, service tests, and async tests. Includes patterns for fixtures, factories, mocking, and parametrize. Use when asked to 'write backend tests', 'test API endpoint', 'test service', 'write pytest tests', 'unit test this', or 'test this function'."
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Backend Testing

You are writing backend tests using pytest. Follow these patterns and conventions to produce high-quality, maintainable tests.

## Target
$ARGUMENTS
(If no specific target, write tests for the modules specified in test-plan.json)

## Pre-Flight Checks

Before writing any tests:

1. **Read existing conftest.py files** to understand the fixture hierarchy:
   ```bash
   find <project_root> -name "conftest.py" | sort
   ```

2. **Read existing tests** to match conventions:
   ```bash
   find <project_root>/tests -name "test_*.py" | head -10
   ```

3. **Check pyproject.toml** for pytest configuration:
   ```bash
   grep -A 20 "\[tool.pytest" <project_root>/pyproject.toml
   ```

4. **Identify test dependencies** already installed:
   ```bash
   grep -E "pytest|httpx|respx|factory|faker" <project_root>/pyproject.toml
   ```

## Test File Structure

Every test file follows this structure:

```python
"""Tests for <module_name>.

Tests cover: <brief description of what behaviors are tested>
"""
from __future__ import annotations

import pytest
# Standard library imports
# Third-party test imports (httpx, respx, factory_boy)
# Application imports

# === Fixtures (if not in conftest.py) ===

@pytest.fixture
def sample_data():
    """Provide sample data for tests."""
    return {...}

# === Unit Tests ===

class TestClassName:
    """Tests for ClassName."""

    def test_behavior_scenario_expected(self):
        """Should <expected behavior> when <scenario>."""
        # Arrange
        ...
        # Act
        result = ...
        # Assert
        assert result == expected

    def test_behavior_edge_case(self):
        """Should <handle edge case>."""
        ...

# === Parametrized Tests ===

@pytest.mark.parametrize("input_val,expected", [
    ("valid_input", "expected_output"),
    ("edge_case", "edge_output"),
])
def test_behavior_multiple_cases(input_val, expected):
    """Should produce correct output for various inputs."""
    result = function_under_test(input_val)
    assert result == expected
```

## Naming Convention

```
test_<behavior>_<scenario>_<expected>
```

Examples:
- `test_create_user_valid_data_returns_user`
- `test_create_user_duplicate_email_raises_conflict`
- `test_get_user_not_found_returns_none`
- `test_delete_user_with_projects_cascades`

## Fixture Patterns

### conftest.py Hierarchy

```
tests/
├── conftest.py          # Shared: db session, test client, auth fixtures
├── unit/
│   ├── conftest.py      # Unit-specific: mocks, stubs
│   └── test_service.py
├── integration/
│   ├── conftest.py      # Integration-specific: real db, seeded data
│   └── test_api.py
```

### Common Fixtures

```python
# Database session (async)
@pytest.fixture
async def db_session():
    """Provide a test database session with rollback."""
    async with async_session() as session:
        async with session.begin():
            yield session
            await session.rollback()

# FastAPI test client (async)
@pytest.fixture
async def client(db_session):
    """Provide an async test client."""
    from httpx import AsyncClient, ASGITransport
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

# Authenticated client
@pytest.fixture
async def auth_client(client):
    """Provide an authenticated test client."""
    token = create_test_token(user_id="test-user")
    client.headers["Authorization"] = f"Bearer {token}"
    return client
```

## API Endpoint Testing

### FastAPI with httpx AsyncClient

```python
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

class TestCreateEndpoint:
    """Tests for POST /api/v1/items."""

    async def test_create_valid_returns_201(self, client):
        """Should create item and return 201."""
        response = await client.post("/api/v1/items", json={
            "name": "Test Item",
            "quantity": 5
        })
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test Item"
        assert "id" in data

    async def test_create_missing_required_field_returns_422(self, client):
        """Should return 422 when required field is missing."""
        response = await client.post("/api/v1/items", json={
            "quantity": 5
            # name is missing
        })
        assert response.status_code == 422

    async def test_create_unauthorized_returns_401(self, client):
        """Should return 401 without auth token."""
        # client has no auth header
        response = await client.post("/api/v1/items", json={"name": "Test"})
        assert response.status_code == 401
```

## Mocking External Services

### RESPX for HTTP calls

```python
import respx
from httpx import Response

@pytest.fixture
def mock_external_api():
    """Mock external API calls."""
    with respx.mock:
        respx.get("https://api.example.com/data").mock(
            return_value=Response(200, json={"result": "ok"})
        )
        yield

async def test_service_calls_external_api(mock_external_api):
    """Should call external API and process response."""
    result = await my_service.fetch_data()
    assert result == "ok"
```

### unittest.mock for internal dependencies

```python
from unittest.mock import AsyncMock, patch, MagicMock

async def test_service_with_mocked_repo():
    """Should use repository to fetch data."""
    mock_repo = AsyncMock()
    mock_repo.get_by_id.return_value = {"id": "123", "name": "Test"}

    service = MyService(repo=mock_repo)
    result = await service.get_item("123")

    mock_repo.get_by_id.assert_called_once_with("123")
    assert result["name"] == "Test"
```

## Database Testing

### Transaction Rollback Pattern

```python
@pytest.fixture
async def db_session(async_engine):
    """Each test gets its own transaction that rolls back."""
    async with async_engine.connect() as conn:
        trans = await conn.begin()
        session = AsyncSession(bind=conn)
        yield session
        await trans.rollback()
```

### Testing CRUD Operations

```python
class TestUserRepository:
    """Tests for UserRepository CRUD operations."""

    async def test_create_persists_user(self, db_session):
        repo = UserRepository(db_session)
        user = await repo.create(name="Alice", email="alice@test.com")
        assert user.id is not None
        assert user.name == "Alice"

    async def test_create_duplicate_email_raises(self, db_session):
        repo = UserRepository(db_session)
        await repo.create(name="Alice", email="alice@test.com")
        with pytest.raises(IntegrityError):
            await repo.create(name="Bob", email="alice@test.com")

    async def test_get_nonexistent_returns_none(self, db_session):
        repo = UserRepository(db_session)
        result = await repo.get_by_id(uuid4())
        assert result is None
```

## Async Testing

```python
import pytest

# Mark individual tests
@pytest.mark.asyncio
async def test_async_function():
    result = await my_async_function()
    assert result is not None

# Or mark entire class
@pytest.mark.asyncio
class TestAsyncService:
    async def test_method(self):
        ...
```

If the project uses `pytest-asyncio` with `mode = "auto"` in pyproject.toml, no marks are needed.

## Parametrize Patterns

### Basic Parametrize
```python
@pytest.mark.parametrize("input_val,expected", [
    (0, "zero"),
    (1, "one"),
    (-1, "negative"),
    (999, "large"),
])
def test_classify_number(input_val, expected):
    assert classify(input_val) == expected
```

### Parametrize with IDs
```python
@pytest.mark.parametrize("email,valid", [
    ("user@example.com", True),
    ("user@.com", False),
    ("", False),
    ("user@example", False),
], ids=["valid_email", "missing_domain", "empty", "no_tld"])
def test_email_validation(email, valid):
    assert is_valid_email(email) == valid
```

### Parametrize Error Cases
```python
@pytest.mark.parametrize("bad_input,error_type", [
    (None, TypeError),
    (-1, ValueError),
    ("", ValueError),
    (float("inf"), OverflowError),
])
def test_process_rejects_bad_input(bad_input, error_type):
    with pytest.raises(error_type):
        process(bad_input)
```

## Test Quality Checklist

Before finishing each test file, verify:

- [ ] Each test has a descriptive docstring
- [ ] Tests follow Arrange-Act-Assert pattern
- [ ] No hardcoded magic values without explanation
- [ ] Fixtures are used for shared setup
- [ ] Edge cases are covered (empty, None, boundary values)
- [ ] Error paths are tested (what SHOULD fail)
- [ ] Tests are independent (no test depends on another's side effects)
- [ ] Async tests are properly marked
- [ ] No external network calls without mocking
- [ ] Test names describe behavior, not implementation

## Rules

- Match existing project conventions — read existing tests first
- Use fixtures from conftest.py — do not duplicate them
- Each test should test ONE behavior
- Tests must be deterministic — no random data without seeding
- Use `pytest.raises` for expected exceptions, not try/except
- Prefer `assert result == expected` over `assertTrue(result == expected)`
- Do not test private methods directly — test through public interface
- If a function is hard to test, that's a design smell — note it, don't work around it
