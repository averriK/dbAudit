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
  "https://api.github.com/repos/averriK/dbAudit/contents/install/install-mac.sh?ref=main" \
  -o install-dbAudit-mac.sh

sudo env DBAUDIT_GITHUB_TOKEN="$DBAUDIT_GITHUB_TOKEN" bash install-dbAudit-mac.sh
rm -f install-dbAudit-mac.sh
```

### Windows (Git Bash)

Open **Git Bash** and run:

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
