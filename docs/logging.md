---
layout: default
title: Logging
permalink: /docs/logging/
---

# Logging

dbAudit writes two structured CSV logs, one per pipeline family. Both
loggers are current; each domain keeps its own schema and event
vocabulary.

| Pipeline | Log file | Schema | Event names |
|---|---|---|---|
| Geochemistry — `dbaudit --project`, `auditGeochemistry()` | `<project>/proc/log.csv` | 5 columns | `SCREAMING_SNAKE` codes |
| Monitoring — `dbaudit piezometer` / `dbaudit inclinometer`, `auditPiezometer()`, `auditInclinometer()` | `<project>/audit/log.csv` | 9 columns | single-word uppercase events from the catalog `inst/events.csv` |

The bare invocation `dbaudit --project <DATA_ROOT>` (no subcommand)
keeps the historical geochemistry contract and writes the geochemistry
log.

Both logs store severity under the same contract. The stored `level` is
primary — it records what the pipeline established about the fact, not
a category recomputed by the reader:

- `INFO` — process marks and site conditions; nothing wrong with the
  data.
- `WARNING` — a data problem occurred and the pipeline **resolved** it;
  the database is consistent; the original value stays on record; the
  source practice still needs correction.
- `ERROR` — a data problem occurred and could **not** be resolved;
  human action is required. `level == "ERROR"` is the work list filter.

## Geochemistry log

Path: `<project>/proc/log.csv`, written by the geochemistry pipeline
(`R/parseLab.R`, `R/parseAssay.R`, `R/audit.R`).

Columns:

- `ts`: timestamp (`YYYY-MM-DD HH:MM:SS`)
- `level`: `INFO`, `WARNING`, `ERROR`
- `file`: input file path or a stable logical identifier (e.g.
  `data/proc/client.csv` for audit events)
- `event`: machine-friendly event code (`SCREAMING_SNAKE`)
- `message`: free-text details (often contains `jobID=...`,
  `sampleID=...`, etc.)

### Reading + filtering with data.table

Note: the severity column is named `level` (not `ID`).

```r
library(data.table)
log <- fread("<project>/proc/log.csv")

# All errors
log[level == "ERROR"]

# Count by event
log[, .N, by = .(level, event)][order(level, -N)]

# Filter a single event
log[event == "PARSE_ERROR"]

# Filter audit events (the audit uses a stable file id)
log[file == "data/proc/client.csv"]
```

### Event reference (categories)

#### 1) Lab parsing (`R/parseLab.R`)

- `FILE_START` (INFO): started parsing a certificate file
- `PARSE_OK` (INFO): parsing completed (message includes `rows=...`)
- `PARSE_ERROR` (ERROR): parsing failed (message includes error + `jobID=...`)
- `UNKNOWN_FORMAT` (ERROR): lab format detection failed (`format=auto`)

Diagnostics:

- `DIAG_INDEX_EMPTY` (WARNING): empty/malformed analyte identifiers in the header
- `DUPLICATE_VID` (ERROR): duplicated analyte identifiers (`valueID`) in the header
- `SAMPLEID_NOT_UNIQUE` (ERROR): duplicated sample rows detected
- `SAMPLES_DECLARED_MISMATCH` (WARNING): header sample count differs from observed
- `EXTRA_COLS_DROPPED` (WARNING): extra trailing columns were dropped to match expected schema
- `MISSING_COLS_PADDED` (WARNING): missing expected columns were padded with NA

#### 2) Assay/client parsing (`R/parseAssay.R`)

- `CLIENT_FILE_START` (INFO): started parsing the assay CSV
- `CLIENT_PARSE_OK` (INFO): parsing completed (message includes `rows=...; jobIDs=...; sampleIDs=...`)
- `CLIENT_PARSE_ERROR` (ERROR): parsing failed

Input schema checks:

- `CLIENT_MISSING_COLUMNS` (ERROR): required columns missing
- `CLIENT_EMPTY_JOBID` (WARNING): empty `jobID` count
- `CLIENT_EMPTY_SAMPLEID` (WARNING): empty `sampleID` count

#### 3) Structure audit (`auditStructure` in `R/audit.R`)

