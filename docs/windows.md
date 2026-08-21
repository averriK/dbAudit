---
layout: default
title: Windows
permalink: /docs/windows/
---

# Windows

dbaudit installs via **PowerShell** and runs via `Rscript` at runtime. It requires **R >= 4.1.0**; the installer verifies the version and aborts below 4.1.

## Install

```powershell
git clone git@github.com:averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

Options:

- `-SkipPackages` — skip R package installation (packages are auto-installed on the first run).
- `-Force` — replace an existing installation without the `[y/N]` prompt.

The installer:

- Copies the runtime under a per-user directory (default: `%LOCALAPPDATA%\Programs\_runtime\dbAudit`)
- Writes launchers under a per-user bin directory (default: `%LOCALAPPDATA%\Programs`)
  - `dbaudit.cmd` (PowerShell / CMD)
  - `dbaudit` (Git Bash shim)
- Adds that bin directory to the **User PATH**

Open a **new terminal** after installing so PATH updates are picked up.

## Verify

PowerShell or Git Bash (in a **new** terminal):

```powershell
dbaudit --check
```

`--check` reports the R version, the `Rscript` location, the installation root, and the five required R packages (`data.table`, `stringr`, `lubridate`, `readxl`, `jsonlite`) with versions — unlike `--help`, it exercises the R runtime, not just the launcher.

```powershell
dbaudit --help
```

## R / Rscript

Quick checks:

PowerShell:

```powershell
Get-Command Rscript -ErrorAction SilentlyContinue
```

Git Bash:

```bash
command -v Rscript || command -v Rscript.exe
```

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
```
