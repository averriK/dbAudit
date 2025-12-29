---
layout: default
title: dbAudit
permalink: /
---

# dbAudit

Geochemical certificate parser and audit tool.

- Parses **lab certificates** (type A and type B) into `lab.csv` + `index.csv`.
- Parses **assay/client tables** (type A and type B) into `client.csv`.
- Runs audits (structure + values).

## Requirements

- R installed (`Rscript` must be available at runtime).

## Install

### macOS / Linux (system-wide `/usr/local`)

```bash
git clone git@github.com:averriK/dbAudit.git
sudo bash dbAudit/install/install.sh
```

### Windows (PowerShell)

```powershell
git clone git@github.com:averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

For more details (paths, uninstall, troubleshooting), see: [Install]({{ "/docs/install/" | relative_url }}).

## Run

```bash
dbAudit --project project/<PROJECT>/data
```

Outputs under `--project`:

- `proc/`
- `proc/log.csv`

Next:

- [Quick start]({{ "/docs/quickstart/" | relative_url }})
- [Logging]({{ "/docs/logging/" | relative_url }})
- [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }})
