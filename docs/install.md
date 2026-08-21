---
layout: default
title: Install
permalink: /docs/install/
---

# Install

dbAudit is installed from a local checkout / extracted package (repo-based). The installers do not download from GitHub.

The installers deploy the **CLI** (`dbaudit`). They do not install the R package; see [CLI vs R package](#cli-vs-r-package) below.

## Requirements

- **R >= 4.1.0** (the version declared in `DESCRIPTION`). The installers do **not** install R.
  - On **Windows**, R does not have to be on the `PATH`: the installer and the launcher read the
    registry keys the CRAN installer writes, so an installed R is found either way. A machine with
    no R still installs dbaudit and reports what is missing; R can be installed afterwards without
    reinstalling dbaudit.
  - On **macOS / Linux**, `Rscript` must be discoverable on the `PATH`, and the installer aborts
    if it is not.
  - Both installers verify the version and abort below 4.1 when R is present.
- Internet access to CRAN during installation, unless the required packages are already present or package installation is skipped.
- Five required R packages: `data.table`, `stringr`, `lubridate`, `readxl`, `jsonlite`. The installer installs any that are missing; with `--skip-packages` / `-SkipPackages` they are auto-installed on the first `dbaudit` run instead.

## macOS / Linux

Installer: `install/install.sh` (system-wide `/usr/local`).

```bash
git clone https://github.com/averriK/dbAudit.git
sudo bash dbAudit/install/install.sh
```

Installed paths:

- `/usr/local/bin/dbaudit` — symlink to the runtime wrapper
- `/usr/local/libexec/dbAudit/` — runtime (`DBAudit`, `R/`, `inst/`, `bin/dbaudit`, `.version`)

Options:

- `--skip-packages` — skip R package installation; the five packages are auto-installed on the first run.

**Reinstalling is interactive.** When an existing installation is detected, the installer prints its build (from the `.version` manifest) and asks `Existing dbaudit will be removed. Continue? [y/N]`. Under non-interactive `sudo` (CI, piped input, `sudo -n`) that prompt cannot be answered and the run blocks or aborts. Run reinstalls from an interactive terminal. A first install on a clean machine asks nothing.

Uninstall:

```bash
sudo bash dbAudit/install/uninstall.sh
```

OS details: [macOS / Linux]({{ "/docs/macos/" | relative_url }})

## Windows

Installer: `install/install.ps1` (PowerShell, per-user; no administrator rights required).

```powershell
git clone https://github.com/averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

The installer:

- copies the runtime under `%LOCALAPPDATA%\Programs\_runtime\dbAudit`,
- writes two launchers under `%LOCALAPPDATA%\Programs` — `dbaudit.cmd` (PowerShell / CMD) and `dbaudit` (Git Bash shim),
- adds that directory to the **User PATH**.

Open a **new** terminal after installing so the PATH update is picked up.

Options:

- `-SkipPackages` — same semantics as `--skip-packages` above.
- `-Force` — replace an existing installation without prompting. Without it, reinstalling asks the same `[y/N]` question as on macOS/Linux. (`install.sh` has no `--force` equivalent.)

Uninstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
```

OS details: [Windows]({{ "/docs/windows/" | relative_url }})

## Verify

```
dbaudit --check
```

`--check` reports the R version, the `Rscript` location, the installation root, and each of the five required packages with its installed version, ending in a single status line:

```
Required R Packages:
  [✓] data.table (version 1.18.4)
  [✓] stringr (version 1.6.0)
  [✓] lubridate (version 1.9.5)
  [✓] readxl (version 1.5.0)
  [✓] jsonlite (version 2.0.0)

Status: ✓ All dependencies satisfied
```

```
dbaudit --version
```

prints the installed build from the `.version` manifest:

```
dbaudit
Build: 892a246 (dev)
Installed: 2026-08-19 16:48:12 UTC
```

## The `.version` manifest

Both installers write a `.version` manifest at the runtime root (`/usr/local/libexec/dbAudit/.version`; `%LOCALAPPDATA%\Programs\_runtime\dbAudit\.version`). It is a plain `key=value` file with the shared keys `commit`, `branch`, `tag`, `install_date`, plus platform-specific install paths (`bin_path` and `libexec_dir` on macOS/Linux; `libexec_dir`, `bin_dir`, `cmd_path`, `shim_path`, `path_added` on Windows). `dbaudit --version` reads it, and the installers and uninstallers use its recorded paths to remove a previous installation, including one installed to a custom location.

## Detecting an outdated binary

The installation is a **copy** of the checkout: pulling, committing, or editing the repo does not change the installed CLI. To detect drift, compare the installed build against the checkout:

```bash
dbaudit --version
git -C dbAudit rev-parse --short HEAD
```

If the `Build:` commit differs from the checkout `HEAD`, the installed CLI is running older code — re-run the installer to update it.

## CLI vs R package

The installers copy the runtime files and link a launcher; they never run `R CMD INSTALL`. Two distinct surfaces result:

- **CLI**: `dbaudit [geochemistry|piezometer|inclinometer] --project <DATA_ROOT>` — self-contained, sources its own copy of `R/` from the runtime root.
- **R package**: `library(dbAudit)` — required by project runners that call the exported entrypoints (`auditGeochemistry()`, `auditPiezometer()`, `auditInclinometer()`) from R. It is installed separately, with `R CMD INSTALL` on the checkout directory.

Installing or updating one surface does not update the other.
