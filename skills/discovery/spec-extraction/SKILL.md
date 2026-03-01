---
name: spec-extraction
description: "Extract testable specifications from documentation, docstrings, type hints, validation rules, and API schemas. Turns implicit behavior into explicit test requirements. Use when asked to 'extract specs', 'find specifications', 'what should be tested', 'extract requirements', 'find testable behaviors', or 'list all validations'."
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Spec Extraction

You are extracting testable specifications from a codebase. Your goal is to turn implicit behavior — buried in docstrings, type hints, validators, constraints, and schemas — into explicit, testable requirements.

## Target
$ARGUMENTS
(If no specific target given, extract specs from the entire project in the current working directory)

## Extraction Sources

Work through each source systematically. For every spec you find, record it with its source location.

### 1. Docstrings

Search for docstrings in all code files:

```bash
# Python — Google style, NumPy style, RST
grep -rn '"""' --include="*.py" -l .
```

For each function/class with a docstring, extract:
- **Behavior descriptions**: "Returns X when Y", "Raises Z if W"
- **Parameter constraints**: "must be positive", "cannot be empty"
- **Return value specs**: "returns None if not found", "returns list sorted by date"
- **Side effects**: "creates a record in the database", "sends an email"
- **Preconditions**: "requires authentication", "user must have admin role"

Docstring formats to parse:

**Google style:**
```python
def func(x: int) -> str:
    """Convert integer to string.

    Args:
        x: Must be non-negative.

    Returns:
        String representation, zero-padded to 3 digits.

    Raises:
        ValueError: If x is negative.
    """
```

**NumPy style:**
```python
def func(x):
    """Convert integer to string.

    Parameters
    ----------
    x : int
        Must be non-negative.

    Returns
    -------
    str
        Zero-padded to 3 digits.
    """
```

### 2. Type Hints and Return Types

```bash
grep -rn "def .*->.*:" --include="*.py" .
```

Extract specs from types:
- `-> Optional[X]` → can return None (test both paths)
- `-> list[X]` → can return empty list (test empty case)
- `Union[X, Y]` → multiple return types (test each)
- `Literal["a", "b"]` → only these values valid
- `int` vs `float` → precision matters

### 3. Pydantic Validators and Field Constraints

```bash
grep -rn "Field(\|validator\|field_validator\|model_validator\|@validate" --include="*.py" .
```

Extract from Pydantic models:
- `Field(min_length=1)` → empty string invalid
- `Field(ge=0, le=100)` → boundary conditions at 0, 100, -1, 101
- `Field(pattern=r"...")` → regex validation
- `Field(default=X)` → default value behavior
- `@field_validator` → custom validation logic (read the function)
- `@model_validator(mode="before")` → pre-processing rules
- `@model_validator(mode="after")` → cross-field validation

### 4. OpenAPI / Swagger Schemas

```bash
# FastAPI auto-generates from Pydantic models
# Look for manually defined schemas too
find . -name "openapi*" -o -name "swagger*" | grep -v node_modules
```

For FastAPI projects, the schema is derived from route signatures and Pydantic models. Extract:
- Required vs optional parameters
- Query parameter constraints
- Path parameter types
- Request body structure
- Response status codes and schemas
- Error response formats

### 5. Database Constraints

```bash
# SQLAlchemy models
grep -rn "Column\|ForeignKey\|UniqueConstraint\|CheckConstraint\|nullable\|unique\|index" --include="*.py" .

# Alembic migrations
grep -rn "op\.\(add_column\|create_table\|create_index\|create_unique_constraint\|create_check_constraint\)" --include="*.py" .
```

Extract:
- `nullable=False` → NULL not allowed (test with None)
- `unique=True` → duplicates rejected (test duplicate insert)
- `ForeignKey(...)` → referential integrity (test orphan prevention)
- `CheckConstraint(...)` → custom DB-level rules
- `server_default=...` → default value behavior
- `Index(...)` → performance assumptions (existence, not behavior)
- Cascade rules: `ondelete="CASCADE"` vs `"SET NULL"` vs `"RESTRICT"`

### 6. Error Handling Patterns

```bash
# What errors are raised
grep -rn "raise \|HTTPException\|abort(" --include="*.py" .

# What errors are caught
grep -rn "except \|catch " --include="*.py" --include="*.ts" .
```

For each error raised, extract:
- What condition triggers it
- What error type/status code
- What message/detail is returned
- Whether it is tested

### 7. Configuration Defaults and Ranges

```bash
grep -rn "class.*Settings.*BaseSettings\|environ\|getenv\|env_file" --include="*.py" .
```

Extract:
- Required environment variables (no default → must be set)
- Default values (behavior when not configured)
- Valid ranges for numeric settings
- Enum-like settings with specific valid values

### 8. Decorator-Based Specs

```bash
grep -rn "@.*require\|@.*permission\|@.*rate_limit\|@.*cache\|@.*retry\|@.*deprecated" --include="*.py" .
```

Extract:
- `@require_auth` → authentication required
- `@require_permission("admin")` → specific role needed
- `@rate_limit(100, "minute")` → rate limiting behavior
- `@cache(ttl=300)` → caching behavior
- `@retry(max_attempts=3)` → retry behavior

## Output Format

Write specs to `extracted-specs.json` in the project root:

```json
{
  "specs": [
    {
      "id": "spec-001",
      "module": "<module path>",
      "function": "<function name>",
      "source_file": "<file:line>",
      "source_type": "docstring|type_hint|validator|constraint|schema|error_handler|config|decorator",
      "description": "<what should happen>",
      "test_type": "unit|integration|e2e",
      "priority": "critical|high|medium|low",
      "test_cases": [
        {
          "scenario": "<description>",
          "input": "<example input>",
          "expected": "<expected outcome>",
          "edge_case": true
        }
      ]
    }
  ],
  "stats": {
    "total_specs": 0,
    "by_source": {
      "docstring": 0,
      "type_hint": 0,
      "validator": 0,
      "constraint": 0,
      "schema": 0,
      "error_handler": 0,
      "config": 0,
      "decorator": 0
    },
    "by_priority": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0
    }
  }
}
```

## Boundary Condition Generation

For every numeric constraint found, automatically generate boundary test cases:

| Constraint | Test Values |
|-----------|-------------|
| `ge=0` | -1 (reject), 0 (accept), 1 (accept) |
| `le=100` | 99 (accept), 100 (accept), 101 (reject) |
| `min_length=1` | "" (reject), "a" (accept) |
| `max_length=255` | "a"*255 (accept), "a"*256 (reject) |
| `pattern=r"^\d{3}$"` | "123" (accept), "12" (reject), "1234" (reject), "abc" (reject) |

## Rules

- Every spec must reference a source location (file:line)
- Do not invent specs — only extract what is explicitly stated or strongly implied by code
- When a validator contains complex logic, read the full function and extract each condition
- Group related specs by module for easier test planning
- Flag specs that contradict each other (e.g., docstring says one thing, type hint says another)
- Distinguish between "what the code does" and "what it should do" — prefer documented intent over implementation
