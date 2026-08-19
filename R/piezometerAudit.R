## R/piezometerAudit.R
## Piezometer pipeline, migrated verbatim from AR-S2L1X scripts/runAudit.R
## (stage-1 migration; the application repository remains the producer of
## record until the switch-over). Declared adaptations only: the shared
## dbAudit logger replaces the local one, and inclinometer branches are out
## of scope for auditPiezometer().


.readRaw <- function(raw, id, name) {
  FILES <- .rawFiles(raw = raw, id = id, name = name)
  if (length(FILES) == 0L) {
    stop(sprintf("no raw %s.csv files found for %s", name, id), call. = FALSE)
  }
  data.table::rbindlist(
    l = lapply(X = FILES, FUN = function(file) data.table::fread(file = file)),
    use.names = TRUE
  )
}

.emptyHeader <- function() {
  data.table::data.table(
    ID = character(),
    SiteID = character(),
    HoleID = character(),
    SensorID = character(),
    SourcePath = character(),
    SourceSheet = character(),
    Field = character(),
    RawLabel = character(),
    RawValue = character(),
    SourceRow = integer(),
    SourceCol = integer()
  )
}

.readHeader <- function(raw, id) {
  FILES <- .rawFiles(raw = raw, id = id, name = "header")
  if (length(FILES) == 0L) return(.emptyHeader())
  data.table::rbindlist(
    l = lapply(X = FILES, FUN = function(file) data.table::fread(file = file)),
    use.names = TRUE
  )
}

.readDB <- function(db, id, name) {
  FILE <- file.path(db, sprintf("%s.%s.csv", id, name))
  if (!file.exists(FILE)) {
    stop(sprintf("db file not found: %s", FILE), call. = FALSE)
  }
  data.table::fread(file = FILE)
}

.readAllRaw <- function(raw, id, name) {
  data.table::rbindlist(
    l = lapply(X = id, FUN = function(ID) .readRaw(raw = raw, id = ID, name = name)),
    use.names = TRUE
  )
}

.readAllHeader <- function(raw, id) {
  data.table::rbindlist(
    l = lapply(X = id, FUN = function(ID) .readHeader(raw = raw, id = ID)),
    use.names = TRUE
  )
}

.readAllDB <- function(db, id, name) {
  data.table::rbindlist(
    l = lapply(X = id, FUN = function(ID) .readDB(db = db, id = ID, name = name)),
    use.names = TRUE
  )
}

.readDBList <- function(db, id, name) {
  OUT <- lapply(X = id, FUN = function(ID) .readDB(db = db, id = ID, name = name))
  names(OUT) <- id
  OUT
}

.checkColumns <- function(log, file, data, cols, event = "") {
  MISS <- setdiff(cols, names(data))
  if (length(MISS) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MALFORMED",
      source = file,
      detail = sprintf("missing=%s", paste(MISS, collapse = ", "))
    )
    return(FALSE)
  }
  TRUE
}

.readRejects <- function(audit, id) {
  # The gate sink holds heterogeneous records (rejections carry source
  # lineage; corrections may not). Only REJECTED records take part in
  # the raw/db reconciliation.
  COLS <- c("ID", "SourcePath", "SourceSheet", "SourceRow")
  LIST <- lapply(X = id, FUN = function(ID) {
    FILE <- file.path(audit, sprintf("%s.reject.csv", ID))
    if (!file.exists(FILE)) return(NULL)
    DT <- data.table::fread(file = FILE)
    if (all(c("level", "event") %in% names(DT))) DT <- DT[event == "UNREADABLE"]
    if (!all(COLS %in% names(DT)) || nrow(DT) == 0L) return(NULL)
    DT[, ..COLS]
  })
  data.table::rbindlist(l = LIST, use.names = TRUE)
}

.readRepairs <- function(raw, audit, id) {
  # Systematic filename repairs applied by the gate: the db carries the
  # repaired HoleID (the filename key) while data/raw keeps the raw
  # evidence under the typed one. The census must compare the raw side
  # under the repaired key — rekeying, not discounting, so a repaired
  # record lost on the way to db still surfaces as MISSING (ruling
  # 2026-08-19 closing the false-MISSING interaction found by the
  # idFixFilename stress case).
  LIST <- lapply(X = id, FUN = function(ID) {
    IDX <- .readRaw(raw = raw, id = ID, name = "index")
    if (!all(c("FileKeyOK", "FileKey", "SourcePath") %in% names(IDX))) {
      return(NULL)
    }
    BAD <- unique(IDX[
      !is.na(FileKeyOK) & FileKeyOK == FALSE & nzchar(FileKey),
      .(SourcePath, FileKey)
    ])
    if (nrow(BAD) == 0L) return(NULL)
    FILE <- file.path(audit, sprintf("%s.reject.csv", ID))
    if (!file.exists(FILE)) return(NULL)
    SINK <- data.table::fread(file = FILE)
    if (!all(c("event", "SourcePath") %in% names(SINK))) return(NULL)
    BAD <- BAD[SourcePath %in% unique(SINK[event == "MISLABELED", SourcePath])]
    if (nrow(BAD) == 0L) return(NULL)
    BAD[, .(ID = ID, SourcePath, FileKey)]
  })
  data.table::rbindlist(l = LIST, use.names = TRUE)
}

