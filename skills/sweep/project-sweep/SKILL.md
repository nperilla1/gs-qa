---
name: project-sweep
description: "Sweep a single project directory with the full QA pipeline. Focused version of full-sweep that targets one project. Use when asked to 'sweep <project>', 'test <project>', 'qa project', 'qa:project', 'run tests for <name>', or 'sweep this project'."
allowed-tools: Agent, Read, Grep, Glob, Bash, Write, Edit, TaskCreate, TaskUpdate, TaskList, AskUserQuestion
---

# Project Sweep

You are running a focused QA sweep on a single project. This is the same 11-phase pipeline as full-sweep, but scoped to one project directory.

## Target Project
$ARGUMENTS
(If no specific project given, use the current working directory)

## Project Resolution

Resolve the target to an absolute project directory path:

1. If `$ARGUMENTS` is an absolute path, use it directly
2. If it's a relative path, resolve from the current working directory
3. If it's a project name (e.g., "writer", "watcher"), search for it:
   ```bash
   find . -maxdepth 3 -name "pyproject.toml" -o -name "package.json" | xargs grep -l "<project_name>" 2>/dev/null
   ```
4. If ambiguous, ask the user with AskUserQuestion

Verify the project exists:
```bash
ls <project_path>/pyproject.toml 2>/dev/null || ls <project_path>/package.json 2>/dev/null || echo "No project file found"
```

## Execution

Once the project directory is resolved, execute the full 11-phase pipeline exactly as described in the full-sweep skill, but scoped entirely to this single project.

### Phase 0: Stack Detection
```bash
cd <project_path> && bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh
```

### Phase 1: Intent Discovery
Discover intent for `<project_path>` only. Write `intent-map.json` to the project root.

### Phase 2: Static Analysis
Run linters/type checkers only on `<project_path>` source files.

### Phase 3: Test Planning
Plan tests based on the project's intent map. Write `test-plan.json` to the project root.

### Phase 4: Test Generation
Generate tests only for this project. Respect existing test conventions found in the project.

### Phase 5: Quality Gate
Audit all generated test files against the quality rubric.

### Phase 6: Test Execution + Healing
Run tests scoped to this project only:
```bash
# Python
python -m pytest <project_path>/tests -v --tb=short

# TypeScript
npx jest --roots <project_path>
npx playwright test <project_path>/tests
```

### Phase 7: Mutation Testing
Mutate only this project's source files:
```bash
# Python
mutmut run --paths-to-mutate=<project_path>/src --tests-dir=<project_path>/tests
```

### Phase 8: Bug Fixing
Fix bugs found in this project only. Max 3 attempts per bug.

### Phase 9: Review
Review all generated tests and fixes for this project.

### Phase 10: Reporting
Write `qa-report.md` to the project root, covering only this project.

## Task Tracking

Create tasks scoped to this project:

```
Task: "QA <project>: Stack Detection"
Task: "QA <project>: Intent Discovery"        → blocked by Stack Detection
Task: "QA <project>: Static Analysis"          → blocked by Stack Detection
Task: "QA <project>: Test Planning"            → blocked by Intent Discovery
Task: "QA <project>: Test Generation"          → blocked by Test Planning
Task: "QA <project>: Quality Gate"             → blocked by Test Generation
Task: "QA <project>: Test Execution"           → blocked by Quality Gate
Task: "QA <project>: Mutation Testing"         → blocked by Test Execution
Task: "QA <project>: Bug Fixing"              → blocked by Test Execution
Task: "QA <project>: Review"                  → blocked by Test Execution, Mutation, Bug Fixing
Task: "QA <project>: Report"                  → blocked by Review
```

## Existing Test Integration

Before generating new tests, check what already exists:
1. Find existing test files and read them
2. Understand the existing fixture hierarchy (conftest.py files)
3. Do NOT overwrite existing tests — only add new test files
4. Follow the existing naming conventions and patterns
5. Reuse existing factories, fixtures, and helpers

## Rules

- Scope everything to the target project — do not touch other projects
- Respect existing test infrastructure — extend, do not replace
- If the project already has a conftest.py, read it and use its fixtures
- Write new test files with names that do not conflict with existing tests
- Report progress after each phase
- Budget limits are the same as full-sweep
