#!/usr/bin/env bash
# dbAudit Installer for macOS/Linux (single /usr/local layout)
#
# Goals:
#   - Single installation layout (no ~/.local)
#   - No sudo calls inside this script (run it with sudo if needed)
#   - Clear, deterministic locations:
#       * Binary:  /usr/local/bin/dbAudit
#       * Runtime: /usr/local/libexec/dbAudit (DBAudit, R/, bin/dbAudit)
#   - Remote-only (no local checkout mode):
#       * The installer always downloads the dbAudit tarball for main.
#       * Even if you run this script from inside a repo checkout, it will ignore local files.
#
# Usage (remote install, private repo):
#   Put a GitHub token (read access) in one of these files (recommended for Windows users
#   who can't paste into Git Bash):
#     - ~/.config/dbAudit/github.token
#     - ~/.dbAudit.token
#
#   Then run (no prompts):
#     curl -fsSL \
#       -H "Authorization: Bearer $(tr -d $'\\r\\n' < ~/.config/dbAudit/github.token)" \
#       -H "Accept: application/vnd.github.raw" \
#       "https://api.github.com/repos/averriK/dbAudit/contents/install/install.bash.sh?ref=main" \
#     | sudo bash
#
# Note:
#   This installer does not install R. R (Rscript) is a runtime dependency.

set -euo pipefail

BIN_DIR="/usr/local/bin"
LIBEXEC_DIR="/usr/local/libexec/dbAudit"
GITHUB_REPO="averriK/dbAudit"
TARBALL_URL_PUBLIC="https://codeload.github.com/${GITHUB_REPO}/tar.gz/refs/heads/main"
TARBALL_URL_API="https://api.github.com/repos/${GITHUB_REPO}/tarball/main"
DOCS_URL="https://averrik.github.io/dbAudit/"

# Token discovery (optional)
# - Preferred: env var DBAUDIT_GITHUB_TOKEN
# - Otherwise: read from a token file (CRLF/newlines stripped)
CALLER_HOME="$HOME"
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  # Resolve invoking user's home so token files work even when running under sudo.
  CALLER_HOME_RESOLVED="$(eval echo "~${SUDO_USER}" 2>/dev/null || true)"
  if [[ -n "$CALLER_HOME_RESOLVED" && "$CALLER_HOME_RESOLVED" != "~${SUDO_USER}" ]]; then
    CALLER_HOME="$CALLER_HOME_RESOLVED"
  fi
fi

if [[ -z "${DBAUDIT_GITHUB_TOKEN:-}" ]]; then
  for f in \
    "${DBAUDIT_TOKEN_FILE:-}" \
    "$CALLER_HOME/.config/dbAudit/github.token" \
    "$CALLER_HOME/.dbAudit.github.token" \
    "$CALLER_HOME/.dbAudit.token"; do
    [[ -n "$f" ]] || continue
    if [[ -f "$f" ]]; then
      DBAUDIT_GITHUB_TOKEN="$(tr -d $'\r\n' < "$f")"
      if [[ -n "${DBAUDIT_GITHUB_TOKEN:-}" ]]; then
        break
      fi
    fi
  done
fi

# Colours (for clarity only)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()   { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()     { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "dbAudit Installer (single /usr/local layout)"

# Remote-only: download tarball for main into a temporary directory
if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  error "curl and tar are required to install dbAudit (not found in PATH)."
fi

info "Downloading dbAudit from main branch..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TARBALL_URL="$TARBALL_URL_PUBLIC"
CURL_ARGS=()

# Private repo support: use a token-authenticated GitHub API tarball.
if [[ -n "${DBAUDIT_GITHUB_TOKEN:-}" ]]; then
  TARBALL_URL="$TARBALL_URL_API"
  CURL_ARGS+=(
    -H "Authorization: Bearer ${DBAUDIT_GITHUB_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "User-Agent: dbAudit-installer"
  )
fi

info "Downloading $TARBALL_URL"
if ! curl -fsSL "${CURL_ARGS[@]}" "$TARBALL_URL" -o "$TMP_DIR/dbaudit.tar.gz"; then
  if [[ -z "${DBAUDIT_GITHUB_TOKEN:-}" ]]; then
    error "Failed to download dbAudit. If this repo is private, set DBAUDIT_GITHUB_TOKEN (read-only) and rerun."
  fi
  error "Failed to download dbAudit from $TARBALL_URL"