.checkSourceCensus <- function(log, source, walked, pattern = "[.]xlsx$") {
  # MISSING (ERROR, catalog): source-to-raw census. The parse layer
  # walks its id-rooted subtrees only; a data file anywhere else under
  # the source root never reached raw and nobody reconciled it
  # (PLAN-virtual-site.md detection gap 2, closed 2026-08-18). Both
  # sides compare as normalized absolute paths.
  FILES <- listSourceFiles(path = source, pattern = pattern)
  FILES <- normalizePath(path.expand(FILES), mustWork = FALSE)
  Walked <- normalizePath(
    path.expand(unique(.asChar(walked))),
    mustWork = FALSE
  )
  MISS <- setdiff(FILES, Walked)
  if (length(MISS) > 0L) {
    Prefix <- paste0(normalizePath(path.expand(source), mustWork = TRUE), "/")
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MISSING",
      source = sub(pattern = Prefix, replacement = "", x = MISS, fixed = TRUE),
      detail = "data file under the source root never parsed"
    )
  }
  invisible(TRUE)
}

.checkRawDBKeys <- function(log, rawData, dbIndex, rejects = NULL, repairs = NULL) {
  COLS <- c("ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet", "SourceRow")
  if (!.checkColumns(log = log, file = "data/raw", data = rawData, cols = COLS)) {
    return(invisible(FALSE))
  }
  if (!.checkColumns(log = log, file = "data/db", data = dbIndex, cols = COLS)) {
    return(invisible(FALSE))
  }

  RAW <- unique(rawData[, ..COLS])
  DB <- unique(dbIndex[, ..COLS])
  if (!is.null(rejects) && nrow(rejects) > 0L) {
    TRACE <- c("ID", "SourcePath", "SourceSheet", "SourceRow")
    RAW <- RAW[!unique(rejects), on = TRACE]
    DB <- DB[!unique(rejects), on = TRACE]
  }
  if (!is.null(repairs) && nrow(repairs) > 0L) {
    # Compare the raw side under the repaired key (see .readRepairs).
    RAW[repairs, on = c("ID", "SourcePath"), HoleID := i.FileKey]
  }
  AUX <- RAW[!DB, on = COLS]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MISSING",
      source = "data/db",
      detail = sprintf("raw records missing in db; count=%d", nrow(AUX))
    )
  }
  AUX <- DB[!RAW, on = COLS]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MISSING",
      source = "data/raw",
      detail = sprintf("db records missing in raw; count=%d", nrow(AUX))
    )
  }
  invisible(TRUE)
}

# Excel serial date rendered as a log date label; a non-numeric date
# passes through untouched so the emission never hides the raw
# evidence.
.asDateLabel <- function(date) {
  Day <- suppressWarnings(as.numeric(.asChar(date)))
  OUT <- format(as.Date(Day, origin = "1899-12-30"), format = "%Y-%m-%d")
  data.table::fifelse(is.na(Day), .asChar(date), OUT)
}

.checkDuplicateRaw <- function(log, rawData) {
  # DUPLICATED record (ERROR, catalog): two readings the client's own
  # columns cannot distinguish. The key is THE CLIENT'S OWN ROW
  # IDENTITY: instrument (ID, SiteID, HoleID, SensorID) plus date PLUS
  # time PLUS stage, each wherever the source sheet provides it; a
  # column absent from a domain leaves the identity to the columns that
  # exist. The source position (SourceRow) is never part of the
  # identity — a re-entered identical row always carries another
  # SourceRow. Ruling 2026-08-18: the previous date-only key over-fired
  # on legitimate practice (intra-day development series with distinct
  # horas; Zero Reading vs Field Read distinguished by stage).
  # (PLAN-virtual-site.md detection gap 1, closed 2026-08-18; rekeyed
  # to the client identity 2026-08-18.)
  COLS <- c("ID", "SiteID", "HoleID", "SensorID", "date",
            "SourceRow", "variable")
  if (!.checkColumns(log = log, file = "data/raw", data = rawData, cols = COLS)) {
    return(invisible(FALSE))
  }
  KEY <- c("ID", "SiteID", "HoleID", "SensorID", "date",
           intersect(c("time", "stage"), names(rawData)))
  AUX <- rawData[, .N, by = c(KEY, "variable")][N > 1L]
  if (nrow(AUX) > 0L) {
    AUX <- rawData[unique(AUX[, ..KEY]), on = KEY][, .(
      rows = data.table::uniqueN(SourceRow),
      SourceRow = paste(sort(unique(SourceRow)), collapse = "/"),
      variables = paste(sort(unique(variable)), collapse = ", ")
    ), by = KEY]
    .logEvent(
      log.file = log,
      scope = "record",
      event = "DUPLICATED",
      SiteID = AUX$SiteID,
      HoleID = AUX$HoleID,
      datetime = .asDateLabel(date = AUX$date),
      source = "data/raw",
      detail = sprintf(
        "ID=%s; SensorID=%s; rows=%d; SourceRow=%s; variables=%s",
        AUX$ID, AUX$SensorID, AUX$rows, AUX$SourceRow, AUX$variables
      )
    )
  }
  invisible(TRUE)
}

