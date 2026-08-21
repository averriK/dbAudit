---
layout: default
title: Monitoring audits
permalink: /docs/audit-monitoring/
---

# Monitoring audits

This is the monitoring chapter of the audit documentation. It covers
the three monitoring domains and their runners:

| ID | Instrument | Runner | CLI |
|---|---|---|---|
| `PCG` | Casagrande piezometer (Excel workbooks) | `auditPiezometer()` | `dbaudit piezometer --project <DATA_ROOT>` |
| `PCV` | Vibrating-wire piezometer (multi-sheet Excel) | `auditPiezometer()` | `dbaudit piezometer --project <DATA_ROOT>` |
| `INC` | Inclinometer (CSV exports) | `auditInclinometer()` | `dbaudit inclinometer --project <DATA_ROOT>` |

Each runner executes parse → gate → database → audit in one call. The
piezometer runner takes `--id <PCG,PCV>` to restrict domains and
`--manifest <PATH>` to override the parse manifest; the inclinometer
runner takes `--manifest <PATH>`. A successful run prints nothing and
exits 0; the results are the files below. The geochemistry chapter is
[Audits]({{ "/docs/audit/" | relative_url }}); the event model and the
log schema are in [Logging]({{ "/docs/logging/" | relative_url }}).

## Project layout and the destructive contract

The project root holds the user's input under `source/<ID>/<Site>/…`
and three runner-owned output trees:

- `raw/` — parsed tables, one tree per source file, with full lineage
  (`SourcePath`, `SourceSheet`, `SourceRow`);
- `db/` — the consolidated database tables;
- `audit/` — the event log, the gate sink, and the audit products.

`source/` is required and never written. The runner **owns** the output
trees for its ids and regenerates them on every run: it deletes
`raw/<ID>` and reinitializes `audit/log.csv`. Consequence: running
`auditInclinometer()` after `auditPiezometer()` on the same project
leaves `audit/log.csv` with only the inclinometer rows (the piezometer
products on disk are untouched). A combined run that needs one shared
log belongs to an application runner, not to chained engine runners.

## The identity gate

Identity repairs are applied **only under systematic evidence**; a
conflict without such evidence is reported, never guessed.

For PCG workbooks, the parse layer records both identities: the
instrument declared by the file content (`HoleID`) and the key carried
by the filename (`FileKey`), with `FileKeyOK` marking their agreement.
When the content identity disagrees with the filename key across a
file, the gate repairs `HoleID` from the filename evidence and records
the repair in the gate sink as `MISLABELED` (`WARNING`) rows, one per
affected value row.
The database carries the repaired key; `raw/` keeps the typed identity
untouched as evidence. Any identity conflict the gate did **not**
repair is emitted as `MISLABELED` (`ERROR`) in the log: the readings
may belong to another instrument.

For INC surveys, the identity check compares the declared installation
and the filename token against the hole identity. A format variant that
normalizes to the same instrument is `MISLABELED` (`WARNING`); a
genuinely different declared instrument is `MISLABELED` (`ERROR`). The
folder/filename identity wins in the database; the declared value stays
visible in `INC.index.csv`.

## The value gate and rejections

Every candidate reading passes a value gate before entering the
database:

- A decimal-comma value is repaired on entry: `COMMA` (`WARNING`) in
  the gate sink, with the original and repaired values in `detail`.
- A value that is neither numeric nor an admitted missing marker is
  rejected: `UNREADABLE` (`ERROR`) in the gate sink. The reading is
  absent from the database — the series keeps a visible gap at that
  date.

The gate enforces conservation: candidates = accepted + rejected, or
the run stops. The gate sink `audit/<ID>.reject.csv` carries the event
columns (`ts`, `event`, `level`, `detail`) plus the complete data row,
so every rejection and repair traces to its source file, sheet, and
row. The sink file exists only when the gate recorded something.

### Flag `D` (dry wells)

A dry Casagrande reading has no level value. `PZ.data.csv` marks the
**declared dry condition** with flag `D` — a site condition, not a data
problem (catalog class `condition`). A record whose level was rejected
at the gate (`UNREADABLE` in the sink) carries no flag: that is a data
gap, not a dry well.

## The census and the reconciliation

Two checks close the loop between what the field delivered and what the
database holds:

- **Source-to-raw census** (`MISSING`, `ERROR`): every data file of the
  domain's file type under the `source/` root is compared against the
  files the parse layer actually walked. A file anywhere else under `source/` — a stray
  backup folder, a misplaced export — never reached `raw/`, and the
  census names it.
- **Raw-to-db reconciliation** (`MISSING`, `ERROR`): the unique key
  tuples (`ID`, `SiteID`, `HoleID`, `SensorID`, source lineage) of
  `raw/` and `db/` are compared in both directions. Gate-rejected
  records are excluded from both sides — a rejection is already on
  record in the sink. Systematic filename repairs **re-key** the raw
  side to the repaired identity rather than discounting it, so a
  repaired record lost on the way to the database still surfaces as
  `MISSING`.

