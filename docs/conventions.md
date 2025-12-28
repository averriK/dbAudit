---
layout: default
title: Conventions
permalink: /docs/conventions/
---

# Conventions
This repo follows a strict set of conventions to keep the codebase predictable and to avoid accidental API/behavior changes.

## 1) Public vs internal functions
### Public entrypoints (OK to call from outside)
Public functions have **no leading dot**.
Examples:
- `DBAudit()` (runner)
- `parseLabData()`, `parseLabDataA()`
- `parseAssayData()`, `parseAssayDataA()`, `parseAssayDataB()`
- `auditStructure()`, `auditValues()`, `auditValuesB()`

### Internal helpers (not part of the public API)
Internal helpers start with a **leading dot** (`.`) and are not intended to be used externally.
Examples:
- `.logInit()`, `.log()`
- `.drop()`
- `.cleanId()`
- `.reconcileColumns()`
- `.detectAssayFormat()`
- `.chooseAssayFile()` (runner-local helper)

Allowed “dot” exceptions that are still internal:
- `.as.numeric()`
- `.as.Date()`

Rationale:
- The dot prefix makes it obvious which functions are implementation details.
- It reduces the risk of name clashes and accidental reliance on internals.

## 2) Naming rules
- No `snake_case` for new identifiers.
- Prefer **camelCase** for function names (`auditStructure`, `inferMethodVotesDlB`).
- Prefer dot-style variable names for paths and I/O (`log.file`, `data.file`, `index.file`, `input.file`).
- Avoid “ephemeral” chained temporaries in production code; keep transformations readable.

## 3) File placement rules (what goes where)
### `R/helpers.R`
Put here:
- Cross-cutting utilities used by multiple modules (logging, safe conversions, small general helpers).

Do NOT put here:
- Pipeline-specific heuristics that only one module uses.

### Module files in `R/*.R`
Put domain logic in the module that owns it:
- `R/parseLab.R`: lab certificate parsing
- `R/parseAssay.R`: assay parsing
- `R/audit.R`: audit logic
- `R/dbAudit.R`: runner orchestration (paths, execution order, deterministic assay selection)

Module-local helpers:
- If a helper is only used inside one module, keep it in that module and dot-prefix it.
  Example: `.chooseAssayFile()` lives in `R/dbAudit.R`.

### CLI scripts (repo root)
- `DBAudit` is the CLI entrypoint.
- It should only:
  1) validate the working directory (repo root),
  2) parse CLI flags (e.g. `--project`),
  3) `source()` canonical R modules,
  4) call exactly one public entrypoint (`DBAudit(project.path=...)`).

### `R/legacy/`
- Reference-only snapshots and deprecated wrappers.
- Must NOT be sourced by normal runs.
- Used only for comparison/history.

### `R/wip.R`
- Experimental work-in-progress.
- Must not be required by tests or the CLI.
