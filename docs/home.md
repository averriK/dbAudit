---
layout: default
title: dbAudit
permalink: /
---

# dbAudit

Geochemical certificate parser and validator.

- Parses **lab certificates** (type A and type B) into `lab.csv` + `index.csv`.
- Parses **assay/client tables** (type A and type B) into `client.csv`.
- Runs audits:
  - structure audit (systematic jobID/sampleID mismatches)
  - value audit (type A numeric comparison; type B method inference + DL/tag/value checks)

## Install dependencies (first run)

```bash
bash install/install.sh
```

## Quick run

```bash
dbAudit --project project/BV/data
```

- Outputs: `project/BV/data/proc/`
- Log: `project/BV/data/proc/log.csv`

Go to the full docs index: [Documentation]({{ "/docs/" | relative_url }})
