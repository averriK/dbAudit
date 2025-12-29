---
layout: default
title: Troubleshooting
permalink: /docs/troubleshooting/
---

# Troubleshooting

## `dbAudit: command not found`

### macOS / Linux

Confirm the binary exists:

```bash
ls -l /usr/local/bin/dbAudit
```

If it exists but your shell can’t find it, confirm `/usr/local/bin` is on your `PATH`.

### Windows

Open a **new** PowerShell window (PATH updates require a new session), then run:

```powershell
where.exe dbAudit
```

If nothing is returned, confirm `%USERPROFILE%\bin` is on your Windows **User PATH**.

## Remote install errors (private repo)

### `404 Not Found` when downloading an installer

If you see `{"message":"Not Found","status":"404"}` from the GitHub API, it usually means:

- you used a token that does not have access to this repo, or
- you are hitting the wrong repo path in the URL.

Double-check that the URL contains `averriK/dbAudit` and that the token has **read** access.

### `401/403` when downloading an installer

- `401 Unauthorized`: token is missing/invalid.
- `403 Forbidden`: token is valid but does not have permission.

### `Access to the path 'C:\\install-*.ps1' is denied`

This happens when you run from `PS C:\\>` and use a relative `-OutFile` like `install-dbAudit.ps1`.
PowerShell tries to write to `C:\\install-dbAudit.ps1`.

Fix: write to a safe path like `$env:TEMP` (see the [Install]({{ "/docs/install/" | relative_url }}) page).

## Permission denied during install on macOS/Linux

The macOS/Linux installer installs into `/usr/local` and does not run `sudo` internally.

Run it with `sudo`:

```bash
sudo bash install/install.sh
```

## `Rscript` not found

`dbAudit` requires `Rscript` at runtime.

### macOS / Linux

```bash
command -v Rscript
Rscript --version
```

If `command -v` prints nothing, install R for your OS and ensure `Rscript` is on PATH.

### Windows

```powershell
where.exe Rscript
```

If `Rscript.exe` exists on disk but is not found on PATH, add its directory to your Windows **User PATH** (or rerun the installer).

## R packages fail to install

When `dbAudit` runs, it sources `R/setup.R` and installs missing packages:

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
- Your OS and whether you installed via the installer scripts or from a local checkout.