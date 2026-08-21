---
layout: default
title: Troubleshooting
permalink: /docs/troubleshooting/
---

# Troubleshooting

## Run `--check` first

```
dbaudit --check
```

One command covers most of this page: it reports the R version, whether `Rscript` is on `PATH`, the installation root, and each of the five required R packages with its installed version, ending in a status line (`Status: ✓ All dependencies satisfied`, or the list of missing packages). If `--check` passes, the installation is sane and the problem is elsewhere.

## `dbaudit: command not found`

### macOS / Linux

Confirm the binary exists:

```bash
ls -l /usr/local/bin/dbaudit
```

Expected: a symlink to `/usr/local/libexec/dbAudit/bin/dbaudit`. If it exists but your shell can't find it, confirm `/usr/local/bin` is on your `PATH`.

### Windows

- Open a **new** terminal after running the installer (PATH changes are not picked up by existing terminals).
- Confirm the launchers exist (default locations):
  - `%LOCALAPPDATA%\Programs\dbaudit.cmd` (PowerShell / CMD launcher)
  - `%LOCALAPPDATA%\Programs\dbaudit` (Git Bash shim)
- The runtime lives separately under `%LOCALAPPDATA%\Programs\_runtime\dbAudit`.
- Confirm `%LOCALAPPDATA%\Programs` is on the **User PATH** (the installer adds it and records `path_added=` in the `.version` manifest).

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

## Installer blocks or aborts on reinstall

When an existing installation is detected, both installers ask an interactive question — `Existing dbaudit will be removed. Continue? [y/N]` — before removing anything. Under non-interactive `sudo` (CI, piped input, `sudo -n`) the prompt cannot be answered: the run blocks or aborts with `Aborted by user.`

- macOS/Linux: run the reinstall from an interactive terminal; `install.sh` has no flag to skip the prompt.
- Windows: pass `-Force` to replace without prompting.

A first install on a clean machine asks nothing.

## Installed binary is outdated

The installation is a **copy** of the checkout: pulling or editing the repo does not change the installed CLI, so a stale binary fails silently — commands run, but against older code. Compare the installed build against the checkout:

```bash
dbaudit --version
git -C dbAudit rev-parse --short HEAD
```

`dbaudit --version` prints the `Build:` commit recorded in the `.version` manifest at install time:

```
dbaudit
Build: 892a246 (dev)
Installed: 2026-08-19 16:48:12 UTC
```

If the `Build:` commit differs from the checkout `HEAD`, re-run the installer. `Build: unknown (version file not found)` means the runtime has no `.version` manifest (e.g. an installation predating the manifest): reinstall to regenerate it.

## `Rscript` not found

`dbaudit` requires `Rscript` at runtime, and **R >= 4.1.0** (the installers verify the version and abort below 4.1).

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
- `readxl`
- `jsonlite`

All five are required: `readxl` reads the monitoring Excel inputs and `jsonlite` reads the parse manifest — a partial set breaks the monitoring domains even when geochemistry still runs.

If package installation fails, common causes include:

- No internet access / proxy restrictions.
- R library permissions (`.libPaths()` in R shows where packages go).
- On Windows, packages install as pre-compiled binaries only (no Rtools compilation); if no binary exists for your R version, upgrade R.

Try running again in a network environment that can reach CRAN, or install the packages using R directly. `dbaudit --check` confirms the result.

## Still stuck?

Capture:

- The exact command you ran.
- The full error output.
- The output of `dbaudit --check` and `dbaudit --version`.
- Your OS and whether you installed via the installer scripts.
