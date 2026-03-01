# Testing Patterns -- Comprehensive Reference

Reference guide for backend and frontend test patterns. Use this when generating or evaluating tests.

## Universal Principles

### AAA Pattern (Arrange / Act / Assert)

Every test follows three phases:

```python
def test_create_organization():
    # Arrange -- set up preconditions
    org_data = {"name": "Test Org", "ein": "12-3456789"}

    # Act -- execute the behavior under test
    result = service.create_organization(org_data)

    # Assert -- verify the outcome
    assert result.id is not None
    assert result.name == "Test Org"
```

Never mix phases. If Act produces side effects, assert those too.

### Test Naming

Name tests to describe the behavior, not the implementation:

| Bad | Good |
|-----|------|
| `test_function` | `test_create_org_returns_id` |
| `test_error` | `test_create_org_rejects_duplicate_ein` |
| `test_method_1` | `test_update_org_preserves_existing_contacts` |
| `test_edge_case` | `test_create_org_with_empty_name_raises_validation` |

Pattern: `test_[action]_[condition]_[expected_outcome]`

### Test Independence

- Each test must pass when run alone and in any order
- Never rely on state from a previous test
- Use fixtures for shared setup, not shared mutable variables
- Clean up after yourself (database rollback, temp file deletion)

### Determinism

- No `time.time()`, `datetime.now()`, or `random()` without freezing/seeding
- No network calls to real services
- No file system reads from unpredictable locations
- No tests that depend on execution speed

## Python / pytest

### Fixtures

```python
import pytest
from httpx import ASGITransport, AsyncClient

@pytest.fixture
def organization_data():
    """Factory fixture for organization test data."""
    return {"name": "Acme Corp", "ein": "12-3456789", "type": "nonprofit"}

@pytest.fixture
async def db_session(engine):
    """Provide a transactional database session that rolls back after each test."""
    async with engine.begin() as conn:
        session = AsyncSession(bind=conn)
        yield session
        await conn.rollback()

@pytest.fixture
async def client(app):
    """Async HTTP client for API testing."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
```

### Fixture Scopes

| Scope | Lifetime | Use For |
|-------|----------|---------|
| `function` (default) | Per test | Most fixtures |
| `class` | Per test class | Shared class state |
| `module` | Per test file | Expensive setup shared across file |
| `session` | Entire test run | Database engine, event loop |

### Parametrize

Test multiple inputs with a single test function:

```python
@pytest.mark.parametrize("ein,valid", [
    ("12-3456789", True),
    ("123456789", False),
    ("", False),
    ("12-345678", False),
    ("12-34567890", False),
])
def test_validate_ein(ein, valid):
    assert validate_ein(ein) == valid
```

### Markers

```python
@pytest.mark.asyncio         # Async test
@pytest.mark.slow            # Skip with -m "not slow"
@pytest.mark.integration     # Requires external services
@pytest.mark.parametrize     # Multiple input sets
@pytest.mark.skip(reason="") # Skip unconditionally
@pytest.mark.xfail           # Expected to fail
```

### Conftest Hierarchy

```
tests/
  conftest.py          # Session-scoped: event loop, engine, app
  unit/
    conftest.py        # Module-scoped: mock services, factories
    test_services.py
  integration/
    conftest.py        # Module-scoped: real DB session, test client
    test_api.py
```

Each conftest.py provides fixtures for its directory and all subdirectories.

### Async Testing

```python
import pytest

@pytest.mark.asyncio
async def test_async_service(db_session):
    service = OrganizationService(db_session)
    result = await service.get_by_id(uuid4())
    assert result is None
```

Requires `pytest-asyncio`. Configure mode in `pyproject.toml`:
```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"  # or "strict"
```

### Mocking

```python
from unittest.mock import AsyncMock, MagicMock, patch

# Mock an external service
@pytest.fixture
def mock_llm_client():
    client = AsyncMock()
    client.generate.return_value = "Generated text"
    return client

# Patch at the point of use, not definition
@patch("src.services.writer.LLMClient")
async def test_writer_uses_llm(mock_cls, mock_llm_client):
    mock_cls.return_value = mock_llm_client
    writer = SectionWriter()
    result = await writer.write(section_data)
    mock_llm_client.generate.assert_called_once()

# Inline mock for simple cases
async def test_with_mock(monkeypatch):
    monkeypatch.setattr("src.config.SETTING", "test_value")
```

### Factory Pattern

```python
@pytest.fixture
def make_organization():
    """Factory that creates organizations with sensible defaults."""
    created = []

    def _make(**overrides):
        defaults = {
            "name": f"Test Org {len(created)}",
            "ein": f"12-{3456789 + len(created)}",
            "type": "nonprofit",
        }
        defaults.update(overrides)
        org = Organization(**defaults)
        created.append(org)
        return org

    return _make
```

## Database Testing

### Transaction Rollback Pattern

