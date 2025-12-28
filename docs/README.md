# Documentation

User-facing documentation is published via GitHub Pages:

- https://srkconsulting.github.io/PE-DBAudit/docs/

## Chapters

- `docs/quickstart.md`: install + run
- `docs/project-layout.md`: expected project folder structure
- `docs/logging.md`: log schema, filters, and event reference
- `docs/parsers.md`: parser behavior (type A + type B)
- `docs/audit.md`: audit behavior (structure + values; type-B method inference)
- `docs/tests.md`: optional self-check tests

## Quick commands

You can run `dbAudit` from any directory (it runs the pipeline from its runtime root internally).

- Install dependencies (first run):
  - `bash install.sh`

- Run a project:
  - `dbAudit --project project/BV/data`

- Optional self-checks:
  - `Rscript test-A/run.R`
  - `Rscript test-B/run.R`
