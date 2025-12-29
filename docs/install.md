---
layout: default
title: Install
permalink: /docs/install/
---

# Install

dbAudit is installed from a local checkout / extracted package (repo-based). The installers do not download from GitHub.

## macOS / Linux

Installer: `install/install.sh` (system-wide `/usr/local`)

```bash
git clone git@github.com:averriK/dbAudit.git
sudo bash dbAudit/install/install.sh
```

Installed paths:

- `/usr/local/bin/dbAudit`
- `/usr/local/libexec/dbAudit/`

Uninstall:

```bash
sudo bash dbAudit/install/uninstall.bash.sh
```

## Windows

Installer: `install/install.ps1` (PowerShell)

```powershell
git clone git@github.com:averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

The installer writes launchers under a per-user bin directory and adds it to the **User PATH** (unless `-SkipPath`).
Open a **new** terminal after installing.

Uninstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
```

## Notes

- R is required at runtime (`Rscript` must be discoverable).
- OS-specific details:
  - macOS/Linux: [macOS / Linux]({{ "/docs/macos/" | relative_url }})
  - Windows: [Windows]({{ "/docs/windows/" | relative_url }})
