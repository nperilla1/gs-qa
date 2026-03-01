#!/usr/bin/env bash
# check-test-infra.sh — Verify test infrastructure is ready
# Returns non-zero if critical issues are found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-.}"
ISSUES=0

# Detect stack
STACK=$(bash "$SCRIPT_DIR/detect-stack.sh" "$PROJECT_DIR")
LANGUAGE=$(echo "$STACK" | grep "^language=" | cut -d= -f2)
TEST_RUNNER=$(echo "$STACK" | grep "^test_runner=" | cut -d= -f2)

echo "Checking test infrastructure for $PROJECT_DIR..."
echo "Language: $LANGUAGE | Test Runner: $TEST_RUNNER"
echo "---"

# --- Python Checks ---
if [[ "$LANGUAGE" == "python" ]]; then
  # Check pytest is installed
  if ! command -v pytest &>/dev/null && ! python -m pytest --version &>/dev/null 2>&1; then
    echo "FAIL: pytest not found. Run: pip install pytest"
    ISSUES=$((ISSUES + 1))
  else
    echo "OK: pytest found"
  fi

  # Check tests directory exists
  if [[ -d "$PROJECT_DIR/tests" ]]; then
    TEST_COUNT=$(find "$PROJECT_DIR/tests" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | wc -l | tr -d ' ')
    echo "OK: tests/ directory found ($TEST_COUNT test files)"
  else
    echo "WARN: No tests/ directory found"
  fi

  # Check conftest.py
  if [[ -f "$PROJECT_DIR/tests/conftest.py" ]]; then
    echo "OK: tests/conftest.py exists"
  else
    echo "WARN: No tests/conftest.py — fixtures may not be shared"
  fi

  # Check pytest config
  if grep -q "\[tool.pytest" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    echo "OK: pytest configured in pyproject.toml"
  elif [[ -f "$PROJECT_DIR/pytest.ini" ]]; then
    echo "OK: pytest.ini found"
  else
    echo "WARN: No pytest configuration found"
  fi

  # Check coverage
  if python -c "import pytest_cov" 2>/dev/null; then
    echo "OK: pytest-cov available"
  else
    echo "WARN: pytest-cov not installed (needed for coverage reports)"
  fi

  # Check mutmut
  if command -v mutmut &>/dev/null; then
    echo "OK: mutmut available (mutation testing)"
  else
    echo "INFO: mutmut not installed (optional, for mutation testing)"
  fi
fi

# --- TypeScript Checks ---
if [[ "$LANGUAGE" == "typescript" ]]; then
  if [[ -f "$PROJECT_DIR/node_modules/.bin/vitest" ]]; then
    echo "OK: vitest found"
  elif [[ -f "$PROJECT_DIR/node_modules/.bin/jest" ]]; then
    echo "OK: jest found"
  else
    echo "FAIL: No test runner found. Run: npm install --save-dev vitest"
    ISSUES=$((ISSUES + 1))
  fi

  # Check for Playwright
  if [[ -f "$PROJECT_DIR/playwright.config.ts" ]] || [[ -f "$PROJECT_DIR/playwright.config.js" ]]; then
    echo "OK: Playwright config found"
    if [[ -d "$PROJECT_DIR/node_modules/@playwright" ]]; then
      echo "OK: Playwright installed"
    else
      echo "WARN: Playwright config exists but package not installed"
    fi
  fi
fi

# --- General Checks ---
# Check for CI config
if [[ -f "$PROJECT_DIR/.github/workflows/test.yml" ]] || [[ -f "$PROJECT_DIR/.github/workflows/ci.yml" ]]; then
  echo "OK: CI workflow found"
else
  echo "INFO: No CI workflow detected"
fi

# Check for .env.test
if [[ -f "$PROJECT_DIR/.env.test" ]]; then
  echo "OK: .env.test found"
else
  echo "INFO: No .env.test (tests may need environment variables)"
fi

echo "---"
if [[ $ISSUES -gt 0 ]]; then
  echo "RESULT: $ISSUES critical issue(s) found. Run setup-qa.sh to fix."
  exit 1
else
  echo "RESULT: Test infrastructure ready."
  exit 0
fi
