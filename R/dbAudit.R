# ----------------------------------------------------------------------
# DBAudit: project runner (lab + assay + audits)
# Contract:
# - Working directory must be the repo root.
# - CLI provides only the project path; everything else uses defaults.
# - Assay file is detected deterministically within the assay folder.

.chooseAssayFile <- function(assay.dir) {
  if (!dir.exists(assay.dir)) stop(sprintf("assay.dir not found: %s", assay.dir))

  # Prefer known filenames first.
  preferred.names <- c("_Assay_Comp.csv", "AAQ_Sample_Assay.csv")
  for (nm in preferred.names) {
    p <- file.path(assay.dir, nm)
    if (file.exists(p)) return(p)
  }

  files <- list.files(assay.dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
  files <- sort(files)

  if (length(files) == 0L) {
    stop(sprintf("No assay CSV files found under: %s", assay.dir))
  }

  # Try to identify assay structure using the existing header-based detector.
  fmt <- vapply(
    files,
    FUN = function(f) {
      tryCatch(.detectAssayFormat(f), error = function(e) NA_character_)
    },
    FUN.VALUE = character(1)
  )

  candidates <- files[!is.na(fmt)]

  if (length(candidates) == 1L) return(candidates[1])

  if (length(candidates) > 1L) {
    msg <- paste(sprintf("%s(%s)", basename(candidates), fmt[match(candidates, files)]), collapse = ", ")
    stop(sprintf("Multiple assay-like CSV files found under %s: %s", assay.dir, msg))
  }

  # Fallback: allow exactly one CSV even if format detection was inconclusive.
  if (length(files) == 1L) return(files[1])

  stop(sprintf(
    "Cannot uniquely identify assay CSV under %s. Candidates: %s",
    assay.dir,
    paste(basename(files), collapse = ", ")
  ))
}

DBAudit <- function(
  project.path,
  lab.dir.name = file.path("raw", "lab"),
  assay.dir.name = file.path("raw", "assay"),
  proc.dir.name = "proc",
  assay.file = NULL
) {

  project.path <- path.expand(project.path)
  if (!dir.exists(project.path)) stop(sprintf("project.path not found: %s", project.path))
  project.path <- normalizePath(project.path, mustWork = TRUE)

  lab.dir <- file.path(project.path, lab.dir.name)
  assay.dir <- file.path(project.path, assay.dir.name)
  proc.dir <- file.path(project.path, proc.dir.name)

  if (!dir.exists(lab.dir)) stop(sprintf("lab.dir not found: %s", lab.dir))
  if (!dir.exists(proc.dir)) dir.create(proc.dir, recursive = TRUE, showWarnings = FALSE)

  # Assay file selection:
  # - Default: detect deterministically inside assay.dir
  # - Override: --assay-file can specify an absolute path, or a basename relative to assay.dir
  input.file <- NULL

  if (!is.null(assay.file) && nzchar(assay.file)) {
    p <- path.expand(assay.file)

    # Accept either:
    # - an absolute path (or ~), or
    # - a basename relative to assay.dir.

    if (!file.exists(p)) {
      p2 <- file.path(assay.dir, assay.file)
      if (file.exists(p2)) {
        p <- p2
      } else {
        stop(sprintf("assay.file not found: %s (also tried: %s)", assay.file, p2))
      }
    }

    if (isTRUE(file.info(p)$isdir)) {
      stop(sprintf("assay.file must be a file (got directory): %s", p))
    }

    input.file <- p
  } else {
    input.file <- .chooseAssayFile(assay.dir)
  }

  input.file <- normalizePath(input.file, mustWork = TRUE)

  # Paths
  log.file <- file.path(proc.dir, "log.csv")
  raw.path <- lab.dir
  data.file <- file.path(proc.dir, "lab.csv")
  index.file <- file.path(proc.dir, "index.csv")
  output.file <- file.path(proc.dir, "client.csv")

  # Initialize log file at run start
  if (!file.exists(log.file)) .logInit(log.file)

  # ----------------------------------------------------------------------
  # Parse Stage

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

  if (!file.exists(output.file)) {
    stop(sprintf("client.csv not created: %s", output.file))
  }

  # ----------------------------------------------------------------------
  # Audit Stage

  fix.structure <- TRUE
  fix.values <- FALSE

  INDEX.lab <- fread(index.file)
  DATA.lab <- fread(data.file)
  DATA.client <- fread(output.file)

  jobID.lab.failed <- .jobIDsWithLabParseErrors(log.file = log.file)
  jobID.client.failed <- .jobIDsWithClientParseErrors(log.file = log.file)

  # If a lab certificate failed to parse, lab has no usable backing for that jobID.
  # Keep client rows so the audit can report missing lab support.
  if (length(jobID.lab.failed)) {
    DATA.lab <- DATA.lab[!(jobID %in% jobID.lab.failed)]
  }

  # If the assay parse had job-scoped errors (rare), exclude those client rows from audit.
  if (length(jobID.client.failed)) {
    DATA.client <- DATA.client[!(jobID %in% jobID.client.failed)]
  }

  OUT <- auditStructure(log.file = log.file, data.lab = DATA.lab, data.client = DATA.client, fix = fix.structure)
  DATA.client <- OUT$data.client

  std.missing <- is.na(DATA.client$standardID) | DATA.client$standardID == ""
  if (all(std.missing)) {
    OUT <- auditValuesB(
      log.file = log.file,
      data.lab = DATA.lab,
      data.client = DATA.client,
      index.lab = INDEX.lab,
      fix = fix.values
    )
  } else {
    OUT <- auditValues(
      log.file = log.file,
      data.lab = DATA.lab,
      data.client = DATA.client,
      fix = fix.values
    )
  }
  DATA.client <- OUT$data.client

  # Clean LOG with repeated entries
  LOG <- fread(log.file)
  LOG <- unique(LOG, by = setdiff(names(LOG), "ts"))
  fwrite(LOG, log.file)

  invisible(list(
    project.path = project.path,
    input.file = input.file,
    lab.dir = lab.dir,
    assay.dir = assay.dir,
    proc.dir = proc.dir,
    log.file = log.file,
    index.file = index.file,
    lab.file = data.file,
    client.file = output.file
  ))
}
