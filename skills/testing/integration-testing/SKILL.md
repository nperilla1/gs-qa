---
name: integration-testing
description: "Write integration tests that verify cross-service interactions, workflow pipelines, and end-to-end data flow. Tests the boundaries between components. Use when asked to 'test integration', 'test workflow', 'test pipeline', 'integration tests', 'test cross-service', or 'test data flow'."
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Integration Testing

You are writing integration tests that verify how components work together. Unlike unit tests (isolated) or E2E tests (full stack), integration tests focus on the boundaries between two or more components.

## Target
$ARGUMENTS
(If no specific target, write integration tests for cross-component interactions in the test plan)

## What to Integration Test

Integration tests verify the contracts between components:

- **API + Database**: Does the API actually persist and retrieve data correctly?
- **Service + External API**: Does the service handle real API responses (mocked at HTTP level)?
- **Workflow + Activities**: Does the orchestration call activities in the right order with the right data?
- **Queue Producer + Consumer**: Do messages serialize/deserialize correctly?
- **Auth + Protected Routes**: Do authenticated requests actually work end-to-end?

## Pre-Flight Checks

1. **Identify integration boundaries** in the project:
   ```bash
   # Find service/client files that cross boundaries
   grep -rn "httpx\|requests\|AsyncClient" --include="*.py" -l .
   grep -rn "fetch\|axios" --include="*.ts" -l .
   ```

2. **Check for existing integration tests**:
   ```bash
   find . -path "*/integration/*" -name "test_*" | sort
   find . -name "*integration*" -name "test_*" | sort
   ```

3. **Identify external dependencies**:
   ```bash
   grep -rn "docker-compose\|testcontainers" . --include="*.py" --include="*.toml" --include="*.yaml"
   ```

## Pattern: API + Database Integration

Test the full request lifecycle through the API to the database and back.

```python
"""Integration tests for the items API with real database."""
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.fixture
async def seeded_db(db_session):
    """Seed database with test data."""
    await db_session.execute(
        text("INSERT INTO items (id, name, status) VALUES (:id, :name, :status)"),
        {"id": "test-1", "name": "Existing Item", "status": "active"}
    )
    await db_session.commit()
    return db_session

class TestItemsAPIIntegration:
    """Test items API with real database operations."""

    async def test_create_then_retrieve(self, client, db_session):
        """Should persist item to DB and retrieve it."""
        # Create via API
        create_resp = await client.post("/api/v1/items", json={
            "name": "Integration Test Item",
            "description": "Created via integration test"
        })
        assert create_resp.status_code == 201
        item_id = create_resp.json()["id"]

        # Retrieve via API
        get_resp = await client.get(f"/api/v1/items/{item_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["name"] == "Integration Test Item"

        # Verify in database directly
        result = await db_session.execute(
            text("SELECT name FROM items WHERE id = :id"),
            {"id": item_id}
        )
        assert result.scalar() == "Integration Test Item"

    async def test_update_reflects_in_list(self, client, seeded_db):
        """Should reflect updates in list queries."""
        # Update
        await client.patch("/api/v1/items/test-1", json={"status": "archived"})

        # List should show updated status
        list_resp = await client.get("/api/v1/items?status=archived")
        items = list_resp.json()
        assert any(i["id"] == "test-1" for i in items)

    async def test_delete_cascades_to_related(self, client, seeded_db):
        """Should cascade delete to related records."""
        await client.delete("/api/v1/items/test-1")

        # Related records should also be gone
        result = await seeded_db.execute(
            text("SELECT count(*) FROM item_tags WHERE item_id = :id"),
            {"id": "test-1"}
        )
        assert result.scalar() == 0
```

## Pattern: Service + External API

Test that services correctly interact with external APIs, mocked at the HTTP transport level.

```python
"""Integration tests for the notification service with external API."""
import respx
from httpx import Response

@pytest.fixture
def mock_email_api():
    """Mock the email provider API at HTTP level."""
    with respx.mock:
        respx.post("https://api.sendgrid.com/v3/mail/send").mock(
            return_value=Response(202, json={"message_id": "sg-123"})
        )
        yield

@pytest.fixture
def mock_email_api_failure():
    """Mock email API returning errors."""
    with respx.mock:
        respx.post("https://api.sendgrid.com/v3/mail/send").mock(
            return_value=Response(429, json={"error": "rate limited"})
        )
        yield

class TestNotificationServiceIntegration:
    """Test notification service with mocked external APIs."""

    async def test_send_email_success(self, mock_email_api):
        """Should send email via provider and return message ID."""
        service = NotificationService()
        result = await service.send_email(
            to="user@test.com",
            subject="Test",
            body="Hello"
        )
        assert result.message_id == "sg-123"
        assert result.status == "sent"

    async def test_send_email_rate_limited_retries(self, mock_email_api_failure):
        """Should retry on rate limit and eventually raise."""
        service = NotificationService(max_retries=2)
        with pytest.raises(RateLimitError):
            await service.send_email(
                to="user@test.com",
                subject="Test",
                body="Hello"
            )
```

