---
name: qa:project
description: "Sweep a single project with the full QA pipeline. Usage: /qa:project <project-name>"
---

# /qa:project -- Single Project QA Sweep

You are running a full QA sweep on a specific project. This is the targeted version of `/qa:sweep`.

## Arguments

`$ARGUMENTS` should contain the project name (e.g., `writer`, `watcher`, `advertiser`, `emailer`, `sites`).

If no argument is provided, list available projects and ask the user to choose:
```bash
ls -d /Users/nicolasperilla/Documents/gs_projects/gs-production-v2/*/pyproject.toml 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {}
```

## Project Resolution

1. Parse the project name from `$ARGUMENTS`
2. Look for the project directory at:
   - `./[project-name]/` (relative to gs-production-v2)
   - `/Users/nicolasperilla/Documents/gs_projects/gs-production-v2/[project-name]/`
3. If not found, report an error and list available projects
4. Verify the project has a `pyproject.toml` or `package.json`

## Execution

1. `cd` into the project directory
2. Read the project's `CLAUDE.md` if it exists for project-specific conventions
3. Invoke the `full-sweep` skill scoped to this project
4. All QA artifacts are saved within the project directory

## Phase Customization

The standard sweep phases apply, but with project-specific adjustments:

- **Python projects** (pyproject.toml): Use pytest, ruff, mypy
- **TypeScript projects** (package.json): Use vitest/jest, biome, tsc
- **Mixed projects**: Run both pipelines

## Reporting

Report results scoped to the single project:

```
PROJECT QA: [project-name]
==========================
Directory: [path]
Stack: [Python 3.12 / TypeScript / etc.]
Duration: [time]
Health Score: [X/100]

Phase Results:
  Intent Discovery: X behaviors found
  Static Analysis:  X issues (X fixed)
  Test Generation:  X tests created
  Test Execution:   X pass, X fail
  Mutation Testing: X% kill rate
  Bugs Fixed:       X/Y

Full report: [project-name]/qa-report.md
```

## Rules

- Scope all operations to the single project directory
- Do not modify files outside the project directory
- Respect the project's existing test structure and conventions
- If the project has a CLAUDE.md, follow its instructions for testing
