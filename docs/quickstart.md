---
layout: default
title: Quick start
permalink: /docs/quickstart/
---

# Quick start

## 1) Install

Choose your OS:

- macOS / Linux: [macOS / Linux install]({{ "/docs/macos/" | relative_url }})
- Windows: [Windows install]({{ "/docs/windows/" | relative_url }})

## 2) Run a project

The CLI expects a **data root** folder:

```bash
dbAudit --project project/<PROJECT>/data
```

Defaults under `--project`:

- Lab certificates: `raw/lab/`
- Assay folder: `raw/assay/` (assay CSV auto-detected inside)
- Outputs: `proc/`

Optional overrides:

```bash
# Override folder names (relative to --project)

dbAudit --project project/<PROJECT>/data --lab-dir raw/lab --assay-dir raw/assay --proc-dir proc

# Override assay file (basename resolved under raw/assay)

dbAudit --project project/<PROJECT>/data --assay-file AAQ_Sample_Assay.csv
```

## 3) Inspect outputs

The run writes a log to `proc/log.csv`.

```r
library(data.table)

log <- fread("project/<PROJECT>/data/proc/log.csv")
log[level == "ERROR"]
```

See the full log guide: [Logging]({{ "/docs/logging/" | relative_url }})
