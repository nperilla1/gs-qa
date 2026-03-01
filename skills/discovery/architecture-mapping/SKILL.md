---
name: architecture-mapping
description: "Map a codebase's architecture — routes, models, services, database schemas, and dependencies. Creates a structural understanding of any project regardless of language or framework. Use when asked to 'map architecture', 'understand codebase', 'find all endpoints', 'map project structure', 'show me the architecture', or 'how is this organized'."
allowed-tools: Read, Grep, Glob, Bash
---

# Architecture Mapping

You are mapping the architecture of a codebase to create a comprehensive structural understanding. This is a discovery tool — you read and analyze, you do not modify anything.

## Target
$ARGUMENTS
(If no specific target given, map the current working directory)

## Phase 1: Entry Points

Find the application entry points — these are the roots from which everything flows.

### Python Projects
```bash
# FastAPI / Flask / Django
grep -rn "FastAPI\|Flask\|Django" --include="*.py" -l .
grep -rn "if __name__" --include="*.py" -l .
grep -rn "uvicorn\|gunicorn" --include="*.py" --include="*.toml" --include="*.cfg" .
```

### TypeScript/JavaScript Projects
```bash
# Next.js / Express / Nest
grep -rn "createServer\|express()\|NestFactory\|createApp" --include="*.ts" --include="*.js" -l .
cat package.json | grep -A5 '"scripts"'
```

Read each entry point file to understand the application bootstrap process.

## Phase 2: Route Definitions

Map every API endpoint and page route.

### FastAPI
```bash
grep -rn "@app\.\|@router\." --include="*.py" .
```
For each route, extract: HTTP method, path, function name, request/response models, dependencies.

### Express / Nest
```bash
grep -rn "router\.\(get\|post\|put\|patch\|delete\)\|@Get\|@Post\|@Put\|@Patch\|@Delete" --include="*.ts" --include="*.js" .
```

### Next.js
```bash
find . -path "*/app/*/page.*" -o -path "*/app/*/route.*" -o -path "*/pages/*.tsx"
```

### Django
```bash
grep -rn "path(\|re_path(\|url(" --include="*.py" .
```

Produce a route table:
```
| Method | Path | Handler | Auth | Request Model | Response Model |
```

## Phase 3: Data Models

Find all data model definitions — these define the shape of your domain.

### SQLAlchemy / Django ORM
```bash
grep -rn "class.*Base\)\|class.*Model\)\|class.*db.Model" --include="*.py" .
```
For each model: table name, columns with types, relationships, constraints, indexes.

### Pydantic / Dataclasses
```bash
grep -rn "class.*BaseModel\)\|class.*BaseSettings\)\|@dataclass" --include="*.py" .
```
For each schema: fields, types, validators, default values.

### TypeScript
```bash
grep -rn "interface \|type \|z.object\|@Entity\|@Table" --include="*.ts" .
```

### Prisma
```bash
cat prisma/schema.prisma 2>/dev/null
```

## Phase 4: Service Layer

Map the business logic layer — the modules that contain application logic between routes and data.

```bash
# Find service/use-case modules
find . -name "*service*" -o -name "*usecase*" -o -name "*interactor*" -o -name "*handler*" | grep -v node_modules | grep -v __pycache__
```

For each service:
- What entity/domain does it manage?
- What operations does it perform?
- What dependencies does it inject?
- What external services does it call?

## Phase 5: Database Schemas

Map the database structure from migrations and schema files.

### Alembic (Python)
```bash
find . -path "*/alembic/versions/*.py" | sort
```
Read the most recent migration to understand current schema state.

### Prisma
```bash
cat prisma/schema.prisma
```

### Raw SQL
```bash
find . -name "*.sql" | grep -i "schema\|migration\|init"
```

### Direct DB Inspection (if accessible)
```bash
# PostgreSQL via SSH
ssh gs-production-v2 "docker exec gs-backend psql -U n8n -d gs_unified -c '\dt <schema>.*'"
```

## Phase 6: External Integrations

Find all external API calls, message queue connections, and third-party service integrations.

```bash
# HTTP clients
grep -rn "httpx\|requests\|fetch\|axios\|got(" --include="*.py" --include="*.ts" --include="*.js" -l .

# Message queues
grep -rn "celery\|rabbitmq\|redis\|kafka\|temporal" --include="*.py" --include="*.ts" -l .

# Cloud services
grep -rn "boto3\|s3\|sqs\|sns\|lambda\|azure\|gcloud" --include="*.py" --include="*.ts" -l .
```

For each integration: service name, client location, endpoints called, authentication method.

## Phase 7: Middleware and Cross-Cutting Concerns

Map middleware, decorators, and cross-cutting concerns.

```bash
# Authentication
grep -rn "auth\|jwt\|bearer\|session\|login\|permission" --include="*.py" --include="*.ts" -l .

# Error handling
grep -rn "exception_handler\|error_handler\|@app.exception\|ErrorBoundary" --include="*.py" --include="*.ts" -l .

# Logging
grep -rn "structlog\|logging\|logger\|winston\|pino" --include="*.py" --include="*.ts" -l .

# Validation
grep -rn "validator\|middleware\|guard\|interceptor" --include="*.py" --include="*.ts" -l .
```

## Phase 8: Configuration

Map all configuration sources and their hierarchy.

```bash
# Env files
find . -name ".env*" -not -path "*/node_modules/*" | sort

# Settings modules
grep -rn "BaseSettings\|config\|Settings" --include="*.py" -l .
grep -rn "process.env\|dotenv" --include="*.ts" --include="*.js" -l .

# Docker/infrastructure
find . -name "docker-compose*" -o -name "Dockerfile*" | sort
```

## Output Format

Present the architecture map as a structured summary:

```
## Architecture Map: <project name>

### Stack
- Language: ...
- Framework: ...
- Database: ...
- Package Manager: ...

### Entry Points
- <file>: <purpose>

### Routes (N endpoints)
| Method | Path | Handler | Auth Required |
|--------|------|---------|--------------|

### Data Models (N models)
| Model | Table | Key Fields | Relationships |
|-------|-------|-----------|---------------|

### Services (N services)
| Service | Domain | Key Operations | Dependencies |
|---------|--------|---------------|-------------|

### External Integrations
| Service | Client Location | Purpose |
|---------|----------------|---------|

### Middleware Chain
1. <middleware 1>: <purpose>
2. <middleware 2>: <purpose>

### Configuration
| Source | Priority | Purpose |
|--------|----------|---------|

### Dependency Graph
<text diagram showing how components connect>
```

## Rules

- Read actual files — do not guess from names
- Map what EXISTS, not what you think SHOULD exist
- Note any orphaned files (defined but never imported/used)
- Note any circular dependencies
- If the codebase is a monorepo, map each project separately
- This is a read-only operation — do not modify any files
