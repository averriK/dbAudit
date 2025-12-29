---
layout: default
title: Install
permalink: /docs/install/
---

# Install

This repo is private.
To install without a GitHub account, you need a GitHub token (read access) provided by your administrator.

## macOS / Linux

The macOS/Linux installer is `install/install.sh`.
It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

### Remote install (recommended)

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install.sh?ref=main" \
  -o install-dbAudit.sh

sudo env DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit.sh
rm -f install-dbAudit.sh
```

### Install from a local checkout

If you already have a local copy of the repo:

```bash
sudo bash install/install.sh
```

### Installed paths

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`

### Uninstall

```bash
curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.sh?ref=main" \
  -o uninstall-dbAudit.sh

sudo bash uninstall-dbAudit.sh
rm -f uninstall-dbAudit.sh
```

## Windows (PowerShell)

The Windows installer is `install/install.ps1`.

### Remote install (recommended)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$token = Read-Host "GitHub token (read access to averriK/dbAudit)"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }

$installer = Join-Path $env:TEMP "install-dbAudit.ps1"
iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/install.ps1?ref=main" -OutFile $installer

& $installer -AutoInstall -GitHubToken $token
Remove-Item -Force $installer
```

After installing, close and reopen PowerShell so PATH updates are picked up.

### Install from a local checkout

If you already have a local copy of the repo:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install\install.ps1 -AutoInstall
```

### Installed paths

- Runtime: `%LOCALAPPDATA%\dbAudit\libexec\dbAudit`
- Shims: `%USERPROFILE%\bin` (`dbAudit.ps1`, `dbAudit.cmd`)

### Uninstall

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$token = Read-Host "GitHub token (read access to averriK/dbAudit)"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }

$uninstaller = Join-Path $env:TEMP "uninstall-dbAudit.ps1"
iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.ps1?ref=main" -OutFile $uninstaller

& $uninstaller
Remove-Item -Force $uninstaller
```

## OS-specific notes

- macOS/Linux details: [macOS / Linux]({{ "/docs/macos/" | relative_url }})
- Windows details: [Windows]({{ "/docs/windows/" | relative_url }})