- `JOBID_MISMATCH` (WARNING): some client jobIDs not found in lab
- `JOBID_FIXED` (INFO): systematic jobID prefix/suffix fix inferred/applied
- `WRONG_JOBID` (ERROR): remaining unmatched jobID (one row per jobID)

- `SAMPLEID_MISMATCH` (WARNING): some client sampleIDs not found in lab (for matched jobIDs)
- `SAMPLEID_FIXED` (INFO): systematic sampleID prefix/suffix fix inferred/applied
- `WRONG_SAMPLEID` (ERROR): remaining unmatched sampleID (one row per sampleID)

- `SAMPLEID_MULTI_JOBID` (WARNING): sampleIDs found under multiple lab jobIDs (excluded from jobID inference)
- `STRUCTURE_APPLIED` (INFO): summary of applied structural fixes

#### 4) Numeric value audit (`auditValues` in `R/audit.R`)

- `VALUE_MISMATCH` (WARNING): mismatch summary (message includes `count=...; tol=...`)
- `VALUE_FIXED` (INFO): per-row fix applied (only when `fix=TRUE`)
- `WRONG_VALUE` (ERROR): per-row mismatch (only when `fix=FALSE`)
- `VALUES_APPLIED` (INFO): summary of applied value fixes

Notes:
- `tol` is configurable via the runner CLI flag `--tol` (default: `0.05`).

#### 5) Type-B method inference + DL/tag checks (`auditValues(format="B")` in `R/audit.R`)

Method inference:

- `METHOD_INFERRED` (INFO): inferred a unique `standardID` for `(jobID, elementID, unitID)`
- `METHOD_UNDETERMINED` (ERROR): insufficient evidence to pick a method
- `METHOD_AMBIGUOUS` (ERROR): conflicting evidence (no unique winner)

Missing groups/rows:

- `CLIENT_ANALYTE_NOT_IN_LAB` (WARNING): assay groups missing in lab index
- `MISSING_LAB_ANALYTE` (ERROR): per-group missing analyte in lab
- `CLIENT_ROWS_NOT_IN_LAB` (WARNING): assay rows missing in lab for the inferred method
- `MISSING_LAB_VALUE` (ERROR): per-row missing lab value
- `MISSING_LAB_VALUE_TRUNCATED` (ERROR): too many missing rows; logging was truncated

Tag + detection limit consistency:

- `TAGDL_MISMATCH` (WARNING): tag mismatch summary
- `WRONG_TAGDL` (ERROR): per-row tag mismatch
- `WRONG_MIN_DL` (ERROR): owner declared `<` but value != `minDL`
- `WRONG_MAX_DL` (ERROR): owner declared `>` but value != `maxDL`

#### 6) Captured warnings (generic)

- `WARNING` (WARNING): a warning emitted by R during parsing (message is the warning text)

### Practical examples

Find all type-B inference failures:

```r
log <- fread("<project>/proc/log.csv")
log[event %chin% c("METHOD_UNDETERMINED", "METHOD_AMBIGUOUS")]
```

Filter errors for a specific jobID (most error messages include
`jobID=...`):

```r
log <- fread("<project>/proc/log.csv")
log[level == "ERROR" & grepl("jobID=LAB123", message, fixed = TRUE)]
```

## Monitoring log

Path: `<project>/audit/log.csv`, written by the monitoring runners
(`R/eventLog.R`). One record per observed fact.

Columns:

- `ts`: timestamp (`YYYY-MM-DD HH:MM:SS`)
- `scope`: what the fact is about — `run`, `file`, `survey`, `record`
  (closed set)
- `SiteID`, `HoleID`: instrument identity, when the fact has one
- `datetime`: the reading's date label, when the fact has one
- `source`: the source file, sheet, or product table the fact was
  observed in
- `level`: `INFO`, `WARNING`, `ERROR` (stored severity, contract above)
- `event`: single-word uppercase event name from the catalog
- `detail`: free-text specifics (`ID=...; count=...`, repaired values,
  affected columns)

Each runner **reinitializes** `audit/log.csv` at the start of its audit
stage. Running `auditInclinometer()` after `auditPiezometer()` on the
same project leaves the log with only the inclinometer rows; a combined
PCG/PCV/INC run that needs one shared log belongs to an application
runner, not to chained engine runners.

### The event catalog

