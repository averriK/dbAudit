#!/usr/bin/env bash
# Convenience wrapper (local checkout)
#
# Recommended usage:
#   bash install.sh
#
# Remote (no repo):
#   curl -fsSL https://raw.githubusercontent.com/SRKConsulting/PE-DBAudit/main/install/install.sh | bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
exec bash "$ROOT_DIR/install/install.sh" "$@"
