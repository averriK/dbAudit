#!/usr/bin/env bash
# Piezometer engine example: runs the bundled Vega synthetic site through
# the piezometer contract (PCG + PCV).
#
# The fixture ships in the repository under inst/fixtures/Vega and carries a
# known-truth corruption matrix (truth.csv). Its source/ tree is copied into
# a temporary project; the runner creates raw/, db/ and audit/ there, and
# the temporary directory is removed at the end.
#
# Always runs this checkout's engine via Rscript, so the output matches this
# revision regardless of any installed dbaudit.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$ROOT/inst/fixtures/Vega"

ENGINE=(Rscript "$ROOT/DBAudit")
echo "engine: ${ENGINE[*]}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

project="$WORK/Vega"
mkdir -p "$project"
cp -R "$FIXTURE/source" "$project/source"

"${ENGINE[@]}" piezometer --project "$project"

echo "-- audit/log.csv (timestamp column dropped) --"
cut -d, -f2- "$project/audit/log.csv"

echo "-- db/PCG.data.csv rows 4-6: RecordID 5 carries the repaired decimal comma --"
head -n 1 "$project/db/PCG.data.csv"
sed -n '5,7p' "$project/db/PCG.data.csv"

echo "-- audit/PCG.reject.csv: the COMMA repair record for that row --"
grep "3594,53" "$project/audit/PCG.reject.csv" | cut -d, -f2-
