# Tech Stack Detection Guide

How to automatically detect a project's technology stack by examining files, dependencies, and directory structure. This information drives test generation strategy.

## Detection Order

Run detection in this order. Each step narrows the configuration for subsequent steps.

### 1. Language Detection

| Indicator | Language | Confidence |
|-----------|----------|------------|
| `pyproject.toml` or `setup.py` or `setup.cfg` | Python | High |
| `package.json` | JavaScript/TypeScript | High |
| `go.mod` | Go | High |
| `Cargo.toml` | Rust | High |
| `*.py` files in src/ | Python | Medium |
| `*.ts` or `*.tsx` files in src/ | TypeScript | Medium |
| `tsconfig.json` | TypeScript | High |
| `requirements.txt` alone | Python | Medium |
| `Pipfile` | Python | High |

For mixed projects (e.g., Python backend + TypeScript frontend), detect both and treat as separate test targets.

### 2. Framework Detection

#### Python Frameworks

| Indicator | Framework | Test Strategy |
|-----------|-----------|--------------|
| `fastapi` in dependencies | FastAPI | httpx AsyncClient, TestClient |
| `from fastapi import` in code | FastAPI | httpx AsyncClient, TestClient |
| `django` in dependencies | Django | django.test.TestCase |
| `flask` in dependencies | Flask | flask.testing.FlaskClient |
| `temporalio` in dependencies | Temporal | Temporal test environment |
| `sqlalchemy` in dependencies | SQLAlchemy | Transaction rollback fixtures |
| `pydantic` in dependencies | Pydantic | Model validation tests |

#### TypeScript Frameworks

| Indicator | Framework | Test Strategy |
|-----------|-----------|--------------|
| `next` in package.json dependencies | Next.js | next/jest, Playwright |
| `next.config.*` file | Next.js | next/jest, Playwright |
| `app/` dir with `page.tsx` | Next.js App Router | Server component testing |
| `pages/` dir with `*.tsx` | Next.js Pages Router | getServerSideProps testing |
| `react` in dependencies | React | React Testing Library |
| `vue` in dependencies | Vue.js | Vue Test Utils |
| `svelte` in dependencies | Svelte | Svelte Testing Library |
| `express` in dependencies | Express | Supertest |

### 3. Test Runner Detection

#### Python

| Indicator | Test Runner |
|-----------|-------------|
| `[tool.pytest]` in pyproject.toml | pytest |
| `pytest.ini` or `setup.cfg [tool:pytest]` | pytest |
| `conftest.py` exists | pytest |
| `unittest` imports in test files | unittest (usually via pytest) |
| `pytest-asyncio` in dependencies | pytest with async support |

#### TypeScript

| Indicator | Test Runner |
|-----------|-------------|
| `vitest` in devDependencies | Vitest |
| `vitest.config.*` file | Vitest |
| `jest` in devDependencies | Jest |
| `jest.config.*` file | Jest |
| `@playwright/test` in devDependencies | Playwright |
| `playwright.config.*` file | Playwright |
| `cypress` in devDependencies | Cypress |

### 4. Database Detection

| Indicator | Database | Test Approach |
|-----------|----------|--------------|
| `asyncpg` or `psycopg2` in deps | PostgreSQL | Transaction rollback, test schema |
| `pgvector` in deps | PostgreSQL + vectors | Vector fixture data |
| `sqlalchemy` in deps | SQL via ORM | AsyncSession fixtures |
| `alembic` in deps | SQL with migrations | Run migrations in test setup |
| `prisma` in deps | Prisma | prisma migrate reset |
| `drizzle-orm` in deps | Drizzle | Test database |
| `DATABASE_URL` in .env | SQL database | Connection string parsing |

### 5. Package Manager Detection

| Indicator | Manager | Install Command | Run Command |
|-----------|---------|-----------------|-------------|
| `uv.lock` | uv | `uv sync` | `uv run pytest` |
| `poetry.lock` | Poetry | `poetry install` | `poetry run pytest` |
| `Pipfile.lock` | Pipenv | `pipenv install` | `pipenv run pytest` |
| `pnpm-lock.yaml` | pnpm | `pnpm install` | `pnpm test` |
| `yarn.lock` | Yarn | `yarn install` | `yarn test` |
| `bun.lockb` or `bun.lock` | Bun | `bun install` | `bun test` |
| `package-lock.json` | npm | `npm install` | `npm test` |
| `requirements.txt` only | pip | `pip install -r requirements.txt` | `pytest` |

### 6. Frontend Detection

| Indicator | Type | Visual Testing? |
|-----------|------|----------------|
| `package.json` with React/Vue/Svelte | SPA | Yes |
| `next.config.*` | SSR/SSG | Yes |
| `index.html` in public/ | Static | Yes |
| No frontend indicators | Backend only | No |
| `tailwindcss` in deps | CSS framework | Affects visual baselines |
| `shadcn` components | Component library | Affects visual baselines |

### 7. CI/CD Detection

| Indicator | CI System |
|-----------|-----------|
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `Jenkinsfile` | Jenkins |
| `.circleci/config.yml` | CircleCI |
| `bitbucket-pipelines.yml` | Bitbucket |

### 8. Linter/Formatter Detection

| Indicator | Tool | Language |
|-----------|------|----------|
| `[tool.ruff]` in pyproject.toml | Ruff | Python |
| `ruff.toml` | Ruff | Python |
| `biome.json` or `biome.jsonc` | Biome | TypeScript |
| `.eslintrc.*` | ESLint | TypeScript |
| `.prettierrc.*` | Prettier | TypeScript |
| `[tool.mypy]` in pyproject.toml | mypy | Python |
| `[tool.black]` in pyproject.toml | Black | Python |

## Using detect-stack.sh

The plugin includes `scripts/detect-stack.sh` which automates this detection:

```bash
./scripts/detect-stack.sh /path/to/project
```

Output is a JSON object:
```json
{
  "language": "python",
  "version": "3.12",
  "framework": "fastapi",
  "test_runner": "pytest",
  "database": "postgresql",
  "orm": "sqlalchemy",
  "package_manager": "uv",
  "linter": "ruff",
  "formatter": "ruff",
  "type_checker": "mypy",
  "has_frontend": false,
  "frontend_framework": null,
  "ci": "github-actions",
  "existing_tests": true,
  "test_directory": "tests"
}
```

Agents should use this output to configure test generation templates and tool selection.

## Detection to Action Mapping

| Detection | Action |
|-----------|--------|
| Python + FastAPI + pytest | Use httpx AsyncClient fixtures, test routes |
| Python + SQLAlchemy + asyncpg | Use transaction rollback fixtures, test repos |
| Python + Temporal | Use Temporal test environment, test workflows |
| TypeScript + Next.js + Playwright | Use POM pattern, test pages and API routes |
| TypeScript + React + Vitest | Use React Testing Library, test components |
| PostgreSQL + pgvector | Include vector fixture data, test similarity search |
| uv package manager | Use `uv run` prefix for all commands |
| ruff linter | Run `ruff check` and `ruff format --check` in static analysis |

## Handling Unknown Stacks

If a project uses a stack not covered here:
1. Identify the closest known stack
2. Use generic testing patterns (AAA, isolation, determinism)
3. Flag the unknown stack to the user for guidance
4. Document any new patterns discovered for future use
