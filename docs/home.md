---
layout: default
title: dbAudit
permalink: /
---

# dbAudit

**Parse-and-audit pipelines for three data domains: geochemistry
certificates, piezometers, and inclinometers.**

One CLI, three contracts selected by a positional subcommand:

```bash
dbaudit [geochemistry|piezometer|inclinometer] --project <DATA_ROOT> [OPTIONS]
```

- `geochemistry` — also the default when no subcommand is given —
  parses lab certificates and assay/client tables (models A and B) into
  normalized `lab.csv` + `index.csv` + `client.csv` under `proc/` and
  audits structure and values with configurable tolerance.
- `piezometer` parses Casagrande (PCG) and vibrating-wire (PCV)
  workbooks from `source/` into `raw/`, `db/` and `audit/` products
  with a cataloged event log.
- `inclinometer` does the same for inclinometer survey exports (INC).

The four runners are also exported by the `dbAudit` R package:
`auditGeochemistry()` (alias `DBAudit()`), `auditPiezometer()`,
`auditInclinometer()`.

## Start here

- [Install]({{ "/docs/install/" | relative_url }}) — macOS / Linux / Windows install scripts, verification, uninstall.
- [Quick start]({{ "/docs/quickstart/" | relative_url }}) — one verified run per domain on the shipped synthetic fixtures.
- [Documentation hub]({{ "/docs/" | relative_url }}) — full index, by task and by domain.

## Topics

- [Project layouts]({{ "/docs/project-layout/" | relative_url }}) — the two folder contracts and what the tool creates.
- [Parsers]({{ "/docs/parsers/" | relative_url }}) · [PCG]({{ "/docs/parser-pcg/" | relative_url }}) · [PCV]({{ "/docs/parser-pcv/" | relative_url }}) · [INC]({{ "/docs/parser-inc/" | relative_url }})
- [Audits (geochemistry)]({{ "/docs/audit/" | relative_url }}) · [Audits (monitoring)]({{ "/docs/audit-monitoring/" | relative_url }})
- [Logging]({{ "/docs/logging/" | relative_url }}) — log schemas, level semantics, event catalog.
- [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }})

## If you read one page only

Read: [Quick start]({{ "/docs/quickstart/" | relative_url }}).
