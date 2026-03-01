# Intent Discovery Guide

How to extract testable intent from any codebase. Intent is what the code SHOULD do -- the contract it promises to fulfill -- as opposed to what it currently DOES do (which may include bugs).

## What Is Intent?

Intent is the answer to: "If this code works correctly, what should happen?"

Sources of intent, ranked by confidence:

| Rank | Source | Confidence | Why |
|------|--------|------------|-----|
| 1 | CLAUDE.md / README | High | Explicit requirements written by developers |
| 2 | API specifications (OpenAPI, GraphQL schema) | High | Formal contracts |
| 3 | Type signatures + Pydantic schemas | High | Compiler-enforced constraints |
| 4 | Existing passing tests | High | Behaviors someone explicitly verified |
| 5 | Database schema + migrations | High | Data invariants |
| 6 | Docstrings and inline comments | Medium | Developer annotations (may be stale) |
| 7 | Validation logic | Medium | Business rules encoded in code |
| 8 | Error handling | Medium | Expected failure modes |
| 9 | Configuration / env vars | Medium | Behavioral switches |
| 10 | Code structure and naming | Low | Implicit intent from naming conventions |
| 11 | Git commit messages | Low | Historical intent (may be outdated) |

## Reading CLAUDE.md and README

These are the highest-confidence sources. Extract:

1. **Feature descriptions**: "The system does X" -> test that X works
2. **Architecture decisions**: "We use repository pattern" -> test repo interface contracts
3. **Known gotchas**: "pgvector returns embeddings as strings" -> test serialization
4. **Workflow descriptions**: "NOFO analysis -> strategy -> writing" -> test the chain
5. **Data model invariants**: "Grant instance is shared, project instance is per-org" -> test isolation
6. **Performance requirements**: "Must handle 22K organizations" -> test with load

## Extracting Intent from Code

### FastAPI Routes

```python
@router.post("/organizations", status_code=201, response_model=OrganizationResponse)
async def create_organization(data: CreateOrganizationRequest, db: AsyncSession = Depends(get_db)):
```

Intents extracted:
- INT: POST /organizations returns 201 on success
- INT: Response matches OrganizationResponse schema
- INT: Request must match CreateOrganizationRequest schema
- INT: Invalid request body returns 422
- INT: Requires database session (dependency injection)

### Pydantic Models

```python
class CreateOrganizationRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    ein: str = Field(pattern=r"^\d{2}-\d{7}$")
    org_type: OrgType
    website: HttpUrl | None = None
```

Intents extracted:
- INT: name is required, 1-255 characters
- INT: ein must match XX-XXXXXXX format
- INT: org_type must be a valid OrgType enum value
- INT: website is optional, must be valid URL if provided
- INT: Unknown fields are silently dropped (Pydantic v2 default)

### SQLAlchemy Models

```python
class Organization(Base):
    __tablename__ = "organizations"
    __table_args__ = (
        UniqueConstraint("ein", name="uq_org_ein"),
        {"schema": "crm"},
    )
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
```

Intents extracted:
- INT: Organization EIN must be unique (database constraint)
- INT: Organization ID is auto-generated UUID
- INT: Organization name cannot be null
- INT: Organization lives in the crm schema

### Service Layer

```python
class OrganizationService:
    async def create(self, data: CreateOrgRequest) -> Organization:
        """Create a new organization. Raises DuplicateEINError if EIN exists."""
```

Intents extracted:
- INT: create() returns an Organization
- INT: create() raises DuplicateEINError on duplicate EIN
- INT: create() accepts CreateOrgRequest

### Error Handling

```python
try:
    result = await db.execute(query)
except IntegrityError as e:
    if "uq_org_ein" in str(e):
        raise DuplicateEINError(f"EIN {data.ein} already exists")
    raise
```

Intents extracted:
- INT: Duplicate EIN raises DuplicateEINError with the EIN in the message
- INT: Other integrity errors are re-raised (not swallowed)

## Identifying Ambiguities

Flag these as ambiguities in the Intent Map:

### Unclear Validation Boundaries
- Is empty string "" a valid name, or should it be rejected?
- What happens with unicode in EIN? Is "１２-３４５６７８９" valid?
- Are leading/trailing spaces in name preserved or stripped?

### Missing Error Handling
- What happens if the database is unreachable during create?
- What happens if two concurrent requests create the same EIN?
- What happens on partial failure (org created but contact creation fails)?

### Implicit Behavior
- Does deleting an organization cascade to contacts?
- Are soft-deleted orgs visible in list queries?
- Does update preserve fields not included in the request?

### When to Ask vs Assume

| Situation | Action |
|-----------|--------|
| P0 intent is ambiguous | ASK the user |
| P1 intent has reasonable default | ASSUME and document |
| P2/P3 intent is ambiguous | ASSUME and document |
| Security-related ambiguity | ALWAYS ASK |
| Data integrity ambiguity | ALWAYS ASK |
| UI/UX preference | ASSUME common convention |

## The Intent Map Structure

Every discovered intent becomes an entry:

```json
{
  "id": "INT-001",
  "description": "POST /organizations returns 201 with the created organization",
  "source": "src/api/routes/organizations.py:15",
  "confidence": "high",
  "priority": "P0",
  "category": "core-journey",
  "endpoints": ["/api/v1/organizations"],
  "models": ["Organization", "CreateOrganizationRequest"],
  "services": ["OrganizationService"],
  "tested": false,
  "existing_tests": []
}
```

## Common Intent Patterns by Framework

### FastAPI
- Route handler returns correct status code
- Request validation rejects invalid input (422)
- Auth dependency blocks unauthenticated requests (401)
- Auth dependency blocks unauthorized requests (403)
- Response matches response_model schema
- Dependency injection works correctly

### React Components
- Component renders without crashing
- Component displays props correctly
- User interactions trigger expected callbacks
- Loading states display correctly
- Error states display correctly
- Component is accessible (ARIA labels, keyboard nav)

### Database Repositories
- CRUD operations work correctly
- Unique constraints are enforced
- Foreign key relationships are maintained
- Pagination returns correct pages
- Filters narrow results correctly
- Soft delete hides records from normal queries

### Temporal Workflows
- Workflow completes successfully for valid input
- Workflow signals are handled correctly
- Workflow queries return correct state
- Activity failures trigger retries
- Activity retries exhaust -> workflow fails gracefully
- Workflow idempotency (same input twice = same result)

## Priority Classification

| Priority | Criteria | Examples |
|----------|----------|---------|
| P0 | Security, data integrity, core user journeys | Auth, data creation, payment |
| P1 | Important features, business logic, error handling | Search, filtering, validation |
| P2 | Secondary features, edge cases | Pagination, sorting, export |
| P3 | Cosmetic, convenience, rarely used paths | UI polish, admin features |

## Category Classification

| Category | What It Covers |
|----------|---------------|
| security | Authentication, authorization, input sanitization, secrets |
| data-integrity | Database constraints, transactions, consistency, backups |
| core-journey | Primary user flows (create, read, update, delete) |
| business-logic | Domain-specific rules, calculations, transformations |
| edge-case | Boundary conditions, empty inputs, concurrent access |
