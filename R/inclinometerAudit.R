## R/inclinometerAudit.R
## Inclinometer audit checks, migrated verbatim from AR-S2L1X
## scripts/runAudit.R (engine consolidation; the application repository
## imports these checks from this namespace).
##
## Structural checks only: naming identity, survey header completeness,
## raw-to-db survey coverage, duplicated depths, and display-unit stability
## per hole. The equipment-family mathematics that turns raw sums into
## displacements is deliberately absent until it is reviewed and documented;
## see AR-S2L1X dev/SoT/PLAN-INC-calculation-research.md.

.flagINC <- function(audit, surveyID, label) {
  audit[
    SurveyID %in% surveyID & status == "OK",
    `:=`(status = "WARNING", event = label)
  ]
  invisible(TRUE)
}

.checkINCCoverage <- function(log, rawIndex, dbIndex) {
  RawPaths <- unique(rawIndex[RawLabel == "Survey DateTime", SourcePath])
  DBPaths <- unique(dbIndex[RawBlock != "BuildCheck", SourcePath])
  Dropped <- dbIndex[
    RawBlock == "BuildCheck" & RawLabel == "DUPLICATED", RawValue
  ]
  MISS <- setdiff(RawPaths, c(DBPaths, Dropped))
  if (length(MISS) > 0L) {
    .logEvent(
      log.file = log, scope = "file", event = "MISSING",
      source = "data/db/INC.index.csv",
      detail = sprintf("ID=INC; raw surveys missing in db; surveys=%d", length(MISS))
    )
  }
  ORPH <- setdiff(DBPaths, RawPaths)
  if (length(ORPH) > 0L) {
    .logEvent(
      log.file = log, scope = "file", event = "MISSING",
      source = "data/raw/INC",
      detail = sprintf("ID=INC; db surveys missing in raw; surveys=%d", length(ORPH))
    )
  }
  invisible(TRUE)
}

.checkINCNaming <- function(log, audit, dbIndex) {
  Inst <- unique(dbIndex[
    RawLabel == "Installation" & RawBlock != "BuildCheck",
    .(SurveyID, HoleID, Installation = trimws(RawValue))
  ])
  BAD <- Inst[toupper(Installation) != toupper(HoleID)]
  if (nrow(BAD) > 0L) {
    .flagINC(audit = audit, surveyID = BAD$SurveyID, label = "MISLABELED")
    .normID <- function(x) gsub("0+([0-9])", "\\1", gsub("[^A-Z0-9]", "", toupper(x)))
    Var <- BAD[.normID(Installation) == .normID(HoleID)]
    Real <- BAD[.normID(Installation) != .normID(HoleID)]
    if (nrow(Var)) {
      .logEvent(
        log.file = log, scope = "survey", event = "MISLABELED",
        level = "WARNING",
        source = "data/db/INC.index.csv",
        detail = sprintf("ID=INC; field=Installation; count=%d; format variant normalized", nrow(Var))
      )
    }
    if (nrow(Real)) {
      .logEvent(
        log.file = log, scope = "survey", event = "MISLABELED",
        level = "ERROR",
        source = "data/db/INC.index.csv",
        detail = sprintf("ID=INC; field=Installation; count=%d; different instrument declared", nrow(Real))
      )
    }
  }

  Files <- unique(dbIndex[
    RawBlock != "BuildCheck",
    .(SurveyID, HoleID, SourcePath)
  ])
  Files[, OK := grepl(
    pattern = paste0("_", HoleID, "_Inclinometer"),
    x = basename(SourcePath),
    fixed = TRUE
  ), by = SurveyID]
  BAD <- Files[OK == FALSE]
  if (nrow(BAD) > 0L) {
    .flagINC(audit = audit, surveyID = BAD$SurveyID, label = "MISLABELED")
    .normID <- function(x) gsub("0+([0-9])", "\\1", gsub("[^A-Z0-9]", "", toupper(x)))
    BAD[, token := sub("^[^_]*_(.+)_Inclinometer.*$", "\\1", basename(SourcePath))]
    Var <- BAD[.normID(token) == .normID(HoleID)]
    Real <- BAD[.normID(token) != .normID(HoleID)]
    if (nrow(Var)) {
      .logEvent(
        log.file = log, scope = "survey", event = "MISLABELED",
        level = "WARNING",
        source = "data/db/INC.index.csv",
        detail = sprintf("ID=INC; field=SourcePath; count=%d; format variant normalized", nrow(Var))
      )
    }
    if (nrow(Real)) {
      .logEvent(
        log.file = log, scope = "survey", event = "MISLABELED",
        level = "ERROR",
        source = "data/db/INC.index.csv",
        detail = sprintf("ID=INC; field=SourcePath; count=%d; different instrument in filename", nrow(Real))
      )
    }
  }
  invisible(TRUE)
}

