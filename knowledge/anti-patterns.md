# Test Anti-Patterns

Patterns to avoid when writing or reviewing tests. Each anti-pattern includes what it looks like, why it is harmful, and how to fix it.

## 1. Tautological Tests (Always Pass)

**What it looks like:**
```python
def test_organization_exists():
    org = Organization(name="Test")
    assert org is not None  # This can never be None
```

**Why it is harmful:** Test passes regardless of whether the code works. It gives false confidence.

**Fix:** Assert on specific behavior, not existence:
```python
def test_organization_stores_name():
    org = Organization(name="Test")
    assert org.name == "Test"
```

## 2. Testing the Mock

**What it looks like:**
```python
def test_send_email(mock_email_service):
    mock_email_service.send.return_value = True
    result = mock_email_service.send("test@example.com", "Hello")
    assert result is True  # Testing the mock's return value
```

**Why it is harmful:** You proved the mock works, not your code. The real `send()` method is never invoked.

**Fix:** Mock the dependency, test your code:
```python
def test_notification_sends_email(mock_email_service):
    notifier = Notifier(email_service=mock_email_service)
    notifier.notify_user(user_id="123", message="Hello")
    mock_email_service.send.assert_called_once_with("user@example.com", "Hello")
```

## 3. Overly Specific Tests (Brittle)

**What it looks like:**
```python
def test_format_output():
    result = format_report(data)
    assert result == "Report: Acme Corp\n  Revenue: $1,000,000\n  Employees: 50\n"
```

**Why it is harmful:** Any formatting change (extra space, newline) breaks the test, even if the output is semantically correct.

**Fix:** Assert on structure, not exact strings:
```python
def test_format_output():
    result = format_report(data)
    assert "Acme Corp" in result
    assert "$1,000,000" in result
    assert "50" in result
```

## 4. Sleep-Based Waits (Flaky)

**What it looks like:**
```python
async def test_background_job():
    await trigger_job()
    await asyncio.sleep(5)  # Hope the job finished
    result = await get_job_result()
    assert result.status == "completed"
```

**Why it is harmful:** Passes on fast machines, fails on slow ones. Wastes time on fast machines.

**Fix:** Poll with timeout, or use event-based synchronization:
```python
async def test_background_job():
    await trigger_job()
    result = await poll_until(
        lambda: get_job_result(),
        condition=lambda r: r.status == "completed",
        timeout=10,
        interval=0.1,
    )
    assert result.status == "completed"
```

## 5. Tests Without Assertions

**What it looks like:**
```python
def test_process_data():
    data = load_test_data()
    process(data)
    # No assertion -- just checking it doesn't crash
```

**Why it is harmful:** Only catches crashes, misses wrong results. The function could return garbage and the test passes.

**Fix:** Assert on the expected outcome:
```python
def test_process_data():
    data = load_test_data()
    result = process(data)
    assert result.processed_count == len(data)
    assert all(item.status == "processed" for item in result.items)
```

## 6. Order-Dependent Tests

**What it looks like:**
```python
class TestUserWorkflow:
    user_id = None

    def test_1_create_user(self, db):
        user = create_user(db, name="Test")
        TestUserWorkflow.user_id = user.id  # Shared state

    def test_2_get_user(self, db):
        user = get_user(db, TestUserWorkflow.user_id)  # Depends on test_1
        assert user.name == "Test"
```

**Why it is harmful:** test_2 fails if test_1 is skipped, filtered, or runs in a different order.

**Fix:** Each test sets up its own data:
```python
def test_create_user(db):
    user = create_user(db, name="Test")
    assert user.id is not None

def test_get_user(db, make_user):
    user = make_user(name="Test")
    retrieved = get_user(db, user.id)
    assert retrieved.name == "Test"
```

## 7. Shared Mutable State

**What it looks like:**
```python
test_data = []  # Module-level mutable state

def test_add_item():
    test_data.append("item1")
    assert len(test_data) == 1

def test_add_another():
    test_data.append("item2")
    assert len(test_data) == 1  # FAILS: test_data has 2 items now
```

**Why it is harmful:** Tests pollute each other. Results depend on execution order.

**Fix:** Use fixtures for per-test state:
```python
@pytest.fixture
def test_data():
    return []

def test_add_item(test_data):
    test_data.append("item1")
    assert len(test_data) == 1

def test_add_another(test_data):
    test_data.append("item2")
    assert len(test_data) == 1  # PASSES: fresh list each time
```

## 8. Testing Implementation Details

**What it looks like:**
```python
def test_sort_uses_quicksort():
    with patch("module.quicksort") as mock_qs:
        sort_data([3, 1, 2])
        mock_qs.assert_called_once()
```

**Why it is harmful:** Test breaks if you switch to mergesort, even though the behavior (sorted output) is identical.

