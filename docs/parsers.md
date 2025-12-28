---
layout: default
title: Parsers
permalink: /docs/parsers/
---

# Parsers
The project exposes *universal* parsers for laboratory certificates and assay (client) tables.

## Lab certificates
### Type A (original)
- Function: `parseLabDataA()` (kept for regression)
- Layout: classic certificate where analytes are encoded as `valueID = elementID_standardID_unitID` and the header block is fixed.

### Universal
- Function: `parseLabData(path, format=c("auto","A","B"), ...)`
- When `format="A"`, the universal parser uses the type-A implementation and is verified against the original.
- When `format="B"`, it parses the type-B certificate layout (see below).
- When `format="auto"`, it detects per-file format.

### Type B
Type-B lab certificates may contain **duplicated analytes** (same `elementID` and `unitID`) across multiple `standardID`s in the same certificate.
The parser:
- reads the analyte header from the `ELEMENT` row (analytes start later in the row),
- reads `Method`/`Units`/`Det. Lim`/`Upper Lim` rows to build `standardID`, `unitID`, `minDL`, `maxDL`,
- pivots the certificate into long format and preserves detection limit tags (`<`/`>` as `tagDL`).

## Assay (client) tables
### Type A (original)
- Function: `parseAssayDataA()` (kept for regression)
- Layout: analyte columns are encoded as `element_standard_unit`.

### Universal
- Function: `parseAssayData(input.file, format=c("auto","A","B"), ...)`
- When `format="A"`, the universal parser uses the type-A implementation and is verified against the original.
- When `format="B"`, it parses an assay table where analyte columns look like `Element_ppm` / `Element_pct`.

### Type B
Type-B assay tables do **not** declare `standardID` (method) explicitly.
The parser:
- extracts analyte columns matching `^[^_]+_(ppm|pct)$`,
- normalizes `unitID` (e.g., `pct`, `ppm`),
- assigns `jobID` from `Labjob_*` columns (per-analyte mapping),
- sets `standardID := NA_character_` (method must be inferred later from lab + `index.csv`),
- parses `<`/`>` prefixes into `tagDL` and numeric `value`.

## Outputs
Both lab and assay parsers write long-format tables:
- `lab.csv`: `(jobID, sampleID, elementID, standardID, unitID, tagDL, value, ...)`
- `index.csv`: one row per analyte per certificate, including `minDL/maxDL` and `standardID`
- `client.csv`: `(jobID, sampleID, elementID, standardID, unitID, tagDL, value)` (for type B, `standardID` starts as `NA`)

## Regression guarantee (type A)
`project/test-A/run.R` runs:
- original type-A parsers, and
- universal parsers with `format="A"`

and asserts that `index.csv`, `lab.csv`, and `client.csv` are identical (set equality).