## R/piezometerParse.R
## Piezometer pipeline, migrated verbatim from AR-S2L1X scripts/parser/{utils,parsePCG,parsePCV}.R and scripts/runParse.R
## (stage-1 migration; the application repository remains the producer of
## record until the switch-over). Declared adaptations only: the shared
## dbAudit logger replaces the local one, and inclinometer branches are out
## of scope for auditPiezometer().


loadParserManifest <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("manifest not found: %s", path), call. = FALSE)
  }
  jsonlite::fromJSON(txt = path, simplifyVector = FALSE)
}

normalizeLabel <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  x <- tolower(x)
  x <- gsub(pattern = "[[:space:]]+", replacement = " ", x = x)
  x <- gsub(pattern = "^[[:space:]]+|[[:space:]]+$", replacement = "", x = x)
  x <- gsub(pattern = "[[:space:]]*:[[:space:]]*$", replacement = "", x = x)
  x
}

normalizeHoleID <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- trimws(gsub(pattern = "[[:space:]]+", replacement = " ", x = x))
  x <- gsub(pattern = "[[:space:]/]+", replacement = "_", x = x)
  x <- gsub(pattern = "_+", replacement = "_", x = x)
  gsub(pattern = "^_|_$", replacement = "", x = x)
}

readExcelCells <- function(path, sheet) {
  DT <- suppressMessages(readxl::read_excel(
    path = path,
    sheet = sheet,
    col_names = FALSE,
    col_types = "text",
    .name_repair = "minimal"
  ))
  as.matrix(x = as.data.frame(
    x = lapply(X = DT, FUN = function(x) {
      x <- as.character(x)
      x[is.na(x)] <- ""
      trimws(gsub(pattern = "[[:space:]]+", replacement = " ", x = x))
    }),
    stringsAsFactors = FALSE
  ))
}

matchGridFields <- function(cells, aliases) {
  Norm <- matrix(
    data = normalizeLabel(x = cells),
    nrow = nrow(cells),
    ncol = ncol(cells)
  )
  LIST <- list()

  for (Field in names(aliases)) {
    Pattern <- normalizeLabel(x = unlist(x = aliases[[Field]], use.names = FALSE))
    OK <- matrix(
      data = Norm %in% Pattern,
      nrow = nrow(Norm),
      ncol = ncol(Norm)
    )
    IDX <- which(x = OK, arr.ind = TRUE)
    if (nrow(IDX) == 0L) next

    LIST[[length(LIST) + 1L]] <- data.table::data.table(
      Field = Field,
      RawLabel = cells[IDX],
      SourceRow = IDX[, 1],
      SourceCol = IDX[, 2]
    )
  }

  if (length(LIST) == 0L) {
    return(data.table::data.table(
      Field = character(),
      RawLabel = character(),
      SourceRow = integer(),
      SourceCol = integer()
    ))
  }

  data.table::rbindlist(l = LIST, use.names = TRUE)
}

.tableAliases <- function(config, table, slot) {
  Source <- config$tables[[table]][[slot]]
  LIST <- lapply(X = names(Source), FUN = function(Field) {
    if (identical(slot, "variables")) {
      return(Source[[Field]]$labels)
    }
    Source[[Field]]
  })
  names(LIST) <- names(Source)
  LIST
}

.tableVariables <- function(config, table) {
  Source <- config$tables[[table]]$variables
  data.table::data.table(
    variable = names(Source),
    units = vapply(
      X = Source,
      FUN = function(x) {
        Units <- x$units
        if (is.null(Units) || length(Units) == 0L) return("")
        Units
      },
      FUN.VALUE = character(1)
    )
  )
}

.tableMatchAliases <- function(config, table) {
  c(
    .tableAliases(config = config, table = table, slot = "columns"),
    .tableAliases(config = config, table = table, slot = "variables")
  )
}

.cleanUnits <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- trimws(x)
  x <- gsub(pattern = "^[(]", replacement = "", x = x)
  x <- gsub(pattern = "[)]$", replacement = "", x = x)
  trimws(x)
}

