---
layout: default
title: Parsers
permalink: /docs/parsers/
---

# Parsers

dbAudit ships two parser families:

- **Geochemistry** (this page): laboratory certificates and assay (client) tables, CSV inputs, two certificate models (type A / type B). They run inside the geochemistry contract (`dbaudit --project <DATA_ROOT>` or `auditGeochemistry()`).
- **Monitoring** (one page per instrument): field-monitoring sources in Excel and CSV, driven by a versioned JSON parse manifest. They run inside `dbaudit piezometer` and `dbaudit inclinometer`.

None of the parser functions named below is exported: `NAMESPACE` exports the four runners only (`DBAudit`, `auditGeochemistry`, `auditPiezometer`, `auditInclinometer`). The parser names are internal reference points into `R/`, useful for reading logs and source, not a public API.

## Monitoring parsers

| Page | Instrument | Input |
|---|---|---|
| [PCG parser]({{ "/docs/parser-pcg/" | relative_url }}) | Casagrande piezometer | Excel workbook, one per piezometer |
| [PCV parser]({{ "/docs/parser-pcv/" | relative_url }}) | Vibrating-wire piezometer | Multi-sheet Excel workbook, one per borehole |
| [INC parser]({{ "/docs/parser-inc/" | relative_url }}) | Inclinometer | `;`-delimited CSV exports (native `.gkn`/`.dux` files are rejected) |
| [Parse manifest]({{ "/docs/manifest/" | relative_url }}) | — | JSON label catalog that drives PCG/PCV/INC recognition |

The monitoring parsers read `source/<ID>/<SiteID>/…` and write per-key tables under `raw/<ID>/`; the runner deletes and regenerates `raw/<ID>` on every run. Layout details are in [Typical project layout]({{ "/docs/project-layout/" | relative_url }}).

## Geochemistry parsers

### Lab certificates

#### Type A (original)
- Function: `parseLabDataA()` (kept as the type-A reference implementation)
- Layout: classic certificate where analytes are encoded as `valueID = elementID_standardID_unitID` and the header block is fixed.

#### Universal
- Function: `parseLabData(path, format=c("auto","A","B"), ...)`
- When `format="A"`, the universal parser routes each file to the type-A implementation (`R/parseLab.R:174`).
- When `format="B"`, it parses the type-B certificate layout (see below).
- When `format="auto"`, it detects per-file format.

#### Type B
Type-B lab certificates may contain **duplicated analytes** (same `elementID` and `unitID`) across multiple `standardID`s in the same certificate.
The parser:
- reads the analyte header from the `ELEMENT` row (analytes start later in the row),
- reads `Method`/`Units`/`Det. Lim`/`Upper Lim` rows to build `standardID`, `unitID`, `minDL`, `maxDL`,
- pivots the certificate into long format and preserves detection limit tags (`<`/`>` as `tagDL`).

### Assay (client) tables

#### Type A (original)
- Function: `parseAssayDataA()` (kept as the type-A reference implementation)
- Layout: analyte columns are encoded as `element_standard_unit`.

#### Universal
- Function: `parseAssayData(input.file, format=c("auto","A","B"), ...)`
- When `format="A"`, the universal parser routes the file to the type-A implementation (`R/parseAssay.R:80`).
- When `format="B"`, it parses an assay table where analyte columns look like `Element_ppm` / `Element_pct`.

#### Type B
Type-B assay tables do **not** declare `standardID` (method) explicitly.
The parser:
- extracts analyte columns matching `^[^_]+_(ppm|pct)$`,
- normalizes `unitID` (e.g., `pct`, `ppm`),
- requires the four fixed job columns `Labjob_CuT`, `Labjob_Mo`, `Labjob_CuCN`, `Labjob_CuS` (`R/parseAssay.R:112`) and assigns `jobID` per analyte from them — `Labjob_CuT` by default, `Labjob_Mo` for Mo, `Labjob_CuCN` for CuCn/CuCN, `Labjob_CuS` for CuS (`R/parseAssay.R:150-153`). This wiring is specific to the Cu/Mo assay contract, not a generic column mapping,
- sets `standardID := NA_character_` (method must be inferred later from lab + `index.csv`),
- parses `<`/`>` prefixes into `tagDL` and numeric `value`.

### Outputs
Both lab and assay parsers write long-format tables:
- `lab.csv`: `(jobID, sampleID, elementID, standardID, unitID, tagDL, value, ...)`
- `index.csv`: one row per analyte per certificate, including `minDL/maxDL` and `standardID`
- `client.csv`: `(jobID, sampleID, elementID, standardID, unitID, tagDL, value)` (for type B, `standardID` starts as `NA`)

### Regression evidence
The versioned regression suite is `tests/testthat/test-synthetic-fixtures.R`: it runs the full geochemistry pipeline on the two shipped synthetic certificate models (`tests/testthat/fixtures/synthetic-A` and `synthetic-B`) and pins the md5 of `lab.csv`, `index.csv` and `client.csv`, plus the `(level, event)` log counts. A change in either parser's output fails that suite. Regenerating the fixtures is an intentional contract change and re-records the golden values.
