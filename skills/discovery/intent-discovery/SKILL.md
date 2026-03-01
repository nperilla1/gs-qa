---
name: intent-discovery
description: "Study code + documentation to build an Intent Map — discover what the software is SUPPOSED to do before testing it. Reads CLAUDE.md, README, docs, docstrings, API schemas, existing tests, and commit messages to extract intended behaviors. Use when starting any QA work, before generating tests, or when asked to 'discover intent', 'what does this code do', 'build intent map', 'analyze project intent', or 'understand what this should do'."
allowed-tools: Read, Grep, Glob, Bash, Write, AskUserQuestion
---

# Intent Discovery

You are performing intent discovery — systematically understanding what a codebase is SUPPOSED to do before testing it. Your output is an Intent Map that captures every intended behavior as a testable specification.

## Target
$ARGUMENTS
(If no specific target given, discover intent for the entire project in the current working directory)

## Phase 1: Stack Detection

Run the stack detection script to understand the project's technology:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh
```

Read the output carefully. It tells you:
- Languages and frameworks in use
- Test frameworks already configured
- Existing test locations and counts
- Package manager and dependencies
- Whether it is a monorepo

## Phase 2: Documentation Review

Read all available documentation sources in this order:

### 2a. Project-Level Documentation
1. Read `CLAUDE.md` if it exists — this is the most authoritative source of intent
2. Read `README.md` for high-level purpose and features
3. Search for `docs/` directory and read any files within
4. Read `CHANGELOG.md` or `HISTORY.md` for feature evolution
5. Read `pyproject.toml`, `package.json`, or equivalent for project description and dependencies

### 2b. API Documentation
- **FastAPI**: Find all files with `app = FastAPI` or `APIRouter()`. Extract route definitions, request/response models, and docstrings
- **Express/Nest**: Find all router/controller files. Extract route definitions and middleware
- **Next.js**: Find all `app/` or `pages/` route files
- **Django**: Find `urls.py` files and view definitions
- Look for OpenAPI/Swagger specs (`openapi.json`, `swagger.yaml`, `docs/api/`)

### 2c. Type Definitions and Models
- **Python**: Find Pydantic models, dataclasses, TypedDict definitions
- **TypeScript**: Find interfaces, type definitions, Zod schemas
- **Database**: Find SQLAlchemy models, Prisma schema, migration files
- Extract field constraints: required fields, validators, min/max values, patterns

### 2d. Docstrings and Comments
Search for functions with docstrings that describe behavior:
```
# Python
grep -rn '"""' src/ --include="*.py" | head -50

# TypeScript
grep -rn '/\*\*' src/ --include="*.ts" | head -50
```

Read the top-level docstrings of key modules and classes.

## Phase 3: Architecture Mapping

Map the codebase structure to understand component relationships:

1. **Entry points**: Find `main.py`, `app.py`, `index.ts`, `server.ts`
2. **Route files**: All API endpoint definitions
3. **Model files**: All data models and schemas
4. **Service files**: Business logic modules
5. **Repository/DAL files**: Database access layer
6. **Middleware**: Authentication, validation, error handling
7. **Workers/Jobs**: Background tasks, queue consumers
8. **Configuration**: Settings, env files, feature flags

## Phase 4: Existing Test Analysis

Read existing tests to understand what is already covered:

1. Find all test files: `tests/`, `__tests__/`, `*.test.*`, `*.spec.*`
2. Read test names to understand intended behaviors
3. Identify gaps — what modules have no corresponding tests?
4. Note test patterns used (fixtures, factories, mocks, parametrize)

## Phase 5: Commit History Analysis

If the project is a git repo, check recent commits for intent clues:
```bash
git log --oneline -30
```

Look for commit messages that describe features, fixes, and behavioral changes.

## Phase 6: Ambiguity Resolution

For any behavior where intent is unclear:
1. First check if there are tests that clarify the expected behavior
2. Check if there are docstrings or comments that explain it
3. If still unclear, use AskUserQuestion to ask the user directly

Common ambiguities to watch for:
- Is an empty input valid or should it error?
- What happens on concurrent access?
- Are there rate limits or quotas?
- What is the expected behavior on network failure?
- Are deletions soft or hard?

## Phase 7: Write Intent Map

Write the intent map to `intent-map.json` in the project root.

### Intent Map JSON Structure

```json
{
  "project": {
    "name": "<project name>",
    "description": "<one-line description>",
    "stack": {
      "language": "<primary language>",
      "framework": "<primary framework>",
      "test_framework": "<test framework>",
      "database": "<database if any>",
      "package_manager": "<package manager>"
    }
  },
  "modules": [
    {
      "name": "<module name>",
      "path": "<relative path>",
      "purpose": "<what this module does>",
      "intents": [
        {
          "id": "<module>.<behavior>",
          "description": "<what it should do>",
          "source": "<where intent was discovered: docstring|test|readme|api_schema|type_hint|user>",
          "priority": "<critical|high|medium|low>",
          "type": "<unit|integration|e2e|visual>",
          "inputs": "<expected inputs>",
          "outputs": "<expected outputs>",
          "edge_cases": [
            "<edge case 1>",
            "<edge case 2>"
          ],
          "existing_test": "<path to existing test if any, null if none>"
        }
      ]
    }
  ],
  "cross_cutting": [
    {
      "id": "<concern>",
      "description": "<authentication, error handling, logging, etc.>",
      "affected_modules": ["<module1>", "<module2>"],
      "intents": [
        {
          "id": "<concern>.<behavior>",
          "description": "<what it should do>",
          "source": "<source>",
          "priority": "<priority>"
        }
      ]
    }
  ],
  "coverage_gaps": [
    {
      "module": "<module with no tests>",
      "risk": "<high|medium|low>",
      "reason": "<why this is a gap>"
    }
  ],
  "ambiguities": [
    {
      "module": "<module>",
      "question": "<what is unclear>",
      "resolution": "<how it was resolved or 'unresolved'>"
    }
  ]
}
```

### Priority Assignment Rules

- **critical**: Authentication, authorization, payment processing, data persistence, core business logic
- **high**: API endpoints, data validation, error handling, integrations
- **medium**: UI behavior, formatting, logging, non-critical features
- **low**: Cosmetic behavior, developer tooling, debug endpoints

## Rules

- Read actual code — do not guess or assume behavior from file names alone
- Every intent must cite its source (docstring, test, README, schema, or user confirmation)
- If a behavior seems important but has no documentation, flag it as an ambiguity
- Do not invent intents — only document what the code is INTENDED to do
- Prioritize depth over breadth — a thorough analysis of key modules beats a shallow scan of everything
- The intent map is the foundation for all subsequent QA phases — accuracy here prevents wasted effort later
