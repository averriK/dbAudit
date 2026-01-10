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
#   macOS/Linux: sudo bash dbAudit/install/install.sh [--skip-packages]
#
# Options:
#   --skip-packages  Skip R package installation (packages will be installed on first run)
#
# Windows:
#   Use the PowerShell installer instead:
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
#
# Requirements:
#   - R (>= 3.5) must be installed and Rscript must be in PATH
#   - Internet connectivity (for package installation, unless --skip-packages is used)

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

# Parse arguments
SKIP_PACKAGES=false
for arg in "$@"; do
  if [[ "$arg" == "--skip-packages" ]]; then
    SKIP_PACKAGES=true
  fi
done

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

echo ""
info "Checking R installation..."
if ! command -v Rscript >/dev/null 2>&1; then
  error "R is not installed or Rscript is not in PATH.

dbAudit requires R (>= 3.5) to run.

Install R from CRAN:
  - macOS:  brew install r  OR  https://cran.r-project.org/bin/macosx/
  - Linux:  sudo apt install r-base  OR  https://cran.r-project.org/bin/linux/

After installing R, run this installer again."
fi

# Verify R version >= 3.5
R_VERSION=$(Rscript --version 2>&1 | grep -oE 'version [0-9]+\.[0-9]+' | head -1 | grep -oE '[0-9]+\.[0-9]+')
if [[ -z "$R_VERSION" ]]; then
  warn "Could not determine R version - assuming it's compatible"
else
  R_MAJOR=$(echo "$R_VERSION" | cut -d. -f1)
  R_MINOR=$(echo "$R_VERSION" | cut -d. -f2)

  if [[ "$R_MAJOR" -lt 3 ]] || { [[ "$R_MAJOR" -eq 3 ]] && [[ "$R_MINOR" -lt 5 ]]; }; then
    error "R version $R_VERSION found, but dbAudit requires R >= 3.5.

Please upgrade R from: https://cran.r-project.org/"
  fi

  ok "R version $R_VERSION detected"
fi

echo ""
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

info "Generating version file..."
(
  cd "$SRC_ROOT" >/dev/null 2>&1
  COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
  INSTALL_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || date -u)

  cat > "$LIBEXEC_DIR/.version" <<EOF
commit=$COMMIT
branch=$BRANCH
tag=$TAG
install_date=$INSTALL_DATE
EOF
) || warn "Could not generate version file (git not available or not a git repo)"

if [[ ! -f "$LIBEXEC_DIR/DBAudit" ]] || [[ ! -f "$LIBEXEC_DIR/R/setup.R" ]] || [[ ! -f "$LIBEXEC_DIR/bin/dbAudit" ]]; then
  error "Invalid installed layout: missing expected runtime files under $LIBEXEC_DIR"
fi

# Install R package dependencies
echo ""
if [[ "$SKIP_PACKAGES" = false ]]; then
  info "Installing R package dependencies (data.table, stringr, lubridate)..."
  info "This may take a few minutes..."

  INSTALL_SCRIPT=$(cat <<'REOF'
repos <- "https://cloud.r-project.org"
required <- c("data.table", "stringr", "lubridate")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  cat(sprintf("Installing: %s\n", paste(missing, collapse=", ")))
  install.packages(missing, repos = repos, quiet = FALSE)

  # Verify installation succeeded
  still_missing <- missing[!sapply(missing, requireNamespace, quietly = TRUE)]
  if (length(still_missing) > 0) {
    cat(sprintf("\nERROR: Failed to install packages: %s\n", paste(still_missing, collapse=", ")))
    cat("\nTroubleshooting:\n")
    cat("  1. Check internet connectivity\n")
    cat("  2. Verify CRAN mirror is accessible: https://cloud.r-project.org\n")
    cat("  3. Try manual installation: R -e 'install.packages(c(\"data.table\", \"stringr\", \"lubridate\"))'\n")
    cat("  4. Check R library permissions: .libPaths()\n")
    quit(status = 1)
  }

  cat("\nPackages installed successfully.\n")
} else {
  cat("All required packages already installed.\n")
}
REOF
)

  if ! echo "$INSTALL_SCRIPT" | Rscript - ; then
    error "Failed to install R packages. See troubleshooting steps above."
  fi

  ok "R packages installed successfully"
else
  warn "Skipping R package installation (--skip-packages flag used)"
  info "Packages will be auto-installed on first dbAudit run"
fi

echo ""
info "Linking $BIN_DIR/dbAudit -> $LIBEXEC_DIR/bin/dbAudit"
if ! ln -sf "$LIBEXEC_DIR/bin/dbAudit" "$BIN_DIR/dbAudit" 2>/dev/null; then
  error "Could not create symlink $BIN_DIR/dbAudit (permission denied?). Run this installer with sudo for a system-wide install."
fi

ok "Installation complete"

echo ""
info "Verify installation:"
info "  dbAudit --check"
info ""
info "Get help:"
info "  dbAudit --help"

echo ""
info "Documentation:"
info "  $DOCS_URL"