.checkINCConsolidated <- function(log, dbIndex) {
  # DUPLICATED survey (WARNING, catalog): the build consolidates
  # byte-identical survey files and records the dropped path in the
  # BuildCheck block of INC.index.csv; the log said nothing about it
  # (PLAN-logging.md Vega blind spot 1, closed 2026-08-18).
  DUP <- dbIndex[RawBlock == "BuildCheck" & RawLabel == "DUPLICATED"]
  if (nrow(DUP) == 0L) return(invisible(TRUE))
  .logEvent(
    log.file = log, scope = "survey", event = "DUPLICATED",
    SiteID = DUP$SiteID, HoleID = DUP$HoleID,
    source = "data/db/INC.index.csv",
    detail = sprintf(
      "ID=INC; SurveyID=%s; identical file consolidated; dropped=%s",
      DUP$SurveyID, basename(DUP$RawValue)
    )
  )
  invisible(TRUE)
}

.checkINCCounts <- function(log, dbIndex) {
  # MISCOUNTED (ERROR, catalog): the build compares the declared Num
  # Depths against the observed profile and records the disagreement in
  # the BuildCheck block; neither the log nor the deck ever saw it
  # (PLAN-logging.md Vega blind spot 2, closed 2026-08-18).
  BAD <- dbIndex[RawBlock == "BuildCheck" & RawLabel == "MISCOUNTED"]
  if (nrow(BAD) == 0L) return(invisible(TRUE))
  .logEvent(
    log.file = log, scope = "survey", event = "MISCOUNTED",
    SiteID = BAD$SiteID, HoleID = BAD$HoleID,
    source = "data/db/INC.index.csv",
    detail = sprintf("ID=INC; SurveyID=%s; %s", BAD$SurveyID, BAD$RawValue)
  )
  invisible(TRUE)
}

.checkINCHeader <- function(log, audit, dbIndex) {
  # Depth Bottom belongs to header COMPLETENESS: the field list gates
  # what the encabezado must carry, not what the project consumes
  # (PLAN-logging.md Vega blind spot 3, closed 2026-08-18).
  Fields <- c(
    "Survey DateTime", "Sensor SN", "Num Depths", "Depth Bottom",
    "DepthUnits", "DisplayUnits", "Instrument Constant", "Actl Cnst"
  )
  Surveys <- unique(dbIndex[RawBlock != "BuildCheck", .(SurveyID)])
  Expected <- Surveys[, .(RawLabel = Fields), by = SurveyID]
  Seen <- unique(dbIndex[RawLabel %in% Fields, .(SurveyID, RawLabel)])
  MISS <- Expected[!Seen, on = c("SurveyID", "RawLabel")]
  if (nrow(MISS) > 0L) {
    .flagINC(audit = audit, surveyID = unique(MISS$SurveyID), label = "INCOMPLETE")
    .logEvent(
      log.file = log, scope = "survey", event = "INCOMPLETE",
      source = "data/db/INC.index.csv",
      detail = sprintf("ID=INC; missing header fields; count=%d", nrow(MISS))
    )
  }

  EMPTY <- dbIndex[
    RawLabel %in% Fields & !nzchar(trimws(as.character(RawValue))),
    .N,
    by = RawLabel
  ]
  if (nrow(EMPTY) > 0L) {
    .logEvent(
      log.file = log, scope = "survey", event = "INCOMPLETE",
      source = "data/db/INC.index.csv",
      detail = sprintf("ID=INC; empty field=%s; rows=%d", EMPTY$RawLabel, EMPTY$N)
    )
    BAD <- dbIndex[
      RawLabel %in% Fields & !nzchar(trimws(as.character(RawValue))), unique(SurveyID)
    ]
    .flagINC(audit = audit, surveyID = BAD, label = "INCOMPLETE")
  }
  invisible(TRUE)
}

