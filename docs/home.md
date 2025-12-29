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
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install.bash.sh?ref=main" \
  -o install-dbAudit.bash.sh

sudo env DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit.bash.sh
rm -f install-dbAudit.bash.sh
unset DBAUDIT_GITHUB_TOKEN
```

### Windows (Git Bash)

Open **Git Bash** and run:

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install.windows?ref=main" \
  -o install-dbAudit.windows

DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit.windows
rm -f install-dbAudit.windows
unset DBAUDIT_GITHUB_TOKEN
```

Make sure Git Bash can find `dbAudit`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

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
