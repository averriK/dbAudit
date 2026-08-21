## R/inclinometerBuild.R
## Inclinometer raw-to-database build, migrated verbatim from el proyecto de monitoreo downstream
## scripts/runData.R (engine consolidation; the application repository
## imports .incTables from this namespace).
##
## INC raw is wide (one row per depth reading, columns Depth/A0/A180/B0/B180)
## and its survey constants live in index.csv as RawBlock/RawLabel/RawValue
## evidence, so it does not pass through the long variable/value/units
## piezometer machinery. Contract: el proyecto de monitoreo downstream dev/SoT/PLAN-INC-data-contract.md.

.incDatetime <- function(x, field = "Survey DateTime") {
  Value <- trimws(as.character(x))
  OUT <- as.POSIXct(x = Value, format = "%d/%m/%Y %H:%M:%S", tz = "UTC")
  BAD <- is.na(OUT)
  if (any(BAD)) {
    Values <- unique(Value[BAD])
    Values <- Values[seq_len(min(length(Values), 10L))]
    stop(
      sprintf("unparseable %s values: %s", field, paste(Values, collapse = ", ")),
      call. = FALSE
    )
  }
  OUT
}

.incSurveys <- function(index) {
  DT <- index[RawLabel == "Survey DateTime"]
  AUX <- DT[, .N, by = .(SourcePath)][N > 1L]
  if (nrow(AUX) > 0L) {
    print(AUX)
    stop("multiple Survey DateTime rows in one INC source file", call. = FALSE)
  }
  MISS <- setdiff(unique(index$SourcePath), DT$SourcePath)
  if (length(MISS) > 0L) {
    MISS <- basename(MISS[seq_len(min(length(MISS), 5L))])
    stop(
      sprintf("INC source files without Survey DateTime: %s", paste(MISS, collapse = ", ")),
      call. = FALSE
    )
  }
  Surveys <- DT[, .(
    ID, SiteID, HoleID, SensorID, SourcePath,
    datetime = .incDatetime(x = RawValue)
  )]
  Surveys[, SurveyID := sprintf(
    "%s@%s", HoleID, format(datetime, format = "%Y%m%dT%H%M%S", tz = "UTC")
  )]
  Surveys[]
}

.incSurveyContent <- function(data, index, path) {
  list(
    readings = data[SourcePath == path, .(Depth, A0, A180, B0, B180)],
    headers = index[
      SourcePath == path & RawBlock != "ParserCheck",
      .(RawBlock, RawLabel, RawValue)
    ]
  )
}

