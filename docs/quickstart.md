---
layout: default
title: Quick start
permalink: /docs/quickstart/
---

# Quick start

dbAudit runs three pipelines behind one CLI. A leading positional token
selects the contract; an invocation without a token keeps the historical
geochemistry contract:

```bash
dbaudit [geochemistry|piezometer|inclinometer] --project <DATA_ROOT> [OPTIONS]
```

This page installs the tool, verifies the installation, and runs each
domain once against the synthetic fixtures that ship with the repository.
Every command was executed as written; quoted output is trimmed and
project paths are shortened to `<DATA_ROOT>`.

## 1) Install

- macOS / Linux: [macOS / Linux install]({{ "/docs/macos/" | relative_url }})
- Windows: [Windows install]({{ "/docs/windows/" | relative_url }})

Installation is repo-based: you clone the repository and run the
installer from the clone. The commands below assume the clone directory
`dbAudit` is in your working directory; it holds the fixture material
used in this page.

## 2) Verify

```bash
dbaudit --check
```

```
dbaudit System Diagnostics
==================================================

R version: 4.6.0
...
Required R Packages:
  [✓] data.table (version 1.18.4)
  [✓] stringr (version 1.6.0)
  [✓] lubridate (version 1.9.5)
  [✓] readxl (version 1.5.0)
  [✓] jsonlite (version 2.0.0)

Status: ✓ All dependencies satisfied
```

All five packages are required. When a package is missing, `--check`
reports it as `MISSING` and the next pipeline run installs it
automatically. `dbaudit --help` prints the full option surface of the
three contracts.

## 3) Geochemistry: run the synthetic-A fixture

The repository ships one single-certificate fixture per supported
certificate model: `tests/testthat/fixtures/synthetic-A` and
`synthetic-B`. Copy synthetic-A into the default geochemistry layout
(`raw/lab/` for certificates, `raw/assay/` for the assay table) and run:

```bash
mkdir -p demo-geochemistry/raw/lab demo-geochemistry/raw/assay
cp dbAudit/tests/testthat/fixtures/synthetic-A/raw/SYN0001.A25_ORSYN25000001.csv demo-geochemistry/raw/lab/
cp dbAudit/tests/testthat/fixtures/synthetic-A/assay/_Assay_Comp.csv demo-geochemistry/raw/assay/

dbaudit geochemistry --project demo-geochemistry
```

The run exits 0 and creates `proc/` with four files:

```
demo-geochemistry/proc/client.csv
demo-geochemistry/proc/index.csv
demo-geochemistry/proc/lab.csv
demo-geochemistry/proc/log.csv
```

On a fixture this small the type-A layout detector prints a few
`longer object length is not a multiple of shorter object length`
warnings; they do not affect the outputs.

The fixture plants one wrong assay value, and the log records it:

```r
library(data.table)
log <- fread("demo-geochemistry/proc/log.csv")
log[level == "ERROR", .(event, message)]
```

```
         event  message
1: WRONG_VALUE  jobID=SYN0001.A25; sampleID=SYN00000003; elementID=Zn;
                standardID=G0100; unitID=ppm; value.client=1400;
                value.lab=1266; tol=0.05
```

Format auto-detection can be pinned per run
(`--lab-format A --assay-format A` for synthetic-A; `B` for
synthetic-B):

```bash
dbaudit geochemistry --project demo-geochemistry --lab-format A --assay-format A
```

The bare invocation `dbaudit --project demo-geochemistry` runs the same
geochemistry contract and produces the same four files.

## 4) Piezometers: run the Vega fixture

`inst/fixtures/Vega` is a complete synthetic monitoring project: one
`source/` tree covering the three monitoring instrument ids — PCG
(Casagrande piezometers), PCV (vibrating-wire piezometers), INC
(inclinometers) — plus `truth.csv`, the record of its planted
anomalies. It travels in the repository and in every installation
(`/usr/local/libexec/dbAudit/inst/fixtures/Vega` on macOS/Linux).

A monitoring project root contains one user-owned subtree, `source/`;
the tool creates everything else. Copy the source tree and run:

```bash
mkdir -p demo-vega
cp -R dbAudit/inst/fixtures/Vega/source demo-vega/
dbaudit piezometer --project demo-vega
```

The run exits 0 and creates `raw/`, `db/` and `audit/`:

```
demo-vega/audit/PCG.audit.csv
demo-vega/audit/PCG.reject.csv
demo-vega/audit/PCV.audit.csv
demo-vega/audit/PZ.data.csv
demo-vega/audit/PZ.index.csv
demo-vega/audit/log.csv
demo-vega/db/PCG.data.csv
demo-vega/db/PCG.index.csv
demo-vega/db/PCV.data.csv
demo-vega/db/PCV.index.csv
demo-vega/raw/PCG/...
demo-vega/raw/PCV/...
```

`audit/log.csv` opens and closes with run markers and records each
planted anomaly against the file, survey or record it belongs to:

```
ts,scope,SiteID,HoleID,datetime,source,level,event,detail
...,run,"","","",auditPiezometer,INFO,START,""
...,file,"","","",backup/PCG/Vega/VP-2_Depósito_de_Relaves_Vega.xlsx,ERROR,MISSING,data file under the source root never parsed
...,record,Vega,VP-2,2023-12-14,data/raw,ERROR,DUPLICATED,"ID=PCG; SensorID=0; rows=2; ..."
...,run,"","","",auditPiezometer,INFO,DONE,PZ.data=218; PZ.index=218
```

## 5) Inclinometers: same project, second contract

The inclinometer contract reads the same project root — its input is
`source/INC/`:

```bash
dbaudit inclinometer --project demo-vega
```

The run exits 0 and adds `raw/INC/`, `db/INC.data.csv`,
`db/INC.index.csv` and `audit/INC.audit.csv`.

> **The monitoring runners are destructive.** Every run deletes and
> regenerates `raw/<ID>` for the ids it processes and reinitializes
> `audit/log.csv`. After the inclinometer run above, `audit/log.csv`
> holds only the INC rows; the piezometer events from step 4 are gone.
> Keep your own material under `source/` only, and archive `audit/`
> products you need to retain before re-running. See
> [Project layouts]({{ "/docs/project-layout/" | relative_url }}).

```r
log <- fread("demo-vega/audit/log.csv")
log[level == "ERROR", .(scope, HoleID, event)]
```

```
    scope HoleID      event
1: survey   VI-1 MISCOUNTED
2: survey        MISLABELED
3: survey        INCOMPLETE
4: survey           REDATED
```

## 6) Next

- Folder contracts for both layouts: [Project layouts]({{ "/docs/project-layout/" | relative_url }})
- Log schemas and the event catalog: [Logging]({{ "/docs/logging/" | relative_url }})
- What the audits check: [Audits (geochemistry)]({{ "/docs/audit/" | relative_url }}), [Audits (monitoring)]({{ "/docs/audit-monitoring/" | relative_url }})
- Worked examples: [Examples]({{ "/docs/examples/" | relative_url }})
- The acceptance suite behind the fixtures: [Tests]({{ "/docs/tests/" | relative_url }})