.checkSourceSheets <- function(log, raw, id) {
  # MALFORMED (ERROR, catalog): a sheet that DECLARES the client
  # monitoring header marker (see .hasSheetMarker) but fails the
  # data-sheet gate was previously skipped in silence with zero
  # readings (PLAN-virtual-site.md detection gap 3, closed 2026-08-18).
  # A raw index written before the HasMarker column existed cannot
  # observe the marker: the check skips it until a re-parse.
  invisible(lapply(X = id, FUN = function(ID) {
    IDX <- .readRaw(raw = raw, id = ID, name = "index")
    COLS <- c("SiteID", "HoleID", "SourcePath", "SourceSheet",
              "IsDataSheet", "HasMarker")
    if (!all(COLS %in% names(IDX))) return(NULL)
    BAD <- IDX[HasMarker == TRUE & IsDataSheet == FALSE]
    if (nrow(BAD) == 0L) return(NULL)
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MALFORMED",
      SiteID = BAD$SiteID,
      HoleID = BAD$HoleID,
      source = sprintf("%s [%s]", basename(BAD$SourcePath), BAD$SourceSheet),
      detail = sprintf(
        "ID=%s; declared monitoring sheet fails the data-sheet gate; readings skipped",
        BAD$ID
      )
    )
  }))
}

.checkRawUnits <- function(log, rawData) {
  COLS <- c("ID", "variable", "units")
  if (!.checkColumns(log = log, file = "data/raw", data = rawData, cols = COLS)) {
    return(invisible(FALSE))
  }
  AUX <- rawData[, .(
    N.units = data.table::uniqueN(units),
    units = paste(sort(unique(units)), collapse = ", ")
  ), by = .(ID, variable)][N.units > 1L]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MIXED",
      source = "data/raw",
      detail = sprintf(
        "ID=%s; variable=%s; units=%s", AUX$ID, AUX$variable, AUX$units
      )
    )
  }
  invisible(TRUE)
}

.checkDBUnits <- function(log, data) {
  COLS <- grep(pattern = "^units[.]", x = names(data), value = TRUE)
  if (length(COLS) == 0L) {
    .logEvent(
      log.file = log, scope = "file", event = "MALFORMED",
      source = "data/db", detail = "no units.* columns present"
    )
    return(invisible(FALSE))
  }
  AUX <- data.table::rbindlist(
    l = lapply(X = COLS, FUN = function(col) {
      Var <- sub(pattern = "^units[.]", replacement = "", x = col)
      if (!Var %in% names(data)) {
        return(data.table::data.table(column = col, N = 0L))
      }
      data[!is.na(get(Var)) & (is.na(get(col)) | !nzchar(as.character(get(col)))),
           .(column = col, N = .N)]
    }),
    use.names = TRUE
  )[N > 0L]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "UNITLESS",
      source = "data/db",
      detail = sprintf("column=%s; rows=%d", AUX$column, AUX$N)
    )
  }
  invisible(TRUE)
}

# Residual filename-ID conflicts: the gate repairs HoleID only under
# systematic evidence and records MISLABELED (corrected) in the
# sink. Any FileKeyOK == FALSE source NOT repaired is retained suspect.
.checkFileIDResidual <- function(log, raw, audit, id) {
  invisible(lapply(X = id, FUN = function(ID) {
    IDX <- .readRaw(raw = raw, id = ID, name = "index")
    if (is.null(IDX) || !all(c("FileKeyOK", "FileKey", "SourcePath") %in% names(IDX))) {
      return(NULL)
    }
    BAD <- unique(IDX[
      !is.na(FileKeyOK) & FileKeyOK == FALSE & nzchar(FileKey),
      .(SourcePath, HoleID, FileKey)
    ])
    if (nrow(BAD) == 0L) return(NULL)
    FILE <- file.path(audit, sprintf("%s.reject.csv", ID))
    if (file.exists(FILE)) {
      SINK <- data.table::fread(FILE)
      if (all(c("event", "SourcePath") %in% names(SINK))) {
        Fixed <- unique(SINK[event == "MISLABELED", SourcePath])
        BAD <- BAD[!(SourcePath %in% Fixed)]
      }
    }
    if (nrow(BAD) == 0L) return(NULL)
    .logEvent(
      log.file = log,
      scope = "file",
      event = "MISLABELED",
      level = "ERROR",
      HoleID = BAD$HoleID,
      source = basename(BAD$SourcePath),
      detail = sprintf("content=%s; filename=%s; not repaired", BAD$HoleID, BAD$FileKey)
    )
  }))
}

