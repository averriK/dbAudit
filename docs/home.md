---
layout: default
title: dbAudit
permalink: /
---

# dbAudit

Geochemical certificate parser and audit tool.

- Parses **lab certificates** (type A and type B) into `lab.csv` + `index.csv`.
- Parses **assay/client tables** (type A and type B) into `client.csv`.
- Runs audits (structure + values).

## Requirements

- R installed (`Rscript` must be available at runtime).
- For remote installation from a **private** repo, you need a GitHub token provided by your administrator.

## Install

### macOS / Linux (system-wide `/usr/local`)

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install.sh?ref=main" \
  -o install-dbAudit.sh

sudo env DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit.sh
rm -f install-dbAudit.sh
```

### Windows (PowerShell)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$token = Read-Host "GitHub token (read access to averriK/dbAudit)"
$headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }

iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/install.ps1?ref=main" -OutFile install-dbAudit.ps1
.\install-dbAudit.ps1 -AutoInstall -GitHubToken $token
```

After installing, close and reopen PowerShell so PATH updates are picked up.

For more details (paths, uninstall, troubleshooting), see: [Install]({{ "/docs/install/" | relative_url }}).

## Run

```bash
dbAudit --project project/<PROJECT>/data
```

Outputs under `--project`:

- `proc/`
- `proc/log.csv`

Next:

- [Quick start]({{ "/docs/quickstart/" | relative_url }})
- [Logging]({{ "/docs/logging/" | relative_url }})
- [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }})
