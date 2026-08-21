# PLAN-el proyecto de monitoreo downstream-ingest-gate

## Status

Active SoT for possible el proyecto de monitoreo downstream work inside `dbAudit`.

Do not create nested SoT folders for this topic. Keep this as a single flat
plan under:

```text
dev/SoT/PLAN-el proyecto de monitoreo downstream-ingest-gate.md
```

## Correction

The previous copied tree:

```text
dev/SoT/instrument/current/
dev/SoT/instrument/legacy/
```

is rejected. It is too nested and contaminates `dbAudit/dev/SoT`.

## Current Understanding

`dbAudit` currently exposes one closed runner:

```r
DBAudit(project.path = ...)
```

and one CLI surface:

```sh
dbaudit --project <DATA_ROOT>
```

It is not a generic verb CLI. It does not expose public `parse`, `build`, or
`audit` verbs. Those are internal stages of the existing assay/certificate
pipeline.

## el proyecto de monitoreo downstream Difference

el proyecto de monitoreo downstream is not only an audit-after-build workflow.

The required production shape is:

```text
source -> raw -> QAQC gate -> db
                         -> reject/log
```

The approved database must contain only:

- observations that passed QAQC;
- observations repaired by an approved rule.

Observations with unrepaired errors must be rejected and logged, not inserted
into the approved database.

## Immediate Rule

Do not implement a `dbAudit` CLI extension yet.

Before any code move, define the public runner contract for el proyecto de monitoreo downstream:

```r
<RunnerName>(project.path = ...)
```

No runner name is approved yet.

## Compatibility Rule

Existing `dbAudit` users must not be affected.

Do not change in the first design pass:

```text
DBAudit
R/dbAudit.R
R/parseLab.R
R/parseAssay.R
R/audit.R
bin/dbaudit
```

## Open Questions

1. Is el proyecto de monitoreo downstream one public runner or several public stage functions?
2. Is `project.path` the `data/` root?
3. What is the authoritative log for the QAQC gate?
4. Where do rejected observations live?
5. Are `PCG` and `PCV` the first accepted scope, with `INC` kept out until the
   database contract is approved?
6. Which repair rules are allowed before insertion into `db`?

## Source Memory

Detailed design memory remains in el proyecto de monitoreo downstream:

```text
dev/SoT/REPORT-dbaudit-contract-correction.md
dev/SoT/PLAN-ingest-gate-contract.md
dev/SoT/PLAN-public-runner-contract.md
```

Do not bulk-copy those files into nested `dbAudit/dev/SoT` folders.
