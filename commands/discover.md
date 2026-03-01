---
name: qa:discover
description: "Run intent discovery only — analyze the codebase to build an Intent Map without generating tests."
---

# /qa:discover -- Intent Discovery

You are running intent discovery on the current project to build an Intent Map. This phase analyzes what the code SHOULD do by examining all available sources of intent.

## Process

### Step 1: Tech Stack Detection

Run `scripts/detect-stack.sh` or manually detect:
- Language and version
- Framework
- Test runner
- Database
- Package manager

### Step 2: Intent Source Discovery

Scan the project for sources of intent, in priority order:

1. **CLAUDE.md / README.md** -- highest confidence, explicit requirements
2. **API route definitions** -- endpoints define contracts (FastAPI routes, Next.js pages)
3. **Pydantic models / TypeScript interfaces** -- schemas define data contracts
4. **Database models / migrations** -- schema defines data invariants
5. **Existing tests** -- tests encode expected behaviors
6. **Docstrings and comments** -- developer intent documentation
7. **Type annotations** -- constrain valid inputs/outputs
8. **Validation logic** -- encodes business rules
9. **Error handling** -- defines failure modes
10. **Configuration / env vars** -- behavioral switches

### Step 3: Intent Extraction

For each source, extract intended behaviors:
- What does this code promise to do?
- What inputs does it accept and reject?
- What outputs does it guarantee?
- What side effects does it have?
- What error conditions does it handle?

Classify each intent:
- **Category**: security, data-integrity, core-journey, business-logic, edge-case
- **Priority**: P0 (must test), P1 (should test), P2 (nice to test), P3 (optional)
- **Confidence**: high (explicit in docs/tests), medium (inferred from code), low (assumed)

### Step 4: Ambiguity Detection

Flag any ambiguous behaviors:
- Code that could be interpreted multiple ways
- Missing validation that might be intentional
- Undocumented error handling decisions
- Implicit assumptions about data format or ordering

### Step 5: Coverage Gap Analysis

Cross-reference discovered intents against existing tests:
- Which intents have tests already?
- Which intents have no test coverage?
- Which files have no test coverage at all?

### Step 6: Output

Write the Intent Map to `intent-map.json` using the `intent-map.json` template.

Display a summary:

```
INTENT DISCOVERY COMPLETE
=========================
Project: [name]
Sources analyzed: X

Intended Behaviors: X
  P0 (Critical):    X
  P1 (High):        X
  P2 (Medium):      X
  P3 (Low):         X

Coverage:
  Already tested:   X (Y%)
  Untested:         X (Y%)

Ambiguities: X
  Resolved: X
  Needs clarification: X

Intent Map saved to: intent-map.json
```

Ask the user if they want to:
1. Proceed with test generation (`/qa:sweep`)
2. Review and refine the Intent Map
3. Resolve ambiguities before continuing

## Rules

- Never generate tests in this command -- discovery only
- Flag ambiguities rather than making assumptions for P0/P1 intents
- For P2/P3 intents, document your assumption and move on
- If $ARGUMENTS contains a path, use that as the project directory
- Reuse an existing intent-map.json if found (ask user whether to overwrite or merge)
