# ----------------------------------------------------------------------
# Parser A (original): mantiene comportamiento existente.

parseAssayDataA <- function(input.file, log.file, output.file) {
  FILE <- input.file
  tryCatch({
    .log(log.file, "INFO", FILE, "CLIENT_FILE_START", "begin")

    if (!file.exists(FILE)) stop("FILE not found")

    DROP <- .drop(FILE)
    AUX <- fread(FILE, colClasses = "character", drop = if (DROP == 0L) NULL else DROP)

    # Required columns check (client CSV must provide these names)
    req <- c("Sample_Id", "Certificate")
    miss <- setdiff(req, names(AUX))
    if (length(miss)) {
      .log(log.file, "ERROR", FILE, "CLIENT_MISSING_COLUMNS",
        sprintf("missing=[%s]", paste(miss, collapse = ", "))
      )
      stop(sprintf("Missing required columns: %s", paste(miss, collapse = ", ")))
    }

    setnames(AUX, old = c("Sample_Id", "Certificate"), new = c("sampleID", "jobID"))

    # Warn on empty IDs (file-focused counts only)
    empty.job <- sum(is.na(AUX$jobID) | AUX$jobID == "")
    if (empty.job > 0L) .log(log.file, "WARNING", FILE, "CLIENT_EMPTY_JOBID", sprintf("rows=%d", empty.job))
    empty.smp <- sum(is.na(AUX$sampleID) | AUX$sampleID == "")
    if (empty.smp > 0L) .log(log.file, "WARNING", FILE, "CLIENT_EMPTY_SAMPLEID", sprintf("rows=%d", empty.smp))

    VID <- setdiff(names(AUX), c("sampleID", "jobID"))
    AUX[, (VID) := lapply(.SD, function(x) fifelse(x == "", NA_character_, x)), .SDcols = VID]

    DATA <- melt(
      AUX,
      id.vars = c("sampleID", "jobID"),
      variable.name = "valueID",
      value.name = "value",
      variable.factor = FALSE,
      na.rm = TRUE
    ) |> unique()

    DATA[, elementID := tstrsplit(valueID, "_", fixed = TRUE)[[1]]]
    DATA[, standardID := tstrsplit(valueID, "_", fixed = TRUE)[[2]]]
    DATA[, unitID := tstrsplit(valueID, "_", fixed = TRUE)[[3]]]
    DATA[, valueID := NULL]

    idx <- !is.na(DATA$value) & stringr::str_detect(DATA$value, "[<>]")
    idx[is.na(idx)] <- FALSE
    DATA[, tagDL := "+"]
    DATA[idx, tagDL := stringr::str_extract(value, pattern = "[<>]")]
    DATA[idx, value := stringr::str_replace(value, pattern = "^\\s*[<>]\\s*", replacement = "")]
    DATA[, value := .as.numeric(value)]

    if (!dir.exists(dirname(output.file))) dir.create(dirname(output.file), recursive = TRUE, showWarnings = FALSE)
    fwrite(DATA, file = output.file, append = FALSE, col.names = TRUE)

    .log(log.file, "INFO", FILE, "CLIENT_PARSE_OK",
      sprintf("rows=%d; jobIDs=%d; sampleIDs=%d",
        nrow(DATA), uniqueN(DATA$jobID), uniqueN(DATA$sampleID)
      )
    )
  }, error = function(e) {
    .log(log.file, "ERROR", FILE, "CLIENT_PARSE_ERROR", conditionMessage(e))
  })
}

# ----------------------------------------------------------------------
# Parser universal: soporta tipo A y tipo B.

parseAssayData <- function(input.file, log.file, output.file, format = c("auto", "A", "B")) {
  format <- match.arg(format)

  if (identical(format, "auto")) {
    format <- .detectAssayFormat(input.file)
    if (is.na(format)) stop("Unknown assay layout (expected A or B)")
  }

  if (identical(format, "A")) return(parseAssayDataA(input.file, log.file, output.file))
  if (identical(format, "B")) return(parseAssayDataB(input.file, log.file, output.file))
  stop("Invalid format")
}

.detectAssayFormat <- function(FILE) {
  DROP <- .drop(FILE)
  HDR <- fread(FILE, nrows = 0L, drop = if (DROP == 0L) NULL else DROP)
  NMS <- names(HDR)

  if (any(grepl("^[^_]+_[^_]+_[^_]+$", NMS))) return("A")

  has.labjob <- any(grepl("^Labjob_", NMS, ignore.case = TRUE))
  has.unit.cols <- any(grepl("^[^_]+_(ppm|pct)$", NMS, ignore.case = TRUE))
  if (isTRUE(has.labjob) && isTRUE(has.unit.cols)) return("B")

  NA_character_
}

