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

Options:

- `--skip-packages` — skip R package installation (packages are auto-installed on the first run).

## What the installer does

Deterministic layout:

- Binary: `/usr/local/bin/dbaudit` (symlink)
- Runtime: `/usr/local/libexec/dbAudit/`
  - `/usr/local/libexec/dbAudit/bin/dbaudit` (bash wrapper)
  - `/usr/local/libexec/dbAudit/DBAudit` (R entrypoint)
  - `/usr/local/libexec/dbAudit/R/...`
  - `/usr/local/libexec/dbAudit/inst/...` (event catalog, parse manifest, Vega fixture)
  - `/usr/local/libexec/dbAudit/.version` (install manifest: commit, branch, tag, install date, paths)

Notes:

- The installer does **not** install R. It requires **R >= 4.1.0** and aborts below that version.
- `dbaudit` requires `Rscript` at runtime.
- `DBAudit` sources `R/setup.R` at startup; `R/setup.R` installs missing packages (`data.table`, `stringr`, `lubridate`, `readxl`, `jsonlite`) and loads them.
- Reinstalling over an existing installation opens an interactive `[y/N]` prompt; under non-interactive `sudo` the run blocks or aborts. See [Install]({{ "/docs/install/" | relative_url }}).

## Verify

```bash
dbaudit --check
```

reports the R version, the `Rscript` location, the installation root, and the five required packages with versions.

## Uninstall

```bash
sudo bash dbAudit/install/uninstall.sh
```
