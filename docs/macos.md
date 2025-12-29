---
layout: default
title: macOS / Linux
permalink: /docs/macos/
---

# macOS / Linux

The macOS/Linux installer is `install/install.sh`.

It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

## Option A (recommended): remote install

```bash
curl -fsSL https://raw.githubusercontent.com/averriK/dbAudit/main/install/install.sh | sudo bash
```

## Option B: install from a local checkout

```bash
git clone https://github.com/averriK/dbAudit.git
cd dbAudit
sudo bash install/install.sh
```

## What the installer does

Deterministic layout:

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`
  - `/usr/local/libexec/dbAudit/bin/dbAudit` (bash wrapper)
  - `/usr/local/libexec/dbAudit/DBAudit` (R entrypoint)
  - `/usr/local/libexec/dbAudit/R/...`

Notes:

- The installer does **not** install R.
- `dbAudit` requires `Rscript` at runtime (the wrapper calls `Rscript "$DBAUDIT_HOME/DBAudit" ...`).
- `DBAudit` sources `R/setup.R` at startup; `R/setup.R` installs missing packages (`data.table`, `stringr`, `lubridate`) and loads them.

## Uninstall

Remote uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/averriK/dbAudit/main/install/uninstall.sh | sudo bash
```

Local uninstall (from a repo checkout):

```bash
sudo bash install/uninstall.sh
```
