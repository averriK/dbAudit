---
layout: default
title: INC parser
permalink: /docs/parser-inc/
---

# INC parser — inclinometer CSV exports

The INC parser reads inclinometer survey **CSV exports** — one file per survey — and produces per-borehole tables under `raw/INC/`. It runs inside `dbaudit inclinometer` (or `auditInclinometer()`). Implementation: `parseINC()` in `R/inclinometerParse.R:8-22`; the expected structure is declared by the `INC.structure` block of the [parse manifest]({{ "/docs/manifest/" | relative_url }}), with an identical built-in default when the manifest carries no INC block (`R/inclinometerParse.R:41-57`).

## Native files are rejected — export to CSV first

This is the parser's first-order limitation: it reads the readout software's **CSV export only**. If the source tree contains any native `.gkn` or `.dux` file, the run stops before parsing anything, naming up to five offenders (`.checkINCSourceFormats`, `R/inclinometerParse.R:24-39`). Verified on a fixture copy with one stray `.gkn`:

```
Error: unsupported native inclinometer files (1 .gkn/.dux): VEGA_VI-1_20230111.gkn; parseINC reads CSV exports only
```

Remove or convert the native files, then rerun.

## Input contract

- Files: `.csv` under `source/INC/<SiteID>/<HoleID>/…`, walked recursively (`R/inclinometerParse.R:12`). The keys come from the directory path: `SiteID` is the first level, `HoleID` the second, `SensorID` fixed at `"0"` (`R/inclinometerParse.R:63-73`).
- Delimiter: `;`. Each line is split on semicolons; there is no quoting layer (`R/inclinometerParse.R:60-61`).

Each export contains, in order:

1. a `Headings` row followed by an `Installation v1` values row — installation metadata (site, installation, depth interval, units …);
2. a second `Headings` row followed by a `Survey v2` values row — survey metadata (datetime, passes, depths, sensor serial …);
3. the data header `Depth;A0;A180;B0;B180`, then one row per depth with the four axis readings.

The data header row is located by exact whole-row match: its five fields must equal `Depth`, `A0`, `A180`, `B0`, `B180` (`.incDataHeaderRow`, `R/inclinometerParse.R:100-105`). Data rows are padded or truncated to exactly five fields (`R/inclinometerParse.R:174-200`). Values stay text at the parse stage; the survey datetime lives in the `Survey v2` block, not in the data rows.

## Structural checks

For every file the parser records a `ParserCheck` row in `index.csv` with four fields: `InstallationHeaderOK`, `SurveyHeaderOK` (each `Headings` row must be followed by its declared block name), `DataHeaderOK`, and `DataRows` (`.checkINCFile`, `R/inclinometerParse.R:107-122`). A file with a broken structure still yields a check row, so the downstream audit can name it instead of losing it silently.

## Products

Per borehole, under `raw/INC/<SiteID>/<HoleID>/0/`:

- `data.csv` — one row per depth per survey file: `Depth, A0, A180, B0, B180` plus keys and `SourcePath`/`SourceRow`
- `index.csv` — the label/value pairs of both metadata blocks, plus one `ParserCheck` row per file

The runner deletes and regenerates `raw/INC` on every run.

## Verified example

```sh
cp -R <INSTALL_ROOT>/inst/fixtures/Vega ~/vega-demo
dbaudit inclinometer --project ~/vega-demo
```

The run exits 0. `raw/INC/Vega/VI-1/0/data.csv` starts:

```
ID,SiteID,HoleID,SensorID,SourcePath,SourceSheet,SourceRow,Depth,A0,A180,B0,B180
INC,Vega,VI-1,0,source/INC/Vega/VI-1/VEGA_VI-1_Inclinometer_20230111.csv,"",6,0.5,-571344,629630,-139564,197724
INC,Vega,VI-1,0,source/INC/Vega/VI-1/VEGA_VI-1_Inclinometer_20230111.csv,"",7,1,-696079,750495,104135,-54280
```

and `index.csv` carries the metadata and the per-file check:

```
INC,Vega,VI-1,0,source/INC/Vega/VI-1/VEGA_VI-1_Inclinometer_20230111.csv,"",2,Installation v1,Site,VEGA,,,,
INC,Vega,VI-1,0,source/INC/Vega/VI-1/VEGA_VI-1_Inclinometer_20230111.csv,"",5,ParserCheck,INC.csv,"",TRUE,TRUE,TRUE,38
```

Downstream behavior (build, audit events such as `MISLABELED`, `REDATED`, `MISCOUNTED`, `DUPLICATED`) is documented in [Monitoring audits]({{ "/docs/audit-monitoring/" | relative_url }}) and [Logging]({{ "/docs/logging/" | relative_url }}).
