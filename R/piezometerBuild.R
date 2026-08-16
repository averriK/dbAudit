## R/piezometerBuild.R
## Piezometer pipeline, migrated verbatim from AR-S2L1X scripts/runData.R
## (stage-1 migration; the application repository remains the producer of
## record until the switch-over). Declared adaptations only: the shared
## dbAudit logger replaces the local one, and inclinometer branches are out
## of scope for auditPiezometer().


.rawFiles <- function(raw, id, name) {
  FILES <- list.files(
    path = file.path(raw, id),
    pattern = paste0("^", name, "[.]csv$"),
    recursive = TRUE,
    full.names = TRUE
  )
  sort(FILES)
}

.readRawTable <- function(raw, id, name, colClasses = NULL) {
  FILES <- .rawFiles(raw = raw, id = id, name = name)
  if (length(FILES) == 0L) {
    stop(sprintf("no %s.csv files found for %s", name, id), call. = FALSE)
  }
  data.table::rbindlist(
    l = lapply(X = FILES, FUN = function(file) {
      data.table::fread(file = file, colClasses = colClasses)
    }),
    use.names = TRUE
  )
}

.readRawIndex <- function(raw, id) {
  FILES <- .rawFiles(raw = raw, id = id, name = "index")
  if (length(FILES) == 0L) {
    stop(sprintf("no index.csv files found for %s", id), call. = FALSE)
  }
  data.table::rbindlist(
    l = lapply(
      X = FILES,
      FUN = function(file) {
        data.table::fread(
          file = file,
          select = c("ID", "SiteID", "HoleID", "SensorID")
        )
      }
    ),
    use.names = TRUE
  )
}

.checkRawIndex <- function(data, index) {
  COLS <- c("ID", "SiteID", "HoleID", "SensorID")
  MISS <- setdiff(COLS, intersect(names(data), names(index)))
  if (length(MISS) > 0L) {
    stop(sprintf("raw key columns missing: %s", paste(MISS, collapse = ", ")), call. = FALSE)
  }

  DataKey <- unique(data[, ..COLS])
  IndexKey <- unique(index[, ..COLS])
  BadKey <- DataKey[!IndexKey, on = COLS]
  if (nrow(BadKey) > 0L) {
    print(BadKey)
    stop("raw data has keys missing from raw index", call. = FALSE)
  }
}

.asChar <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  trimws(x)
}

.isMissing <- function(x) {
  toupper(.asChar(x)) %in% c("", "-", "NA", "N.A.", "N/A")
}

