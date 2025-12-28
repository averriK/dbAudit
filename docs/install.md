---
layout: default
title: Install
permalink: /docs/install/
---

# Install

This repo provides two OS-appropriate installers:

- macOS/Linux: Bash installer (`install/install.sh`) → installs to `/usr/local`.
- Windows: PowerShell installer (`install/install.ps1`) → installs to `%LOCALAPPDATA%` and adds shims to your user PATH.

For exact flags and defaults, always prefer:

```bash
dbAudit --help
```

## macOS / Linux

### Option A (recommended): remote install

```bash
curl -fsSL https://raw.githubusercontent.com/averriK/dbAudit/main/install/install.sh | sudo bash
```

### Option B: install from a local checkout

```bash
git clone https://github.com/averriK/dbAudit.git
cd dbAudit
sudo bash install/install.sh
```

### What the installer does

Deterministic layout:

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`
  - `/usr/local/libexec/dbAudit/bin/dbAudit`
  - `/usr/local/libexec/dbAudit/DBAudit`
  - `/usr/local/libexec/dbAudit/R/...`

Notes:

- The installer does **not** install R.
- `dbAudit` requires `Rscript` at runtime.
- On first run, `dbAudit` sources `R/setup.R`, which installs missing R packages:
  - `data.table`, `stringr`, `lubridate`

### Uninstall

Remote uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/averriK/dbAudit/main/install/uninstall.sh | sudo bash
```

## Windows (PowerShell)

### Option A (recommended): remote install

PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

iwr -UseBasicParsing https://raw.githubusercontent.com/averriK/dbAudit/main/install/install.ps1 -OutFile install-dbAudit.ps1
.\install-dbAudit.ps1 -AutoInstall
```

### Option B: install from a local checkout

PowerShell:

```powershell
git clone https://github.com/averriK/dbAudit.git
cd dbAudit

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install\install.ps1 -AutoInstall
```

### What the installer does

Deterministic layout:

- Runtime: `%LOCALAPPDATA%\dbAudit\libexec\dbAudit`
- Shims: `%USERPROFILE%\bin`
  - `dbAudit.ps1` (PowerShell launcher)
  - `dbAudit.cmd` (CMD launcher)

It also:

- Detects `Rscript.exe`.
- If R is missing and `-AutoInstall` is provided, it attempts to install R using `winget` or `choco` (best effort).
- Ensures the directory containing `Rscript.exe` is added to the **Windows User PATH**.
- Ensures `%USERPROFILE%\bin` is added to the **Windows User PATH**.

Important:

- After installation, close and reopen your shell (PowerShell / Git Bash) so PATH updates are picked up.

### Uninstall

PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

iwr -UseBasicParsing https://raw.githubusercontent.com/averriK/dbAudit/main/install/uninstall.ps1 -OutFile uninstall-dbAudit.ps1
.\uninstall-dbAudit.ps1
```