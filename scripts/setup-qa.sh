#!/usr/bin/env bash
# setup-qa.sh — Install QA dependencies based on detected stack
# Auto-detects the project stack and installs appropriate test tooling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-.}"

echo "Setting up QA infrastructure for: $PROJECT_DIR"

# Detect stack
STACK=$(bash "$SCRIPT_DIR/detect-stack.sh" "$PROJECT_DIR")
LANGUAGE=$(echo "$STACK" | grep "^language=" | cut -d= -f2)
FRAMEWORK=$(echo "$STACK" | grep "^framework=" | cut -d= -f2)
TEST_RUNNER=$(echo "$STACK" | grep "^test_runner=" | cut -d= -f2)
PKG_MANAGER=$(echo "$STACK" | grep "^package_manager=" | cut -d= -f2)
HAS_PLAYWRIGHT=$(echo "$STACK" | grep "^has_playwright=" | cut -d= -f2)

echo "Detected: language=$LANGUAGE, framework=$FRAMEWORK, test_runner=$TEST_RUNNER"

# --- Python Setup ---
if [[ "$LANGUAGE" == "python" ]]; then
  echo "Installing Python QA dependencies..."

  DEPS="pytest pytest-asyncio pytest-cov pytest-xdist httpx respx factory-boy"

  # Add mutation testing
  DEPS="$DEPS mutmut"

  # Add framework-specific deps
  if [[ "$FRAMEWORK" == "fastapi" ]]; then
    DEPS="$DEPS anyio"
  fi

  case "$PKG_MANAGER" in
    uv)
      echo "Using uv to install: $DEPS"
      cd "$PROJECT_DIR" && uv add --dev $DEPS 2>/dev/null || echo "Some deps may already exist"
      ;;
    poetry)
      echo "Using poetry to install: $DEPS"
      cd "$PROJECT_DIR" && poetry add --group dev $DEPS 2>/dev/null || echo "Some deps may already exist"
      ;;
    pip)
      echo "Using pip to install: $DEPS"
      cd "$PROJECT_DIR" && pip install $DEPS 2>/dev/null || echo "Some deps may already exist"
      ;;
  esac

  # Create conftest.py if missing
  if [[ ! -f "$PROJECT_DIR/tests/conftest.py" ]]; then
    mkdir -p "$PROJECT_DIR/tests"
    echo "# QA-generated root conftest" > "$PROJECT_DIR/tests/conftest.py"
    echo "Created tests/conftest.py"
  fi
fi

# --- TypeScript Setup ---
if [[ "$LANGUAGE" == "typescript" ]]; then
  echo "Installing TypeScript QA dependencies..."

  case "$PKG_MANAGER" in
    bun)
      cd "$PROJECT_DIR" && bun add -d vitest @vitest/coverage-v8 2>/dev/null || true
      ;;
    pnpm)
      cd "$PROJECT_DIR" && pnpm add -D vitest @vitest/coverage-v8 2>/dev/null || true
      ;;
    npm)
      cd "$PROJECT_DIR" && npm install --save-dev vitest @vitest/coverage-v8 2>/dev/null || true
      ;;
    yarn)
      cd "$PROJECT_DIR" && yarn add -D vitest @vitest/coverage-v8 2>/dev/null || true
      ;;
  esac
fi

# --- Playwright Setup ---
if [[ "$HAS_PLAYWRIGHT" == "false" ]]; then
  echo "Playwright not detected. To add E2E testing, run:"
  echo "  npx playwright init"
else
  echo "Playwright detected. Checking browser installation..."
  npx playwright install --with-deps chromium 2>/dev/null || echo "Run 'npx playwright install' manually if needed"
fi

echo "QA setup complete."