.asNum <- function(x, field) {
  x <- .asChar(x)
  OUT <- suppressWarnings(as.numeric(x))
  OUT[.isMissing(x = x)] <- NA_real_
  BAD <- is.na(OUT) & !.isMissing(x = x)
  if (any(BAD)) {
    Values <- unique(x[BAD])
    Values <- Values[seq_len(min(length(Values), 10L))]
    stop(
      sprintf(
        "non-numeric %s values: %s",
        field,
        paste(Values, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  OUT
}

.toDatetime <- function(date, time) {
  Date <- .asNum(x = date, field = "date")
  Time <- .asNum(x = time, field = "time")
  Time[is.na(Time)] <- 0
  as.POSIXct(
    x = Date * 86400 + round(Time * 86400),
    origin = "1899-12-30",
    tz = "UTC"
  )
}

.cleanRawData <- function(data) {
  COLS <- c(
    "ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
    "SourceRow", "index", "stage", "date", "time", "comment", "variable",
    "value", "units"
  )
  MISS <- setdiff(COLS, names(data))
  if (length(MISS) > 0L) {
    stop(sprintf("raw data columns missing: %s", paste(MISS, collapse = ", ")), call. = FALSE)
  }

  data[, `:=`(
    ID = .asChar(ID),
    SiteID = .asChar(SiteID),
    HoleID = .asChar(HoleID),
    SensorID = .asChar(SensorID),
    SourcePath = .asChar(SourcePath),
    SourceSheet = .asChar(SourceSheet),
    SourceRow = as.integer(SourceRow),
    index = .asChar(index),
    stage = .asChar(stage),
    comment = .asChar(comment),
    variable = .asChar(variable),
    value = .asNum(x = value, field = "value"),
    units = .asChar(units),
    datetime = .toDatetime(date = date, time = time)
  )]
  data[]
}

.checkVariables <- function(data, id, variables) {
  BadVariable <- setdiff(unique(data$variable), variables)
  if (length(BadVariable) > 0L) {
    stop(
      sprintf(
        "unsupported %s variables: %s",
        id,
        paste(BadVariable, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

.checkDuplicates <- function(data) {
  COLS <- c(
    "ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
    "SourceRow", "index", "stage", "date", "time", "comment", "variable"
  )
  DUP <- data[, .N, by = COLS][N > 1L]
  if (nrow(DUP) > 0L) {
    print(DUP)
    stop("duplicated variable in raw observation", call. = FALSE)
  }
}

.wideTable <- function(data) {
  COLS <- c(
    "ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
    "SourceRow", "index", "stage", "comment", "datetime"
  )
  Values <- data.table::dcast(
    data = data,
    formula = stats::as.formula(paste(paste(COLS, collapse = " + "), "~ variable")),
    value.var = "value"
  )
  Units <- data.table::dcast(
    data = data[, .(ID, SiteID, HoleID, SensorID, SourcePath, SourceSheet,
                    SourceRow, index, stage, comment, datetime,
                    variable = paste0("units.", variable), units)],
    formula = stats::as.formula(paste(paste(COLS, collapse = " + "), "~ variable")),
    value.var = "units"
  )
  if (nrow(Values[!Units, on = COLS]) > 0L || nrow(Units[!Values, on = COLS]) > 0L) {
    stop("value and unit keys do not match", call. = FALSE)
  }
  COLS.units <- setdiff(names(Units), COLS)
  Values[Units, on = COLS, (COLS.units) := mget(paste0("i.", COLS.units))]
  Wide <- Values
  data.table::setorder(
    x = Wide,
    ID, SiteID, HoleID, SensorID, datetime, SourcePath, SourceSheet, SourceRow
  )
  Wide[, RecordID := seq_len(.N)]
  Wide[]
}

.completeColumns <- function(data, cols) {
  MISS <- setdiff(cols, names(data))
  if (length(MISS) > 0L) {
    data[, (MISS) := lapply(X = MISS, FUN = function(x) NA)]
  }
  data.table::setcolorder(x = data, neworder = cols)
  data[, ..cols]
}

.dbSchema <- function() {
  list(
    PCG = list(
      variables = c("depth", "level", "head", "change"),
      data = c(
        "RecordID", "ID", "SiteID", "HoleID", "SensorID", "datetime",
        "index", "comment", "depth", "units.depth", "level", "units.level",
        "head", "units.head", "change", "units.change"
      )
    ),
    PCV = list(
      variables = c(
        "depth", "level", "head", "reading", "frequency", "temperature",
        "pressure"
      ),
      data = c(
        "RecordID", "ID", "SiteID", "HoleID", "SensorID", "datetime",
        "stage", "depth", "units.depth", "level", "units.level", "head",
        "units.head", "reading", "units.reading", "frequency",
        "units.frequency", "temperature", "units.temperature", "pressure",
        "units.pressure"
      )
    )
  )
}

.dbTables <- function(data, id, schema) {
  DATA <- data[ID == id]
  .checkVariables(data = DATA, id = id, variables = schema[[id]]$variables)
  .checkDuplicates(data = DATA)

  Wide <- .wideTable(data = DATA)
  IndexCols <- c(
    "RecordID", "ID", "SiteID", "HoleID", "SensorID", "datetime", "index",
    "stage", "SourcePath", "SourceSheet", "SourceRow"
  )
  list(
    data = .completeColumns(data = data.table::copy(Wide), cols = schema[[id]]$data),
    index = .completeColumns(data = data.table::copy(Wide), cols = IndexCols)
  )
}

.writeDB <- function(tables, db, id) {
  dir.create(path = db, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(x = tables$data, file = file.path(db, sprintf("%s.data.csv", id)))
  data.table::fwrite(x = tables$index, file = file.path(db, sprintf("%s.index.csv", id)))
}

.buildDBTables <- function(data, id, schema) {
  OUT <- lapply(X = id, FUN = function(ID) {
    .dbTables(data = data, id = ID, schema = schema)
  })
  names(OUT) <- id
  OUT
}

.writeDBTables <- function(tables, db) {
  invisible(lapply(X = names(tables), FUN = function(ID) {
    .writeDB(tables = tables[[ID]], db = db, id = ID)
  }))
}

.summarizeDBTables <- function(tables) {
  data.table::rbindlist(l = lapply(X = names(tables), FUN = function(ID) {
    data.table::data.table(
      ID = ID,
      RowsData = nrow(tables[[ID]]$data),
      RowsIndex = nrow(tables[[ID]]$index)
    )
  }), use.names = TRUE)
}

.gateRecord <- function(data, cause, disposition, detail) {
  data.table::data.table(
    ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    cause = cause,
    disposition = disposition,
    detail = detail,
    data
  )
}

.gateValues <- function(data) {
  Value <- .asChar(data$value)
  PASS <- .isMissing(Value) | !is.na(suppressWarnings(as.numeric(Value)))
  COMMA <- !PASS & grepl(pattern = "^-?[0-9]+,[0-9]+$", x = Value)
  BAD <- !PASS & !COMMA

  Records <- list()
  if (any(COMMA)) {
    Records[[length(Records) + 1L]] <- .gateRecord(
      data = data[COMMA],
      cause = "VALUE_COMMA_DECIMAL",
      disposition = "corrected",
      detail = sprintf(
        "value=%s; repaired=%s; inserted into db",
        Value[COMMA], sub(",", ".", Value[COMMA], fixed = TRUE)
      )
    )
    data[COMMA, value := sub(",", ".", .asChar(value), fixed = TRUE)]
  }
  if (any(BAD)) {
    Records[[length(Records) + 1L]] <- .gateRecord(
      data = data[BAD],
      cause = "VALUE_UNREADABLE",
      disposition = "rejected",
      detail = sprintf("value=%s; rejected", Value[BAD])
    )
    data <- data[!BAD]
  }
  list(data = data, records = Records)
}

.gatePCGKeys <- function(data, raw) {
  Inspection <- .readRawTable(raw = raw, id = "PCG", name = "index")
  COLS <- c("HoleID", "FileKey", "FileKeyOK", "SourcePath")
  if (!all(COLS %in% names(Inspection))) {
    return(list(data = data, records = list()))
  }
  BAD <- unique(Inspection[
    FileKeyOK == FALSE & nzchar(FileKey),
    .(SourcePath, HoleID, FileKey)
  ])
  if (nrow(BAD) == 0L) {
    return(list(data = data, records = list()))
  }

  Records <- list(.gateRecord(
    data = data[BAD[, .(SourcePath)], on = "SourcePath"],
    cause = "FILE_ID_CONFLICT",
    disposition = "corrected",
    detail = "HoleID repaired from systematic filename evidence"
  ))
  data[BAD, on = "SourcePath", HoleID := i.FileKey]
  list(data = data, records = Records)
}

.writeGateRecords <- function(records, audit, id) {
  DT <- data.table::rbindlist(l = records, use.names = TRUE)
  for (idOne in id) {
    FILE <- file.path(audit, sprintf("%s.reject.csv", idOne))
    AUX <- if (nrow(DT) > 0L) DT[ID == idOne] else DT
    if (nrow(AUX) > 0L) {
      dir.create(path = audit, recursive = TRUE, showWarnings = FALSE)
      data.table::fwrite(x = AUX, file = FILE)
    } else if (file.exists(FILE)) {
      invisible(file.remove(FILE))
    }
  }
  invisible(nrow(DT))
}

# Build-stage repair (taxonomy ruling 2026-08-16): the db stores the
# RECOMPUTED change (head - lag(head)); the typed value is preserved as
# evidence in the gate sink (cause CHANGE_INCONSISTENT, corrected).
.repairPCGChange <- function(tables, audit) {
  if (is.null(tables$PCG)) return(invisible(tables))
  DT <- tables$PCG$data
  COLS <- c("RecordID", "SiteID", "HoleID", "SensorID", "datetime", "head", "change")
  if (!all(COLS %in% names(DT))) return(invisible(tables))
  data.table::setorder(DT, SiteID, HoleID, SensorID, datetime, RecordID)
  DT[, recalc.change := head - data.table::shift(head),
    by = .(SiteID, HoleID, SensorID)]
  BAD <- DT[!is.na(change) & !is.na(recalc.change) &
    abs(change - recalc.change) > 1e-6]
  if (nrow(BAD) > 0L) {
    Records <- .gateRecord(
      data = BAD[, .(ID = "PCG", SiteID, HoleID, SensorID, datetime, RecordID)],
      cause = "CHANGE_INCONSISTENT",
      disposition = "corrected",
      detail = sprintf(
        "typed=%s; recomputed=%s; recomputed value stored",
        format(BAD$change), format(round(BAD$recalc.change, 6))
      )
    )
    FILE <- file.path(audit, "PCG.reject.csv")
    dir.create(path = audit, recursive = TRUE, showWarnings = FALSE)
    if (file.exists(FILE)) {
      OLD <- data.table::fread(FILE)
      Records <- data.table::rbindlist(
        l = list(OLD, Records), use.names = TRUE, fill = TRUE
      )
    }
    data.table::fwrite(x = Records, file = FILE)
    DT[BAD, on = "RecordID", change := recalc.change]
  }
  DT[, recalc.change := NULL]
  invisible(tables)
}

.gatePiezometers <- function(data, raw, audit, id) {
  Candidates <- nrow(data)
  Records <- list()

  if ("PCG" %in% id) {
    OUT <- .gatePCGKeys(data = data, raw = raw)
    data <- OUT$data
    Records <- c(Records, OUT$records)
  }
  OUT <- .gateValues(data = data)
  data <- OUT$data
  Records <- c(Records, OUT$records)

  Rejected <- sum(vapply(
    X = Records,
    FUN = function(x) nrow(x[cause == "VALUE_UNREADABLE"]),
    FUN.VALUE = integer(1)
  ))
  if (Candidates != nrow(data) + Rejected) {
    stop("gate conservation failed: candidates != accepted + rejected", call. = FALSE)
  }

  .writeGateRecords(records = Records, audit = audit, id = id)
  data
}
