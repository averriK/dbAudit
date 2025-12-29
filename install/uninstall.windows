#!/usr/bin/env bash
# dbAudit Uninstaller for Windows (Git Bash)
#
# Removes:
#   - $HOME/.local/bin/dbAudit
#   - $HOME/.local/libexec/dbAudit

set -euo pipefail

BIN_PATH="${HOME}/.local/bin/dbAudit"
LIBEXEC_DIR="${HOME}/.local/libexec/dbAudit"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()   { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()     { echo -e "${GREEN}[OK]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

info "dbAudit Uninstaller (Windows / Git Bash)"

if [[ -e "$BIN_PATH" ]]; then
  info "Removing $BIN_PATH"
  rm -f "$BIN_PATH"
  ok "Removed $BIN_PATH"
else
  warn "Not found: $BIN_PATH"
fi

if [[ -d "$LIBEXEC_DIR" ]]; then
  info "Removing $LIBEXEC_DIR"
  rm -rf "$LIBEXEC_DIR"
  ok "Removed $LIBEXEC_DIR"
else
  warn "Not found: $LIBEXEC_DIR"
fi

echo ""
ok "Uninstall complete"