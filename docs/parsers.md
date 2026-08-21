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
- Function: `parseLabDataA()` (kept as the type-A reference implementation). It and the universal parser share the same per-file implementation, so both accept exactly the same layouts.
- Layout: classic certificate where analytes are encoded as `valueID = elementID_standardID_unitID`.
- Block anchoring: the file is read as one grid and the blocks are located from the `SAMPLE` row in the first column, never from fixed line numbers. Metadata is every row above the method row; the INDEX block is the five rows running from one row above `SAMPLE` to three rows below it (method, `SAMPLE`, `DESCRIPTION`, `MIN DETECTION`, `MAX DETECTION`, matched by label); sample data is everything below `MAX DETECTION`.
- Failure: a file with no `SAMPLE` row in the first column, with fewer than two rows above it, or with no data row below `MAX DETECTION`, stops with `INDEX block not found: no SAMPLE row in the first column`. A five-row window whose labels do not match stops with `Unexpected INDEX header: ...`. Either way the certificate is dropped whole and logged as `PARSE_ERROR`.

##### Accepted header sub-variant

The header block is **not** a fixed six rows. Certificates from the same laboratory also arrive in a second header shape, which the parser accepts without configuration:

| Feature | Standard layout | Sub-variant |
|---|---|---|
| Key punctuation | `LabjobNo:` | `LabjobNo :` (space before the colon) |
| Extra metadata rows | — | `CLIENT :`, `PROJECT :`, `CERTIFICATE COMMENTS :` |
| Multi-line values | — | a quoted comment spanning several raw lines |
| Method row | first cell empty | first cell reads `METHOD` |
| Dates | `05-Jan-2025` | `18/02/2025` |

Extra metadata rows are read and ignored: the index carries `jobID`, `despatchID`, `dateReceived`, `dateFinalized` and `sampleN`, and gains no client or project field. Anchoring on `SAMPLE` is what makes the multi-line comment harmless — a quoted value spanning raw lines no longer shifts the blocks below it. Both shapes are pinned by `tests/testthat/test-parse-labA-variant.R`.

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

#### Certificate dates

`DATE RECEIVED` and `DATE FINALIZED` are normalized to ISO `YYYY-MM-DD` by a reader that does not depend on the host locale: every month-name token in English, Spanish or Portuguese — abbreviated or full — is rewritten to its number before parsing, and only numeric formats are then attempted. `%b`/`%B` and month-name parse orders are deliberately unused, because they resolve against the host's `LC_TIME` and made the same certificate readable on one machine and unreadable on another.

Accepted, on any host: `2025-04-10`, `10/04/2025`, `10-Apr-2025`, `10-ABR-2025`, `1-dic-2024`, `15 AGO 2023`, `6 May 24`. Pinned by `tests/testthat/test-parse-dates.R`.

A month name in any other language cannot be resolved. It is not an error: the date lands as `NA` in the index and every value on the certificate still ingests. Numeric dates such as `18/02/2025` carry no language and are always safe. See [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }}#certificates-fail-to-parse).

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