.checkPCVHeader <- function(log, header) {
  if (nrow(header) == 0L) return(invisible(TRUE))
  COLS <- c("ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
            "Field", "RawValue")
  if (!.checkColumns(log = log, file = "data/raw/PCV/header.csv", data = header,
                     cols = COLS)) {
    return(invisible(FALSE))
  }
  DT <- header[ID == "PCV"]
  if (nrow(DT) == 0L) return(invisible(TRUE))

  KEYS <- c("ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet")
  Fields <- c("Model", "SerialNo", "Range", "Sensor", "Tk", "CF",
              "InstallDepth", "HoleID", "Inclination", "SensorElevation")
  Keys <- unique(DT[, ..KEYS])
  Expected <- Keys[, .(Field = Fields), by = KEYS]
  Seen <- unique(DT[Field %in% Fields, c(KEYS, "Field"), with = FALSE])
  AUX <- Expected[!Seen, on = c(KEYS, "Field")]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "INCOMPLETE",
      source = "data/raw/PCV/header.csv",
      detail = sprintf("ID=PCV; missing header fields; count=%d", nrow(AUX))
    )
  }

  AUX <- DT[
    Field %in% Fields & (is.na(RawValue) | !nzchar(trimws(as.character(RawValue)))),
    .N,
    by = Field
  ]
  if (nrow(AUX) > 0L) {
    .logEvent(
      log.file = log,
      scope = "file",
      event = "INCOMPLETE",
      source = "data/raw/PCV/header.csv",
      detail = sprintf("ID=PCV; empty field=%s; rows=%d", AUX$Field, AUX$N)
    )
  }
  invisible(TRUE)
}

.initAudit <- function(data) {
  invisible(lapply(X = names(data), FUN = function(ID) {
    data[[ID]][, `:=`(status = "OK", event = "")]
  }))
  data
}
.pzTables <- function(data, index, rejects = NULL) {
  COLS.data <- c("ID", "RecordID", "SiteID", "HoleID", "SensorID", "datetime",
                 "status", "event", "depth", "units.depth", "level", "units.level",
                 "head", "units.head")
  COLS.index <- c("ID", "RecordID", "SiteID", "HoleID", "SensorID", "datetime",
                  "index", "stage", "SourcePath", "SourceSheet", "SourceRow")

  DATA <- data.table::rbindlist(
    l = lapply(X = data, FUN = function(DT) DT[, ..COLS.data]),
    use.names = TRUE
  )
  # DRY declared condition (flag D, catalog inst/events.csv): a dry
  # Casagrande reading has no level value; the flag replaces the
  # implicit-NA convention.
  DATA[, flag := data.table::fifelse(ID == "PCG" & is.na(level), "D", "")]
  INDEX <- index[, ..COLS.index]
  # Flag D marks the dry condition only: a record whose level was
  # rejected at the gate (UNREADABLE in the sink) is a data gap, not a
  # dry well (PLAN-virtual-site.md detection gap 4, closed 2026-08-18).
  if (!is.null(rejects) && nrow(rejects) > 0L) {
    TRACE <- c("ID", "SourcePath", "SourceSheet", "SourceRow")
    Gated <- INDEX[
      unique(rejects[, ..TRACE]),
      on = TRACE,
      nomatch = NULL,
      .(ID, RecordID)
    ]
    DATA[Gated, on = c("ID", "RecordID"), flag := ""]
  }
  data.table::setorder(DATA, ID, SiteID, HoleID, SensorID, datetime, RecordID)
  data.table::setorder(INDEX, ID, SiteID, HoleID, SensorID, datetime, RecordID)
  list(data = DATA, index = INDEX)
}

.writeAudit <- function(path, id, data, pz) {
  dir.create(path = path, recursive = TRUE, showWarnings = FALSE)
  invisible(lapply(X = id, FUN = function(idOne) {
    data.table::fwrite(
      x = data[[idOne]],
      file = file.path(path, sprintf("%s.audit.csv", idOne))
    )
  }))
  data.table::fwrite(x = pz$data, file = file.path(path, "PZ.data.csv"))
  data.table::fwrite(x = pz$index, file = file.path(path, "PZ.index.csv"))
}
