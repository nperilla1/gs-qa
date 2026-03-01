#!/usr/bin/env bash
# detect-stack.sh — Auto-detect project language, framework, test runner, DB
# Outputs structured key=value pairs for use by other scripts and agents

set -euo pipefail

PROJECT_DIR="${1:-.}"

LANGUAGE="unknown"
FRAMEWORK="unknown"
TEST_RUNNER="unknown"
DB="unknown"
FRONTEND="unknown"
PACKAGE_MANAGER="unknown"

# --- Language Detection ---
if [[ -f "$PROJECT_DIR/pyproject.toml" ]] || [[ -f "$PROJECT_DIR/setup.py" ]] || [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
  LANGUAGE="python"
  # Package manager
  if [[ -f "$PROJECT_DIR/uv.lock" ]]; then
    PACKAGE_MANAGER="uv"
  elif [[ -f "$PROJECT_DIR/poetry.lock" ]]; then
    PACKAGE_MANAGER="poetry"
  elif [[ -f "$PROJECT_DIR/Pipfile.lock" ]]; then
    PACKAGE_MANAGER="pipenv"
  else
    PACKAGE_MANAGER="pip"
  fi
elif [[ -f "$PROJECT_DIR/package.json" ]]; then
  LANGUAGE="typescript"
  if grep -q '"type": "module"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    LANGUAGE="typescript"
  fi
  # Package manager
  if [[ -f "$PROJECT_DIR/bun.lockb" ]] || [[ -f "$PROJECT_DIR/bun.lock" ]]; then
    PACKAGE_MANAGER="bun"
  elif [[ -f "$PROJECT_DIR/pnpm-lock.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
  elif [[ -f "$PROJECT_DIR/yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
  else
    PACKAGE_MANAGER="npm"
  fi
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  LANGUAGE="go"
  PACKAGE_MANAGER="go"
elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
  LANGUAGE="rust"
  PACKAGE_MANAGER="cargo"
fi

# --- Framework Detection ---
if [[ "$LANGUAGE" == "python" ]]; then
  DEPS=""
  if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    DEPS=$(cat "$PROJECT_DIR/pyproject.toml")
  elif [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    DEPS=$(cat "$PROJECT_DIR/requirements.txt")
  fi

  if echo "$DEPS" | grep -qi "fastapi"; then
    FRAMEWORK="fastapi"
  elif echo "$DEPS" | grep -qi "django"; then
    FRAMEWORK="django"
  elif echo "$DEPS" | grep -qi "flask"; then
    FRAMEWORK="flask"
  elif echo "$DEPS" | grep -qi "starlette"; then
    FRAMEWORK="starlette"
  fi
elif [[ "$LANGUAGE" == "typescript" ]] && [[ -f "$PROJECT_DIR/package.json" ]]; then
  PKG=$(cat "$PROJECT_DIR/package.json")
  if echo "$PKG" | grep -q '"next"'; then
    FRAMEWORK="nextjs"
  elif echo "$PKG" | grep -q '"express"'; then
    FRAMEWORK="express"
  elif echo "$PKG" | grep -q '"hono"'; then
    FRAMEWORK="hono"
  elif echo "$PKG" | grep -q '"fastify"'; then
    FRAMEWORK="fastify"
  fi
elif [[ "$LANGUAGE" == "go" ]]; then
  if [[ -f "$PROJECT_DIR/go.mod" ]] && grep -q "gin-gonic" "$PROJECT_DIR/go.mod" 2>/dev/null; then
    FRAMEWORK="gin"
  elif [[ -f "$PROJECT_DIR/go.mod" ]] && grep -q "go-chi" "$PROJECT_DIR/go.mod" 2>/dev/null; then
    FRAMEWORK="chi"
  fi
fi

# --- Test Runner Detection ---
if [[ "$LANGUAGE" == "python" ]]; then
  if [[ -f "$PROJECT_DIR/pyproject.toml" ]] && grep -q "pytest" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    TEST_RUNNER="pytest"
  elif [[ -f "$PROJECT_DIR/pytest.ini" ]] || [[ -f "$PROJECT_DIR/setup.cfg" ]]; then
    TEST_RUNNER="pytest"
  elif find "$PROJECT_DIR" -maxdepth 2 -name "test_*.py" 2>/dev/null | head -1 | grep -q .; then
    TEST_RUNNER="pytest"
  fi
elif [[ "$LANGUAGE" == "typescript" ]] && [[ -f "$PROJECT_DIR/package.json" ]]; then
  PKG=$(cat "$PROJECT_DIR/package.json")
  if echo "$PKG" | grep -q '"vitest"'; then
    TEST_RUNNER="vitest"
  elif echo "$PKG" | grep -q '"jest"'; then
    TEST_RUNNER="jest"
  elif echo "$PKG" | grep -q '"@playwright/test"'; then
    TEST_RUNNER="playwright"
  fi
elif [[ "$LANGUAGE" == "go" ]]; then
  TEST_RUNNER="go-test"
fi

# --- Database Detection ---
if [[ "$LANGUAGE" == "python" ]]; then
  DEPS=""
  if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    DEPS=$(cat "$PROJECT_DIR/pyproject.toml")
  fi
  if echo "$DEPS" | grep -qi "asyncpg\|sqlalchemy\|psycopg"; then
    DB="postgresql"
  elif echo "$DEPS" | grep -qi "pymongo\|motor"; then
    DB="mongodb"
  elif echo "$DEPS" | grep -qi "aiosqlite\|sqlite"; then
    DB="sqlite"
  fi
elif [[ "$LANGUAGE" == "typescript" ]] && [[ -f "$PROJECT_DIR/package.json" ]]; then
  PKG=$(cat "$PROJECT_DIR/package.json")
  if echo "$PKG" | grep -q '"pg"\|"postgres"\|"@prisma"'; then
    DB="postgresql"
  elif echo "$PKG" | grep -q '"mongodb"\|"mongoose"'; then
    DB="mongodb"
  fi
fi

# --- Frontend Detection ---
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  PKG=$(cat "$PROJECT_DIR/package.json")
  if echo "$PKG" | grep -q '"react"'; then
    FRONTEND="react"
  elif echo "$PKG" | grep -q '"vue"'; then
    FRONTEND="vue"
  elif echo "$PKG" | grep -q '"svelte"'; then
    FRONTEND="svelte"
  fi
fi

# Check for Playwright separately (E2E testing)
HAS_PLAYWRIGHT="false"
if [[ -f "$PROJECT_DIR/playwright.config.ts" ]] || [[ -f "$PROJECT_DIR/playwright.config.js" ]]; then
  HAS_PLAYWRIGHT="true"
elif [[ -f "$PROJECT_DIR/package.json" ]] && grep -q '@playwright/test' "$PROJECT_DIR/package.json" 2>/dev/null; then
  HAS_PLAYWRIGHT="true"
fi

# --- Output ---
echo "language=$LANGUAGE"
echo "framework=$FRAMEWORK"
echo "test_runner=$TEST_RUNNER"
echo "database=$DB"
echo "frontend=$FRONTEND"
echo "package_manager=$PACKAGE_MANAGER"
echo "has_playwright=$HAS_PLAYWRIGHT"
echo "project_dir=$PROJECT_DIR"
