# dbAudit

**Geochemical Certificate Parser and Validator**

R pipeline for parsing laboratory geochemical certificates into normalized long-format tables with automated QA/QC audits. Reconciles laboratory data against client assay compositions, detects systematic ID mismatches, and flags value discrepancies with configurable tolerance.

[![R Version](https://img.shields.io/badge/R-%E2%89%A53.5-blue)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Capabilities](#capabilities)
- [Documentation](#documentation)
- [Core Functions](#core-functions)
- [Workflow](#workflow)
- [Parsing Stage](#parsing-stage)
- [Audit Stage](#audit-stage)
- [Validation Stage](#validation-stage)
- [Input Format](#input-format)
- [Outputs](#outputs)
- [Logging System](#logging-system)
- [Project Structure](#project-structure)
- [Dependencies](#dependencies)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Citation](#citation)
- [Author](#author)

---

## Installation

### Requirements

- **R (≥ 3.5)**: Core language
  - Verify: `Rscript --version`
  - Install: [CRAN Downloads](https://cran.r-project.org/)
  - Ensure `Rscript` is in your PATH

- **R Packages** (auto-installed by installer):
  - `data.table` - Fast data I/O and manipulation
  - `stringr` - String processing
  - `lubridate` - Date parsing

**Note:** The installer will check for R (≥ 3.5) and install required packages automatically. If you prefer to manage packages manually, use the `--skip-packages` flag (macOS/Linux) or `-SkipPackages` (Windows).

### Install (repo-based)

#### macOS / Linux (system-wide `/usr/local`)

```bash
git clone git@github.com:averriK/dbAudit.git
sudo bash dbAudit/install/install.sh
```

**Installed paths:**
- `/usr/local/bin/dbaudit`
- `/usr/local/libexec/dbAudit/`

**Skip package installation:**
```bash
sudo bash dbAudit/install/install.sh --skip-packages
```

#### Windows (PowerShell)

```powershell
git clone git@github.com:averriK/dbAudit.git
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
```

**Installed paths:**
- `%LOCALAPPDATA%\Programs\dbAudit\bin\`
- `%LOCALAPPDATA%\Programs\dbAudit\libexec\dbAudit\`

**Skip package installation:**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1 -SkipPackages
```

**Notes:**
- The Windows installer adds its `bin` directory to the **User PATH** (unless you pass `-SkipPath`). Open a **new** terminal after installing.
- Windows uses **pre-compiled binary packages only** (cannot compile from source without Rtools).
- If you have an older R version without binary packages available, upgrade R first.

### Verify Installation

After installing, verify all dependencies are satisfied:

```bash
dbaudit --check
```

**Expected output:**
```
dbaudit System Diagnostics
==================================================

R version: 4.5.2
Rscript: /usr/local/bin/Rscript
Installation: /usr/local/libexec/dbAudit

Required R Packages:
  [✓] data.table (version 1.18.0)
  [✓] stringr (version 1.6.0)
  [✓] lubridate (version 1.9.4)

Status: ✓ All dependencies satisfied
```

### Troubleshooting Installation

**R not found:**
- Install R from [CRAN](https://cran.r-project.org/)
- Ensure `Rscript` is in your PATH
- Restart terminal after installing R

**R version too old:**
- Check version: `Rscript --version`
- Upgrade to R ≥ 3.5 from [CRAN](https://cran.r-project.org/)

**Package installation fails (Windows):**
- Check if binary packages are available for your R version
- Upgrade to the latest R version if binaries are unavailable
- **Do NOT install Rtools** unless you know you need it - dbAudit only uses binaries

**Package installation fails (macOS/Linux):**
- Check internet connectivity
- Verify CRAN mirror is accessible: https://cloud.r-project.org
- Check library permissions: `Rscript -e '.libPaths()'`
- Install manually: `Rscript -e 'install.packages(c("data.table", "stringr", "lubridate"))'`

**Corporate network / proxy issues:**
- Configure R proxy: `Rscript -e 'Sys.setenv(http_proxy="http://proxy:port")'`
- Or use manual installation and transfer packages offline

---

## Quick Start

### 1. Prepare input data

For quick verification, use the bundled datasets:
- Type A: `project/test-A/`
- Type B: `project/test-B/`

For project runs, `DBAudit` expects the following layout under a `project.path` (data root):
- Lab certificates: `project.path/raw/lab/`
- Assay folder: `project.path/raw/assay/` (assay CSV is auto-detected inside)
- Outputs: `project.path/proc/`

### Path contract (defaults)

The project-relative default folders are the **single source of truth** for CLI help and the runner:

- `raw/lab` (lab certificates)
- `raw/assay` (assay/client folder)
- `proc` (outputs)

Canonical definitions live in `R/dbAudit.R` (`.dbauditPathDefaults`).

To prevent documentation drift, run:

```bash
bin/verify-docs
```

### 2. Run the pipeline

From terminal:

```bash
dbaudit --project project/<PROJECT>/data
```

Recommended (avoid fragile auto-detection for production runs):

Optional:
- `--tol <NUMBER>` controls the **relative tolerance** used by value audits (default: `0.05`).

```bash
# Type A

dbaudit --project project/<PROJECT>/data --lab-format A --assay-format A

# Type B

dbaudit --project project/<PROJECT>/data --lab-format B --assay-format B
```

### 3. Check outputs

```r
library(data.table)

# Example outputs (project runs)
lab <- fread("project/<PROJECT>/data/proc/lab.csv")
index <- fread("project/<PROJECT>/data/proc/index.csv")
client <- fread("project/<PROJECT>/data/proc/client.csv")
log <- fread("project/<PROJECT>/data/proc/log.csv")

log[level == "ERROR"]
```

### 4. Run validation (optional)

```r
source("R/validate.R")
```

This cross-checks parsed laboratory data against client assay composition and reports:
- Missing keys (observations in client but not in lab)
- Value discrepancies (for matching keys)
- Systematic ID prefix/suffix mismatches

---

## Capabilities

This project provides an end-to-end R pipeline (`DBAudit`) that:
- Parses laboratory certificates (type A and type B) into long-format tables (`lab.csv`) plus analyte metadata (`index.csv`).
- Parses assay/client tables (type A and type B) into a long-format table (`client.csv`).
- Runs audits:
  - Structure audit: detects and can apply systematic jobID/sampleID prefix/suffix fixes (in-memory).
  - Value audit:
    - Type A (`auditValues(format="A")`): direct numeric comparison using a relative tolerance.
    - Type B (`auditValues(format="B")`): infers `standardID` (method) per `(jobID, elementID, unitID)` using lab-derived `index.csv`, then audits tag/value consistency.
- Writes a structured CSV log (`log.csv`) with event codes and diagnostics.
- Includes runnable tests for regression (type A) and smoke coverage (type B).

## Documentation

- GitHub Pages (user docs, if enabled): https://averrik.github.io/dbAudit/docs/
- In-repo docs (source): `docs/`

---

## Core Functions

### Data Parsing

| Function | Description | Input | Output |
|----------|-------------|-------|--------|
| `parseLabData` | Parse laboratory certificates (type A/B) | CSVs under `path` (searched recursively) | `lab.csv`, `index.csv`, `log.csv` |
| `parseAssayData` | Parse assay/client table (type A/B) | One assay CSV (`input.file`) | `client.csv`, `log.csv` |

**Key parameters:**
- `path`: Directory containing input CSVs
- `mode`: `"append"` (default, stream writes) or `"bind"` (aggregate in memory)
- `index.file`, `data.file`, `log.file`: Output paths

**Notes:**
- Original type-A implementations are preserved as `parseLabDataA()` and `parseAssayDataA()` for regression.
- Universal parsers accept `format=c("auto","A","B")` and can parse both layouts.

### Audit Functions

| Function | Description | Input | Output |
|----------|-------------|-------|--------|
| `auditStructure` | Detect jobID/sampleID mismatches | `data.client`, `data.lab` | Log warnings/errors |
| `auditValues` | Value audit (A/B): `format="A"` direct compare; `format="B"` infer method via `index.csv` then audit tags + values | `data.client`, `data.lab` (+ `index.lab` for B) | Log mismatches + inference diagnostics |

**Key parameters:**
- `fix`: `TRUE` to auto-correct systematic ID patterns (in-memory only)
- `file.id`: File identifier for logging

### Helper Functions

| Function | Description |
|----------|-------------|
| `.logInit`, `.log` | Initialize and append to log file |
| `.as.numeric`, `.as.Date` | Robust type conversion |
| `.cleanId` | Strip whitespace and normalize IDs |
| `.reconcileColumns` | Align expected vs. actual columns |
| `.jobIDsWithErrors` | Extract problematic jobIDs from log |

---

## Workflow

The typical analysis chain:

```bash
# Run pipeline

dbaudit --project project/<PROJECT>/data
```

Optional path overrides:

```bash
# If your data-root layout differs

dbaudit --project project/<PROJECT>/data \
  --lab-dir raw/lab \
  --assay-dir raw/assay \
  --proc-dir proc
```

Optional assay file override:

```bash
# Use a specific assay file (basename is resolved under raw/assay)

dbaudit --project project/<PROJECT>/data --assay-file AAQ_Sample_Assay.csv
```

```r
# Review log for errors
log <- fread("project/<PROJECT>/data/proc/log.csv")
log[level == "ERROR"]

# (Optional) Run validation helpers
source("R/validate.R")
```

---

## Parsing Stage

### Input Format

This repo supports **type A** and **type B** layouts for both lab certificates and assay tables.
For detailed format notes, see `docs/parsers.md`.

Expected CSV structure (with minor variations tolerated):

**Header block (rows 1-6):**
```
LabjobNo:,<jobID>
DespatchNo:,<despatchID>
# of SAMPLES:,<N>
DATE RECEIVED:,<date>
DATE FINALIZED:,<date>
ESTADO:,<status>
```

**Method codes row**, then field headers:
```
SAMPLE,Analysis Order,<analyte1>,<analyte2>,...
DESCRIPTION,,<unit1>,<unit2>,...
MIN DETECTION,,<minDL1>,<minDL2>,...
MAX DETECTION,,<maxDL1>,<maxDL2>,...
```

**Data rows:**
```
<sampleID>,<order>,<value1>,<value2>,...
```

**Supported variations:**
- Leading numeric index column (auto-detected and dropped)
- Trailing empty columns or QC tags (trimmed with logging)
- Detection limit signs (`<`, `>`) preserved in `tagDL` column
- Ragged rows tolerated (`fill = TRUE` in `fread`)
- Type-B lab certificates with `ELEMENT` header row, `Method`/`Det. Lim`/`Upper Lim` metadata rows, and duplicated analytes across methods
- Type-B assay tables with analyte columns `Element_(ppm|pct)` and no explicit `standardID`

### Output Tables

#### `index.csv`

Analyte metadata with certificate info.

Locations:
- Project runs: `project/<PROJECT>/data/proc/index.csv`
- Tests: `test-A/index.csv` and `test-B/index.csv`

| Column | Description |
|--------|-------------|
| `fileID` | Source file name |
| `jobID` | Laboratory job number |
| `despatchID` | Despatch number |
| `dateReceived` | Date received by lab |
| `dateFinalized` | Date finalized by lab |
| `sampleN` | Declared number of samples |
| `standardID` | Method/standard code |
| `elementID` | Element/analyte name |
| `unitID` | Unit of measurement |
| `valueID` | Composite key: `elementID_standardID_unitID` |
| `minDL`, `maxDL` | Detection limits |

#### `lab.csv`

Long-format measurements.

Locations:
- Project runs: `project/<PROJECT>/data/proc/lab.csv`
- Tests: `test-A/lab.csv` and `test-B/lab.csv`

| Column | Description |
|--------|-------------|
| `jobID` | Laboratory job number |
| `despatchID` | Despatch number |
| `sampleID` | Sample identifier |
| `elementID` | Element/analyte name |
| `standardID` | Method/standard code |
| `unitID` | Unit of measurement |
| `tagDL` | Detection limit tag (`<`, `>`, or empty) |
| `value` | Numeric measurement |
| `valueID` | Composite key |

#### `client.csv` (assay / optional)

Client assay composition.

Locations:
- Project runs: `project/<PROJECT>/data/proc/client.csv`
- Tests: `test-A/client.csv` and `test-B/client.csv`

| Column | Description |
|--------|-------------|
| `jobID` | Job number |
| `sampleID` | Sample identifier |
| `elementID` | Element/analyte name |
| `standardID` | Method/standard code |
| `unitID` | Unit of measurement |
| `value` | Numeric measurement |

---

## Audit Stage

Automated structural and value audits run from `DBAudit` via `R/dbAudit.R` (which calls `R/audit.R`).

### Structure Audit

`auditStructure(log.file, data.client, data.lab, fix = FALSE)`

**Stage 1: jobID matching**
- Detects client jobIDs not found in lab data
- Attempts systematic prefix/suffix correction if `fix = TRUE`
- Logs:
  - `WARNING JOBID_MISMATCH: count=N`
  - `INFO JOBID_FIXED: fixed=K; prefix=P; suffix=S`
  - `ERROR WRONG_JOBID: jobID=...`

**Stage 2: sampleID matching**
- Detects client sampleIDs not found in lab data (within known jobIDs)
- Attempts systematic prefix/suffix correction if `fix = TRUE`
- Logs:
  - `WARNING SAMPLEID_MISMATCH: count=N`
  - `INFO SAMPLEID_FIXED: fixed=K; prefix=P; suffix=S`
  - `ERROR WRONG_SAMPLEID: sampleID=...`

### Value Audit

`auditValues(log.file, data.lab, data.client, fix = FALSE)`

Compares values for matching keys `(jobID, sampleID, elementID, standardID, unitID)`.

**Tolerance:** Relative tolerance `tol` (configurable)

**Logs:**
- `WARNING VALUE_MISMATCH: count=N; tol=T`
- `INFO VALUE_FIXED: ...` (if `fix = TRUE`)
- `ERROR WRONG_VALUE: ...` (if `fix = FALSE`)
- `INFO VALUES_APPLIED: fixed=N; tol=T`

### Type-B Value Audit (method inference)

`auditValuesB(log.file, data.lab, data.client, index.lab = INDEX.lab, min.votes = 2L)`

Type B differs because the assay table may not declare `standardID` (method), while the lab certificate can contain multiple methods for the same analyte.
The audit uses `index.csv` (from lab) as the source of candidate methods and detection limits (`minDL/maxDL`), infers a single method per `(jobID, elementID, unitID)`, and then audits:
- tag consistency (`tagDL` must match lab)
- numeric value consistency (tolerance)

See `docs/audit.md` for details.

---

## Validation Stage

Interactive cross-checks via `R/validate.R` (not called by `DBAudit`).

**Usage:**
```r
source("R/validate.R")
```

**Five stages:**
1. **jobID prefix/suffix check**: Auto-detect and strip systematic patterns
2. **sampleID prefix/suffix check**: Auto-detect and strip systematic patterns
3. **Missing analyte keys**: List observations in client but not in lab
4. **Value comparison**: Flag discrepancies using `.valuesEqual()`
5. **Review missing-by-unit**: Highlight potential unit mismatches

**Notes:**
- Auto-corrections applied only to in-memory `DATA.client` (not written back)
- No dedicated validation log; review console output
- `R/validate_alt.R` is an exploratory variant with extra summaries

---

## Input Format

### Laboratory Certificates

Expected columns in header:
- `LabjobNo:` - Laboratory job number
- `DespatchNo:` - Despatch number
- `# of SAMPLES:` - Declared sample count
- `DATE RECEIVED:` - Receipt date
- `DATE FINALIZED:` - Finalization date
- `ESTADO:` - Status

Field headers:
- `SAMPLE` - Sample identifiers
- `Analysis Order` - Processing order (dropped in output)
- Analyte columns with method codes above

Detection limits:
- `MIN DETECTION` row
- `MAX DETECTION` row

### Client Assay Composition

Expected columns:
- `jobID`
- `sampleID`
- `elementID`
- `standardID`
- `unitID`
- `value`

File naming convention: `*_Assay_Comp.csv` (flexible)

---

## Outputs

Project runs write outputs to `project/<PROJECT>/data/proc/`.
Test scripts write outputs under `test-A/` and `test-B/`.

| File | Description | Format |
|------|-------------|--------|
| `lab.csv` | Parsed laboratory measurements | Long format |
| `index.csv` | Analyte metadata + certificate info | One row per analyte per certificate |
| `client.csv` | Parsed client assay composition | Long format |
| `log.csv` | Parser and audit log | Timestamped events |

**Output modes:**
- `"append"` (default): Stream-write with proper headers
- `"bind"`: Aggregate in memory, write once at end

---

## Logging System

All events logged to:
- Project runs: `project/<PROJECT>/data/proc/log.csv`
- Tests: `project/test-A/proc/log.csv` and `project/test-B/proc/log.csv`

| Column | Description |
|--------|-------------|
| `ts` | Timestamp |
| `level` | INFO, WARNING, ERROR |
| `file` | Source file path |
| `event` | Event code |
| `message` | Details |

### Log Events

**Laboratory parsing:**
- `INFO FILE_START`: Begin processing
- `WARNING DIAG_INDEX_EMPTY`: Empty/malformed analyte identifiers
- `WARNING EXTRA_COLS_DROPPED`: Unexpected extra columns
- `WARNING MISSING_COLS_PADDED`: Missing expected columns
- `WARNING SAMPLES_DECLARED_MISMATCH`: Declared vs. observed sample count differs
- `ERROR SAMPLEID_NOT_UNIQUE`: Duplicate sampleID in batch
- `ERROR DUPLICATE_VID`: Duplicate analyte valueID in header
- `INFO PARSE_OK`: Successful parse
- `ERROR PARSE_ERROR`: Parse failure

**Client parsing:**
- `INFO CLIENT_FILE_START`: Begin processing
- `WARNING CLIENT_EMPTY_JOBID`: Empty jobID count
- `WARNING CLIENT_EMPTY_SAMPLEID`: Empty sampleID count
- `ERROR CLIENT_MISSING_COLUMNS`: Required columns missing
- `INFO CLIENT_PARSE_OK`: Successful parse
- `ERROR CLIENT_PARSE_ERROR`: Parse failure

**Audit events:**
- `WARNING JOBID_MISMATCH`: jobID not found in lab
- `INFO JOBID_FIXED`: Systematic jobID correction applied
- `ERROR WRONG_JOBID`: Unresolved jobID mismatch
- `WARNING SAMPLEID_MISMATCH`: sampleID not found in lab
- `INFO SAMPLEID_FIXED`: Systematic sampleID correction applied
- `ERROR WRONG_SAMPLEID`: Unresolved sampleID mismatch
- `WARNING VALUE_MISMATCH`: Value discrepancy
- `INFO VALUE_FIXED`: Value correction applied
- `ERROR WRONG_VALUE`: Unresolved value mismatch
- `INFO STRUCTURE_APPLIED`: Summary of structural fixes
- `INFO VALUES_APPLIED`: Summary of value fixes

**Type-B value audit events (method inference + DL/tag checks; `auditValues(format="B")`):**
- `INFO METHOD_INFERRED`: Inferred `standardID` for an analyte group
- `ERROR METHOD_UNDETERMINED`: Not enough evidence to pick one method
- `ERROR METHOD_AMBIGUOUS`: Conflicting evidence (no unique winner)
- `WARNING CLIENT_ANALYTE_NOT_IN_LAB`: Assay analyte group missing from lab index
- `ERROR MISSING_LAB_ANALYTE`: Per-group missing lab analyte
- `WARNING CLIENT_ROWS_NOT_IN_LAB`: Assay rows missing in lab for the inferred method
- `ERROR MISSING_LAB_VALUE`: Per-row missing lab value
- `WARNING TAGDL_MISMATCH`: Tag discrepancy summary
- `ERROR WRONG_TAGDL`: Tag discrepancy per row
- `ERROR WRONG_MIN_DL`: Owner declared `<` but value != `minDL`
- `ERROR WRONG_MAX_DL`: Owner declared `>` but value != `maxDL`

### Filtering Logs

```r
log <- fread("project/<PROJECT>/data/proc/log.csv")

# Errors only
log[level == "ERROR"]

# By stage
log[grepl("^data/lab/", file)]      # Lab parsing
log[grepl("^data/client/", file)]   # Client parsing
log[grepl("^CLIENT_", event)]       # Client events

# By jobID (extract from message)
log[grepl("jobID=LAB12345", message)]
```

---

## Project Structure

```
dbAudit/
├── DBAudit                # R CLI entrypoint (invoked by dbaudit)
├── bin/
│   └── dbaudit            # Bash CLI (preferred)
├── install/
│   ├── install.sh         # Installer (macOS/Linux, /usr/local)
│   ├── uninstall.sh       # Uninstaller (macOS/Linux)
│   ├── install.ps1        # Installer (Windows, PowerShell)
│   └── uninstall.ps1      # Uninstaller (Windows, PowerShell)
├── R/
│   ├── setup.R            # Package loading
│   ├── dbAudit.R          # Project runner function (DBAudit)
│   ├── helpers.R          # Helpers (logging + shared utilities)
│   ├── parseLab.R         # Lab parsing (type A + type B)
│   ├── parseAssay.R       # Assay parsing (type A + type B)
│   ├── audit.R            # Audit (structure + values; includes type-B method inference)
│   ├── legacy/            # Deprecated wrapper-only layout + runner snapshots (reference only)
│   └── wip.R              # Work-in-progress (may change)
├── docs/
│   ├── README.md
│   ├── plan.md
│   ├── parsers.md
│   ├── audit.md
│   └── tests.md
├── project/               # Project datasets (can be large; tracked via Git LFS)
│   ├── test-A/            # Type-A regression dataset + runner
│   └── test-B/            # Type-B dataset + runner
├── README.md
└── PE-DBAudit.Rproj

```

---

## Dependencies

### Core Requirements

- **R (≥ 3.5)**: Base language

### R Package Dependencies

**Data manipulation:**
- `data.table`: Fast data operations and `fread`/`fwrite`

**Text processing:**
- `stringr`: String manipulation

**Date handling:**
- `lubridate`: Date parsing (with base R fallback in `.as.Date`)

### Installation

Use the repo-based installers: see the **Installation** section at the top of this README, or `docs/install.md`.

---

## Troubleshooting

### Input folders not found

For project runs, ensure:
- `project/<PROJECT>/data/raw/lab/` exists
- `project/<PROJECT>/data/raw/assay/` exists and contains the assay CSV

In CLI terms, you run:
- `dbaudit --project project/<PROJECT>/data`

For a self-contained check, run `Rscript project/test-A/run.R` or `Rscript project/test-B/run.R`.

### Outputs not created

Check `project/<PROJECT>/data/proc/log.csv` for ERROR or WARNING entries:

```r
log <- fread("project/<PROJECT>/data/proc/log.csv")
log[level == "ERROR"]
```

### Parsing errors

**Duplicate valueID:**
```
ERROR DUPLICATE_VID: jobID=...
```
Check for duplicate analyte columns in source CSV.

**Sample count mismatch:**
```
WARNING SAMPLES_DECLARED_MISMATCH: jobID=...
```
Declared count (header) vs. observed count (data rows) differ. Inspect source CSV.

**Non-unique sampleID:**
```
ERROR SAMPLEID_NOT_UNIQUE: jobID=...
```
Duplicate sampleID rows detected. Check for repeated samples in source CSV.

### Validation issues

**Skip problematic jobIDs:**

```r
# Get jobIDs with errors
bad.jobs <- .jobIDsWithErrors(log.file = "project/<PROJECT>/data/proc/log.csv")

# Filter before validation
data.lab <- data.lab[!jobID %in% bad.jobs]
```

**Systematic ID mismatches:**

Run structure audit with `fix = TRUE`:
```r
auditStructure(log.file, data.client, data.lab, fix = TRUE)
```

**Value discrepancies:**

Adjust tolerance in `auditValues()` or review `.valuesEqual()` logic in `R/helpers.R`.

### Performance

For large datasets, use `mode = "bind"` when calling `parseLabData()` manually:

```r
parseLabData(
  path = "project/<PROJECT>/data/raw/lab",
  mode = "bind",  # Aggregate in memory
  index.file = "project/<PROJECT>/data/proc/index.csv",
  data.file = "project/<PROJECT>/data/proc/lab.csv",
  log.file = "project/<PROJECT>/data/proc/log.csv"
)
```

---

## Contributing

Issues and pull requests are welcome at the [GitHub repository](https://github.com/averriK/dbAudit).

For bug reports, please include:
- Operating system and version
- R version
- Complete code that caused the issue
- Error messages from `data/proc/log.csv`

---

## License

MIT License

Copyright (c) 2025 Alejandro Verri Kozlowski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Citation

When using this pipeline in research or professional work, please cite:

```bibtex
@software{dbaudit2025,
  author = {Verri Kozlowski, Alejandro},
  title = {dbAudit: Geochemical Certificate Parser and Validator},
  year = {2025},
  url = {https://github.com/averriK/dbAudit}
}
```

---

## Author

**Alejandro Verri Kozlowski**

- Email: averri@fi.uba.ar
- ORCID: [0000-0002-8535-1170](https://orcid.org/0000-0002-8535-1170)
- GitHub: [@averriK](https://github.com/averriK)

**Affiliation:**
- Facultad de Ingeniería, Universidad de Buenos Aires
