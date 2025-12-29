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

### Windows (Git Bash)

Open a **new** Git Bash window and run:

```bash
command -v dbAudit
```

If nothing is returned, ensure `$HOME/.local/bin` is on your Git Bash `PATH`.

## Remote install errors (private repo)

### `404 Not Found` when downloading an installer

If you see `{"message":"Not Found","status":"404"}` from the GitHub API, it usually means:

- you used a token that does not have access to this repo, or
- you are hitting the wrong repo path in the URL.

Double-check that the URL contains `averriK/dbAudit` and that the token has **read** access.

### `401/403` when downloading an installer

- `401 Unauthorized`: token is missing/invalid.
- `403 Forbidden`: token is valid but does not have permission.


## Permission denied during install on macOS/Linux

The macOS/Linux installer installs into `/usr/local` and does not run `sudo` internally.

Run it with `sudo`:

```bash
sudo bash install/install-mac.sh
```

## `Rscript` not found

`dbAudit` requires `Rscript` at runtime.

### macOS / Linux

```bash
command -v Rscript
Rscript --version
```

If `command -v` prints nothing, install R for your OS and ensure `Rscript` is on PATH.

### Windows (Git Bash)

```bash
command -v Rscript || command -v Rscript.exe
```

If `Rscript` is not found, install R for Windows and ensure Git Bash can discover it (it must be on PATH in Git Bash).

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