---
layout: default
title: Project layout
permalink: /docs/project-layout/
---

# Typical project layout

A project lives under `project/<PROJECT>/data/`.
You run the pipeline by passing the **data root** to `--project`:

```bash
dbAudit --project project/<PROJECT>/data
```

## Expected folders under the data root

```
project/<PROJECT>/data/
  raw/
    lab/
      <lab_certificate_1>.csv
      <lab_certificate_2>.csv
      ...
    assay/
      <assay_file>.csv
  proc/
    index.csv
    lab.csv
    client.csv
    log.csv
```

### `raw/lab/`

- Input: lab certificate CSV files.
- The runner searches recursively under this folder.

### `raw/assay/`

- Input: one assay/client CSV.
- Default behavior: the runner auto-detects which CSV to use using deterministic rules:
  1) Prefer `raw/assay/_Assay_Comp.csv` if present
  2) Else prefer `raw/assay/AAQ_Sample_Assay.csv` if present
  3) Else, scan `*.csv` and keep files that match the known assay formats
  4) Error if ambiguous (multiple candidates)

- Optional override: use `--assay-file <PATH>` to force a specific file.

### `proc/`

Outputs written by the pipeline:
- `index.csv`: analyte metadata per certificate
- `lab.csv`: long-format lab values
- `client.csv`: long-format assay values
- `log.csv`: structured log with event codes

See:
- [Parsers]({{ "/docs/parsers/" | relative_url }})
- [Logging]({{ "/docs/logging/" | relative_url }})
