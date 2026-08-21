---
layout: default
title: Documentation
permalink: /docs/
---

# Documentation

dbAudit parses and audits three data domains — geochemistry lab
certificates, piezometers (Casagrande and vibrating wire) and
inclinometers — behind one CLI:

```bash
dbaudit [geochemistry|piezometer|inclinometer] --project <DATA_ROOT> [OPTIONS]
```

An invocation without a subcommand keeps the historical geochemistry
contract. The same runners are exported by the `dbAudit` R package:
`auditGeochemistry()` (alias `DBAudit()`), `auditPiezometer()`,
`auditInclinometer()`.

## By task

- **Install and verify** — [Install]({{ "/docs/install/" | relative_url }}), with platform detail in [macOS / Linux]({{ "/docs/macos/" | relative_url }}) and [Windows]({{ "/docs/windows/" | relative_url }}); [Troubleshooting]({{ "/docs/troubleshooting/" | relative_url }}) when something fails.
- **Run each domain once** — [Quick start]({{ "/docs/quickstart/" | relative_url }}): install → `--check` → one verified run per domain on the shipped synthetic fixtures.
- **Lay out a project** — [Project layouts]({{ "/docs/project-layout/" | relative_url }}): the two folder contracts, what the tool creates, and why the monitoring outputs are regenerated on every run.
- **Read the log** — [Logging]({{ "/docs/logging/" | relative_url }}): the two log schemas, level semantics, and the event catalog.
- **Understand the audits** — [Audits (geochemistry)]({{ "/docs/audit/" | relative_url }}) and [Audits (monitoring)]({{ "/docs/audit-monitoring/" | relative_url }}).
- **Follow worked examples** — [Examples]({{ "/docs/examples/" | relative_url }}).
- **Run the test suite** — [Tests]({{ "/docs/tests/" | relative_url }}).

## By domain

### Geochemistry

Certificate models A and B, assay/client tables, structural and value
audits with configurable tolerance.

- [Quick start §3]({{ "/docs/quickstart/" | relative_url }}) — first run on the synthetic-A fixture.
- [Parsers]({{ "/docs/parsers/" | relative_url }}) — lab and assay parsing, models A and B.
- [Audits (geochemistry)]({{ "/docs/audit/" | relative_url }}) — structure and value checks, tolerance, method inference.

### Piezometers

Casagrande (PCG) and vibrating-wire (PCV) workbooks parsed from
`source/` into database tables and audit products.

- [Quick start §4]({{ "/docs/quickstart/" | relative_url }}) — first run on the Vega fixture.
- [PCG parser]({{ "/docs/parser-pcg/" | relative_url }}) · [PCV parser]({{ "/docs/parser-pcv/" | relative_url }})
- [Parse manifest]({{ "/docs/manifest/" | relative_url }}) — the versioned JSON manifest that drives header recognition.
- [Audits (monitoring)]({{ "/docs/audit-monitoring/" | relative_url }})

### Inclinometers

Survey CSV exports (INC) parsed and audited through the same monitoring
contract.

- [Quick start §5]({{ "/docs/quickstart/" | relative_url }}) — first run, and the shared-log caveat.
- [INC parser]({{ "/docs/parser-inc/" | relative_url }}) — accepted export format; native `.gkn`/`.dux` files are rejected.
- [Audits (monitoring)]({{ "/docs/audit-monitoring/" | relative_url }})

## Reference

- [Conventions]({{ "/docs/conventions/" | relative_url }}) — module map, entrypoints, event naming.
- [Tests]({{ "/docs/tests/" | relative_url }}) — the `tests/testthat` suite and its fixtures.
