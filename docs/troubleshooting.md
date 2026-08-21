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

`Build: unknown` on **Windows** had a second cause until build `d108c85`: the PowerShell installer wrote the manifest with a byte-order mark, which turned the first line into an invisible key and hid every field from the reader, so *every* Windows install reported an unknown build however fresh it was. The installer now writes plain UTF-8 and the reader skips a leading mark, so existing installations resolve their build without reinstalling.

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

## Certificates fail to parse

A certificate that cannot be parsed is dropped **whole** — no partial ingest — while the rest of the run continues. Each one leaves a single `ERROR` row in the geochemistry log; how to read and filter it is in [Logging]({{ "/docs/logging/" | relative_url }}).

Before reading further, confirm which build you are running: all three failure modes below are fixed, and the first question is whether your installation predates the fix. See [Installed binary is outdated](#installed-binary-is-outdated).

### The same file parses on one machine and fails on another

**Symptom** — `PARSE_ERROR` whose message is `character string is not in a standard unambiguous format`, on certificates a colleague can parse without trouble. R prints that message in your system language when your R installation carries translations for it.

**Cause** — until build `e763076` the date reader translated Spanish and Portuguese month abbreviations into English and then parsed them with `%b`, which resolves against the host's `LC_TIME`. On a Windows host set to Spanish, an English `10-Apr-2025` was unreadable, and every certificate carrying one died. The identical files parsed on an English or C locale, which is what made this look like bad data rather than a bug.

**Resolved** — from `e763076`. Month names in English, Spanish and Portuguese normalize to their numbers before parsing, and no remaining format consults the locale. Two machines with different system languages now agree on every certificate. Details in [Certificate dates]({{ "/docs/parsers/" | relative_url }}#certificate-dates).

### A single unreadable date kills the whole certificate

**Symptom** — the same `character string is not in a standard unambiguous format`, but on a host whose locale is irrelevant: the certificate carries a month name in a language the reader does not cover (French `Avr`, German `Okt`), or a genuinely malformed date.

**Cause** — until build `77f2a68` the reader's last-resort attempt raised an error rather than returning empty, and that error propagated out and aborted the file.

**Resolved** — from `77f2a68`. A date that cannot be resolved lands as `NA` in `index.csv` and every assay value on the certificate ingests normally. An empty `dateReceived`/`dateFinalized` in the index is now the expected trace of an unusual date format, not a sign of a lost certificate.

### `Unexpected INDEX header` or `INDEX block not found`

**Symptom** — `PARSE_ERROR` with `Unexpected INDEX header: ...`, or `INDEX block not found: no SAMPLE row in the first column`, on type-A certificates.

**Cause** — until build `e763076` the type-A parser located its blocks by counting raw lines from the top of the file, assuming a fixed six-row header. A sub-variant from the same laboratory inserts `CLIENT`, `PROJECT` and `CERTIFICATE COMMENTS` rows, may span a quoted comment across several raw lines, and labels the method row `METHOD` — each of which shifted the count and made the analyte block land on the wrong rows.

**Resolved** — from `e763076`. The blocks are anchored on the `SAMPLE` row instead of on line numbers, so extra header rows and multi-line comments are harmless. The accepted variations are tabulated in [Accepted header sub-variant]({{ "/docs/parsers/" | relative_url }}#accepted-header-sub-variant).

If a certificate still fails on a current build, the two messages mean what they say: the parser could not find a `SAMPLE` row in the first column, or the five rows around it were not the expected `SAMPLE` / `DESCRIPTION` / `MIN DETECTION` / `MAX DETECTION` set. Open the file and compare it against that page before reporting it.

## Still stuck?

Capture:

- The exact command you ran.
- The full error output.
- The output of `dbaudit --check` and `dbaudit --version`.
- Your OS and whether you installed via the installer scripts.
