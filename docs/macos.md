---
layout: default
title: macOS / Linux
permalink: /docs/macos/
---

# macOS / Linux

The macOS/Linux installer is `install/install.bash.sh`.

It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

## Install (remote-only)

This repo is private, so `raw.githubusercontent.com/...` will return `404` unless you authenticate.
Use the GitHub API with a token (read access):

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install.bash.sh?ref=main" \
  -o install-dbAudit.bash.sh

sudo env DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit.bash.sh
rm -f install-dbAudit.bash.sh
unset DBAUDIT_GITHUB_TOKEN
```

## What the installer does

Deterministic layout:

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`
  - `/usr/local/libexec/dbAudit/bin/dbAudit` (bash wrapper)
  - `/usr/local/libexec/dbAudit/DBAudit` (R entrypoint)
  - `/usr/local/libexec/dbAudit/R/...`

Notes:

- The installer does **not** install R.
- `dbAudit` requires `Rscript` at runtime (the wrapper calls `Rscript "$DBAUDIT_HOME/DBAudit" ...`).
- `DBAudit` sources `R/setup.R` at startup; `R/setup.R` installs missing packages (`data.table`, `stringr`, `lubridate`) and loads them.

## Uninstall

Remote uninstall:

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.bash.sh?ref=main" \
  -o uninstall-dbAudit.bash.sh

sudo bash uninstall-dbAudit.bash.sh
rm -f uninstall-dbAudit.bash.sh
unset DBAUDIT_GITHUB_TOKEN
```
