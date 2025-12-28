#!/usr/bin/env bash
# dbAudit Uninstaller for macOS/Linux (single /usr/local layout)
#
# Removes:
#   - /usr/local/bin/dbAudit
#   - /usr/local/libexec/dbAudit
#
# Note:
#   This script does not call sudo. If you installed with sudo, uninstall with sudo too.

set -euo pipefail

BIN_PATH="/usr/local/bin/dbAudit"
LIBEXEC_DIR="/usr/local/libexec/dbAudit"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()   { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()     { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "dbAudit Uninstaller (single /usr/local layout)"

if [[ -e "$BIN_PATH" ]]; then
  info "Removing $BIN_PATH"
  if ! rm -f "$BIN_PATH" 2>/dev/null; then
    error "Could not remove $BIN_PATH (permission denied?). Run this uninstaller with sudo."
  fi
  ok "Removed $BIN_PATH"
else
  warn "Not found: $BIN_PATH"
fi

if [[ -d "$LIBEXEC_DIR" ]]; then
  info "Removing $LIBEXEC_DIR"
  if ! rm -rf "$LIBEXEC_DIR" 2>/dev/null; then
    error "Could not remove $LIBEXEC_DIR (permission denied?). Run this uninstaller with sudo."
  fi
  ok "Removed $LIBEXEC_DIR"
else
  warn "Not found: $LIBEXEC_DIR"
fi

echo ""
ok "Uninstall complete"
