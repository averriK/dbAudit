#!/usr/bin/env bash
# dbaudit Uninstaller for macOS/Linux (single /usr/local layout)
#
# Removes:
#   - /usr/local/bin/dbaudit
#   - /usr/local/libexec/dbAudit
#
# Note:
#   This script does not call sudo. If you installed with sudo, uninstall with sudo too.

set -euo pipefail

BIN_PATH="/usr/local/bin/dbaudit"
LIBEXEC_DIR="/usr/local/libexec/dbAudit"
VERSION_FILE="$LIBEXEC_DIR/.version"
MANIFEST_PRESENT=false

# If a manifest exists, prefer the recorded paths.
if [[ -f "$VERSION_FILE" ]]; then
  MANIFEST_PRESENT=true
  BIN_PATH_MANIFEST="$(grep -E '^bin_path=' "$VERSION_FILE" | head -1 | cut -d= -f2- || true)"
  LIBEXEC_MANIFEST="$(grep -E '^libexec_dir=' "$VERSION_FILE" | head -1 | cut -d= -f2- || true)"
  if [[ -n "$BIN_PATH_MANIFEST" ]]; then
    BIN_PATH="$BIN_PATH_MANIFEST"
  fi
  if [[ -n "$LIBEXEC_MANIFEST" ]]; then
    LIBEXEC_DIR="$LIBEXEC_MANIFEST"
  fi
else
  warn "Install manifest not found at $VERSION_FILE."
  warn "Will only remove the default layout if you confirm."
  read -r -p "Proceed with uninstall of default layout? [y/N] " CONFIRM
  case "$CONFIRM" in
    [yY]) ;;
    *) info "Aborted by user."; exit 0 ;;
  esac
fi

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

info "dbaudit Uninstaller (single /usr/local layout)"

if [[ ! -e "$BIN_PATH" && ! -d "$LIBEXEC_DIR" ]]; then
  warn "No dbaudit installation found at recorded paths."
  exit 0
fi

remove_path() {
  local p="$1"
  if [[ -z "$p" || "$p" == "/" ]]; then
    return 0
  fi
  if [[ "$MANIFEST_PRESENT" != true ]]; then
    if [[ -L "$p" ]]; then
      local target
      target="$(readlink "$p" 2>/dev/null || true)"
      if [[ -n "$LIBEXEC_DIR" && -n "$target" && "$target" != "$LIBEXEC_DIR"* ]]; then
        warn "Skipping $p (symlink target not under $LIBEXEC_DIR)"
        return 0
      fi
    elif [[ -e "$p" ]]; then
      warn "Skipping $p (not a symlink; no manifest)"
      return 0
    fi
  fi
  info "Removing $p"
  if ! rm -f "$p" 2>/dev/null; then
    error "Could not remove $p (permission denied?). Run this uninstaller with sudo."
  fi
  ok "Removed $p"
}

remove_dir() {
  local d="$1"
  if [[ -z "$d" || "$d" == "/" ]]; then
    return 0
  fi
  if [[ -d "$d" ]]; then
    info "Removing $d"
    if ! rm -rf "$d" 2>/dev/null; then
      error "Could not remove $d (permission denied?). Run this uninstaller with sudo."
    fi
    ok "Removed $d"
  else
    warn "Not found: $d"
  fi
}

remove_path "$BIN_PATH"

remove_dir "$LIBEXEC_DIR"

echo ""
ok "Uninstall complete"
echo ""
info "Note: PATH or shell configuration is not modified automatically."
info "If you added dbAudit manually to your PATH, remove it manually from your shell rc."