fi
ok "Downloaded archive"

info "Extracting archive..."
if ! tar -xzf "$TMP_DIR/dbaudit.tar.gz" -C "$TMP_DIR" --strip-components=1 2>/dev/null; then
  error "Failed to extract archive"
fi
ok "Extracted"

SRC_ROOT="$TMP_DIR"

echo ""
info "Installation targets:"
info "  Binary : $BIN_DIR/dbAudit"
info "  Runtime: $LIBEXEC_DIR"

# Warn if an existing dbAudit is present in PATH
if command -v dbAudit >/dev/null 2>&1; then
  EXISTING="$(command -v dbAudit)"
  warn "An existing 'dbAudit' command is already in PATH at: $EXISTING"
  warn "If this is an old installation, consider removing it first."
  echo ""
fi

# Create target directories (no sudo inside; rely on caller's permissions)
if [[ ! -d "$BIN_DIR" ]]; then
  info "Creating $BIN_DIR ..."
  if ! mkdir -p "$BIN_DIR" 2>/dev/null; then
    error "Could not create $BIN_DIR (permission denied?). Run this installer with sudo for a system-wide install."
  fi
fi

# Fully replace runtime tree to avoid stale files
if [[ -d "$LIBEXEC_DIR" ]]; then
  warn "Existing runtime directory found at $LIBEXEC_DIR – it will be replaced."
  if ! rm -rf "$LIBEXEC_DIR" 2>/dev/null; then
    error "Could not remove $LIBEXEC_DIR (permission denied?). Run this installer with sudo for a system-wide install."
  fi
fi

info "Creating $LIBEXEC_DIR ..."
if ! mkdir -p "$LIBEXEC_DIR" 2>/dev/null; then
  error "Could not create $LIBEXEC_DIR (permission denied?). Run this installer with sudo for a system-wide install."
fi

# Copy runtime (minimal)
info "Copying runtime from $SRC_ROOT ..."

mkdir -p "$LIBEXEC_DIR/R" "$LIBEXEC_DIR/bin"

cp "$SRC_ROOT/DBAudit" "$LIBEXEC_DIR/DBAudit"
cp -R "$SRC_ROOT/R/." "$LIBEXEC_DIR/R/"
cp "$SRC_ROOT/bin/dbAudit" "$LIBEXEC_DIR/bin/dbAudit"

chmod +x "$LIBEXEC_DIR/bin/dbAudit" || true
chmod +x "$LIBEXEC_DIR/DBAudit" || true

# Validate installed layout
if [[ ! -f "$LIBEXEC_DIR/DBAudit" ]] || [[ ! -f "$LIBEXEC_DIR/R/setup.R" ]] || [[ ! -f "$LIBEXEC_DIR/bin/dbAudit" ]]; then
  error "Invalid installed layout: missing expected runtime files under $LIBEXEC_DIR"
fi

# Create/overwrite symlink in /usr/local/bin
info "Linking $BIN_DIR/dbAudit -> $LIBEXEC_DIR/bin/dbAudit"
if ! ln -sf "$LIBEXEC_DIR/bin/dbAudit" "$BIN_DIR/dbAudit" 2>/dev/null; then
  error "Could not create symlink $BIN_DIR/dbAudit (permission denied?). Run this installer with sudo for a system-wide install."
fi

ok "Installation complete"

echo ""
info "Installed files:"
info "  $BIN_DIR/dbAudit"
info "  $LIBEXEC_DIR/bin/dbAudit"
info "  $LIBEXEC_DIR/DBAudit"
info "  $LIBEXEC_DIR/R/..."

echo ""
info "Verify with:"
info "  dbAudit --help"

echo ""
info "Runtime checks (required to run dbAudit):"
if command -v Rscript >/dev/null 2>&1; then
  ok "Rscript: $(Rscript --version 2>&1 | head -n 1)"
else
  warn "Rscript: not found"
  warn "Install R and make sure 'Rscript' is available in PATH."
  warn "CRAN: https://cran.r-project.org/"
fi

echo ""
info "Documentation:"
info "  $DOCS_URL"
