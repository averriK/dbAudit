## R/inclinometerParse.R
## Inclinometer CSV parser, migrated verbatim from AR-S2L1X
## scripts/parser/parseINC.R (engine consolidation; the application
## repository imports parseINC from this namespace). No declared
## adaptations: the parser reads the client CSV export format described by
## the INC block of the parser manifest.

parseINC <- function(path, manifest = NULL) {
  PATH.source <- path
  .checkINCSourceFormats(path = PATH.source)
  Config <- .incStructure(manifest = manifest)
  FILES <- listSourceFiles(path = PATH.source, pattern = "[.]csv$")

  LIST <- lapply(X = FILES, FUN = function(file) {
    .parseINCFile(file = file, root = PATH.source, config = Config)
  })

  list(
    data = .bindParserTable(x = LIST, name = "data"),
    index = .bindParserTable(x = LIST, name = "index")
  )
}

.checkINCSourceFormats <- function(path) {
  FILES <- listSourceFiles(path = path, pattern = "[.](gkn|dux)$")
  if (length(FILES) == 0L) {
    return(invisible(TRUE))
  }
  Names <- basename(FILES)
  Names <- Names[seq_len(min(length(Names), 5L))]
  stop(
    sprintf(
      "unsupported native inclinometer files (%d .gkn/.dux): %s; parseINC reads CSV exports only",
      length(FILES),
      paste(Names, collapse = ", ")
    ),
    call. = FALSE
  )
}

.incStructure <- function(manifest = NULL) {
  Config <- manifest$INC$structure
  if (is.null(Config)) {
    Config <- list(
      heading = "Headings",
      blocks = list(
        Installation = "Installation v1",
        Survey = "Survey v2"
      ),
      dataHeader = c("Depth", "A0", "A180", "B0", "B180")
    )
  }
  Config$heading <- unlist(x = Config$heading, use.names = FALSE)
  Config$blocks <- lapply(X = Config$blocks, FUN = unlist, use.names = FALSE)
  Config$dataHeader <- unlist(x = Config$dataHeader, use.names = FALSE)
  Config
}

.parseINCFile <- function(file, root, config) {
  Lines <- readLines(con = file, warn = FALSE)
  Parts <- strsplit(x = Lines, split = ";", fixed = TRUE)
  First <- vapply(X = Parts, FUN = function(x) x[1L], FUN.VALUE = character(1))
  PathParts <- .relativeParts(file = file, root = root)
  SiteID <- PathParts[1L]
  HoleID <- if (length(PathParts) >= 2L) PathParts[2L] else ""
  Key <- data.table::data.table(
    ID = "INC",
    SiteID = SiteID,
    HoleID = HoleID,
    SensorID = "0",
    SourcePath = file,
    SourceSheet = ""
  )
  HeadingRows <- which(x = First %in% config$heading)
  DepthRow <- .incDataHeaderRow(parts = Parts, header = config$dataHeader)
  Check <- .checkINCFile(
    parts = Parts,
    headingRows = HeadingRows,
    depthRow = DepthRow,
    config = config
  )

  list(
    data = .parseINCData(
      parts = Parts,
      key = Key,
      depthRow = DepthRow,
      header = config$dataHeader
    ),
    index = data.table::rbindlist(
      l = list(
        .parseINCHeaders(parts = Parts, key = Key, headingRows = HeadingRows),
        .parseINCChecks(key = Key, check = Check, depthRow = DepthRow)
      ),
      use.names = TRUE
    )
  )
}

.incDataHeaderRow <- function(parts, header) {
  Text <- vapply(X = parts, FUN = paste, FUN.VALUE = character(1), collapse = "\r")
  IDX <- which(x = Text == paste(header, collapse = "\r"))
  if (!length(IDX)) return(NA_integer_)
  IDX[1L]
}

.checkINCFile <- function(parts, headingRows, depthRow, config) {
  OK.install <- length(headingRows) >= 1L &&
    headingRows[1L] < length(parts) &&
    parts[[headingRows[1L] + 1L]][1L] %in% config$blocks$Installation
  OK.survey <- length(headingRows) >= 2L &&
    headingRows[2L] < length(parts) &&
    parts[[headingRows[2L] + 1L]][1L] %in% config$blocks$Survey
  OK.data <- !is.na(depthRow) && identical(parts[[depthRow]], config$dataHeader)

  data.table::data.table(
    InstallationHeaderOK = OK.install,
    SurveyHeaderOK = OK.survey,
    DataHeaderOK = OK.data,
    DataRows = if (is.na(depthRow)) 0L else length(parts) - depthRow
  )
}

