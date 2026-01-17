---
layout: default
title: macOS / Linux
permalink: /docs/macos/
---

# macOS / Linux

The macOS/Linux installer is `install/install.sh`.

It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

## Install (repo-based)

```bash
git clone git@github.com:averriK/dbAudit.git
sudo bash dbAudit/install/install.sh
```

## What the installer does

Deterministic layout:

- Binary: `/usr/local/bin/dbaudit`
- Runtime: `/usr/local/libexec/dbAudit/`
  - `/usr/local/libexec/dbAudit/bin/dbaudit` (bash wrapper)
  - `/usr/local/libexec/dbAudit/DBAudit` (R entrypoint)
  - `/usr/local/libexec/dbAudit/R/...`

Notes:

- The installer does **not** install R.
- `dbaudit` requires `Rscript` at runtime.
- `DBAudit` sources `R/setup.R` at startup; `R/setup.R` installs missing packages (`data.table`, `stringr`, `lubridate`) and loads them.

## Uninstall

```bash
sudo bash dbAudit/install/uninstall.sh
```
