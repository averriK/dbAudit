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

Put your GitHub token in `~/.config/dbAudit/github.token` (recommended; CRLF/newlines stripped), then run:

```bash
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/install.bash.sh?ref=main" | sudo bash
```

### Installed paths

- Binary: `/usr/local/bin/dbAudit`
- Runtime: `/usr/local/libexec/dbAudit/`

### Uninstall

```bash
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.bash.sh?ref=main" | sudo bash
```

## Windows (Git Bash)

dbAudit can be installed on Windows using **Git Bash**.

It installs a user-local layout (no admin required):

- Wrapper: `$HOME/.local/bin/dbAudit`
- Runtime: `$HOME/.local/libexec/dbAudit`

The installer is **remote-only**: it always downloads dbAudit and does not install from a local checkout.

### Remote install (recommended)

Open **Git Bash**:

Put your GitHub token in `~/.config/dbAudit/github.token` (recommended; CRLF/newlines stripped), then run:

```bash
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/install.windows?ref=main" | bash
```

### PATH (Git Bash)

Make sure Git Bash can find the wrapper:

```bash
echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.bashrc
```

### Uninstall

Remote uninstall (Git Bash):

```bash
curl -fsSL -H "Authorization: Bearer $(tr -d $'\r\n' < ~/.config/dbAudit/github.token)" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/averriK/dbAudit/contents/install/uninstall.windows?ref=main" | bash
```

## OS-specific notes

- macOS/Linux details: [macOS / Linux]({{ "/docs/macos/" | relative_url }})
- Windows details: [Windows]({{ "/docs/windows/" | relative_url }})
