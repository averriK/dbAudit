---
layout: default
title: PCG parser
permalink: /docs/parser-pcg/
---

# PCG parser — Casagrande piezometer workbooks

The PCG parser reads the client's Casagrande piezometer monitoring workbooks (Excel) and produces per-piezometer long-format tables under `raw/PCG/`. It is the first stage of `dbaudit piezometer` (or `auditPiezometer()`); it is not a standalone command. Implementation: `parsePCG()` in `R/piezometerParse.R:267-282`; recognition is driven by the `PCG` block of the [parse manifest]({{ "/docs/manifest/" | relative_url }}).

## Input contract

- Files: `.xlsx` workbooks under `source/PCG/<SiteID>/…`, walked recursively, extension case-insensitive; Excel lock files (`~$…`) are skipped (`R/piezometerParse.R:216-228`). One workbook per piezometer.
- `SiteID` is the first directory level under `source/PCG/` (`R/piezometerParse.R:207-214`).
- Every cell is read as text with whitespace collapsed (`R/piezometerParse.R:36-52`). Excel date and time serials therefore survive the parse stage as text (e.g. `44937`, `0.52917`); conversion happens later, in the database build.

## Sheet recognition

Each sheet is classified, and the classification is recorded in the per-key `index.csv`:

- **Monitoring-sheet marker.** The sheet declares itself with a title cell starting (after normalization) with `monitoreo de piez` — in PCG workbooks, `MONITOREO DE PIEZÓMETROS`. The marker is the sheet's declared identity, recorded as `HasMarker` (`R/piezometerParse.R:136-143`). A sheet that carries the marker but fails data-sheet recognition is a first-order audit finding (`MALFORMED`), not a silent skip.
- **Data sheet.** A sheet is a data sheet when the campaign table declares both `date` and `time` labels and the header block declares a `HoleID` label (`R/piezometerParse.R:296-298`), recorded as `IsDataSheet`.

## Header block

Header fields are located by their declared labels anywhere in the sheet grid, using the alias lists of `PCG.headers` in the manifest — including the client's typing variants (`Ubicación`/`Ubicacion`, `Piezómetro`/`Piezometro`, `N° Proyecto`/`N Proyecto`/`No Proyecto`). Matching is exact after normalization: accents stripped, lowercased, whitespace collapsed, trailing colon removed (`R/piezometerParse.R:16-25`). The field's value is the first non-empty cell up to four cells to the right of the label (`R/piezometerParse.R:198-205`); the first match per field wins.

## Keys

- `ID` is `PCG` and `SensorID` is fixed at `"0"` — the PCG contract carries one reading point per hole (`R/piezometerParse.R:364-378`).
- `HoleID` is the **declared** header value (`Piezómetro:`), normalized: whitespace and `/` become `_` (`R/piezometerParse.R:27-34`).
- The file name provides a check key: `.pcgFileKey()` strips the `_(Dep|Patio|Zona)…` suffix from the base name (`R/piezometerParse.R:230-236`) and the parser records `FileKey` and `FileKeyOK` in `index.csv`. The parser itself does not repair a mismatch — the declared value is the key of the `raw/` tree. Downstream, the gate records `MISLABELED` (WARNING) in `audit/PCG.reject.csv` and repairs `HoleID` from the systematic filename evidence before database insertion (`R/piezometerBuild.R:317-339`).

## Campaign readings

The campaign table is anchored on the `time` label row (`Hora`); header fields may sit on that row or the row above (two-row header, `R/piezometerParse.R:405-410`). Data rows start after the header; rows with both `date` and `time` empty are dropped (`R/piezometerParse.R:424`). The wide table is pivoted to one row per `(campaign, variable)` for the manifest-declared variables (`depth`, `level`, `head`, `change`), each with its manifest-declared unit (`R/piezometerParse.R:431-443`).

Two declared conventions matter for values:

- **Decimal separator.** The parse stage preserves the value text verbatim. A decimal-comma value (`18,20`) is accepted at the gate, recorded as `COMMA` (WARNING) in the gate sink `audit/PCG.reject.csv` and repaired to a dot before database insertion; any other non-numeric value is rejected as `UNREADABLE` (ERROR) (`R/piezometerBuild.R:286-314`). The missing-value markers `""`, `-`, `NA`, `N.A.`, `N/A` parse to missing (`R/piezometerBuild.R:73-75`).
- **Declared dry.** A dry well is declared in the sheet by leaving the water-level cell empty while the campaign row and its depth remain present. The parser emits no `level` reading for that campaign, and the audit stage marks the record with flag `D` in `PZ.data.csv` — distinct from a value rejected at the gate, which is a data gap, not a dry well (`R/piezometerAudit.R:443-450`).

Geometry columns present in the sheet but listed under `excluded` in the manifest (`Profundidad Piezómetro (m)`, `Cota de boca del tubo (msnm)`, `Cota del fondo de aforo (msnm)`) are deliberately not captured as readings.

## Products

Per key, under `raw/PCG/<SiteID>/<HoleID>/0/`:

- `data.csv` — long-format readings with full source traceability (`SourcePath`, `SourceSheet`, `SourceRow`)
- `header.csv` — the captured header block, one row per field with its raw label and value
- `index.csv` — sheet inspection: marker, data-sheet flag, match counts, file-key check

The runner deletes and regenerates `raw/PCG` on every run.

## Verified example

Copy the shipped synthetic fixture to a writable location and run the PCG contract alone (the fixture travels in the repository and in every installation as `inst/fixtures/Vega`):

```sh
cp -R <INSTALL_ROOT>/inst/fixtures/Vega ~/vega-demo
dbaudit piezometer --project ~/vega-demo --id PCG
```

The run exits 0 and writes `raw/PCG/Vega/VP-1/0/data.csv`:

```
ID,SiteID,HoleID,SensorID,SourcePath,SourceSheet,SourceRow,index,stage,date,time,comment,variable,value,units
PCG,Vega,VP-1,0,source/PCG/Vega/VP-1_Depósito_de_Relaves_Vega.xlsx,VP-1,11,1,"",44937,0.52917,Primera lectura,depth,18.20,m
PCG,Vega,VP-1,0,source/PCG/Vega/VP-1_Depósito_de_Relaves_Vega.xlsx,VP-1,12,2,"",44968,0.49722,Descenso,depth,18.41,m
```

The fixture also carries a deliberate mislabel: the workbook named `VP-5` declares `VP-50`, and `index.csv` records the disagreement for the gate:

```
ID,SiteID,HoleID,SensorID,RawHoleID,FileKey,FileKeyOK,SourcePath,SourceSheet,HeaderMatches,DataMatches,IsDataSheet,HasMarker
PCG,Vega,VP-50,0,VP-50,VP-5,FALSE,source/PCG/Vega/VP-5_Depósito_de_Relaves_Vega.xlsx,VP-50,10,8,TRUE,TRUE
```

Downstream behavior (gate, database, audit events) is documented in [Monitoring audits]({{ "/docs/audit-monitoring/" | relative_url }}) and [Logging]({{ "/docs/logging/" | relative_url }}).