.emptyPiezometerTable <- function() {
  data.table::data.table(
    ID = character(),
    SiteID = character(),
    HoleID = character(),
    SensorID = character(),
    SourcePath = character(),
    SourceSheet = character(),
    SourceRow = integer(),
    index = character(),
    stage = character(),
    date = character(),
    time = character(),
    comment = character(),
    variable = character(),
    value = character(),
    units = character()
  )
}

.completePiezometerColumns <- function(DT) {
  COLS <- names(.emptyPiezometerTable())
  MISS <- setdiff(COLS, names(DT))
  if (length(MISS) > 0L) {
    DT[, (MISS) := lapply(X = MISS, FUN = function(x) character())]
  }
  data.table::setcolorder(x = DT, neworder = COLS)
  DT[]
}

.emptyHeaderTable <- function() {
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

.bindParserTable <- function(x, name) {
  data.table::rbindlist(
    l = lapply(X = x, FUN = function(y) y[[name]]),
    use.names = TRUE
  )
}

extractRightValue <- function(cells, row, col, maxOffset = 4L) {
  if (col >= ncol(cells)) return("")
  Stop <- min(ncol(cells), col + maxOffset)
  Values <- cells[row, (col + 1L):Stop]
  Values <- Values[nzchar(Values)]
  if (length(Values) == 0L) return("")
  Values[1L]
}

siteFromPath <- function(path, root) {
  Rel <- sub(
    pattern = paste0("^", normalizePath(path = root, mustWork = TRUE), "/?"),
    replacement = "",
    x = normalizePath(path = path, mustWork = TRUE)
  )
  strsplit(x = Rel, split = "/", fixed = TRUE)[[1L]][1L]
}

listSourceFiles <- function(path, pattern) {
  if (!dir.exists(path)) {
    stop(sprintf("path not found: %s", path), call. = FALSE)
  }
  FILES <- sort(list.files(
    path = path,
    pattern = pattern,
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  ))
  FILES[!grepl(pattern = "^~[$]", x = basename(FILES))]
}

.pcgFileKey <- function(path) {
  sub(
    pattern = "_(Dep|Patio|Zona).*$",
    replacement = "",
    x = tools::file_path_sans_ext(basename(path))
  )
}

.holeFromPCVFile <- function(file) {
  sub(
    pattern = "^.* CV-",
    replacement = "",
    x = tools::file_path_sans_ext(basename(file))
  )
}

.pcvSheetKey <- function(sheet, holeID) {
  Prefix <- sub(pattern = " [(].*$", replacement = "", x = sheet)
  Gate <- paste0(holeID, "-")
  if (!startsWith(x = Prefix, prefix = Gate)) {
    return(list(HoleID = holeID, SensorID = "0"))
  }

  SensorID <- sub(pattern = Gate, replacement = "", x = Prefix, fixed = TRUE)
  if (!nzchar(SensorID)) SensorID <- "0"
  list(HoleID = holeID, SensorID = SensorID)
}

.relativeParts <- function(file, root) {
  Rel <- sub(
    pattern = paste0("^", normalizePath(path = root, mustWork = TRUE), "/?"),
    replacement = "",
    x = normalizePath(path = file, mustWork = TRUE)
  )
  strsplit(x = Rel, split = "/", fixed = TRUE)[[1L]]
}

parsePCG <- function(path, manifest) {
  PATH.source <- path
  Config <- manifest$PCG
  FILES <- listSourceFiles(path = PATH.source, pattern = "[.]xlsx$")

  LIST <- lapply(X = FILES, FUN = function(file) {
    .parsePCGFile(file = file, root = PATH.source, config = Config)
  })

  list(
    inspection = .bindParserTable(x = LIST, name = "inspection"),
    headers = .bindParserTable(x = LIST, name = "headers"),
    hydraulic = .bindParserTable(x = LIST, name = "hydraulic"),
    instrument = .emptyPiezometerTable()
  )
}

.parsePCGFile <- function(file, root, config) {
  Sheets <- readxl::excel_sheets(path = file)
  SiteID <- siteFromPath(path = file, root = root)

  LIST <- lapply(X = Sheets, FUN = function(sheet) {
    Cells <- readExcelCells(path = file, sheet = sheet)
    HeaderMatches <- matchGridFields(cells = Cells, aliases = config$headers)
    DataMatches <- matchGridFields(
      cells = Cells,
      aliases = .tableMatchAliases(config = config, table = "hydraulic")
    )

    Required <- c("date", "time")
    IsDataSheet <- all(Required %in% DataMatches$Field) &&
      "HoleID" %in% HeaderMatches$Field

    Header <- .parsePCGHeader(
      file = file,
      sheet = sheet,
      siteID = SiteID,
      cells = Cells,
      headerMatches = HeaderMatches
    )
    Key <- .pcgKey(header = Header, path = file)
    if (nrow(Header) > 0L) {
      Header[, `:=`(
        ID = Key$ID,
        HoleID = Key$HoleID,
        SensorID = Key$SensorID
      )]
      data.table::setcolorder(
        x = Header,
        neworder = c(
          "ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
          "Field", "RawLabel", "RawValue", "SourceRow", "SourceCol"
        )
      )
    }
    Hydraulic <- if (isTRUE(IsDataSheet)) {
      .parsePCGHydraulic(
        file = file,
        sheet = sheet,
        siteID = SiteID,
        key = Key,
        cells = Cells,
        dataMatches = DataMatches,
        config = config
      )
    } else {
      .emptyPiezometerTable()
    }

    list(
      inspection = data.table::data.table(
        ID = Key$ID,
        SiteID = SiteID,
        HoleID = Key$HoleID,
        SensorID = Key$SensorID,
        RawHoleID = Key$RawHoleID,
        FileKey = Key$FileKey,
        FileKeyOK = Key$FileKeyOK,
        SourcePath = file,
        SourceSheet = sheet,
        HeaderMatches = data.table::uniqueN(HeaderMatches$Field),
        DataMatches = data.table::uniqueN(DataMatches$Field),
        IsDataSheet = IsDataSheet
      ),
      headers = Header,
      hydraulic = Hydraulic
    )
  })

  list(
    inspection = .bindParserTable(x = LIST, name = "inspection"),
    headers = .bindParserTable(x = LIST, name = "headers"),
    hydraulic = .bindParserTable(x = LIST, name = "hydraulic")
  )
}

.pcgKey <- function(header, path) {
  RawHoleID <- header[Field == "HoleID", RawValue][1L]
  if (length(RawHoleID) == 0L || is.na(RawHoleID)) RawHoleID <- ""
  FileKey <- .pcgFileKey(path = path)
  HoleID <- normalizeHoleID(x = RawHoleID)

  data.table::data.table(
    ID = "PCG",
    HoleID = HoleID,
    SensorID = "0",
    RawHoleID = RawHoleID,
    FileKey = FileKey,
    FileKeyOK = if (nzchar(HoleID)) identical(HoleID, FileKey) else NA
  )
}

.parsePCGHeader <- function(file, sheet, siteID, cells, headerMatches) {
  if (nrow(headerMatches) == 0L) return(.emptyHeaderTable())

  headerMatches[, .SD[1L], by = Field][, .(
    SourcePath = file,
    SourceSheet = sheet,
    SiteID = siteID,
    Field,
    RawLabel,
    RawValue = mapply(
      FUN = function(row, col) {
        extractRightValue(cells = cells, row = row, col = col)
      },
      row = SourceRow,
      col = SourceCol,
      USE.NAMES = FALSE
    ),
    SourceRow,
    SourceCol
  )]
}

.parsePCGHydraulic <- function(file, sheet, siteID, key, cells, dataMatches, config) {
  if (nrow(dataMatches) == 0L) return(.emptyPiezometerTable())

  TimeRow <- dataMatches[Field == "time", SourceRow][1L]
  if (is.na(TimeRow)) return(.emptyPiezometerTable())

  HeaderRows <- c(TimeRow - 1L, TimeRow)
  Header <- dataMatches[SourceRow %in% HeaderRows, .SD[1L], by = Field]
  StartRow <- max(Header[Field %in% c("date", "time"), SourceRow]) + 1L
  if (StartRow > nrow(cells)) return(.emptyPiezometerTable())
  Rows <- seq.int(from = StartRow, to = nrow(cells))
  DATA <- data.table::as.data.table(cells[Rows, Header$SourceCol, drop = FALSE])
  data.table::setnames(x = DATA, old = names(DATA), new = Header$Field)
  DATA[, `:=`(
    ID = key$ID,
    SiteID = siteID,
    HoleID = key$HoleID,
    SensorID = key$SensorID,
    SourcePath = file,
    SourceSheet = sheet,
    SourceRow = Rows
  )]
  DATA <- DATA[nzchar(date) | nzchar(time)]
  if (nrow(DATA) == 0L) return(.emptyPiezometerTable())

  for (Col in setdiff(c("index", "stage", "date", "time", "comment"), names(DATA))) {
    DATA[, (Col) := ""]
  }

  Variables <- .tableVariables(config = config, table = "hydraulic")
  OUT <- data.table::rbindlist(l = lapply(X = Variables$variable, FUN = function(Var) {
    if (!Var %in% names(DATA)) return(.emptyPiezometerTable())
    OK <- nzchar(DATA[[Var]])
    if (!any(OK)) return(.emptyPiezometerTable())
    DATA[OK, .(
      ID, SiteID, HoleID, SensorID, SourcePath, SourceSheet, SourceRow,
      index, stage, date, time, comment,
      variable = Var,
      value = get(Var),
      units = Variables[variable == Var, units][1L]
    )]
  }), use.names = TRUE)

  .completePiezometerColumns(DT = OUT)
}

parsePCV <- function(path, manifest) {
  PATH.source <- path
  Config <- manifest$PCV
  FILES <- listSourceFiles(path = PATH.source, pattern = "[.]xlsx$")

  LIST <- lapply(X = FILES, FUN = function(file) {
    .parsePCVFile(file = file, root = PATH.source, config = Config)
  })

  list(
    inspection = .bindParserTable(x = LIST, name = "inspection"),
    headers = .bindParserTable(x = LIST, name = "headers"),
    hydraulic = .bindParserTable(x = LIST, name = "hydraulic"),
    instrument = .bindParserTable(x = LIST, name = "instrument")
  )
}

.parsePCVFile <- function(file, root, config) {
  SiteID <- siteFromPath(path = file, root = root)
  FileHoleID <- .holeFromPCVFile(file = file)
  Sheets <- readxl::excel_sheets(path = file)

  LIST <- lapply(X = Sheets, FUN = function(sheet) {
    Cells <- readExcelCells(path = file, sheet = sheet)
    HeaderMatches <- matchGridFields(cells = Cells, aliases = config$headers)
    HydraulicMatches <- matchGridFields(
      cells = Cells,
      aliases = .tableMatchAliases(config = config, table = "hydraulic")
    )
    InstrumentMatches <- matchGridFields(
      cells = Cells,
      aliases = .tableMatchAliases(config = config, table = "instrument")
    )

    Header <- .parsePCVHeader(
      file = file,
      sheet = sheet,
      siteID = SiteID,
      cells = Cells,
      headerMatches = HeaderMatches
    )
    Key <- .pcvKey(header = Header, sheet = sheet, holeID = FileHoleID)
    if (nrow(Header) > 0L) {
      Header[, `:=`(
        ID = Key$ID,
        HoleID = Key$HoleID,
        SensorID = Key$SensorID
      )]
      data.table::setcolorder(
        x = Header,
        neworder = c(
          "ID", "SiteID", "HoleID", "SensorID", "SourcePath", "SourceSheet",
          "Field", "RawLabel", "RawValue", "SourceRow", "SourceCol"
        )
      )
    }

    Hydraulic <- .parsePCVTable(
      file = file,
      sheet = sheet,
      siteID = SiteID,
      key = Key,
      cells = Cells,
      matches = HydraulicMatches,
      config = config,
      table = "hydraulic"
    )
    Instrument <- .parsePCVTable(
      file = file,
      sheet = sheet,
      siteID = SiteID,
      key = Key,
      cells = Cells,
      matches = InstrumentMatches,
      config = config,
      table = "instrument"
    )

    list(
      inspection = data.table::data.table(
        ID = Key$ID,
        SiteID = SiteID,
        HoleID = Key$HoleID,
        SensorID = Key$SensorID,
        RawHoleID = Key$RawHoleID,
        SourcePath = file,
        SourceSheet = sheet,
        HeaderMatches = data.table::uniqueN(HeaderMatches$Field),
        HydraulicMatches = data.table::uniqueN(HydraulicMatches$Field),
        InstrumentMatches = data.table::uniqueN(InstrumentMatches$Field),
        IsDataSheet = nrow(Hydraulic) > 0L || nrow(Instrument) > 0L
      ),
      headers = Header,
      hydraulic = Hydraulic,
      instrument = Instrument
    )
  })

  list(
    inspection = .bindParserTable(x = LIST, name = "inspection"),
    headers = .bindParserTable(x = LIST, name = "headers"),
    hydraulic = .bindParserTable(x = LIST, name = "hydraulic"),
    instrument = .bindParserTable(x = LIST, name = "instrument")
  )
}

.pcvKey <- function(header, sheet, holeID) {
  Key <- .pcvSheetKey(sheet = sheet, holeID = holeID)
  RawHoleID <- header[Field == "HoleID", RawValue][1L]
  if (length(RawHoleID) == 0L || is.na(RawHoleID) || !nzchar(RawHoleID)) {
    RawHoleID <- Key$HoleID
  }
  HoleID <- normalizeHoleID(x = RawHoleID)
  if (!nzchar(HoleID)) HoleID <- Key$HoleID

  data.table::data.table(
    ID = "PCV",
    HoleID = HoleID,
    SensorID = Key$SensorID,
    RawHoleID = RawHoleID
  )
}

.parsePCVHeader <- function(file, sheet, siteID, cells, headerMatches) {
  if (nrow(headerMatches) == 0L) return(.emptyHeaderTable())

  headerMatches[, .SD[1L], by = Field][, .(
    SourcePath = file,
    SourceSheet = sheet,
    SiteID = siteID,
    Field,
    RawLabel,
    RawValue = mapply(
      FUN = function(row, col, label, field) {
        .extractPCVHeaderValue(
          cells = cells,
          row = row,
          col = col,
          label = label,
          field = field
        )
      },
      row = SourceRow,
      col = SourceCol,
      label = RawLabel,
      field = Field,
      USE.NAMES = FALSE
    ),
    SourceRow,
    SourceCol
  )]
}

.extractPCVHeaderValue <- function(cells, row, col, label, field) {
  if (identical(field, "HoleID") && row < nrow(cells)) {
    Value <- cells[row + 1L, col]
    if (nzchar(Value)) return(Value)
  }

  if (grepl(pattern = ":[[:space:]]*$", x = label)) {
    Value <- extractRightValue(cells = cells, row = row, col = col)
    if (nzchar(Value)) return(Value)
  }

  Stop <- min(nrow(cells), row + 3L)
  Values <- cells[(row + 1L):Stop, col]
  Values <- Values[nzchar(Values)]
  Values <- Values[!grepl(pattern = "^[(].*[)]$", x = Values)]
  if (length(Values) > 0L) return(Values[1L])

  extractRightValue(cells = cells, row = row, col = col)
}

.parsePCVTable <- function(file, sheet, siteID, key, cells, matches, config, table) {
  if (nrow(matches) == 0L) return(.emptyPiezometerTable())

  DateRow <- matches[Field == "date", SourceRow][1L]
  if (is.na(DateRow)) return(.emptyPiezometerTable())

  Header <- matches[SourceRow == DateRow, .SD[1L], by = Field]
  Variables <- .tableVariables(config = config, table = table)
  if (!any(Variables$variable %in% Header$Field)) return(.emptyPiezometerTable())

  UnitRow <- DateRow + 1L
  if (DateRow + 2L > nrow(cells)) return(.emptyPiezometerTable())
  Rows <- seq.int(from = DateRow + 2L, to = nrow(cells))
  DATA <- data.table::as.data.table(cells[Rows, Header$SourceCol, drop = FALSE])
  data.table::setnames(x = DATA, old = names(DATA), new = Header$Field)
  DATA[, `:=`(
    ID = key$ID,
    SiteID = siteID,
    HoleID = key$HoleID,
    SensorID = key$SensorID,
    SourcePath = file,
    SourceSheet = sheet,
    SourceRow = Rows
  )]

  for (Col in setdiff(c("index", "stage", "date", "time", "comment"), names(DATA))) {
    DATA[, (Col) := ""]
  }
  DATA <- DATA[nzchar(date) | nzchar(stage)]
  if (nrow(DATA) == 0L) return(.emptyPiezometerTable())

  OUT <- data.table::rbindlist(l = lapply(X = Variables$variable, FUN = function(Var) {
    if (!Var %in% names(DATA)) return(.emptyPiezometerTable())
    OK <- nzchar(DATA[[Var]])
    if (!any(OK)) return(.emptyPiezometerTable())

    Units <- Variables[variable == Var, units][1L]
    if (!nzchar(Units)) {
      Units <- .cleanUnits(x = cells[UnitRow, Header[Field == Var, SourceCol][1L]])
    }

    DATA[OK, .(
      ID, SiteID, HoleID, SensorID, SourcePath, SourceSheet, SourceRow,
      index, stage, date, time, comment,
      variable = Var,
      value = get(Var),
      units = Units
    )]
  }), use.names = TRUE)

  .completePiezometerColumns(DT = OUT)
}

.parseAll <- function(source, manifest, id) {
  OUT <- list()
  if ("PCG" %in% id) {
    OUT$PCG <- parsePCG(path = file.path(source, "PCG"), manifest = manifest)
  }
  if ("PCV" %in% id) {
    OUT$PCV <- parsePCV(path = file.path(source, "PCV"), manifest = manifest)
  }
  OUT
}

.writeParseOutput <- function(x, raw) {
  invisible(lapply(X = names(x), FUN = function(id) {
    DATA <- if (identical(id, "INC")) {
      x[[id]]$data
    } else {
      data.table::rbindlist(
        l = list(x[[id]]$hydraulic, x[[id]]$instrument),
        use.names = TRUE
      )
    }
    INDEX <- if (identical(id, "INC")) x[[id]]$index else x[[id]]$inspection
    HEADER <- if ("headers" %in% names(x[[id]])) x[[id]]$headers else NULL
    .writeRawTables(data = DATA, index = INDEX, raw = raw, header = HEADER)
  }))
}

.writeRawTables <- function(data, index, raw, header = NULL) {
  BAD <- data[
    !nzchar(ID) |
      !nzchar(SiteID) |
      !nzchar(HoleID) |
      !nzchar(SensorID)
  ]
  if (nrow(BAD) > 0L) {
    stop("parsed data has incomplete keys", call. = FALSE)
  }

  Keys <- unique(data.table::rbindlist(
    l = list(
      data[, .(ID, SiteID, HoleID, SensorID)],
      index[, .(ID, SiteID, HoleID, SensorID)]
    ),
    use.names = TRUE
  ))
  Keys <- Keys[nzchar(ID) & nzchar(SiteID) & nzchar(HoleID) & nzchar(SensorID)]
  data.table::setorder(Keys, ID, SiteID, HoleID, SensorID)

  invisible(lapply(X = seq_len(nrow(Keys)), FUN = function(i) {
    Key <- Keys[i]
    PATH <- file.path(raw, Key$ID, Key$SiteID, Key$HoleID, Key$SensorID)
    dir.create(path = PATH, recursive = TRUE, showWarnings = FALSE)
    data.table::fwrite(
      x = data[
        ID == Key$ID &
          SiteID == Key$SiteID &
          HoleID == Key$HoleID &
          SensorID == Key$SensorID
      ],
      file = file.path(PATH, "data.csv")
    )
    data.table::fwrite(
      x = index[
        ID == Key$ID &
          SiteID == Key$SiteID &
          HoleID == Key$HoleID &
          SensorID == Key$SensorID
      ],
      file = file.path(PATH, "index.csv")
    )
    if (!is.null(header) && nrow(header) > 0L) {
      data.table::fwrite(
        x = header[
          ID == Key$ID &
            SiteID == Key$SiteID &
            HoleID == Key$HoleID &
            SensorID == Key$SensorID
        ],
        file = file.path(PATH, "header.csv")
      )
    }
  }))
}

.summarizeParseOutput <- function(x) {
  data.table::rbindlist(l = lapply(X = names(x), FUN = function(id) {
    data.table::data.table(
      ID = id,
      Object = names(x[[id]]),
      Rows = vapply(X = x[[id]], FUN = nrow, FUN.VALUE = integer(1)),
      Cols = vapply(X = x[[id]], FUN = ncol, FUN.VALUE = integer(1))
    )
  }), use.names = TRUE)
}
