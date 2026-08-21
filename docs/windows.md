---
layout: default
title: Windows
permalink: /docs/windows/
---

# Windows

dbaudit installs with **PowerShell** and runs through `Rscript`. The install
is **per-user and needs no administrator rights**: the runtime, the
launchers, and the PATH entry all live under your own profile.

R itself is a separate prerequisite — see [R and Rscript](#r-and-rscript)
below. The installer verifies the version and stops below **R 4.1.0**; it
does not install R.

## Install

With git:

```powershell
git clone https://github.com/averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

Without git, download the ZIP from the repository page
(`Code` -> `Download ZIP`), extract it, and run the installer from the
extracted folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit-main\install\install.ps1
```

An extracted ZIP carries no `.git`, so the manifest records the build as
`unknown`. Everything else installs identically.

`-ExecutionPolicy Bypass` applies to that one invocation only; it does not
change the machine policy.

### Update an existing clone

Pull the published branch before reinstalling:

```powershell
cd dbAudit; git checkout main; git pull
powershell -NoProfile -ExecutionPolicy Bypass -File .\install\install.ps1 -Force
```

### Options

| Option | Effect |
|---|---|
| `-Force` | Replace an existing installation without the `[y/N]` prompt |
| `-SkipPackages` | Do not install the R packages (they install on first run) |
| `-LibexecDir <PATH>` | Runtime location (default `%LOCALAPPDATA%\Programs\_runtime\dbAudit`) |
| `-UserBinDir <PATH>` | Launcher location (default `%LOCALAPPDATA%\Programs`) |
| `-RepoRoot <PATH>` | Source tree to install from (default: the parent of the installer) |

### What the installer does

- Copies the runtime — entrypoint, `R/`, and `inst/` (event catalog, parse
  manifest, fixtures) — under `-LibexecDir`.
- Writes two launchers under `-UserBinDir`: `dbaudit.cmd` for PowerShell and
  CMD, and a `dbaudit` shim for Git Bash.
- Adds that directory to the **User PATH**.
- Records the build in a `.version` manifest beside the runtime: commit,
  branch, install date, and the resolved paths, which the next
  reinstallation reads to know what to replace.
- Installs the five R packages unless `-SkipPackages` is given.

Reinstalling over an existing install prompts before replacing it. Under an
automated or non-interactive shell, pass `-Force`: the prompt has no one to
answer it.

**Open a new terminal after installing** so the PATH update is picked up.

## Verify

In a **new** terminal (PowerShell or Git Bash):

```powershell
dbaudit --version
```

Prints the installed build and date. `Build: unknown` means the manifest
could not record the commit — expected for a ZIP install, otherwise a sign
that git was unavailable to the installer.

```powershell
dbaudit --check
```

Reports the R version, the `Rscript` location, the installation root, and
the five required packages (`data.table`, `stringr`, `lubridate`, `readxl`,
`jsonlite`) with their versions. Unlike `--help`, it exercises the R
runtime, not just the launcher.

## R and Rscript

dbaudit does not install R. Install it from CRAN
(<https://cran.r-project.org/bin/windows/base/>) before running the
installer.

The CRAN installer does **not** add R to the PATH by default, and dbaudit
does not require it to: on every run the launcher looks for `Rscript` on
the PATH, then at the path this installation resolved, then in the
registry keys the CRAN installer writes (`SOFTWARE\R-core\R64`,
`\R`, per machine and per user). An R that is installed is found.

If dbaudit still reports that R is missing, check what the machine has:

PowerShell:

```powershell
Get-Command Rscript -ErrorAction SilentlyContinue
```

Git Bash:

```bash
command -v Rscript || command -v Rscript.exe
```

```powershell
reg query "HKLM\SOFTWARE\R-core\R64" /v InstallPath
```

Nothing on the PATH is normal and harmless. Nothing in the registry either
means R is not installed — install it from CRAN and run dbaudit again; no
reinstallation of dbaudit is needed.

Do **not** install a second copy of R to work around a PATH problem: two
installations keep separate package libraries, so packages installed by one
are invisible to the other.

## Data on shared or network drives

Keep the data root on a local disk. On a shared filesystem — a mapped
network drive, a synchronised folder, or a virtual-machine share — the log
writer can hit transient sharing violations. The run survives them and
reports how many records the log is missing, but the log is then
incomplete.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
```

Removes the runtime and both launchers. The bin directory stays on the User
PATH unless you pass `-RemoveUserBinFromPath`; other tools may rely on it.
Use `-LibexecDir` and `-UserBinDir` if the install used non-default paths.

## Troubleshooting

See [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }}) for
`command not found`, `Build: unknown`, execution-policy errors, and the
historical parse failures and their fixes.
