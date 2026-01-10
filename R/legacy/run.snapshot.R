# LEGACY runner snapshot (kept for comparison only)
# This file is NOT used by tests or by the current workflow.
# It reflects the simpler pre-autodetection runner style.

rm(list = ls())
source("R/setup.R")
source("R/helpers.R")
source("R/parseLab.R")
source("R/parseAssay.R")
source("R/audit.R")
project.path <- "project/<PROJECT>"

# ----------------------------------------------------------------------
# Parse Stage: Parse laboratory data (certificates)
# Paths
log.file <- file.path(project.path, "data", "proc", "log.csv")
raw.path <- file.path(project.path, "data", "raw", "lab")
data.file <- file.path(project.path, "data", "proc", "lab.csv")
index.file <- file.path(project.path, "data", "proc", "index.csv")
# Parse client tables
input.file <- file.path(project.path, "data", "raw", "client", "_Assay_Comp.csv")
output.file <- file.path(project.path, "data", "proc", "client.csv")

# Initialize log file at run start
if (!file.exists(log.file)) .logInit(log.file)

parseLabData(
  mode = "append",
  log.file = log.file,
  path = raw.path,
  index.file = index.file,
  data.file = data.file
)


# Clean LOG with repeated entries
LOG <- fread(log.file)
LOG <- unique(LOG, by = setdiff(names(LOG), "ts"))
fwrite(LOG, log.file)

parseAssayData(
  input.file = input.file,
  log.file = log.file,
  output.file = output.file
)


# Clean LOG with repeated entries
LOG <- fread(log.file)
LOG <- unique(LOG, by = setdiff(names(LOG), "ts"))
fwrite(LOG, log.file)

# If client parse failed or no client file exists, skip audit stage.
if (!file.exists(output.file)) {
  quit(save = "no", status = 0)
}

# ----------------------------------------------------------------------
# Audit Stage: Structure (Stage 1 & Stage 2) and Values (Stage 4)


# Control flag for applying fixes in helpers
fix.structure <- TRUE
fix.values <- FALSE

# Load data if needed elsewhere in this script
INDEX.lab <- fread(index.file)
DATA.lab <- fread(data.file)
DATA.client <- fread(output.file)


jobID.failed <- .jobIDsWithErrors(log.file = log.file)
if (length(jobID.failed)) {
  DATA.lab <- DATA.lab[!(jobID %in% jobID.failed)]
  DATA.client <- DATA.client[!(jobID %in% jobID.failed)]
}

# Run audit helpers (Stage 1 & 2)
OUT <- auditStructure(log.file = log.file, data.lab = DATA.lab, data.client = DATA.client, fix = fix.structure)
DATA.client <- OUT$data.client

# Audit values:
# - Use B if client standardID is entirely missing (type-B assay), else A.
std.missing <- is.na(DATA.client$standardID) | DATA.client$standardID == ""
audit.format <- if (all(std.missing)) "B" else "A"
OUT <- auditValues(
  log.file = log.file,
  data.lab = DATA.lab,
  data.client = DATA.client,
  index.lab = INDEX.lab,
  format = audit.format,
  fix = fix.values
)
DATA.client <- OUT$data.client

# Clean LOG with repeated entries
LOG <- fread(log.file)
LOG <- unique(LOG, by = setdiff(names(LOG), "ts"))
fwrite(LOG, log.file)
