---
layout: default
title: Tests
permalink: /docs/tests/
---

# Tests

The versioned test suite lives in `tests/testthat/` (testthat edition 3,
declared in `DESCRIPTION`). It is the only suite that ships with the
repository: every fixture it depends on is either versioned under
`tests/testthat/fixtures/` or installed with the package from
`inst/fixtures/`.

## Running the suite

From the repository root:

```sh
Rscript -e 'testthat::test_local()'
```

Verified 2026-08-21 on a hydrated checkout:

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 124 ]
```

On a fresh clone the two golden tests that target the local-only
`project/` datasets skip (see `test-golden-outputs.R` below); everything
else runs, including under `R CMD check`.

To run a single file, filter by name:

```sh
Rscript -e 'testthat::test_local(filter = "vega")'
```

Verified output: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 103 ]`.

## The six test files

### `test-vega.R` — acceptance suite of the monitoring engine

Runs the full pipeline on Vega, the synthetic corrupt site shipped in
`inst/fixtures/Vega` (three domains — PCG, PCV, INC — under `source/`,
plus the known-truth manifest `truth.csv`). The fixture carries 23
injected defects covering 15 distinct `(event, level)` pairs across 13
events, plus 4 anti-ghost controls; the generator is
`dev/generateVega.R`. The suite copies the fixture to a temporary
project, runs `auditPiezometer()` and then `auditInclinometer()`, and
asserts four gates:

- **Gate a** — every injection detectable today fires with its expected
  level, in the log or in the gate sink (`audit/PCG.reject.csv`).
- **Gate b** — nothing else fires: the complete `(level, event)` count
  table of each log is pinned, so any new emission is a test failure
  (zero ghosts).
- **Gate c** — every correction leaves the correct value in the
  database (decimal-comma repairs, systematic filename repairs).
- **Gate d** — every uncorrectable injection stays visible in the
  products (gaps, duplicated rows, misclosure evidence, flag `D`,
  malformed sheets, index conflicts).

The suite also pins the two deliberate non-emissions — MISCLOSURE
(check suspended pending the row-local redesign) and DRY (recorded as
flag `D` in `PZ.data.csv`, not as a log row) — so a future change in
either is a deliberate re-record of the suite, never an accident.

### `test-census-repairs.R` — census vs. filename repairs

Unit contract of the source-to-database census rekey
(`.checkRawDBKeys()` with a repairs table). Vega alone can only prove
the anti-ghost half (a repaired record that reaches the database must
not fire MISSING); this file pins the discriminating half: a repaired
record lost on the way to the database must still fire MISSING. It also
pins the pre-fix behavior without a repairs table (two mirrored MISSING
from the typed-vs-repaired key mismatch) and asserts that the caller's
raw table keeps its typed key. This is the guard against reintroducing
the rejected design that discounted repaired sources from both census
sides.

### `test-synthetic-fixtures.R` — versioned geochemistry goldens

Golden regression on the two synthetic certificate fixtures under
`tests/testthat/fixtures/` — `synthetic-A` and `synthetic-B`, one per
certificate model (type A, type B). Each run is compared against
recorded md5 sums of `lab.csv`, `index.csv` and `client.csv` (bytes are
the contract) and against the expected `(level, event)` counts of
`log.csv`. The fixtures carry no client material and ship with the
package, so these goldens run everywhere, including `R CMD check`. The
generator is `dev/buildFixtures.R`; regenerating the fixtures is an
intentional contract change that re-records the golden values.

### `test-golden-outputs.R` — local-only extended goldens

The same golden mechanics (md5 sums plus log event counts) applied to
the larger datasets under `project/`, which are ignored by git and
excluded from the build tarball. These tests skip when the datasets are
absent or present only as unhydrated LFS pointers; when they run,
expect several minutes per fixture. They are an optional extended
check, not part of the versioned baseline.

### `test-dbaudit.R` — package smoke test

Asserts that `DBAudit` is exported and, when a local checkout example
is available, that a run produces the log, lab and client outputs.

### `test-verify-docs.R` — documentation drift guard

Runs `inst/scripts/verifyDocs.R` in a subprocess and asserts a clean
exit. The guard cross-checks the documentation surface against the
code's single sources of truth: path defaults, subcommands and the docs
URL from the live CLI help, the required package list from `R/setup.R`,
the monitoring path defaults from `R/auditPiezometer.R`, the event
table in `docs/logging.md` against `inst/events.csv`, and a local
(never versioned) forbidden-pattern list. It skips on installed-package
runs, where there is no `docs/` tree to audit.

## Relation to the retired suites

Earlier revisions documented two runnable suites under `project/`
(`test-A/run.R`, `test-B/run.R`). That directory was never part of a
clone — it is ignored by git and excluded from the tarball — so those
suites existed only on machines that already had the data. The
versioned synthetic fixtures with recorded md5 goldens replace them as
the regression baseline; the local datasets remain reachable through
`test-golden-outputs.R` where they exist.