Every test runs in a transaction that rolls back after the test completes. No data persists between tests.

```python
@pytest.fixture
async def db_session(engine):
    conn = await engine.connect()
    trans = await conn.begin()
    session = AsyncSession(bind=conn)
    yield session
    await trans.rollback()
    await conn.close()
```

### Test Database

For integration tests, use a separate test database or schema:
```python
@pytest.fixture(scope="session")
async def engine():
    test_url = "postgresql+asyncpg://test:test@localhost:5434/gs_unified_test"
    engine = create_async_engine(test_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()
```

### Fixtures for Related Data

```python
@pytest.fixture
async def org_with_contacts(db_session, make_organization, make_contact):
    org = make_organization(name="Test Org")
    db_session.add(org)
    await db_session.flush()
    contacts = [make_contact(organization_id=org.id) for _ in range(3)]
    db_session.add_all(contacts)
    await db_session.flush()
    return org, contacts
```

## API Testing

### httpx AsyncClient

```python
@pytest.mark.asyncio
async def test_create_org_endpoint(client):
    response = await client.post("/api/v1/organizations", json={
        "name": "Test Org",
        "ein": "12-3456789",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Org"
    assert "id" in data

@pytest.mark.asyncio
async def test_create_org_duplicate_ein(client, existing_org):
    response = await client.post("/api/v1/organizations", json={
        "name": "Another Org",
        "ein": existing_org.ein,  # duplicate
    })
    assert response.status_code == 409

@pytest.mark.asyncio
async def test_get_org_not_found(client):
    response = await client.get(f"/api/v1/organizations/{uuid4()}")
    assert response.status_code == 404
```

### Auth Testing

```python
@pytest.fixture
def auth_headers(test_user):
    token = create_jwt(user_id=test_user.id, role="admin")
    return {"Authorization": f"Bearer {token}"}

async def test_protected_endpoint_no_auth(client):
    response = await client.get("/api/v1/admin/users")
    assert response.status_code == 401

async def test_protected_endpoint_wrong_role(client, viewer_headers):
    response = await client.get("/api/v1/admin/users", headers=viewer_headers)
    assert response.status_code == 403

async def test_protected_endpoint_authorized(client, auth_headers):
    response = await client.get("/api/v1/admin/users", headers=auth_headers)
    assert response.status_code == 200
```

## TypeScript / Playwright

### Page Object Model (POM)

```typescript
class DashboardPage {
  constructor(private page: Page) {}

  async navigate() {
    await this.page.goto('/dashboard');
  }

  async getProjectCount(): Promise<number> {
    const count = await this.page.locator('[data-testid="project-count"]').textContent();
    return parseInt(count ?? '0', 10);
  }

  async createProject(name: string) {
    await this.page.click('[data-testid="create-project"]');
    await this.page.fill('[data-testid="project-name"]', name);
    await this.page.click('[data-testid="submit"]');
  }
}
```

### Selectors (Priority Order)

1. `data-testid` -- most stable, explicitly for testing
2. `role` -- accessible, semantic
3. `text` -- user-visible, readable
4. `css` -- last resort, brittle

```typescript
// Prefer
page.getByTestId('submit-button');
page.getByRole('button', { name: 'Submit' });
page.getByText('Welcome back');

// Avoid
page.locator('.btn-primary-lg.mt-4');
page.locator('#app > div:nth-child(3) > button');
```

### Waits and Assertions

```typescript
// Wait for network
await page.waitForResponse(resp => resp.url().includes('/api/projects'));

// Wait for element
await expect(page.getByTestId('project-list')).toBeVisible();

// Wait for navigation
await page.waitForURL('/dashboard');

// Assertions
await expect(page.getByTestId('count')).toHaveText('5');
await expect(page.getByRole('alert')).not.toBeVisible();
```

### Test Isolation

```typescript
test.beforeEach(async ({ page }) => {
  // Reset state before each test
  await page.goto('/');
  await page.evaluate(() => localStorage.clear());
});
```

## Mocking -- When to Mock vs When Not To

### Mock When

- External API calls (LLM providers, payment gateways)
- Time-dependent operations (use `freezegun` / `vi.useFakeTimers`)
- Random number generation (seed or mock)
- File system operations in unit tests
- Email/SMS sending

### Do Not Mock When

- Testing your own code's internal interactions
- The real implementation is fast and deterministic
- You are writing integration tests (that is their purpose)
- The mock would be more complex than the real thing

### Mock Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Mocking the thing under test | Test proves nothing | Mock dependencies, not the subject |
| Over-mocking | Test is disconnected from reality | Mock only external boundaries |
| Mock returning mock | Fragile, hard to debug | Use concrete return values |
| Asserting mock internals | Tests implementation, not behavior | Assert on outputs and side effects |
| Not verifying mock calls | Miss broken interactions | Use `assert_called_with` / `toHaveBeenCalledWith` |