**Fix:** Test the behavior, not the mechanism:
```python
def test_sort_returns_sorted_data():
    result = sort_data([3, 1, 2])
    assert result == [1, 2, 3]
```

## 9. Ignoring Edge Cases

**What it looks like:**
```python
def test_divide():
    assert divide(10, 2) == 5
    assert divide(9, 3) == 3
    # Missing: divide(1, 0), divide(0, 5), divide(-1, 2), divide(MAX_INT, 1)
```

**Why it is harmful:** Happy path works, but production data includes edge cases.

**Fix:** Test boundaries explicitly:
```python
@pytest.mark.parametrize("a,b,expected", [
    (10, 2, 5),        # normal
    (0, 5, 0),         # zero numerator
    (-10, 2, -5),      # negative
    (1, 3, 0.333...),  # non-integer result
])
def test_divide(a, b, expected):
    assert divide(a, b) == pytest.approx(expected)

def test_divide_by_zero():
    with pytest.raises(ZeroDivisionError):
        divide(1, 0)
```

## 10. Hitting Real External Services

**What it looks like:**
```python
async def test_get_weather():
    result = await weather_api.get("New York")  # Real HTTP call
    assert result.temperature > -50
```

**Why it is harmful:** Slow, flaky (network issues), costs money (API calls), non-deterministic (weather changes).

**Fix:** Mock the external service:
```python
async def test_get_weather(mock_weather_api):
    mock_weather_api.get.return_value = WeatherResponse(temperature=72)
    service = WeatherService(api=mock_weather_api)
    result = await service.get_weather("New York")
    assert result.temperature == 72
```

## 11. Snapshot Testing Overuse

**What it looks like:**
```python
def test_api_response(snapshot):
    response = client.get("/api/organizations")
    assert response.json() == snapshot  # 500-line JSON snapshot
```

**Why it is harmful:** Any change requires updating the snapshot. Reviewers cannot tell if the change is intentional or a bug. Snapshots grow stale.

**Fix:** Assert on specific properties. Reserve snapshots for genuinely complex outputs (rendered HTML, serialized configs) that are hard to assert piecewise:
```python
def test_api_response():
    response = client.get("/api/organizations")
    data = response.json()
    assert len(data["items"]) == 5
    assert all("id" in item for item in data["items"])
    assert data["total"] == 5
```

## 12. Copy-Paste Tests

**What it looks like:**
```python
def test_create_org_nonprofit():
    org = create_org(name="A", type="nonprofit")
    assert org.type == "nonprofit"
    assert org.id is not None

def test_create_org_forprofit():
    org = create_org(name="B", type="forprofit")
    assert org.type == "forprofit"
    assert org.id is not None

def test_create_org_government():
    org = create_org(name="C", type="government")
    assert org.type == "government"
    assert org.id is not None
```

**Why it is harmful:** Duplicated logic. If the assertion needs updating, you must change N places.

**Fix:** Use parametrize or factory fixtures:
```python
@pytest.mark.parametrize("org_type", ["nonprofit", "forprofit", "government"])
def test_create_org_with_type(org_type):
    org = create_org(name="Test", type=org_type)
    assert org.type == org_type
    assert org.id is not None
```

## 13. Giant Test Functions

**What it looks like:**
A single test function that is 100+ lines long, testing multiple behaviors at once.

**Why it is harmful:** When it fails, you cannot tell which behavior is broken. It is hard to read, maintain, and debug.

**Fix:** Split into focused tests, each testing one behavior. Use fixtures for shared setup.

## 14. Conditional Logic in Tests

**What it looks like:**
```python
def test_process(data):
    result = process(data)
    if data.type == "A":
        assert result.value == 1
    elif data.type == "B":
        assert result.value == 2
```

**Why it is harmful:** The test has its own logic that could have bugs. Which branch ran?

**Fix:** Separate tests or parametrize:
```python
@pytest.mark.parametrize("data_type,expected", [("A", 1), ("B", 2)])
def test_process(data_type, expected):
    data = make_data(type=data_type)
    result = process(data)
    assert result.value == expected
```

## Quick Reference: Smell -> Fix

| Smell | Likely Anti-Pattern | Fix |
|-------|-------------------|-----|
| Test always passes | Tautological | Assert specific behavior |
| Test breaks on refactor | Implementation testing or brittle | Test behavior, not mechanism |
| Test is flaky | Sleep, external service, shared state | Mock, poll, isolate |
| Test is 100+ lines | Giant function | Split into focused tests |
| Test file has copy-paste | Duplication | Parametrize or factory |
| Test has if/else | Conditional logic | Parametrize |
| Test setup is longer than assertions | Too much arrangement | Extract to fixtures |
| Test name is "test_1", "test_2" | No behavioral description | Name after behavior |