.parseINCHeaders <- function(parts, key, headingRows) {
  if (length(headingRows) == 0L) return(.emptyINCIndex())

  OUT <- data.table::rbindlist(l = lapply(X = headingRows, FUN = function(i) {
    Labels <- parts[[i]]
    Values <- parts[[i + 1L]]
    length(Values) <- length(Labels)
    Values[is.na(Values)] <- ""
    data.table::data.table(
      SourceRow = i + 1L,
      RawBlock = Values[1L],
      RawLabel = Labels[-1L],
      RawValue = Values[-1L]
    )
  }), use.names = TRUE)
  OUT[, `:=`(
    ID = key$ID,
    SiteID = key$SiteID,
    HoleID = key$HoleID,
    SensorID = key$SensorID,
    SourcePath = key$SourcePath,
    SourceSheet = key$SourceSheet,
    InstallationHeaderOK = NA,
    SurveyHeaderOK = NA,
    DataHeaderOK = NA,
    DataRows = NA_integer_
  )]
  .completeINCIndex(DT = OUT)
}

.parseINCChecks <- function(key, check, depthRow) {
  OUT <- data.table::data.table(
    ID = key$ID,
    SiteID = key$SiteID,
    HoleID = key$HoleID,
    SensorID = key$SensorID,
    SourcePath = key$SourcePath,
    SourceSheet = key$SourceSheet,
    SourceRow = depthRow,
    RawBlock = "ParserCheck",
    RawLabel = "INC.csv",
    RawValue = "",
    InstallationHeaderOK = check$InstallationHeaderOK,
    SurveyHeaderOK = check$SurveyHeaderOK,
    DataHeaderOK = check$DataHeaderOK,
    DataRows = check$DataRows
  )
  .completeINCIndex(DT = OUT)
}

.parseINCData <- function(parts, key, depthRow, header) {
  if (is.na(depthRow)) return(.emptyINCData())

  DATA <- data.table::rbindlist(
    l = lapply(X = seq.int(from = depthRow + 1L, to = length(parts)), FUN = function(i) {
      Values <- parts[[i]]
      length(Values) <- 5L
      Values[is.na(Values)] <- ""
      data.table::as.data.table(as.list(Values))[, SourceRow := i]
    }),
    use.names = TRUE
  )
  data.table::setnames(
    x = DATA,
    old = names(DATA)[seq_len(5L)],
    new = header
  )
  DATA[, `:=`(
    ID = key$ID,
    SiteID = key$SiteID,
    HoleID = key$HoleID,
    SensorID = key$SensorID,
    SourcePath = key$SourcePath,
    SourceSheet = key$SourceSheet
  )]
  .completeINCData(DT = DATA)
}

.emptyINCData <- function() {
  data.table::data.table(
    ID = character(),
    SiteID = character(),
    HoleID = character(),
    SensorID = character(),
    SourcePath = character(),
    SourceSheet = character(),
    SourceRow = integer(),
    Depth = character(),
    A0 = character(),
    A180 = character(),
    B0 = character(),
    B180 = character()
  )
}

.completeINCData <- function(DT) {
  COLS <- names(.emptyINCData())
  MISS <- setdiff(COLS, names(DT))
  if (length(MISS) > 0L) {
    DT[, (MISS) := lapply(X = MISS, FUN = function(x) character())]
  }
  data.table::setcolorder(x = DT, neworder = COLS)
  DT[, ..COLS]
}

.emptyINCIndex <- function() {
  data.table::data.table(
    ID = character(),
    SiteID = character(),
    HoleID = character(),
    SensorID = character(),
    SourcePath = character(),
    SourceSheet = character(),
    SourceRow = integer(),
    RawBlock = character(),
    RawLabel = character(),
    RawValue = character(),
    InstallationHeaderOK = logical(),
    SurveyHeaderOK = logical(),
    DataHeaderOK = logical(),
    DataRows = integer()
  )
}

.completeINCIndex <- function(DT) {
  COLS <- names(.emptyINCIndex())
  MISS <- setdiff(COLS, names(DT))
  if (length(MISS) > 0L) {
    DT[, (MISS) := lapply(X = MISS, FUN = function(x) NA)]
  }
  data.table::setcolorder(x = DT, neworder = COLS)
  DT[, ..COLS]
}
