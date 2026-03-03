#!/usr/bin/env bash
# qa-sentinel-gate.sh — PostToolUse hook for Write
# Auto-audits generated test files for common anti-patterns
# Only triggers on test files (test_*.py, *.test.ts, *.spec.ts)

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Extract file path from the tool input (macOS-compatible, no grep -P)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', data)
    print(ti.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only check test files
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Match test file patterns
case "$BASENAME" in
  test_*.py|*_test.py|*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.test.js|*.spec.js)
    ;;
  *)
    exit 0
    ;;
esac

# Only audit if the file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

WARNINGS=""

# Check for common test anti-patterns
if grep -q "sleep(" "$FILE_PATH" 2>/dev/null; then
  WARNINGS+="- WARNING: Test uses sleep() — use explicit waits or polling instead\n"
fi

if grep -q "import requests" "$FILE_PATH" 2>/dev/null; then
  WARNINGS+="- WARNING: Test imports requests directly — use httpx/respx or test client instead\n"
fi

if grep -qE 'assert\s+True|assertTrue\(True|assertEqual\(True' "$FILE_PATH" 2>/dev/null; then
  WARNINGS+="- WARNING: Tautological assertion found (always passes)\n"
fi

if grep -qE 'except\s*:' "$FILE_PATH" 2>/dev/null; then
  WARNINGS+="- WARNING: Bare except clause — tests should assert specific exceptions\n"
fi

if grep -q "mock.patch.*autospec=False" "$FILE_PATH" 2>/dev/null; then
  WARNINGS+="- WARNING: Mock without autospec — use autospec=True to catch signature mismatches\n"
fi

# Check for tests without assertions
if echo "$FILE_PATH" | grep -q '\.py$'; then
  # Count test functions vs assert statements
  TEST_COUNT=$(grep -c "def test_" "$FILE_PATH" 2>/dev/null || echo 0)
  ASSERT_COUNT=$(grep -c "assert" "$FILE_PATH" 2>/dev/null || echo 0)
  if [[ "$TEST_COUNT" -gt 0 && "$ASSERT_COUNT" -eq 0 ]]; then
    WARNINGS+="- WARNING: $TEST_COUNT test function(s) but no assertions found\n"
  fi
fi

if [[ -n "$WARNINGS" ]]; then
  echo -e "Sentinel gate flagged issues in $BASENAME:\n$WARNINGS"
fi

exit 0
