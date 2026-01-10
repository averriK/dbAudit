#!/usr/bin/env bash
# dbAudit Installer (repo-based)
#
# Installs from the local repo / extracted package (no GitHub API).
#
# Layout (macOS/Linux, system-wide):
#   - /usr/local/bin/dbAudit
#   - /usr/local/libexec/dbAudit/...
#
# Usage:
#   macOS/Linux: sudo bash dbAudit/install/install.sh
#
# Windows:
#   Use the PowerShell installer instead:
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
#
# Note:
#   This installer does not install R. R (Rscript) is a runtime dependency.

set -euo pipefail

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

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
SRC_ROOT="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

# Validate local source tree
if [[ ! -f "$SRC_ROOT/DBAudit" ]] || [[ ! -f "$SRC_ROOT/R/setup.R" ]] || [[ ! -f "$SRC_ROOT/bin/dbAudit" ]]; then
  error "Invalid source tree. Run this installer from inside the dbAudit repo/package (expected DBAudit + R/ + bin/dbAudit)."
fi

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_S" in
  MINGW*|MSYS*|CYGWIN*)
    error "Windows detected. Use the PowerShell installer: powershell -NoProfile -ExecutionPolicy Bypass -File .\\dbAudit\\install\\install.ps1"
    ;;
  *)
    ;;
esac

# macOS/Linux system-wide install
BIN_DIR="/usr/local/bin"
LIBEXEC_DIR="/usr/local/libexec/dbAudit"
DOCS_URL="https://averrik.github.io/dbAudit/"

info "dbAudit Installer (macOS/Linux, repo-based)"

echo ""
info "Installation targets:"
info "  Binary : $BIN_DIR/dbAudit"
info "  Runtime: $LIBEXEC_DIR"

if command -v dbAudit >/dev/null 2>&1; then
  EXISTING="$(command -v dbAudit)"
  warn "An existing 'dbAudit' command is already in PATH at: $EXISTING"
  warn "If this is an old installation, consider removing it first."
  echo ""
fi

if [[ ! -d "$BIN_DIR" ]]; then
  info "Creating $BIN_DIR ..."
  if ! mkdir -p "$BIN_DIR" 2>/dev/null; then
    error "Could not create $BIN_DIR (permission denied?). Run this installer with sudo for a system-wide install."
  fi
fi

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

info "Copying runtime from $SRC_ROOT ..."
mkdir -p "$LIBEXEC_DIR/R" "$LIBEXEC_DIR/bin"
cp "$SRC_ROOT/DBAudit" "$LIBEXEC_DIR/DBAudit"
cp -R "$SRC_ROOT/R/." "$LIBEXEC_DIR/R/"
cp "$SRC_ROOT/bin/dbAudit" "$LIBEXEC_DIR/bin/dbAudit"

chmod +x "$LIBEXEC_DIR/bin/dbAudit" || true
chmod +x "$LIBEXEC_DIR/DBAudit" || true

if [[ ! -f "$LIBEXEC_DIR/DBAudit" ]] || [[ ! -f "$LIBEXEC_DIR/R/setup.R" ]] || [[ ! -f "$LIBEXEC_DIR/bin/dbAudit" ]]; then
  error "Invalid installed layout: missing expected runtime files under $LIBEXEC_DIR"
fi

info "Linking $BIN_DIR/dbAudit -> $LIBEXEC_DIR/bin/dbAudit"
if ! ln -sf "$LIBEXEC_DIR/bin/dbAudit" "$BIN_DIR/dbAudit" 2>/dev/null; then
  error "Could not create symlink $BIN_DIR/dbAudit (permission denied?). Run this installer with sudo for a system-wide install."
fi

ok "Installation complete"

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
