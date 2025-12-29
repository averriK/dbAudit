---
layout: default
title: Windows
permalink: /docs/windows/
---

# Windows (Git Bash)

dbAudit runs on Windows using the Bash CLI via **Git Bash**.

## Install

Recommended (remote install):

This repo is private, so `raw.githubusercontent.com/...` will return `404` unless you authenticate.
Use the GitHub API with a token (read access).

Open **Git Bash**:

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo
export DBAUDIT_GITHUB_TOKEN

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install-win.sh?ref=main" \
  -o install-dbAudit-win.sh

bash install-dbAudit-win.sh
rm -f install-dbAudit-win.sh
```

## What gets installed where

- Wrapper: `$HOME/.local/bin/dbAudit`
- Runtime: `$HOME/.local/libexec/dbAudit`

## PATH (Git Bash)

Make sure Git Bash can find the wrapper:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Open a new Git Bash window after updating `~/.bashrc`.

## R / Rscript

dbAudit requires R (Windows) and `Rscript` must be discoverable from Git Bash.

Quick checks:

```bash
command -v Rscript || command -v Rscript.exe
Rscript --version 2>/dev/null || Rscript.exe --version
```

## Verify install

In a new Git Bash:

```bash
dbAudit --help
```

## Uninstall

Remote uninstall (Git Bash):

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo
export DBAUDIT_GITHUB_TOKEN

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall-win.sh?ref=main" \
  -o uninstall-dbAudit-win.sh

bash uninstall-dbAudit-win.sh
rm -f uninstall-dbAudit-win.sh
```