.dedupINCSurveys <- function(data, index, surveys) {
  AUX <- surveys[, .N, by = .(SurveyID)][N > 1L]
  Dropped <- character(0)
  for (surveyID in AUX$SurveyID) {
    Paths <- sort(surveys[SurveyID == surveyID, SourcePath])
    Content <- lapply(X = Paths, FUN = function(path) {
      .incSurveyContent(data = data, index = index, path = path)
    })
    OK <- vapply(
      X = Content[-1L],
      FUN = function(x) identical(x, Content[[1L]]),
      FUN.VALUE = logical(1)
    )
    if (!all(OK)) {
      stop(
        sprintf(
          "INC surveys share SurveyID %s but differ in content: %s",
          surveyID,
          paste(basename(Paths), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    Dropped <- c(Dropped, Paths[-1L])
  }
  Dropped
}

.incCheckRow <- function(survey, label, value) {
  data.table::data.table(
    SurveyID = survey$SurveyID,
    ID = survey$ID,
    SiteID = survey$SiteID,
    HoleID = survey$HoleID,
    SensorID = survey$SensorID,
    SourcePath = survey$SourcePath,
    SourceSheet = "",
    SourceRow = "",
    RawBlock = "BuildCheck",
    RawLabel = label,
    RawValue = value,
    InstallationHeaderOK = "",
    SurveyHeaderOK = "",
    DataHeaderOK = "",
    DataRows = ""
  )
}

.incBuildChecks <- function(data, surveys, dropped, index) {
  LIST <- list()
  for (path in dropped) {
    Kept <- surveys[
      SurveyID == surveys[SourcePath == path, SurveyID] & SourcePath != path
    ][1L]
    LIST[[length(LIST) + 1L]] <- .incCheckRow(
      survey = Kept,
      label = "DUPLICATED",
      value = path
    )
  }
  Declared <- index[
    RawLabel == "Num Depths" & !(SourcePath %in% dropped),
    .(SourcePath, declared = suppressWarnings(as.integer(RawValue)))
  ]
  Observed <- data[, .(observed = .N), by = .(SourcePath)]
  AUX <- Declared[Observed, on = "SourcePath"][!is.na(declared) & declared != observed]
  for (i in seq_len(nrow(AUX))) {
    LIST[[length(LIST) + 1L]] <- .incCheckRow(
      survey = surveys[SourcePath == AUX$SourcePath[i]][1L],
      label = "MISCOUNTED",
      value = sprintf("declared=%d; observed=%d", AUX$declared[i], AUX$observed[i])
    )
  }
  data.table::rbindlist(l = LIST, use.names = TRUE)
}

.incTables <- function(raw) {
  DATA <- .readRawTable(raw = raw, id = "INC", name = "data", colClasses = "character")
  INDEX <- .readRawTable(raw = raw, id = "INC", name = "index", colClasses = "character")
  .checkRawIndex(data = DATA, index = INDEX)

  Surveys <- .incSurveys(index = INDEX)
  Dropped <- .dedupINCSurveys(data = DATA, index = INDEX, surveys = Surveys)
  Checks <- .incBuildChecks(
    data = DATA[!(SourcePath %in% Dropped)],
    surveys = Surveys,
    dropped = Dropped,
    index = INDEX
  )

  DATA <- DATA[!(SourcePath %in% Dropped)]
  INDEX <- INDEX[!(SourcePath %in% Dropped)]
  Surveys <- Surveys[!(SourcePath %in% Dropped)]
  if (anyDuplicated(Surveys$SurveyID) > 0L) {
    stop("SurveyID not unique after deduplication", call. = FALSE)
  }

  DATA[Surveys, on = "SourcePath", `:=`(SurveyID = i.SurveyID, datetime = i.datetime)]
  Units <- INDEX[RawLabel == "DepthUnits", .(SourcePath, units = RawValue)]
  DATA[Units, on = "SourcePath", units.depth := i.units]
  DATA[, `:=`(
    depth = .asNum(x = Depth, field = "depth"),
    A0 = .asNum(x = A0, field = "A0"),
    A180 = .asNum(x = A180, field = "A180"),
    B0 = .asNum(x = B0, field = "B0"),
    B180 = .asNum(x = B180, field = "B180")
  )]

  AUX <- DATA[, .N, by = .(SurveyID, depth)][N > 1L]
  if (nrow(AUX) > 0L) {
    print(AUX)
    stop("duplicated depth inside INC survey", call. = FALSE)
  }

  data.table::setorder(DATA, ID, SiteID, HoleID, SensorID, datetime, SurveyID, depth)
  DATA[, RecordID := seq_len(.N)]

  INDEX[Surveys, on = "SourcePath", SurveyID := i.SurveyID]
  if (nrow(Checks) > 0L) {
    INDEX <- data.table::rbindlist(l = list(INDEX, Checks), use.names = TRUE)
  }
  COLS.index <- c("SurveyID", setdiff(names(INDEX), "SurveyID"))
  data.table::setcolorder(x = INDEX, neworder = COLS.index)

  COLS.data <- c(
    "SurveyID", "RecordID", "ID", "SiteID", "HoleID", "SensorID", "datetime",
    "depth", "units.depth", "A0", "A180", "B0", "B180"
  )
  list(data = DATA[, ..COLS.data], index = INDEX)
}
