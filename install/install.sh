#!/usr/bin/env bash
# dbAudit installer (user-mode, cross-platform)
# - Works on macOS/Linux and Windows via Git Bash
# - Installs the dbAudit CLI into $HOME/bin (no sudo)
# - Installs runtime into $HOME/.local/libexec/dbAudit
# - Verifies Rscript and installs required R packages via R/setup.R
#
# Usage (local checkout):
#   bash install/install.sh
#
# Usage (remote, no repo):
#   curl -fsSL https://raw.githubusercontent.com/averriK/dbAudit/main/install/install.sh | bash

set -euo pipefail

BIN_DIR="$HOME/bin"
LIBEXEC_DIR="$HOME/.local/libexec/dbAudit"
GITHUB_REPO="averriK/dbAudit"
TARBALL_URL="https://codeload.github.com/${GITHUB_REPO}/tar.gz/refs/heads/main"

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

info "dbAudit installer (user mode)"

# Detect if we are running from a local checkout (SCRIPT_DIR/.. contains DBAudit + R/ + bin/dbAudit)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

SRC_ROOT=""
if [[ -f "$REPO_ROOT/DBAudit" ]] && [[ -d "$REPO_ROOT/R" ]] && [[ -f "$REPO_ROOT/bin/dbAudit" ]]; then
  info "Local checkout detected at: $REPO_ROOT"
  SRC_ROOT="$REPO_ROOT"
else
  # Remote mode: download tarball for main into a temporary directory
  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    error "curl and tar are required for remote install (not found in PATH)."
  fi

  info "No local checkout detected; downloading dbAudit from main branch..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  info "Downloading $TARBALL_URL"
  if ! curl -fsSL "$TARBALL_URL" -o "$TMP_DIR/dbaudit.tar.gz"; then
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
info "  Binary : $BIN_DIR/dbAudit"
info "  Runtime: $LIBEXEC_DIR"

# Create target directories (no sudo inside; rely on caller permissions)
if [[ ! -d "$BIN_DIR" ]]; then
  info "Creating $BIN_DIR ..."
  if ! mkdir -p "$BIN_DIR" 2>/dev/null; then
    error "Could not create $BIN_DIR (permission denied?)"
  fi
fi

# Fully replace runtime tree to avoid stale files
if [[ -d "$LIBEXEC_DIR" ]]; then
  warn "Existing runtime directory found at $LIBEXEC_DIR – it will be replaced."
  if ! rm -rf "$LIBEXEC_DIR" 2>/dev/null; then
    error "Could not remove $LIBEXEC_DIR (permission denied?)"
  fi
fi

info "Creating $LIBEXEC_DIR ..."
if ! mkdir -p "$LIBEXEC_DIR" 2>/dev/null; then
  error "Could not create $LIBEXEC_DIR (permission denied?)"
fi

# Copy runtime (minimal)
info "Copying runtime from $SRC_ROOT ..."

mkdir -p "$LIBEXEC_DIR/R" "$LIBEXEC_DIR/bin"

cp "$SRC_ROOT/DBAudit" "$LIBEXEC_DIR/DBAudit"
cp -R "$SRC_ROOT/R/." "$LIBEXEC_DIR/R/"
cp "$SRC_ROOT/bin/dbAudit" "$LIBEXEC_DIR/bin/dbAudit"
chmod +x "$LIBEXEC_DIR/bin/dbAudit" || true

# Create/overwrite shim in $HOME/bin
SHIM_PATH="$BIN_DIR/dbAudit"
info "Writing shim: $SHIM_PATH"
cat > "$SHIM_PATH" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$LIBEXEC_DIR/bin/dbAudit" "\$@"
EOF
chmod +x "$SHIM_PATH" || true

# Verify R is available
if ! command -v Rscript >/dev/null 2>&1; then
  warn "Rscript not found in PATH. You must install R before running dbAudit."
  warn "CRAN: https://cran.r-project.org/"
else
  ok "Rscript found: $(command -v Rscript)"

  info "Installing / verifying R package dependencies..."
  (cd "$LIBEXEC_DIR" && Rscript -e 'source("R/setup.R"); cat("OK: R dependencies installed and loaded.\n")')
fi

# PATH hint
case ":$PATH:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR is on PATH" ;;
  *)
    warn "$BIN_DIR is not on PATH in this shell."
    warn "Add it to PATH (example):"
    warn "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo ""
ok "Installation complete"

echo ""
info "Verify with:"
info "  dbAudit --help"
echo ""
info "Run with:"
info "  dbAudit --project project/<PROJECT>/data"
echo ""
info "Documentation:"
info "  https://github.com/averriK/dbAudit/tree/main/docs/quickstart.md"
