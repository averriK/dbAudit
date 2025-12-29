---
layout: default
title: dbAudit
permalink: /
---

# dbAudit

Geochemical certificate parser and audit tool.

- Parses **lab certificates** (type A and type B) into `lab.csv` + `index.csv`.
- Parses **assay/client tables** (type A and type B) into `client.csv`.
- Runs audits (structure + values).

## Install

Go to: [Install]({{ "/docs/install/" | relative_url }})

## Quick run

```bash
dbAudit --project project/BV/data
```

- Outputs: `project/BV/data/proc/`
- Log: `project/BV/data/proc/log.csv`

Go to the full docs index: [Documentation]({{ "/docs/" | relative_url }})
