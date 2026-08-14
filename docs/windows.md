---
layout: default
title: Windows
permalink: /docs/windows/
---

# Windows

dbaudit installs via **PowerShell** and runs via `Rscript` at runtime.

## Install

```powershell
git clone git@github.com:averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

The installer:

- Copies the runtime under a per-user directory (default: `%LOCALAPPDATA%\Programs\_runtime\dbAudit`)
- Writes launchers under a per-user bin directory (default: `%LOCALAPPDATA%\Programs`)
  - `dbaudit.cmd` (PowerShell / CMD)
  - `dbaudit` (Git Bash shim)
- Adds that bin directory to the **User PATH**

Open a **new terminal** after installing so PATH updates are picked up.

## Verify

PowerShell:

```powershell
dbaudit --help
```

Git Bash:

```bash
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
