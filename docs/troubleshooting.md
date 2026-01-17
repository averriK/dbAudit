---
layout: default
title: Troubleshooting
permalink: /docs/troubleshooting/
---

# Troubleshooting

## `dbaudit: command not found`

### macOS / Linux

Confirm the binary exists:

```bash
ls -l /usr/local/bin/dbaudit
```

If it exists but your shell can’t find it, confirm `/usr/local/bin` is on your `PATH`.

### Windows

- Open a **new** terminal after running the installer (PATH changes are not picked up by existing terminals).
- Confirm the launcher exists (default location): `%LOCALAPPDATA%\Programs\dbAudit\bin\dbaudit.cmd`.

In PowerShell:

```powershell
Get-Command dbaudit -ErrorAction SilentlyContinue
```

In Git Bash:

```bash
command -v dbaudit
```

## Permission denied during install on macOS/Linux

The macOS/Linux installer installs into `/usr/local`.

Run it with `sudo`:

```bash
sudo bash dbAudit/install/install.sh
```

## `Rscript` not found

`dbaudit` requires `Rscript` at runtime.

### macOS / Linux

```bash
command -v Rscript
Rscript --version
```

If `command -v` prints nothing, install R for your OS and ensure `Rscript` is on PATH.

### Windows

In PowerShell:

```powershell
Get-Command Rscript -ErrorAction SilentlyContinue
```

In Git Bash:

```bash
command -v Rscript || command -v Rscript.exe
```

## R packages fail to install

When `dbaudit` runs, it sources `R/setup.R` and installs missing packages:

- `data.table`
- `stringr`
- `lubridate`

If package installation fails, common causes include:

- No internet access / proxy restrictions.
- R library permissions.

Try running again in a network environment that can reach CRAN, or install the packages using R directly.

## Still stuck?

Capture:

- The exact command you ran.
- The full error output.
- Your OS and whether you installed via the installer scripts.
