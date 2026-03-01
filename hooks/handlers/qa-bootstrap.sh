#!/usr/bin/env bash
# qa-bootstrap.sh — SessionStart hook
# Detects project type, verifies QA dependencies, sets up context

set -euo pipefail

QA_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CONTEXT_FILE="$QA_ROOT/context/qa-context.md"
DETECT_SCRIPT="$QA_ROOT/scripts/detect-stack.sh"

# Run stack detection
if [[ -f "$DETECT_SCRIPT" ]]; then
  STACK_INFO=$(bash "$DETECT_SCRIPT" 2>/dev/null || echo "detection_failed")
else
  STACK_INFO="detection_script_missing"
fi

# Build context
cat > "$CONTEXT_FILE" << EOF
---
generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
working_directory: $(pwd)
---

# QA Session Context

## Detected Stack
$STACK_INFO

## Available QA Commands
- \`/qa:sweep\` — Full autonomous QA sweep
- \`/qa:project <name>\` — Sweep a single project
- \`/qa:discover\` — Run intent discovery only
- \`/qa:report\` — Generate/view QA report
- \`/qa:baseline\` — Create visual baselines
- \`/qa:coverage\` — Coverage gap analysis
- \`/qa:heal\` — Fix failing tests

## Notes
- Intent discovery runs first for any sweep
- Tests validate BEHAVIOR, not implementation details
- Existing tests are never modified (only new tests are created)
EOF

echo "gs-qa plugin loaded. Stack detected: $(echo "$STACK_INFO" | head -1). Use /qa:discover to start."
