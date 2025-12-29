---
layout: default
title: Install
permalink: /docs/install/
---

# Install

This repo is private.
To install without a GitHub account, you need a GitHub token (read access) provided by your administrator.

## macOS / Linux

The macOS/Linux installer is `install/install-mac.sh`.
It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

### Remote install (recommended)

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

### Install from a local checkout

If you already have a local copy of the repo:

```bash
sudo bash install/install-mac.sh
```

### Installed paths

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`

### Uninstall

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall-mac.sh?ref=main" \
  -o uninstall-dbAudit-mac.sh

sudo bash uninstall-dbAudit-mac.sh
rm -f uninstall-dbAudit-mac.sh
```

## Windows (Git Bash)

dbAudit can be installed on Windows using **Git Bash**.

It installs a user-local layout (no admin required):

- Wrapper: `$HOME/.local/bin/dbAudit`
- Runtime: `$HOME/.local/libexec/dbAudit`

### Remote install (recommended)

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

### Install from a local checkout

From Git Bash, inside a repo checkout:

```bash
bash install/install-win.sh
```

### PATH (Git Bash)

Make sure Git Bash can find the wrapper:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Uninstall

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

## OS-specific notes

- macOS/Linux details: [macOS / Linux]({{ "/docs/macos/" | relative_url }})
- Windows details: [Windows]({{ "/docs/windows/" | relative_url }})
