---
layout: default
title: Windows
permalink: /docs/windows/
---

# Windows

`dbAudit` on Windows is installed via PowerShell (`install/install.ps1`). The Unix/macOS installer (`install/install.sh`) is not intended for Windows.

## Install

Recommended (remote install):

This repo is private, so `raw.githubusercontent.com/...` will return `404` unless you authenticate.
Use the GitHub API with a token (read access):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$token = Read-Host "GitHub token (read access to averriK/dbAudit)"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }

$installer = Join-Path $env:TEMP "install-dbAudit.ps1"
iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/install.ps1?ref=main" -OutFile $installer

& $installer -AutoInstall -GitHubToken $token
Remove-Item -Force $installer
```

After installing, **close and reopen** PowerShell so your updated PATH is loaded.

## What gets installed where

- Runtime: `%LOCALAPPDATA%\dbAudit\libexec\dbAudit`
- User shims: `%USERPROFILE%\bin`
  - `dbAudit.ps1` (PowerShell launcher)
  - `dbAudit.cmd` (CMD launcher)

The installer adds both:

- `%USERPROFILE%\bin`
- The directory containing `Rscript.exe`

…to the **Windows User PATH**.

## R / Rscript detection

`dbAudit` requires `Rscript.exe`.

The installer:

1. Checks whether `Rscript.exe` is already on PATH.
2. If not, searches common locations such as:
   - `C:\Program Files\R\R-*\bin\x64\Rscript.exe`
   - `C:\R\R-*\bin\x64\Rscript.exe`
3. If still not found and you used `-AutoInstall`, attempts to install R via `winget` or `choco` (best effort).

### If you already have R installed but `Rscript` is not found

In PowerShell:

```powershell
where.exe Rscript
```

If that prints nothing, locate your `Rscript.exe` (commonly under `C:\Program Files\R\R-<version>\bin\x64\`) and ensure that directory is on your **User PATH**.

## Verify install

In a new PowerShell session:

```powershell
dbAudit --help
```

## Uninstall

Remote uninstall:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$token = Read-Host "GitHub token (read access to averriK/dbAudit)"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }

$uninstaller = Join-Path $env:TEMP "uninstall-dbAudit.ps1"
iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.ps1?ref=main" -OutFile $uninstaller

& $uninstaller
Remove-Item -Force $uninstaller
```
