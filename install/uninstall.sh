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
# Some environments may have a non-canonical alias with different casing.
# We remove it only if it points into our runtime.
BIN_PATH_ALIAS="/usr/local/bin/dbaudit"
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

# Remove bin entries, but be conservative: only remove the alias if it points into our runtime.

removeIfLinkPointsToRuntime() {
  local bin_path="$1"

  if [[ ! -e "$bin_path" ]]; then
    warn "Not found: $bin_path"
    return 0
  fi

  # Canonical binary symlink: remove unconditionally.
  if [[ "$bin_path" == "$BIN_PATH" ]]; then
    info "Removing $bin_path"
    if ! rm -f "$bin_path" 2>/dev/null; then
      error "Could not remove $bin_path (permission denied?). Run this uninstaller with sudo."
    fi
    ok "Removed $bin_path"
    return 0
  fi

  # Alias: remove only if it is a symlink into our runtime.
  if [[ -L "$bin_path" ]]; then
    local link
    link="$(readlink "$bin_path" 2>/dev/null || true)"

    # If link is relative, we keep the conservative check and do not attempt to resolve.
    if [[ "$link" == "$LIBEXEC_DIR"/* ]]; then
      info "Removing alias symlink $bin_path -> $link"
      if ! rm -f "$bin_path" 2>/dev/null; then
        error "Could not remove $bin_path (permission denied?). Run this uninstaller with sudo."
      fi
      ok "Removed $bin_path"
    else
      warn "Skipping $bin_path (symlink target not under $LIBEXEC_DIR)"
    fi
  else
    warn "Skipping $bin_path (not a symlink; not removing unknown file)"
  fi
}

removeIfLinkPointsToRuntime "$BIN_PATH"
removeIfLinkPointsToRuntime "$BIN_PATH_ALIAS"

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