Every emission is validated against `inst/events.csv`. The catalog key
is the pair `(event, scope)`: the same single-word event can mean
different facts at different scopes (e.g. `DUPLICATED`). Emitting a
pair that does not resolve to exactly one catalog row **stops the
run**. Beyond the columns below, each catalog row carries bilingual
(EN/ES) meaning, expected-action, and impact texts.

The catalog `level` is a **default the emitting check may override**:
the same event is emitted at `WARNING` when the pipeline resolved the
fact and at `ERROR` when it could not (canonical case: `MISLABELED`,
below).

`class` groups events by the nature of the problem:

- `gross` — an individually wrong reading or identity;
- `systematic` — a consistent distortion across records (units, datum);
- `conformance` — the source does not meet the declared format
  (missing columns, header fields, counts);
- `condition` — a site condition, not a data problem;
- `run` — run markers.

The table below is derived from `inst/events.csv` (levels are the
catalog defaults):

| Event | Scope | Class | Default level | Flag | Meaning |
|---|---|---|---|---|---|
| `COMMA` | record | gross | WARNING |  | Decimal-comma value corrected on entry |
| `UNREADABLE` | record | gross | ERROR |  | Reading not admitted: unreadable value |
| `MISLABELED` | file, survey | gross | WARNING |  | Instrument identity in the file content disagrees with the filename |
| `REDATED` | survey | gross | ERROR |  | Same field survey published under different dates |
| `DUPLICATED` | survey | gross | WARNING |  | Duplicate identical survey files consolidated |
| `DUPLICATED` | record | gross | ERROR |  | Readings the sheet identity cannot distinguish (same instrument and date; hour and stage when declared) |
| `MIXED` | file, survey | systematic | INFO |  | Mixed units across source sheets |
| `UNITLESS` | file | conformance | ERROR |  | Units not declared for a measured variable |
| `MISCOUNTED` | survey | conformance | ERROR |  | Declared depth count disagrees with observed |
| `MALFORMED` | file | conformance | ERROR |  | Required columns missing in a source or product table |
| `INCOMPLETE` | file, survey | conformance | ERROR |  | Required header field or value missing in a source sheet |
| `MISSING` | file | conformance | ERROR |  | Reading present in the field files but absent from the database (or the reverse) with no recorded reason |
| `MISCLOSURE` | record | systematic | ERROR |  | Declared water depth fails geometric closure against the sensor geometry in every known epoch |
| `DRY` | record | condition | INFO | `D` | Well dry at measurement; no level value |
| `START` | run | run | INFO |  | Audit run started |
| `DONE` | run | run | INFO |  | Audit run completed |

Notes on the table:

- **`MISLABELED` is emitted at two levels.** The catalog default is
  `WARNING`: the identity was repaired from systematic evidence (the
  filename key wins; the repair is recorded). A filename/content
  identity conflict the gate could not repair is emitted at `ERROR`:
  the readings may belong to another instrument and the conflict stays
  on the work list.
- **`DUPLICATED` has two catalog rows.** At `survey` scope (`WARNING`)
  byte-identical survey files were consolidated into one; at `record`
  scope (`ERROR`) two readings the sheet's own identity columns cannot
  distinguish remain in the database and statistics may double-count.
- **`DRY` is never emitted to the log.** The dry condition materializes
  as flag `D` in `audit/PZ.data.csv`; the catalog row documents the
  taxonomy and the flag letter.
- **`MISCLOSURE` is catalogued but suspended.** No check emits it; it
  will fire only after the row-local closure redesign. The catalog row
  reserves the name so the taxonomy does not drift.

### The gate sink

Record-scope gate findings are not written to `log.csv`. The gate
writes them to `audit/<ID>.reject.csv` together with the full data row
(source path, sheet, row): `COMMA` (repaired, `WARNING`), `UNREADABLE`
(rejected, `ERROR`) and the repaired-identity `MISLABELED` (`WARNING`)
records live there. See
[Monitoring audits]({{ "/docs/audit-monitoring/" | relative_url }}).

### Reading + filtering with data.table

```r
library(data.table)
log <- fread("<project>/audit/log.csv")

# The work list
log[level == "ERROR"]

# Count by event
log[, .N, keyby = .(level, event)]

# The gate sink (record-scope rejections and repairs)
sink <- fread("<project>/audit/PCG.reject.csv")
sink[, .N, keyby = .(level, event)]
```
