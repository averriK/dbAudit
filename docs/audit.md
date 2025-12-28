---
layout: default
title: Audits
permalink: /docs/audit/
---

# Audits
Auditing is implemented in `R/audit.R` and is designed to be run after parsing.

## Audit domain semantics

The audit treats **lab certificates as the source of truth** and the **assay (client) as the declared scope**.

- **Lab > Assay is OK**: if lab has more certificates/results than the assay references, this is not an error.
- **Assay > Lab is a problem**: if the assay references jobIDs that do not exist in lab, the audit will report it.

Border-case examples:
- Lab has 1000 jobIDs and assay reports 100 jobIDs → OK (audit runs on the assay domain).
- Lab has 100 jobIDs and assay reports 150 jobIDs → ERROR/WARNING events for the 50 missing jobIDs.

Parse-error semantics:
- If a **lab certificate fails to parse**, the lab provides no usable backing for that jobID. The audit keeps the assay rows and reports missing lab support.
- If the **assay file fails to parse**, `client.csv` is not created and the audit stage is skipped.

## Structure audit (A and B)
Function: `auditStructure(log.file, data.client, data.lab, fix=FALSE)`
- Detects systematic jobID/sampleID mismatches (prefix/suffix patterns).
- If `fix=TRUE`, applies in-memory corrections and logs what was changed.

## Value audit (type A)
Function: `auditValues(log.file, data.lab, data.client, fix=FALSE)`
- Compares numeric values for matching keys:
  `(jobID, sampleID, elementID, standardID, unitID)`
- Uses relative tolerance (`tol`) via `.valuesEqual()`.
- Does **not** infer methods; it assumes the client table declares `standardID`.

## Value audit (type B)
Function: `auditValuesB(log.file, data.lab, data.client, index.lab, fix=FALSE, min.votes=2L, tol=5e-2)`

### Why type B needs extra logic
Type-B assay tables do not declare `standardID`, while type-B lab certificates can include multiple methods per analyte.
Therefore, the audit must infer the owner-selected method **per (jobID, elementID, unitID)** before it can compare values.

### Method inference using `index.csv`
`index.lab` (produced from lab certificates) provides the candidate methods and their detection limits:
- candidates: `standardID`
- metadata: `minDL`, `maxDL`

Inference rules:
- **No fallback**: if method is ambiguous/undetermined, log `ERROR` and do not silently choose.
- Minimum evidence: `min.votes` and a strict lead over runner-up.

Votes are computed from two sources:
1) **Exact match to lab values** (`votes_lab`):
   - per sample, compare owner vs lab for each candidate using `(tagDL, value)`.
   - if exactly one candidate matches, that sample votes for that candidate.
2) **Explicit DL tag votes** (`votes_dl`):
   - only when owner explicitly provides `<` or `>`.
   - a vote is counted when the owner’s declared DL matches exactly one candidate’s `minDL` or `maxDL`.

Logged events:
- `METHOD_INFERRED`
- `METHOD_UNDETERMINED`
- `METHOD_AMBIGUOUS`

### Tag audit (type B)
After method inference and joining to lab, the audit validates that owner tags match lab tags:
- `TAGDL_MISMATCH` (summary)
- `WRONG_TAGDL` (per-row errors)

### DL value consistency checks (type B)
When owner declares:
- `tagDL == "<"`: owner value must equal `minDL`
- `tagDL == ">"`: owner value must equal `maxDL`

Events:
- `WRONG_MIN_DL`
- `WRONG_MAX_DL`

### Numeric value audit (type B)
Numeric mismatches are evaluated only on rows where `tagDL` matches (to avoid double-reporting):
- `VALUE_MISMATCH` / `WRONG_VALUE` / `VALUE_FIXED` / `VALUES_APPLIED`

## Notes on robustness
- The “method inference + tagDL audit” is currently **type-B specific**.
- The type-A audit remains a direct numeric comparison (no method inference).