.checkINCUnits <- function(log, audit, dbIndex) {
  DU <- unique(dbIndex[
    RawLabel == "DisplayUnits" & RawBlock != "BuildCheck",
    .(HoleID, SurveyID, Units = trimws(RawValue))
  ])
  AUX <- DU[, .(N = data.table::uniqueN(Units)), by = HoleID][N > 1L]
  for (holeID in AUX$HoleID) {
    Units <- sort(unique(DU[HoleID == holeID, Units]))
    .flagINC(
      audit = audit,
      surveyID = DU[HoleID == holeID, SurveyID],
      label = "MIXED"
    )
    .logEvent(
      log.file = log, scope = "survey", event = "MIXED",
      HoleID = holeID,
      source = "data/db/INC.index.csv",
      detail = sprintf(
        "ID=INC; field=DisplayUnits; units=%s", paste(Units, collapse = ", ")
      )
    )
  }
  invisible(TRUE)
}

.checkINCRedated <- function(log, audit) {
  data.table::setorder(audit, SurveyID, depth)
  SIG <- audit[, .(
    HoleID = HoleID[1L],
    signature = paste(paste(depth, A0, A180, B0, B180, sep = ","), collapse = ";")
  ), by = SurveyID]
  AUX <- SIG[, .(N = .N, surveys = paste(sort(SurveyID), collapse = ", ")),
             by = .(HoleID, signature)][N > 1L]
  if (nrow(AUX) > 0L) {
    Flagged <- SIG[AUX, on = c("HoleID", "signature"), SurveyID]
    audit[
      SurveyID %in% Flagged,
      `:=`(status = "ERROR", event = "REDATED")
    ]
    .logEvent(
      log.file = log, scope = "survey", event = "REDATED",
      source = "data/db/INC.data.csv",
      detail = sprintf(
        "ID=INC; groups=%d; surveys=%d; identical readings under different dates",
        nrow(AUX), length(Flagged)
      )
    )
  }
  invisible(TRUE)
}

.checkINCDuplicates <- function(log, audit) {
  AUX <- audit[, .N, by = .(SurveyID, depth)][N > 1L]
  if (nrow(AUX) > 0L) {
    audit[
      AUX, on = c("SurveyID", "depth"),
      `:=`(status = "ERROR", event = "DUPLICATED")
    ]
    .logEvent(
      log.file = log, scope = "record", event = "DUPLICATED",
      source = "data/db/INC.data.csv",
      detail = sprintf("ID=INC; count=%d", sum(AUX$N))
    )
  }
  invisible(TRUE)
}

.incChecksums <- function(audit, dbIndex) {
  AC <- dbIndex[
    RawLabel == "Actl Cnst",
    .(constant = suppressWarnings(as.numeric(RawValue))[1L]),
    by = SurveyID
  ]
  IV <- dbIndex[
    RawLabel == "Depth Interval",
    .(interval = suppressWarnings(as.numeric(RawValue))[1L] * 1000),
    by = SurveyID
  ]
  audit[AC, on = "SurveyID", constant := i.constant]
  audit[IV, on = "SurveyID", interval := i.interval]
  audit[, `:=`(
    checksumA = interval * (A0 + A180) / (2 * constant),
    checksumB = interval * (B0 + B180) / (2 * constant)
  )]
  audit[, `:=`(constant = NULL, interval = NULL)]
  invisible(TRUE)
}

.auditINC <- function(log, raw, db, audit) {
  DBData <- .readDB(db = db, id = "INC", name = "data")
  DBIndex <- .readDB(db = db, id = "INC", name = "index")
  RawIndex <- .readRaw(raw = raw, id = "INC", name = "index")
  AuditINC <- data.table::copy(DBData)[, `:=`(status = "OK", event = "")]

  ## Report-only face checksums (2026-08-13 ruling): published as QC
  ## evidence in mm with the per-survey Actl Cnst divisor, no acceptance
  ## bands and no log events.
  .incChecksums(audit = AuditINC, dbIndex = DBIndex)

  .checkINCCoverage(log = log, rawIndex = RawIndex, dbIndex = DBIndex)
  .checkINCConsolidated(log = log, dbIndex = DBIndex)
  .checkINCCounts(log = log, dbIndex = DBIndex)
  .checkINCNaming(log = log, audit = AuditINC, dbIndex = DBIndex)
  .checkINCHeader(log = log, audit = AuditINC, dbIndex = DBIndex)
  .checkINCUnits(log = log, audit = AuditINC, dbIndex = DBIndex)
  .checkINCRedated(log = log, audit = AuditINC)
  .checkINCDuplicates(log = log, audit = AuditINC)

  data.table::fwrite(x = AuditINC, file = file.path(audit, "INC.audit.csv"))
  AuditINC
}
