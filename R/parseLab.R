# ----------------------------------------------------------------------
# Parser A (original): mantiene el comportamiento del tipo A.

parseLabDataA <- function(
  path,
  mode = "append",  # "bind" | "append"
  index.file = file.path("./index.csv"),
  data.file = file.path("./data.csv"),
  log.file = file.path("./parse.log.csv")
) {

  if (!dir.exists(dirname(data.file))) dir.create(dirname(data.file), recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop(sprintf("path %s not found. Stop", path))

  INDEX <- data.table()
  DATA <- data.table()
  unlink(index.file)
  unlink(data.file)

  FILES <- list.files(
    path = path,
    pattern = "\\.csv$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  IO.INDEX <- FALSE
  IO.DATA <- FALSE

  for (FILE in FILES) {
    OUT <- .parseLabDataA(FILE, log.file = log.file)

    if (mode == "append") {
      if (nrow(OUT$INDEX) > 0L) {
        fwrite(OUT$INDEX, file = index.file, append = IO.INDEX, col.names = !IO.INDEX)
        IO.INDEX <- TRUE
      }
      if (nrow(OUT$DATA) > 0L) {
        fwrite(OUT$DATA, file = data.file, append = IO.DATA, col.names = !IO.DATA)
        IO.DATA <- TRUE
      }
    }

    if (mode == "bind") {
      INDEX <- list(INDEX, OUT$INDEX) |>
        rbindlist(use.names = TRUE) |>
        unique()
      DATA <- list(DATA, OUT$DATA) |>
        rbindlist(use.names = TRUE) |>
        unique()
    }
  }

  if (mode == "bind") {
    fwrite(INDEX, file = index.file, append = FALSE, col.names = TRUE)
    fwrite(DATA, file = data.file, append = FALSE, col.names = TRUE)
  }

  invisible(TRUE)
}

# ----------------------------------------------------------------------
# Parser universal: soporta tipo A y tipo B.

parseLabData <- function(
  path,
  format = c("auto", "A", "B"),
  mode = "append",  # "bind" | "append"
  index.file = file.path("./index.csv"),
  data.file = file.path("./data.csv"),
  log.file = file.path("./parse.log.csv")
) {

  format <- match.arg(format)

  if (!dir.exists(dirname(data.file))) dir.create(dirname(data.file), recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop(sprintf("path %s not found. Stop", path))

  INDEX <- data.table()
  DATA <- data.table()
  unlink(index.file)
  unlink(data.file)

  FILES <- list.files(
    path = path,
    pattern = "\\.csv$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  IO.INDEX <- FALSE
  IO.DATA <- FALSE

  for (FILE in FILES) {
    OUT <- .parseLabData(FILE, log.file = log.file, format = format)

    if (mode == "append") {
      if (nrow(OUT$INDEX) > 0L) {
        fwrite(OUT$INDEX, file = index.file, append = IO.INDEX, col.names = !IO.INDEX)
        IO.INDEX <- TRUE
      }
      if (nrow(OUT$DATA) > 0L) {
        fwrite(OUT$DATA, file = data.file, append = IO.DATA, col.names = !IO.DATA)
        IO.DATA <- TRUE
      }
    }

    if (mode == "bind") {
      INDEX <- list(INDEX, OUT$INDEX) |>
        rbindlist(use.names = TRUE) |>
        unique()
      DATA <- list(DATA, OUT$DATA) |>
        rbindlist(use.names = TRUE) |>
        unique()
    }
  }

  if (mode == "bind") {
    fwrite(INDEX, file = index.file, append = FALSE, col.names = TRUE)
    fwrite(DATA, file = data.file, append = FALSE, col.names = TRUE)
  }

  invisible(TRUE)
}

# ----------------------------------------------------------------------
# Detector de formato

.detectLabFormat <- function(FILE) {
  # Detect A vs B from header markers.
  #
  # NOTE: The previous implementation used fread(skip="Analysis Order"), but many real type-A
  # certificates use "ANALYSISORDER" (no space) in the header row, which caused massive
  # UNKNOWN_FORMAT false positives.

  head.lines <- readLines(FILE, n = 80L, warn = FALSE)

  # Some real-world certificates contain non-UTF8 bytes. Normalize to UTF-8 so regex ops
  # do not error. Unknown/invalid sequences are dropped (only used for detection).
  head.lines <- iconv(head.lines, from = "", to = "UTF-8", sub = "")
  head.lines[is.na(head.lines)] <- ""

  head.lines <- sub("^\\ufeff", "", head.lines)
  low <- tolower(head.lines)

  # Type B: typically contains a "Method:" marker and/or an ELEMENT header row.
  if (any(grepl("^\\s*element\\b", low)) || any(grepl("method:", low, fixed = TRUE))) {
    return("B")
  }

  # Type A: header row often contains ANALYSISORDER (sometimes "Analysis Order") and has
  # MIN/MAX DETECTION rows.
  if (any(grepl("analysis\\s*order", low)) || any(grepl("analysisorder", low, fixed = TRUE))) {
    return("A")
  }
  if (any(grepl("^\\s*min\\s*detection", low)) && any(grepl("^\\s*max\\s*detection", low))) {
    return("A")
  }

  NA_character_
}

.parseLabData <- function(FILE, log.file, format) {
  if (identical(format, "auto")) {
    format <- .detectLabFormat(FILE)
    if (is.na(format)) {
      .log(log.file, "ERROR", FILE, "UNKNOWN_FORMAT", "Unknown certificate layout (expected A or B)")
      return(list(DATA = data.table(), INDEX = data.table()))
    }
  }

  if (identical(format, "A")) return(.parseLabDataA(FILE, log.file = log.file))
  if (identical(format, "B")) return(.parseLabDataB(FILE, log.file = log.file))
  stop("Invalid format")
}

# ----------------------------------------------------------------------
# Implementación por archivo: tipo A (sin cambios)

.parseLabDataA <- function(.x, log.file) {
  FILE <- .x
  jobID <- NA_character_

  withCallingHandlers({
    tryCatch({

      DROP <- .drop(FILE)

      # -----------------------------------------------------------------------
      # Recover HEADER block metadata (fixed layout, always first 6 rows)
      SELECT <- c(1L, 2L) + DROP
      AUX <- fread(
        FILE,
        nrows = 6L,
        header = FALSE,
        colClasses = "character",
        select = SELECT, fill = TRUE
      )

      KEYS <- tolower(trimws(sub(":*$", "", sub("^\\ufeff", "", AUX[[1]]))))
      VALS <- trimws(gsub("[[:cntrl:]]", "", AUX[[2]]))
      fileID <- basename(FILE)
      jobID <- .cleanId(VALS[match("labjobno", KEYS)])
      despatchID <- .cleanId(VALS[match("despatchno", KEYS)])
      sampleN <- VALS[match("# of samples", KEYS)] |> .as.numeric()
      dateReceived <- VALS[match("date received", KEYS)] |> .as.Date()
      dateFinalized <- VALS[match("date finalized", KEYS)] |> .as.Date()

      # Log file start with minimal context
      .log(log.file, "INFO", FILE, "FILE_START", sprintf("begin; jobID=%s", jobID))

      # -----------------------------------------------------------------------
      # Read INDEX block (fixed layout, always starts at line 7, 5 rows). Remove column 2 (Analysis order)

      AUX <- fread(
        FILE,
        skip = 6L,
        nrows = 5L,
        header = FALSE,
        drop = if (DROP == 0L) 2L else c(1L, 3L),
        fill = TRUE
      ) |> transpose()

      HDR <- AUX[1, ] |> as.character() |> trimws() |> tolower()
      OLD <- c("", "sample", "description", "min detection", "max detection")
      m <- match(HDR, OLD)

      if (length(HDR) != length(OLD) || anyNA(m) || any(duplicated(m))) {
        stop(sprintf("Unexpected INDEX header: %s", paste(HDR, collapse = ", ")))
      }

      NEW <- c("standardID", "elementID", "unitID", "minDL", "maxDL")
      setnames(AUX, new = NEW[m])

      INDEX <- AUX[-1, .(
        standardID,
        elementID,
        valueID = paste(elementID, standardID, tolower(unitID), sep = "_"),
        minDL = .as.numeric(minDL),
        maxDL = .as.numeric(maxDL),
        unitID = tolower(unitID),
        fileID = fileID,
        jobID = jobID,
        despatchID = despatchID,
        dateReceived = dateReceived,
        dateFinalized = dateFinalized,
        sampleN = sampleN
      )] |> unique()

      if (nrow(INDEX) > 0L && any(is.na(INDEX$standardID) | is.na(INDEX$elementID) | is.na(INDEX$unitID))) {
        .log(log.file, "WARNING", FILE, "DIAG_INDEX_EMPTY",
          sprintf("Empty/malformed analyte identifiers; jobID=%s", jobID)
        )
      }

      VID <- INDEX$valueID
      if (any(duplicated(VID))) {
        .log(log.file, "ERROR", FILE, "DUPLICATE_VID",
          sprintf("Duplicate valueID detected; jobID=%s", jobID)
        )
        stop(sprintf("Duplicate VID: %s", paste(unique(VID[duplicated(VID)]), collapse = ", ")))
      }

      AUX <- fread(
        FILE,
        skip = 11L,
        header = FALSE,
        drop = if (DROP == 0L) 2L else c(1L, 3L),
        colClasses = "character",
        fill = TRUE
      )

      AUX <- .reconcileColumns(AUX, VID, FILE, log.file = log.file, jobID = jobID)

      setnames(AUX, old = colnames(AUX), new = c("sampleID", VID))
      AUX[, (names(AUX)) := lapply(.SD, function(x) fifelse(x %in% c(""), NA_character_, x))]

      obsN <- uniqueN(AUX$sampleID)
      rowN <- nrow(AUX)
      dupN <- rowN - obsN

      if (dupN > 0L) {
        .log(log.file, "ERROR", FILE, "SAMPLEID_NOT_UNIQUE",
          sprintf("duplicated_rows=%d; jobID=%s", dupN, jobID)
        )
      }

      if (!is.null(sampleN) && !is.na(sampleN) && is.finite(sampleN)) {
        if (as.integer(sampleN) != obsN) {
          .log(log.file, "WARNING", FILE, "SAMPLES_DECLARED_MISMATCH",
            sprintf("declared=%d; observed=%d; jobID=%s", as.integer(sampleN), obsN, jobID)
          )
        }
      }

      DATA <- melt(
        AUX,
        id.vars = "sampleID",
        variable.name = "valueID",
        value.name = "value",
        variable.factor = FALSE,
        na.rm = TRUE
      ) |> unique()

      DATA <- DATA[INDEX, on = "valueID", nomatch = 0L]

      idx <- !is.na(DATA$value) & stringr::str_detect(DATA$value, "[<>]")
      idx[is.na(idx)] <- FALSE
      DATA[, tagDL := "+"]
      DATA[idx, tagDL := stringr::str_extract(value, pattern = "[<>]")]
      DATA[idx, value := stringr::str_replace(value, pattern = "^\\s*[<>]\\s*", replacement = "")]
      DATA[, value := .as.numeric(value)]

      .log(log.file, "INFO", FILE, "PARSE_OK", sprintf("rows=%d; jobID=%s", nrow(DATA), jobID))

      list(
        INDEX = unique(INDEX[, -"valueID"]),
        DATA = unique(DATA[, -"valueID"])
      )
    }, error = function(e) {
      .log(log.file, "ERROR", FILE, "PARSE_ERROR", sprintf("%s; jobID=%s", conditionMessage(e), jobID))
      list(DATA = data.table(), INDEX = data.table())
    })
  }, warning = function(w) {
    .log(log.file, "WARNING", FILE, "WARNING", conditionMessage(w))
    invokeRestart("muffleWarning")
  })
}

# ----------------------------------------------------------------------
# Implementación por archivo: tipo B

.parseLabDataB <- function(.x, log.file) {
  FILE <- .x
  jobID <- sub("\\.[cC][sS][vV]$", "", basename(FILE))

  withCallingHandlers({
    tryCatch({
      DROP <- .drop(FILE)
      fileID <- basename(FILE)

      # Header-derived metadata (best-effort)
      despatchID <- NA_character_
      dateReceived <- NA_character_
      dateFinalized <- NA_character_

      head.lines <- readLines(FILE, n = 40L, warn = FALSE)
      head.lines <- sub("^\\ufeff", "", head.lines)

      i.received <- grep("Received", head.lines, ignore.case = TRUE)[1]
      if (!is.na(i.received)) {
        f <- strsplit(head.lines[i.received], ",", fixed = TRUE)[[1]]
        f <- trimws(gsub("[[:cntrl:]]", "", f))
        key <- tolower(f)

        k <- which(key == "received:")[1]
        if (length(k) == 1L && k < length(f)) dateReceived <- .as.Date(f[k + 1L])

        k <- which(key %in% c("date completed:", "date completed", "date finalized:", "date finalized"))[1]
        if (length(k) == 1L && k < length(f)) dateFinalized <- .as.Date(f[k + 1L])
      }

      i.despatch <- grep("^\\s*DespatchNo\\s*:", head.lines, ignore.case = TRUE)[1]
      if (!is.na(i.despatch)) {
        f <- strsplit(head.lines[i.despatch], ",", fixed = TRUE)[[1]]
        f <- trimws(gsub("[[:cntrl:]]", "", f))
        if (length(f) >= 2L) despatchID <- .cleanId(f[2L])
      }

      .log(log.file, "INFO", FILE, "FILE_START", sprintf("begin; jobID=%s", jobID))

      # Read the structured type-B block using fread(skip=...) so sep guessing is based on the table,
      # not on free-text header lines.
      HEAD <- fread(FILE, skip = "Method:", nrows = 100L, header = FALSE, colClasses = "character", fill = TRUE)

      c1 <- tolower(trimws(sub("^\\ufeff", "", as.character(HEAD[[1L + DROP]]))))

      i.element <- which(grepl("^element\\b", c1))[1]
      i.method <- which(grepl("^method\\b", c1))[1]
      i.units <- which(grepl("^units\\b", c1))[1]
      i.minDL <- which(grepl("^det", c1))[1]
      i.maxDL <- which(grepl("^upper", c1))[1]

      if (any(is.na(c(i.element, i.method, i.units, i.minDL, i.maxDL)))) {
        stop("Missing required header rows for type-B certificate")
      }

      j0 <- 5L + DROP
      j1 <- ncol(HEAD)

      elementID <- trimws(as.character(unlist(HEAD[i.element, j0:j1, with = FALSE], use.names = FALSE)))
      standardID <- trimws(as.character(unlist(HEAD[i.method, j0:j1, with = FALSE], use.names = FALSE)))
      standardID <- sub("^.*-", "", standardID)
      unitID <- trimws(as.character(unlist(HEAD[i.units, j0:j1, with = FALSE], use.names = FALSE)))
      unitID <- .normUnit(unitID)
      minDL <- trimws(as.character(unlist(HEAD[i.minDL, j0:j1, with = FALSE], use.names = FALSE)))
      maxDL <- trimws(as.character(unlist(HEAD[i.maxDL, j0:j1, with = FALSE], use.names = FALSE)))

      INDEX <- data.table(
        standardID = standardID,
        elementID = elementID,
        valueID = paste(elementID, standardID, unitID, sep = "_"),
        minDL = .as.numeric(minDL),
        maxDL = .as.numeric(maxDL),
        unitID = unitID,
        fileID = fileID,
        jobID = jobID,
        despatchID = despatchID,
        dateReceived = dateReceived,
        dateFinalized = dateFinalized,
        sampleN = NA_real_
      ) |> unique()

      VID <- INDEX$valueID
      if (any(duplicated(VID))) {
        .log(log.file, "ERROR", FILE, "DUPLICATE_VID",
          sprintf("Duplicate valueID detected; jobID=%s", jobID)
        )
        stop(sprintf("Duplicate VID: %s", paste(unique(VID[duplicated(VID)]), collapse = ", ")))
      }

      drop.cols <- if (DROP == 0L) 2:4 else c(1L, 3L, 4L, 5L)
      AUX <- fread(
        FILE,
        skip = "SAMPLES",
        header = FALSE,
        colClasses = "character",
        drop = drop.cols,
        fill = TRUE
      )

      # Drop the header row that starts with "SAMPLES".
      if (nrow(AUX) > 0L) AUX <- AUX[-1]

      AUX <- .reconcileColumns(AUX, VID, FILE, log.file = log.file, jobID = jobID)

      setnames(AUX, old = colnames(AUX), new = c("sampleID", VID))
      AUX[, (names(AUX)) := lapply(.SD, function(x) fifelse(x %in% c(""), NA_character_, x))]

      obsN <- uniqueN(AUX$sampleID)
      rowN <- nrow(AUX)
      dupN <- rowN - obsN
      if (dupN > 0L) {
        .log(log.file, "ERROR", FILE, "SAMPLEID_NOT_UNIQUE",
          sprintf("duplicated_rows=%d; jobID=%s", dupN, jobID)
        )
      }

      INDEX[, sampleN := as.numeric(obsN)]

      DATA <- melt(
        AUX,
        id.vars = "sampleID",
        variable.name = "valueID",
        value.name = "value",
        variable.factor = FALSE,
        na.rm = TRUE
      ) |> unique()

      DATA <- DATA[INDEX, on = "valueID", nomatch = 0L]

      idx <- !is.na(DATA$value) & stringr::str_detect(DATA$value, "[<>]")
      idx[is.na(idx)] <- FALSE
      DATA[, tagDL := "+"]
      DATA[idx, tagDL := stringr::str_extract(value, pattern = "[<>]")]
      DATA[idx, value := stringr::str_replace(value, pattern = "^\\s*[<>]\\s*", replacement = "")]
      DATA[, value := .as.numeric(value)]

      .log(log.file, "INFO", FILE, "PARSE_OK", sprintf("rows=%d; jobID=%s", nrow(DATA), jobID))

      list(
        INDEX = unique(INDEX[, -"valueID"]),
        DATA = unique(DATA[, -"valueID"])
      )
    }, error = function(e) {
      .log(log.file, "ERROR", FILE, "PARSE_ERROR", sprintf("%s; jobID=%s", conditionMessage(e), jobID))
      list(DATA = data.table(), INDEX = data.table())
    })
  }, warning = function(w) {
    .log(log.file, "WARNING", FILE, "WARNING", conditionMessage(w))
    invokeRestart("muffleWarning")
  })
}
