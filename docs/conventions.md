---
layout: default
title: Conventions
permalink: /docs/conventions/
---

# Conventions

This page records the conventions the codebase actually follows: the
module map of `R/`, the public API surface, the CLI dispatch contract,
the event-naming contract, and the code style.

## 1) Module map (`R/`)

`R/` is both the package source and the file set the CLI `source()`s at
startup. Domain logic lives in the module that owns it; a helper used
by only one module stays in that module, dot-prefixed.

**Shared infrastructure**

- `R/setup.R` — required-package list (`data.table`, `stringr`,
  `lubridate`, `readxl`, `jsonlite`) and the CLI's dependency
  check/auto-install path.
- `R/helpers.R` — cross-cutting utilities (safe conversions, ID
  cleaning, unit handling) and the geochemistry logger (`.logInit()`,
  `.log()`; 5 columns: `ts, level, file, event, message`).
- `R/eventLog.R` — the monitoring event logger, schema v3 (9 columns:
  `ts, scope, SiteID, HoleID, datetime, source, level, event, detail`),
  validated against the catalog `inst/events.csv`.
- `R/dbAudit-package.R` — package documentation skeleton and
  `globalVariables()` declarations.

**Geochemistry (certificate pipeline)**

- `R/parseLab.R` — lab certificate parsing (type A and type B).
- `R/parseAssay.R` — assay table parsing (type A and type B).
- `R/audit.R` — structure and value audits, including type-B method
  inference.
- `R/dbAudit.R` — the runner `auditGeochemistry()` (alias `DBAudit`),
  path defaults and deterministic assay-file selection.

**Piezometers (PCG, PCV)**

- `R/piezometerParse.R` — Excel parsers (Casagrande and vibrating-wire
  workbooks), manifest-driven.
- `R/piezometerBuild.R` — raw-to-database build.
- `R/piezometerAudit.R` — gate, census and audit checks, database
  products.
- `R/auditPiezometer.R` — the runner `auditPiezometer()`:
  parse -> gate -> database -> audit in one call.

**Inclinometers (INC)**

- `R/inclinometerParse.R` — CSV survey-export parser.
- `R/inclinometerBuild.R` — raw-to-database build.
- `R/inclinometerAudit.R` — structural audit checks.
- `R/auditInclinometer.R` — the runner `auditInclinometer()`.

**Reference only**

- `R/legacy/` — snapshots of the pre-consolidation layout. Never
  sourced by normal runs; kept for comparison and history.

## 2) Public API vs. internals

`NAMESPACE` is the authority on the public surface. It exports exactly
four entrypoints, one per pipeline contract plus the historical alias:

- `auditGeochemistry()` — canonical geochemistry runner.
- `DBAudit()` — alias of `auditGeochemistry()`, kept for the legacy
  contract.
- `auditPiezometer()` — piezometer runner (PCG, PCV).
- `auditInclinometer()` — inclinometer runner (INC).

Everything else is internal and carries a leading dot
(`.chooseAssayFile()`, `.logEvent()`, `.checkRawDBKeys()`, ...). The
dot is the house marker for "implementation detail"; it does not
enforce privacy — exports do. Two dotted names are conversion helpers,
not S3 methods: `.as.numeric()` and `.as.Date()`.

## 3) CLI dispatch

`DBAudit` (the Rscript entrypoint, invoked through the `dbaudit`
wrapper) dispatches on one leading positional token:

```
dbaudit [geochemistry|piezometer|inclinometer] --project <DATA_ROOT> [OPTIONS]
```

- A leading non-flag token selects the pipeline contract; an unknown
  token is a hard error.
- No token, or a leading flag, keeps the legacy geochemical invocation
  unchanged: `dbaudit --project <DATA_ROOT>` behaves exactly as it did
  before subcommands existed.
- Each branch parses its own option set (see `dbaudit --help` for the
  per-contract options) and ends in exactly one exported runner call.
- `--help`, `--version` and `--check` exit early, before any package
  loading or auto-install.

The wrapper resolves the installation root through `DBAUDIT_HOME` (set
by `bin/dbaudit`) or, failing that, from the script's own path; there
is no working-directory requirement.

## 4) Event naming

Two event vocabularies coexist, deliberately:

- **Monitoring domains (PCG, PCV, INC)**: events are a single uppercase
  word (`COMMA`, `UNREADABLE`, `MISLABELED`, `REDATED`, `DUPLICATED`,
  `MIXED`, `UNITLESS`, `MISCOUNTED`, `MALFORMED`, `INCOMPLETE`,
  `MISSING`, `MISCLOSURE`, `DRY`, `START`, `DONE`). The catalog
  `inst/events.csv` is the contract: every emission is validated
  against the key `(event, scope)`, and a pair that does not resolve to
  exactly one catalog row stops the run. The catalog level is a
  default the emitter may override — the same event can fire as
  WARNING when the pipeline resolved the fact and as ERROR when it
  could not (canonical case: `MISLABELED`). Anything free-form goes in
  the `detail` column, never into the event name.
- **Geochemistry**: the historical `SCREAMING_SNAKE` event codes
  (`PARSE_OK`, `WRONG_VALUE`, `METHOD_INFERRED`, ...) with the
  5-column logger. This vocabulary is part of the legacy contract and
  is not migrated.

## 5) Code style

- **`data.table` is the table idiom.** The package imports it wholesale
  (`import(data.table)` in `NAMESPACE`); all file I/O goes through
  `fread()`/`fwrite()`; aggregation uses `[, .N, by/keyby = ...]`
  expressions. Reference semantics are handled explicitly: code copies
  (`data.table::copy()`) when the caller must keep the original, and
  the tests pin that contract where it matters (e.g. the census leaves
  the caller's raw table untouched).
- **Naming.** Functions are `camelCase` verbs (`auditPiezometer`,
  `parseLabData`); internals add the leading dot. Path- and file-role
  parameters use dotted lowercase (`project.path`, `log.file`,
  `lab.dir.name`). Stable locals are `PascalCase` (`Catalog`, `Truth`,
  `Log`); short-lived vessels use the compact uppercase vocabulary
  (`DT`, `AUX`, `OUT`, `FILES`); loop indices are single letters. No
  `snake_case` for project-owned identifiers.
- **Comments** record contracts, rulings and deliberate deviations
  (with dates where a ruling applies), not narration of the code.
