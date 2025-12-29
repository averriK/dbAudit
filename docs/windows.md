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

Put your GitHub token in `~/.config/dbAudit/github.token` (recommended; CRLF/newlines stripped), then run:

```bash
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/install.windows?ref=main" | bash
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
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.windows?ref=main" | bash
```
