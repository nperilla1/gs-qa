# gs-qa — Intent-Driven Autonomous QA

A Claude Code plugin that discovers what code is **supposed to do** and then tests whether it actually does it.

## Philosophy

Most QA tools test code against itself — checking that functions return what they return. gs-qa tests code against its **intent**: what the documentation, schemas, docstrings, and specifications say it should do.

```
PHASE 0: DISCOVER INTENT
  Read CLAUDE.md, README, docs, docstrings, API schemas, existing tests
  → Build Intent Map (what the software promises to do)

PHASES 1-10: TEST AGAINST INTENT
  Every test answers: "Does this code fulfill the intent?"
```

## Quick Start

```bash
# Install the plugin
claude plugin add ./gs-qa

# Discover intent for the current project
/qa:discover

# Run a full QA sweep
/qa:sweep

# Sweep a specific project
/qa:project writer

# View the QA report
/qa:report
```

## Commands

| Command | Description |
|---------|-------------|
| `/qa:sweep` | Full autonomous QA sweep (all phases) |
| `/qa:project <name>` | Sweep a single project |
| `/qa:discover` | Run intent discovery only |
| `/qa:report` | Generate or view QA report |
| `/qa:baseline` | Create visual test baselines |
| `/qa:coverage` | Coverage gap analysis |
| `/qa:heal` | Fix failing tests |

## 11-Phase Pipeline

| Phase | What | Agent |
|-------|------|-------|
| 0 | Intent Discovery | qa-intent-discoverer |
| 1 | Static Analysis | (ruff/eslint/semgrep auto-detected) |
| 2 | Test Planning | qa-test-planner |
| 3 | Test Generation | qa-backend-engineer + qa-frontend-engineer |
| 4 | Quality Gate | qa-sentinel |
| 5 | Execution + Healing | qa-healer |
| 6 | Mutation Testing | mutmut/Stryker |
| 7 | Bug Fixing | qa-bug-fixer |
| 8 | Review | qa-reviewer |
| 9 | Visual QA | qa-visual |
| 10 | Reporting | qa-reporter |

## Stack Detection

gs-qa auto-detects your tech stack:
- **Languages**: Python, TypeScript, Go, Rust
- **Frameworks**: FastAPI, Django, Flask, Next.js, Express, Hono
- **Test Runners**: pytest, vitest, jest, Playwright, go test
- **Databases**: PostgreSQL, MongoDB, SQLite
- **Package Managers**: uv, poetry, pip, bun, pnpm, npm, yarn

## Agents

11 specialized agents coordinate the QA pipeline:

- **qa-orchestrator** (Opus) — Coordinates full sweeps, manages task queue
- **qa-intent-discoverer** (Sonnet) — Reads docs/code, builds Intent Map
- **qa-test-planner** (Sonnet) — Turns Intent Map into prioritized test plan
- **qa-backend-engineer** (Sonnet) — Writes pytest tests against intent
- **qa-frontend-engineer** (Sonnet) — Writes Playwright E2E tests
- **qa-sentinel** (Sonnet) — Quality gate, blocks bad tests
- **qa-healer** (Sonnet) — Executes tests, diagnoses and fixes failures
- **qa-bug-fixer** (Opus) — Fixes confirmed app bugs with verification
- **qa-reviewer** (Opus) — Fresh-context review of all output
- **qa-visual** (Sonnet) — Screenshot comparison, visual regression
- **qa-reporter** (Haiku) — Aggregates results into reports

## Key Innovation: The Intent Map

Instead of hardcoding project knowledge, gs-qa dynamically discovers intent from any codebase:

1. Reads all documentation (CLAUDE.md, README, docs/)
2. Maps architecture (routes, models, services, DB schemas)
3. Extracts specifications (docstrings, type hints, schemas, validation rules)
4. Studies existing tests (understand coverage + patterns)
5. Identifies ambiguities and asks clarifying questions
6. Outputs an Intent Map that drives all test generation

## License

MIT
