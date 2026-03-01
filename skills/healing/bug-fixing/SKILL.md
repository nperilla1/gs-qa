---
name: bug-fixing
description: "Fix confirmed application bugs discovered by failing tests. Makes minimal, targeted code changes with a 3-attempt budget per bug. Verifies fixes don't introduce regressions. Use when asked to 'fix bug', 'fix app bug', 'patch application', 'fix this error', or when qa-healer identifies an app bug."
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# Bug Fixing

You are fixing confirmed application bugs that were discovered by failing tests. Your goal is to make the minimal code change that fixes the bug without introducing regressions.

## Target
$ARGUMENTS
(Should include the bug report from qa-healer, or a description of the bug and the failing test)

## Phase 1: Understand the Bug

Read and understand all relevant context before making any changes.

### 1a. Read the Bug Report

Extract from the bug report:
- **Failing test**: Which test file and test name
- **Expected behavior**: What the test expects (backed by a spec/docstring)
- **Actual behavior**: What the app actually does
- **Source location**: Where the bug likely is

### 1b. Read the Failing Test

```bash
# Read the test to understand what it asserts
```

Understand:
- What inputs does the test provide?
- What output does it expect?
- What is the source of truth for the expected behavior? (docstring, spec, documentation)

### 1c. Read the Source Code

```bash
# Read the function being tested
```

Understand:
- What does the function currently do?
- Where does the behavior diverge from the expectation?
- What is the root cause (not just the symptom)?

### 1d. Read Related Code

```bash
# Read callers of the function
grep -rn "function_name(" --include="*.py" .

# Read functions it calls
# Read the data model it operates on
```

Understand the blast radius — what else might be affected by a fix.

## Phase 2: Identify the Root Cause

Common root causes:

| Symptom | Possible Root Cause |
|---------|-------------------|
| Wrong return value | Logic error in computation |
| Missing field in response | Serialization issue or query not selecting field |
| Wrong status code | Incorrect error handling or missing validation |
| None instead of value | Missing null check or wrong query |
| Wrong order | Missing ORDER BY or sort key |
| Duplicate results | Missing DISTINCT or dedup logic |
| Stale data | Missing cache invalidation or wrong transaction scope |
| Type error at runtime | Missing type conversion or validation |
| Off-by-one | Boundary condition in loop or comparison |
| Race condition | Missing lock or atomic operation |

Ask yourself:
- Is this a **logic error** (code does the wrong thing)?
- Is this a **missing feature** (code doesn't handle this case)?
- Is this a **data issue** (code is correct but data is wrong)?
- Is this a **configuration issue** (code looks elsewhere for the answer)?

## Phase 3: Make the Fix

### Minimal Fix Principle

Make the **smallest change** that resolves the issue. This means:
- Change ONE file if possible
- Change the FEWEST lines possible
- Do NOT refactor surrounding code
- Do NOT add features beyond what's needed
- Do NOT change test assertions (the test is correct — the app is wrong)

### Fix Patterns

**Logic error:**
```python
# Before
def calculate_score(points, total):
    return points / total  # Bug: division by zero when total is 0

# After (minimal fix)
def calculate_score(points, total):
    if total == 0:
        return 0.0
    return points / total
```

**Missing validation:**
```python
# Before
@router.post("/items")
async def create_item(item: ItemCreate):
    return await repo.create(item)  # Bug: no duplicate check

# After (minimal fix)
@router.post("/items")
async def create_item(item: ItemCreate):
    existing = await repo.get_by_name(item.name)
    if existing:
        raise HTTPException(status_code=409, detail="Item already exists")
    return await repo.create(item)
```

**Wrong query:**
```python
# Before
async def get_active_items(self):
    query = select(Item)  # Bug: returns ALL items, not just active
    result = await self.session.execute(query)
    return result.scalars().all()

# After (minimal fix)
async def get_active_items(self):
    query = select(Item).where(Item.status == "active")
    result = await self.session.execute(query)
    return result.scalars().all()
```

## Phase 4: Verify the Fix

### 4a. Run the Failing Test

```bash
python -m pytest <test_file>::<test_class>::<test_name> -v --tb=long 2>&1
```

The test must now PASS.

### 4b. Run Related Tests

```bash
# Run all tests in the same module
python -m pytest <test_file> -v --tb=short 2>&1
```

No existing tests should break.

### 4c. Run the Full Test Suite

```bash
python -m pytest <test_dir> -v --tb=short 2>&1
```

Verify no regressions elsewhere.

## Phase 5: Attempt Tracking

You have a maximum of **3 attempts** per bug.

### Attempt 1: Direct Fix
Apply the most obvious fix based on the root cause analysis.

### Attempt 2: Deeper Investigation
If attempt 1 fails:
- Read more surrounding code
- Check if the root cause is actually upstream
- Consider if the fix needs to be in a different location

### Attempt 3: Alternative Approach
If attempt 2 fails:
- Try a fundamentally different approach
- Consider if the bug is actually a design issue
- Check if there are similar patterns elsewhere in the code that work correctly

### After 3 Failed Attempts
Mark the bug as UNFIXED and create a detailed report:

```
## Unfixed Bug Report

### Bug
<description>

### Failing Test
<test file and name>

### Attempts Made
1. <what was tried> — <why it failed>
2. <what was tried> — <why it failed>
3. <what was tried> — <why it failed>

### Root Cause Analysis
<best understanding of why this is hard to fix>

### Recommendation
<what a human should investigate>
```

## Phase 6: Fix Report

For each successfully fixed bug, create a fix report:

```
## Fix Report

### Bug
<description>

### Root Cause
<what was actually wrong>

### Fix
- File: <file path>
- Lines changed: <line numbers>
- Change: <description of what was changed>

### Verification
- Failing test now passes: YES
- Related tests: N passing, 0 failing
- Full suite: N passing, 0 new failures

### Attempts: <N>/3
```

## Rules

- NEVER modify the test to make it pass — the test is correct, the app is wrong
- Make the minimal fix — do not refactor, do not add features
- Always verify with the full test suite — no regressions allowed
- Max 3 attempts per bug — escalate after that
- Read the source code before writing the fix — understand the root cause
- If the fix requires changing more than 20 lines, pause and reconsider — there might be a simpler approach
- If the fix requires changing multiple files, verify you're fixing the root cause and not a symptom
- Document why the fix works, not just what was changed