## Domain checks

On top of the gate, census, and reconciliation, the audit stage runs:

- `DUPLICATED` (record, `ERROR`): readings the sheet's own row identity
  cannot distinguish — instrument plus date, plus time and stage
  wherever the sheet declares them. The source row position is never
  part of the identity. Both rows stay visible in the database.
- `DUPLICATED` (survey, `WARNING`, INC): byte-identical survey files
  consolidated into one; the dropped path is recorded.
- `MIXED` (`INFO`): the same variable declared in different units
  across sheets or surveys.
- `UNITLESS` (`ERROR`): a measured variable with no declared unit.
- `MALFORMED` (`ERROR`): required columns missing in a source or
  product table, or a sheet that declares the monitoring header marker
  but fails the data-sheet gate (its readings are skipped, and the log
  says so).
- `INCOMPLETE` (`ERROR`): required header fields missing or empty (the
  PCV calibration header; the INC survey header).
- `MISCOUNTED` (`ERROR`, INC): the declared depth count disagrees with
  the observed profile.
- `REDATED` (`ERROR`, INC): identical readings published under
  different dates; every member of the signature group is flagged.

`MISCLOSURE` is catalogued but suspended: no check emits it today (see
[Logging]({{ "/docs/logging/" | relative_url }})).

## Products

The database tables in `db/`:

- `PCG.data.csv`, `PCV.data.csv`, `INC.data.csv` — wide reading tables
  with per-variable unit columns;
- `PCG.index.csv`, `PCV.index.csv`, `INC.index.csv` — record-to-source
  lineage (and, for INC, the survey headers and build-check records).

The audit products in `audit/`:

- `log.csv` — the event log (schema in
  [Logging]({{ "/docs/logging/" | relative_url }}));
- `<ID>.reject.csv` — the gate sink;
- `<ID>.audit.csv` — the per-domain audit table: the database rows plus
  `status`/`event` columns; `INC.audit.csv` also carries report-only
  face checksums;
- `PZ.data.csv`, `PZ.index.csv` — the consolidated piezometer product
  (`PCG` + `PCV`), with the `flag` column (`D` = dry).

## Validation: the Vega synthetic site

`inst/fixtures/Vega` is a fully synthetic monitoring site that ships in
the repository and in every installation. It carries all three domains
under `source/`, a stray `source/backup/` tree, and a known-truth
manifest `truth.csv`. Its corruption matrix (counts computed from
`truth.csv`): 23 injected defects covering 15 distinct
`(event, level)` pairs across 13 events, plus 4 anti-ghost controls —
legitimate field situations that must **not** fire.

`tests/testthat/test-vega.R` runs both engine runners on a copy of Vega
and asserts four gates:

- **(a)** every injection detectable today fires with its expected
  level;
- **(b)** nothing else fires — the complete log and sink tables are
  pinned, so a ghost emission fails the suite;
- **(c)** every correction leaves the correct value in the database;
- **(d)** every uncorrectable injection stays visible in the products.

The same run is reproducible by hand. On a copy of the fixture's
`source/` tree:

```sh
dbaudit piezometer --project <DATA_ROOT>
```

leaves in `audit/log.csv` (all identifiers below are fixture
identifiers):

```
    level      event     N
1:  ERROR DUPLICATED     1
2:  ERROR  MALFORMED     1
3:  ERROR    MISSING     1
4:  ERROR   UNITLESS     1
5:   INFO       DONE     1
6:   INFO      MIXED     1
7:   INFO      START     1
```

and in the gate sink `audit/PCG.reject.csv` (the 143 `MISLABELED` rows
are the repaired value rows of one mislabeled workbook):

```
     level      event     N
1:   ERROR UNREADABLE     2
2: WARNING      COMMA     3
3: WARNING MISLABELED   143
```

with exactly 4 `flag == "D"` rows in `audit/PZ.data.csv` (the dry
campaigns of one Casagrande well). Then:

```sh
dbaudit inclinometer --project <DATA_ROOT>
```

reinitializes `audit/log.csv` and leaves only the INC rows — including
the two-level `MISLABELED` case (the format variant normalized at
`WARNING`, the foreign instrument at `ERROR`):

```
     level      event     N
1:   ERROR INCOMPLETE     1
2:   ERROR MISCOUNTED     1
3:   ERROR MISLABELED     1
4:   ERROR    REDATED     1
5:    INFO       DONE     1
6:    INFO      START     1
7: WARNING DUPLICATED     1
8: WARNING MISLABELED     1
```

One unit suite complements the acceptance gates:
`tests/testthat/test-census-repairs.R` pins both halves of the
census/repair contract — a repaired record that reached the database
must not fire `MISSING` (the anti-ghost half Vega proves), and a
repaired record lost on the way to the database must still fire
`MISSING` (the discriminating half Vega cannot exercise, because the
gate's conservation stop makes losing a record mid-pipeline impossible
there).
