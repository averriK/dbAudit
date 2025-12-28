---
layout: default
title: Tests
permalink: /docs/tests/
---

# Tests
The repo includes two runnable test suites:

## `test-A/`
Purpose: **regression** for type-A.

Run:
- `Rscript test-A/run.R`

What it checks:
- Runs the original type-A lab parser (`parseLabDataA`) and the universal lab parser with `format="A"`.
- Asserts that `index.csv` and `lab.csv` are identical (set equality).
- Runs the original type-A assay parser (`parseAssayDataA`) and the universal assay parser with `format="A"`.
- Asserts that `client.csv` is identical.

This answers: “does the universal parser replicate the old parser for type A?”

## `test-B/`
Purpose: **smoke test** for type-B parsing + type-B audit.

Run:
- `Rscript test-B/run.R`

What it does:
- Parses a type-B lab certificate directory (`test-B/raw/`) using `parseLabData(format="B")`.
- Parses a type-B assay table (`test-B/assay/AAQ_Sample_Assay.csv`) using `parseAssayData(format="B")`.
- Runs `auditStructure()` and `auditValuesB()` using `index.csv` produced from the lab.

Outputs:
- `test-B/index.csv`, `test-B/lab.csv`, `test-B/client.csv`, `test-B/log.csv`.

Notes:
- In type B, `client.csv` starts with `standardID=NA` (method is inferred during audit).

## Resultados (última verificación)
- 2025-12-27: `Rscript test-A/run.R` pasó (exit 0).
- 2025-12-27: `Rscript test-B/run.R` pasó (exit 0).