# ----------------------------------------------------------------------
# Parser B (assay): columnas analíticas element_unit y jobID por Labjob_*

parseAssayDataB <- function(input.file, log.file, output.file) {
  FILE <- input.file
  tryCatch({
    .log(log.file, "INFO", FILE, "CLIENT_FILE_START", "begin")

    if (!file.exists(FILE)) stop("FILE not found")

    DROP <- .drop(FILE)
    AUX <- fread(FILE, colClasses = "character", drop = if (DROP == 0L) NULL else DROP)

    req <- c("Sample_Id", "Labjob_CuT", "Labjob_Mo", "Labjob_CuCN", "Labjob_CuS")
    miss <- setdiff(req, names(AUX))
    if (length(miss)) {
      .log(log.file, "ERROR", FILE, "CLIENT_MISSING_COLUMNS",
        sprintf("missing=[%s]", paste(miss, collapse = ", "))
      )
      stop(sprintf("Missing required columns: %s", paste(miss, collapse = ", ")))
    }

    setnames(AUX, old = "Sample_Id", new = "sampleID")

    JOBCOLS <- c("Labjob_CuT", "Labjob_Mo", "Labjob_CuCN", "Labjob_CuS")
    VID <- names(AUX)[grepl("^[^_]+_(ppm|pct)$", names(AUX), ignore.case = TRUE)]

    if (length(VID) == 0L) {
      .log(log.file, "ERROR", FILE, "CLIENT_MISSING_COLUMNS", "missing=[analyte_columns]")
      stop("No analyte columns found")
    }

    AUX <- AUX[, c("sampleID", JOBCOLS, VID), with = FALSE]
    AUX[, (VID) := lapply(.SD, function(x) fifelse(x == "", NA_character_, x)), .SDcols = VID]

    DATA <- melt(
      AUX,
      id.vars = c("sampleID", JOBCOLS),
      measure.vars = VID,
      variable.name = "valueID",
      value.name = "value",
      variable.factor = FALSE,
      na.rm = TRUE
    ) |> unique()

    DATA[, elementID := tstrsplit(valueID, "_", fixed = TRUE)[[1]]]
    DATA[, unitID := tstrsplit(valueID, "_", fixed = TRUE)[[2]]]
    DATA[, unitID := .normUnit(unitID)]
    DATA[, standardID := NA_character_]

    # jobID por analito
    DATA[, jobID := Labjob_CuT]
    DATA[elementID == "Mo", jobID := Labjob_Mo]
    DATA[elementID %chin% c("CuCn", "CuCN"), jobID := Labjob_CuCN]
    DATA[elementID == "CuS", jobID := Labjob_CuS]

    # Warn on empty IDs (file-focused counts only)
    empty.job <- sum(is.na(DATA$jobID) | DATA$jobID == "")
    if (empty.job > 0L) .log(log.file, "WARNING", FILE, "CLIENT_EMPTY_JOBID", sprintf("rows=%d", empty.job))
    empty.smp <- sum(is.na(DATA$sampleID) | DATA$sampleID == "")
    if (empty.smp > 0L) .log(log.file, "WARNING", FILE, "CLIENT_EMPTY_SAMPLEID", sprintf("rows=%d", empty.smp))

    DATA[, c(JOBCOLS, "valueID") := NULL]

    idx <- !is.na(DATA$value) & stringr::str_detect(DATA$value, "[<>]")
    idx[is.na(idx)] <- FALSE
    DATA[, tagDL := "+"]
    DATA[idx, tagDL := stringr::str_extract(value, pattern = "[<>]")]
    DATA[idx, value := stringr::str_replace(value, pattern = "^\\s*[<>]\\s*", replacement = "")]
    DATA[, value := .as.numeric(value)]

    # Align output schema/order with type-A
    setcolorder(DATA, c("sampleID", "jobID", "value", "elementID", "standardID", "unitID", "tagDL"))

    if (!dir.exists(dirname(output.file))) dir.create(dirname(output.file), recursive = TRUE, showWarnings = FALSE)
    fwrite(DATA, file = output.file, append = FALSE, col.names = TRUE)

    .log(log.file, "INFO", FILE, "CLIENT_PARSE_OK",
      sprintf("rows=%d; jobIDs=%d; sampleIDs=%d",
        nrow(DATA), uniqueN(DATA$jobID), uniqueN(DATA$sampleID)
      )
    )
  }, error = function(e) {
    .log(log.file, "ERROR", FILE, "CLIENT_PARSE_ERROR", conditionMessage(e))
  })
}
