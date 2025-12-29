---
layout: default
title: Install
permalink: /docs/install/
---

# Install

This repo is private.
To install without a GitHub account, you need a GitHub token (read access) provided by your administrator.

## macOS / Linux

The macOS/Linux installer is `install/install.bash.sh`.
It installs a system-wide layout under `/usr/local`, so you typically run it with `sudo`.

The installer is **remote-only**: it always downloads dbAudit and does not install from a local checkout.

### Remote install (recommended)

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

### Installed paths

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`

### Uninstall

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

## Windows (Git Bash)

dbAudit can be installed on Windows using **Git Bash**.

It installs a user-local layout (no admin required):

- Wrapper: `$HOME/.local/bin/dbAudit`
- Runtime: `$HOME/.local/libexec/dbAudit`

The installer is **remote-only**: it always downloads dbAudit and does not install from a local checkout.

### Remote install (recommended)

Open **Git Bash**:

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

### PATH (Git Bash)

Make sure Git Bash can find the wrapper:

```bash
echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.bashrc
```

### Uninstall

Remote uninstall (Git Bash):

```bash
read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo

curl -fsSL \
  -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.windows?ref=main" \
  -o uninstall-dbAudit.windows

bash uninstall-dbAudit.windows
rm -f uninstall-dbAudit.windows
unset DBAUDIT_GITHUB_TOKEN
```

## OS-specific notes

- macOS/Linux details: [macOS / Linux]({{ "/docs/macos/" | relative_url }})
- Windows details: [Windows]({{ "/docs/windows/" | relative_url }})
