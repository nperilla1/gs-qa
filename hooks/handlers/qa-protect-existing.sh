#!/usr/bin/env bash
# qa-protect-existing.sh — PreToolUse hook for Edit|Write
# Blocks modification of existing test files during QA sweeps
# Only active when a QA sweep is running (qa-context.md has sweep_active: true)

set -euo pipefail

QA_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CONTEXT_FILE="$QA_ROOT/context/qa-context.md"

# Only enforce during active sweeps
if [[ ! -f "$CONTEXT_FILE" ]] || ! grep -q "sweep_active: true" "$CONTEXT_FILE" 2>/dev/null; then
  exit 0
fi

# Read tool input from stdin
INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', data)
    print(ti.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Check if it's a test file that already exists
case "$BASENAME" in
  test_*.py|*_test.py|*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.test.js|*.spec.js)
    if [[ -f "$FILE_PATH" ]]; then
      echo "BLOCKED: Cannot modify existing test file '$BASENAME' during QA sweep. Create new test files instead."
      exit 2
    fi
    ;;
esac

exit 0