## Pattern: Workflow Pipeline

Test multi-step workflows to verify data flows correctly between steps.

```python
"""Integration tests for the grant analysis pipeline."""

class TestGrantAnalysisPipeline:
    """Test the NOFO analysis → strategy → writing pipeline."""

    async def test_analysis_feeds_strategy(self, db_session, mock_llm):
        """Analysis output should contain fields strategy needs."""
        # Run analysis
        analyzer = NofoAnalyzer(llm=mock_llm)
        analysis = await analyzer.analyze(nofo_text="Sample NOFO...")

        # Verify analysis has all fields strategy requires
        assert analysis.sections is not None
        assert len(analysis.sections) > 0
        assert all(s.requirements for s in analysis.sections)

        # Feed into strategy
        strategist = StrategyBuilder(llm=mock_llm)
        strategy = await strategist.build(analysis=analysis)

        # Strategy should reference analysis sections
        assert strategy.section_strategies is not None
        assert len(strategy.section_strategies) == len(analysis.sections)

    async def test_pipeline_persists_intermediate_results(self, db_session, mock_llm):
        """Each pipeline step should persist its output."""
        pipeline = GrantPipeline(db=db_session, llm=mock_llm)
        await pipeline.run_analysis(grant_id="test-grant")

        # Check intermediate results are in DB
        analysis = await db_session.execute(
            text("SELECT * FROM writer.grant_sections WHERE grant_instance_id = :id"),
            {"id": "test-grant"}
        )
        assert analysis.rowcount > 0
```

## Pattern: Authentication Integration

Test that auth middleware actually protects routes.

```python
"""Integration tests for authentication."""

class TestAuthIntegration:
    """Test auth middleware with real JWT handling."""

    async def test_protected_route_without_token_returns_401(self, client):
        """Should reject requests without auth token."""
        response = await client.get("/api/v1/protected")
        assert response.status_code == 401

    async def test_protected_route_with_expired_token_returns_401(self, client):
        """Should reject expired tokens."""
        expired_token = create_token(user_id="test", expires_delta=timedelta(seconds=-1))
        response = await client.get(
            "/api/v1/protected",
            headers={"Authorization": f"Bearer {expired_token}"}
        )
        assert response.status_code == 401

    async def test_protected_route_with_valid_token_returns_200(self, auth_client):
        """Should accept valid tokens."""
        response = await auth_client.get("/api/v1/protected")
        assert response.status_code == 200

    async def test_admin_route_with_user_role_returns_403(self, auth_client):
        """Should reject non-admin users from admin routes."""
        # auth_client has 'user' role by default
        response = await auth_client.get("/api/v1/admin/users")
        assert response.status_code == 403
```

## Pattern: Queue/Event Processing

Test that producers and consumers agree on message format.

```python
"""Integration tests for event processing."""

class TestEventProcessing:
    """Test event producer → consumer integration."""

    async def test_event_serialization_roundtrip(self):
        """Events should serialize and deserialize correctly."""
        original = UserCreatedEvent(
            user_id="123",
            email="test@test.com",
            created_at=datetime.utcnow()
        )

        # Serialize (as producer would)
        serialized = original.model_dump_json()

        # Deserialize (as consumer would)
        restored = UserCreatedEvent.model_validate_json(serialized)

        assert restored.user_id == original.user_id
        assert restored.email == original.email
        assert restored.created_at == original.created_at

    async def test_consumer_handles_event(self, event_bus):
        """Consumer should process events correctly."""
        handler = UserEventHandler(db=mock_db)
        event = UserCreatedEvent(user_id="123", email="test@test.com")

        await handler.handle(event)

        # Verify side effect
        mock_db.create_profile.assert_called_once_with(user_id="123")
```

## Test Data Management

### Seeding
```python
@pytest.fixture
async def seed_data(db_session):
    """Seed the database with a known state for integration tests."""
    # Use factories or raw SQL
    org = await OrganizationFactory.create(session=db_session, name="Test Org")
    grant = await GrantFactory.create(session=db_session, org=org)
    return {"org": org, "grant": grant}
```

### Cleanup
```python
@pytest.fixture(autouse=True)
async def cleanup(db_session):
    """Clean up after each test."""
    yield
    # Transaction rollback handles cleanup if using the rollback pattern
    # Otherwise, explicit cleanup:
    await db_session.execute(text("DELETE FROM items WHERE name LIKE 'test_%'"))
    await db_session.commit()
```

## Rules

- Integration tests are SLOWER than unit tests — that's expected
- Use real database sessions (with rollback), not mocks
- Mock external HTTP APIs at the transport level (respx, nock), not at the client level
- Test the contract between components, not internal implementation
- Each test should set up its own data — do not depend on shared state between tests
- Name files: `test_<component1>_<component2>_integration.py`
- Place in `tests/integration/` directory
- Mark with `@pytest.mark.integration` if the project uses markers for test categorization
