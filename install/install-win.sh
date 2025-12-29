#!/usr/bin/env bash
# dbAudit Installer for Windows (Git Bash)
#
# Installs a user-local layout (no admin required):
#   - Wrapper:  $HOME/.local/bin/dbAudit
#   - Runtime:  $HOME/.local/libexec/dbAudit
#
# Two modes:
#   - Local mode:  run from a cloned/extracted repo
#   - Remote mode: download the main tarball and install
#
# Private repo support:
#   - Set DBAUDIT_GITHUB_TOKEN with read access.
#
# Example (remote, private repo):
#   read -s -p "GitHub token: " DBAUDIT_GITHUB_TOKEN; echo
#   export DBAUDIT_GITHUB_TOKEN
#   curl -fsSL \
#     -H "Authorization: Bearer $DBAUDIT_GITHUB_TOKEN" \
#     -H "Accept: application/vnd.github.raw" \
#     "https://api.github.com/repos/averriK/dbAudit/contents/install/install-win.sh?ref=main" \
#     -o install-dbAudit-win.sh
#   bash install-dbAudit-win.sh
#   rm -f install-dbAudit-win.sh

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
LIBEXEC_DIR="${HOME}/.local/libexec/dbAudit"
GITHUB_REPO="averriK/dbAudit"
TARBALL_URL_PUBLIC="https://codeload.github.com/${GITHUB_REPO}/tar.gz/refs/heads/main"
TARBALL_URL_API="https://api.github.com/repos/${GITHUB_REPO}/tarball/main"

# Colours (for clarity only)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()   { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()     { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "dbAudit Installer (Windows / Git Bash)"

# Detect local checkout
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

SRC_ROOT=""
if [[ -f "$REPO_ROOT/DBAudit" ]] && [[ -d "$REPO_ROOT/R" ]] && [[ -f "$REPO_ROOT/bin/dbAudit" ]]; then
  info "Local checkout detected at: $REPO_ROOT"
  SRC_ROOT="$REPO_ROOT"
else
  # Remote mode
  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    error "curl and tar are required to install dbAudit (not found in PATH)."
  fi

  info "No local checkout detected; downloading dbAudit from main branch..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  TARBALL_URL="$TARBALL_URL_PUBLIC"
  CURL_ARGS=()

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
fi

echo ""
info "Installation targets:"
info "  Wrapper: $BIN_DIR/dbAudit"
info "  Runtime: $LIBEXEC_DIR"

# Create target dirs
mkdir -p "$BIN_DIR"

# Replace runtime tree
if [[ -d "$LIBEXEC_DIR" ]]; then
  warn "Existing runtime directory found at $LIBEXEC_DIR – it will be replaced."
  rm -rf "$LIBEXEC_DIR"
fi
mkdir -p "$LIBEXEC_DIR" "$LIBEXEC_DIR/R" "$LIBEXEC_DIR/bin"

# Copy runtime
info "Copying runtime from $SRC_ROOT ..."
cp "$SRC_ROOT/DBAudit" "$LIBEXEC_DIR/DBAudit"
cp -R "$SRC_ROOT/R/." "$LIBEXEC_DIR/R/"
cp "$SRC_ROOT/bin/dbAudit" "$LIBEXEC_DIR/bin/dbAudit"

chmod +x "$LIBEXEC_DIR/bin/dbAudit" || true
chmod +x "$LIBEXEC_DIR/DBAudit" || true

# Create a Git Bash wrapper (no symlink; symlinks are often restricted on Windows)
WRAPPER="$BIN_DIR/dbAudit"
info "Writing wrapper: $WRAPPER"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

export DBAUDIT_HOME="${LIBEXEC_DIR}"

# Validate runtime
if [[ ! -f "\$DBAUDIT_HOME/DBAudit" ]]; then
  echo "ERROR: Invalid dbAudit installation: missing DBAudit entrypoint" >&2
  echo "DBAUDIT_HOME: \$DBAUDIT_HOME" >&2
  exit 1
fi

# Prefer Rscript, but fall back to Rscript.exe (Git Bash)
if command -v Rscript >/dev/null 2>&1; then
  RSCRIPT=Rscript
elif command -v Rscript.exe >/dev/null 2>&1; then
  RSCRIPT=Rscript.exe
else
  echo "ERROR: Rscript not found in PATH. Install R for Windows and ensure it is discoverable from Git Bash." >&2
  exit 1
fi

exec "\$RSCRIPT" "\$DBAUDIT_HOME/DBAudit" "\$@"
EOF
chmod +x "$WRAPPER" || true

ok "Installation complete"
echo ""
info "Next steps (Git Bash):"
info "  1) Ensure this is in your PATH: $BIN_DIR"
info "     Example: echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc"
info "  2) Verify: dbAudit --help"

if command -v Rscript >/dev/null 2>&1 || command -v Rscript.exe >/dev/null 2>&1; then
  ok "Rscript found"
else
  warn "Rscript not found in PATH (dbAudit will not run until R is installed/discoverable)."
fi
