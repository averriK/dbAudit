---
layout: default
title: PCV parser
permalink: /docs/parser-pcv/
---

# PCV parser — vibrating-wire piezometer workbooks

The PCV parser reads the client's vibrating-wire piezometer workbooks (multi-sheet Excel) and produces per-sensor long-format tables under `raw/PCV/`. It is the most complex parser in the engine: one workbook per borehole, one sheet per sensor, and two logical tables plus a calibration header extracted from each sheet. It runs inside `dbaudit piezometer` (or `auditPiezometer()`). Implementation: `parsePCV()` in `R/piezometerParse.R:448-463`; recognition is driven by the `PCV` block of the [parse manifest]({{ "/docs/manifest/" | relative_url }}).

## Input contract

- Files: `.xlsx` workbooks under `source/PCV/<SiteID>/…`, walked recursively; lock files (`~$…`) skipped (`R/piezometerParse.R:216-228`). One workbook per borehole, named `… CV-<HoleID>.xlsx`.
- Each sensor along the borehole has its own sheet, named `<HoleID>-<SensorID> (<depth>)` — in the shipped fixture, `VP-4-A (12.50 m)` and `VP-4-B (24.00 m)`.
- Every cell is read as text with whitespace collapsed; Excel date serials survive the parse stage as text.
- Monitoring sheets declare themselves with the title marker `MONITOREO DE PIEZÓMETRO DE CUERDA VIBRANTE` (normalized prefix `monitoreo de piez`), recorded as `HasMarker` (`R/piezometerParse.R:136-143`).

## Keys

- `HoleID` comes from the declared `SONDEO` header cell when present, else from the file name after the `CV-` mark (`.pcvKey`, `R/piezometerParse.R:555-570`; `.holeFromPCVFile`, `:238-244`).
- `SensorID` is derived from the sheet name: strip the trailing ` (…)` depth annotation, require the `<HoleID>-` prefix, and take the remainder — `VP-4-A (12.50 m)` yields sensor `A`. A sheet name that does not carry the prefix falls back to sensor `"0"` (`.pcvSheetKey`, `R/piezometerParse.R:246-256`).

## Header and calibration block

Header fields are matched by declared labels anywhere in the grid using the `PCV.headers` alias lists, which carry the client's case and typing variants (`PROYECTO`/`Proyecto`, `No. Serie`/`N° Serie`/`No Serie`). Three extraction rules apply in order (`.extractPCVHeaderValue`, `R/piezometerParse.R:602-620`):

1. `HoleID` (`SONDEO`) reads the cell **below** the label;
2. a label ending in `:` reads to the **right** (first non-empty cell, up to four);
3. any other label scans up to three cells **below**, skipping parenthesized unit cells such as `(kPa)`, then falls back to the right.

Rule 3 is what captures the calibration header, laid out as a label row over a units row over a values row: `Modelo`, `No. Serie`, `Rango`, `Tk`, `CF`, `Prof. Instalación`, `Inclinac.` (the colon-suffixed `SENSOR:` field follows rule 2). The whole calibration block sits above the readings table and is captured once per sheet into `header.csv` — it is excluded from the readings. The zero-reading row *inside* the readings table is kept as a reading with `stage = "Zero Reading"`.

## Readings: two logical tables

The sheet's single physical grid holds two logical tables that share the same header row, split by the manifest:

- **hydraulic** — `depth` (`Nivel de agua`), `level` (`Elevación Nivel Piezométrico`), `head` (`Carga de Agua`), all in meters;
- **instrument** — `reading` (`R`, `R (B)`), `frequency` (`Frecuencia`), `temperature` (`T`), `pressure` (`Presión`).

Each table is anchored on its `Fecha` label row; the column headers live on that row, the next row carries units, and data rows start two rows below the anchor (`.parsePCVTable`, `R/piezometerParse.R:622-673`). Rows with both `date` and `stage` empty are dropped (`:650`). Units come from the manifest when declared (`m` for the hydraulic variables) and are otherwise captured from the sheet's units row with the parentheses stripped — `(Hz)` becomes `Hz` (`:658-661`).

## Products

Per key, under `raw/PCV/<SiteID>/<HoleID>/<SensorID>/`:

- `data.csv` — hydraulic and instrument readings in one long table, one row per `(row, variable)`, with `SourcePath`, `SourceSheet`, `SourceRow`
- `header.csv` — header plus calibration fields, one row per field with raw label and value
- `index.csv` — per-sheet inspection: marker, data-sheet flag, per-table match counts

The runner deletes and regenerates `raw/PCV` on every run. Calibration-header consistency across sensors of one borehole is checked downstream by the audit stage (`.checkPCVHeader`, see [Monitoring audits]({{ "/docs/audit-monitoring/" | relative_url }})).

## Verified example

```sh
cp -R <INSTALL_ROOT>/inst/fixtures/Vega ~/vega-demo
dbaudit piezometer --project ~/vega-demo --id PCV
```

The run exits 0. `raw/PCV/Vega/VP-4/A/data.csv` starts:

```
ID,SiteID,HoleID,SensorID,SourcePath,SourceSheet,SourceRow,index,stage,date,time,comment,variable,value,units
PCV,Vega,VP-4,A,source/PCV/Vega/Piezómetro CV-VP-4.xlsx,VP-4-A (12.50 m),15,"","",44937,"","",depth,8.73,m
PCV,Vega,VP-4,A,source/PCV/Vega/Piezómetro CV-VP-4.xlsx,VP-4-A (12.50 m),16,"","",44968,"","",depth,8.52,m
```

and `header.csv` carries the calibration fields:

```
PCV,Vega,VP-4,A,source/PCV/Vega/Piezómetro CV-VP-4.xlsx,VP-4-A (12.50 m),Model,Modelo,VW2100-RST,9,2
PCV,Vega,VP-4,A,source/PCV/Vega/Piezómetro CV-VP-4.xlsx,VP-4-A (12.50 m),Tk,Tk,-0.0058712,9,8
PCV,Vega,VP-4,A,source/PCV/Vega/Piezómetro CV-VP-4.xlsx,VP-4-A (12.50 m),CF,CF,0.1183,9,9
```
