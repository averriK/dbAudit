---
layout: default
title: Quick start
permalink: /docs/quickstart/
---

# Quick start

## 1) Install

1) Install **R** (Rscript must be available in your terminal).
2) From the repo root, run:

```bash
bash install.sh
```

This installs the required R packages and installs the `dbAudit` command in `$HOME/bin`.

If your shell cannot find `dbAudit` after installation, add `$HOME/bin` to your PATH (example):

```bash
export PATH="$HOME/bin:$PATH"
```

## 2) Run dbAudit

After installation, `dbAudit` is available on your PATH (typically via `$HOME/bin`).
You can run it from any directory.

## 3) Run a project

The CLI expects a **data root** folder:

```bash
dbAudit --project project/<PROJECT>/data
```

Defaults under `project.path`:
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

## 4) Inspect outputs

```r
library(data.table)

log <- fread("project/<PROJECT>/data/proc/log.csv")
log[level == "ERROR"]
```

See the full log guide: [Logging]({{ "/docs/logging/" | relative_url }})

## 5) Self-check (optional)

- Type-A regression:

```bash
Rscript test-A/run.R
```

- Type-B smoke test:

```bash
Rscript test-B/run.R
```
