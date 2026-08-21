---
layout: default
title: Parse manifest
permalink: /docs/manifest/
---

# Parse manifest — the label contract for monitoring sources

The monitoring parsers do not guess at spreadsheet content: every label they recognize is declared in a versioned JSON manifest, `inst/extdata/piezometer-manifest.json`. The manifest is the contract between the client's spreadsheet conventions — including their typing variants — and the parser's field names. It travels in the repository and in every installation, and a project can override it per run with `--manifest`.

The file is loaded with `jsonlite` without vector simplification (`loadParserManifest()`, `R/piezometerParse.R:9-14`). It has three top-level blocks, one per instrument: `PCG`, `PCV`, `INC`.

## Alias matching

Every alias list maps one parser field to the labels that declare it in the source sheets. Matching is exact **after normalization**: accents transliterated away, lowercased, whitespace collapsed, trailing colon stripped (`normalizeLabel()`, `R/piezometerParse.R:16-25`). That is why alias lists carry the client's typing variants explicitly:

```json
"Location":  ["Ubicación", "Ubicacion"],
"HoleID":    ["Piezómetro", "Piezometro"],
"ProjectID": ["N° Proyecto", "N Proyecto", "No Proyecto"]
```

A label not in any alias list is simply not captured. There is no fuzzy matching.

## Consumed blocks

These blocks drive parser behavior directly:

| Block | Consumer | Role |
|---|---|---|
| `PCG.headers`, `PCV.headers` | `R/piezometerParse.R:290,472` | Alias lists for the header (and PCV calibration) fields |
| `<ID>.tables.<table>.columns` | `R/piezometerParse.R:92-102` | Alias lists for the table's key columns (`index`, `stage`, `date`, `time`, `comment`) |
| `<ID>.tables.<table>.variables` | `R/piezometerParse.R:104-125` | Per-variable `labels` (aliases) and `units`; a `null`/empty unit tells the PCV parser to capture the unit from the sheet's units row |
| `INC.structure` | `R/inclinometerParse.R:41-57` | `heading`, `blocks` (`Installation v1`, `Survey v2`) and `dataHeader` of the CSV export; when the block is absent the parser applies an identical built-in default |

`PCG.tables` declares one table (`hydraulic`); `PCV.tables` declares two (`hydraulic` and `instrument`), which is how one physical PCV grid becomes two logical tables (see the [PCV parser]({{ "/docs/parser-pcv/" | relative_url }})).

## Declarative blocks

Two blocks document parser behavior that is implemented in code, and are not read by the matching engine:

- `keys` — records how each instrument's `HoleID`/`SensorID` are derived (PCG: `SensorID` default `"0"`; PCV: `SensorID` from the sheet name). The derivation itself is hardwired (`.pcgKey`, `.pcvSheetKey` in `R/piezometerParse.R`).
- `excluded` — the inventory of labels deliberately **not** parsed as readings: PCG geometry columns (`Profundidad Piezómetro (m)`, `Cota de boca del tubo (msnm)`, …) and the PCV calibration and geometry labels. Exclusion is effected by their absence from the alias lists; this block keeps the decision visible instead of implicit.

Editing `keys` or `excluded` therefore changes nothing at run time; editing `headers`, `tables` or `structure` changes what is parsed.

## Default resolution and project override

- `dbaudit piezometer` resolves the installation's copy (`<INSTALL_ROOT>/inst/extdata/piezometer-manifest.json`, `DBAudit:328`) unless `--manifest <PATH>` is given (`DBAudit:329`).
- `dbaudit inclinometer` passes the override through, or lets `auditInclinometer()` resolve the copy installed with the R package (`system.file("extdata", "piezometer-manifest.json", package = "dbAudit")`, `R/auditInclinometer.R`); `auditPiezometer()` resolves the same way when called from R with `manifest = NULL` (`R/auditPiezometer.R:46-48`).

A project with its own spreadsheet conventions copies the shipped manifest, edits the alias lists, and points the run at it. Verified:

```sh
cp <INSTALL_ROOT>/inst/extdata/piezometer-manifest.json ~/project-manifest.json
dbaudit piezometer --project ~/vega-demo --id PCG --manifest ~/project-manifest.json
```

The run exits 0 and parses with the overridden manifest; with the unedited copy the products are identical to the default run:

```
ID,SiteID,HoleID,SensorID,SourcePath,SourceSheet,SourceRow,index,stage,date,time,comment,variable,value,units
PCG,Vega,VP-1,0,source/PCG/Vega/VP-1_Depósito_de_Relaves_Vega.xlsx,VP-1,11,1,"",44937,0.52917,Primera lectura,depth,18.20,m
```

The manifest file passed with `--manifest` must exist; a missing path stops the run (`R/piezometerParse.R:10-12`).
