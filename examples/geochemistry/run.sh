#!/usr/bin/env bash
# Geochemistry engine example: runs the two bundled synthetic certificate
# fixtures (type A and type B) through the geochemistry contract.
#
# The fixtures ship in the repository under tests/testthat/fixtures/ and
# carry no client material. Each fixture is copied into a temporary project
# with the default layout (raw/lab + raw/assay); outputs land in proc/ and
# are removed with the temporary directory at the end.
#
# Always runs this checkout's engine via Rscript, so the output matches this
# revision regardless of any installed dbaudit.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$ROOT/tests/testthat/fixtures"

ENGINE=(Rscript "$ROOT/DBAudit")
echo "engine: ${ENGINE[*]}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

run_fixture() {
  local NAME="$1"
  local project="$WORK/$NAME"

  mkdir -p "$project/raw/lab" "$project/raw/assay"
  cp "$FIXTURES/$NAME/raw/"* "$project/raw/lab/"
  cp "$FIXTURES/$NAME/assay/"* "$project/raw/assay/"

  echo
  echo "== $NAME =="
  "${ENGINE[@]}" geochemistry --project "$project"

  echo "-- proc/log.csv (level, event, message) --"
  cut -d, -f2,4- "$project/proc/log.csv"

  echo "-- proc/lab.csv (first 3 rows) --"
  head -n 4 "$project/proc/lab.csv"
}

run_fixture synthetic-A
run_fixture synthetic-B
