---
layout: default
title: Logging
permalink: /docs/logging/
---

# Logging

Project runs write a structured CSV log to:

- `project/<PROJECT>/data/proc/log.csv`

Tests write:

- `test-A/log.csv`
- `test-B/log.csv`

## Log schema

Columns:

- `ts`: timestamp (`YYYY-MM-DD HH:MM:SS`)
- `level`: `INFO`, `WARNING`, `ERROR`
- `file`: input file path or a stable logical identifier (e.g. `data/proc/client.csv` for audit events)
- `event`: machine-friendly event code
- `message`: free-text details (often contains `jobID=...`, `sampleID=...`, etc.)

## Reading + filtering with data.table

Note: the severity column is named `level` (not `ID`).

```r
library(data.table)
log <- fread("project/<PROJECT>/data/proc/log.csv")

# All errors
log[level == "ERROR"]

# Count by event
log[, .N, by = .(level, event)][order(level, -N)]

# Filter a single event
log[event == "PARSE_ERROR"]

# Filter audit events (the audit uses a stable file id)
log[file == "data/proc/client.csv"]
```

## Event reference (categories)

### 1) Lab parsing (`R/parseLab.R`)

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

### 2) Assay/client parsing (`R/parseAssay.R`)

- `CLIENT_FILE_START` (INFO): started parsing the assay CSV
- `CLIENT_PARSE_OK` (INFO): parsing completed (message includes `rows=...; jobIDs=...; sampleIDs=...`)
- `CLIENT_PARSE_ERROR` (ERROR): parsing failed

Input schema checks:

- `CLIENT_MISSING_COLUMNS` (ERROR): required columns missing
- `CLIENT_EMPTY_JOBID` (WARNING): empty `jobID` count
- `CLIENT_EMPTY_SAMPLEID` (WARNING): empty `sampleID` count

### 3) Structure audit (`auditStructure` in `R/audit.R`)

- `JOBID_MISMATCH` (WARNING): some client jobIDs not found in lab
- `JOBID_FIXED` (INFO): systematic jobID prefix/suffix fix inferred/applied
- `WRONG_JOBID` (ERROR): remaining unmatched jobID (one row per jobID)

- `SAMPLEID_MISMATCH` (WARNING): some client sampleIDs not found in lab (for matched jobIDs)
- `SAMPLEID_FIXED` (INFO): systematic sampleID prefix/suffix fix inferred/applied
- `WRONG_SAMPLEID` (ERROR): remaining unmatched sampleID (one row per sampleID)

- `SAMPLEID_MULTI_JOBID` (WARNING): sampleIDs found under multiple lab jobIDs (excluded from jobID inference)
- `STRUCTURE_APPLIED` (INFO): summary of applied structural fixes

### 4) Numeric value audit (`auditValues` in `R/audit.R`)

- `VALUE_MISMATCH` (WARNING): mismatch summary (message includes `count=...; tol=...`)
- `VALUE_FIXED` (INFO): per-row fix applied (only when `fix=TRUE`)
- `WRONG_VALUE` (ERROR): per-row mismatch (only when `fix=FALSE`)
- `VALUES_APPLIED` (INFO): summary of applied value fixes

### 5) Type-B method inference + DL/tag checks (`auditValuesB` in `R/audit.R`)

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

### 6) Captured warnings (generic)

- `WARNING` (WARNING): a warning emitted by R during parsing (message is the warning text)

## Practical examples

### Find all type-B inference failures

```r
log <- fread("project/<PROJECT>/data/proc/log.csv")
log[event %chin% c("METHOD_UNDETERMINED", "METHOD_AMBIGUOUS")]
```

### Filter errors for a specific jobID

Most error messages include `jobID=...`:

```r
log <- fread("project/<PROJECT>/data/proc/log.csv")
log[level == "ERROR" & grepl("jobID=LAB123", message, fixed = TRUE)]
```
