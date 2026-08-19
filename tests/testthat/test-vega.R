## Vega corrupt virtual site: acceptance suite of the piezometer engine.
## Contract: dev/SoT/PLAN-virtual-site.md (rulings 2026-08-18). The fixture
## inst/fixtures/Vega carries the approved corruption matrix (15 injections)
## plus 4 anti-ghost controls with a known-truth manifest (truth.csv); the
## generator is dev/generateVega.R. Four gates:
##   (a) every injection detectable TODAY fires with its expected level;
##   (b) NOTHING else fires (zero ghosts);
##   (c) every correction leaves the correct value in the database;
##   (d) every uncorrectable injection stays visible in the products.
##
## Honesty scope. auditPiezometer() covers PCG + PCV; auditInclinometer()
## covers INC engine-side since the 2026-08-19 consolidation (deliberate
## flip: the INC injections were formerly annotated "validated by AR
## runner" and only their existence was asserted). The four engine
## detection gaps documented on 2026-08-18 (DUPLICATED record keyed on
## SourceRow, no source-to-raw census, silent skip of a declared sheet,
## flag D collateral) were closed the same day: their expectations below
## are deliberate flips from non-emission to emission. Same day, second
## ruling: DUPLICATED record was rekeyed to the client's row identity
## (date + hora + stage wherever the sheet provides them) and the VP-2
## injection regenerated as an identical re-entry (same hora), so the
## emission expectations hold unchanged. Still expected NOT to fire:
## MISCLOSURE (check suspended until the row-local redesign) and DRY
## (flag D in PZ.data.csv is the record, no log emission).

.vegaRoot <- function() {
  PATH <- system.file("fixtures", "Vega", package = "dbAudit")
  if (nzchar(PATH) && dir.exists(PATH)) return(PATH)
  normalizePath(
    test_path("..", "..", "inst", "fixtures", "Vega"),
    mustWork = TRUE
  )
}

.vegaSerial <- function(x) as.integer(as.Date(x) - as.Date("1899-12-30"))

.vegaDate <- function(x) format(x, "%Y-%m-%d", tz = "UTC")

## One shared pipeline run for every gate below.
Root <- .vegaRoot()
Path <- file.path(tempdir(), "vega-site")
if (dir.exists(Path)) unlink(Path, recursive = TRUE)
dir.create(Path, recursive = TRUE, showWarnings = FALSE)
invisible(file.copy(file.path(Root, "source"), Path, recursive = TRUE))
Out <- auditPiezometer(project.path = Path, id = c("PCG", "PCV"))

Truth <- data.table::fread(
  file = file.path(Root, "truth.csv"),
  colClasses = "character"
)
Log <- data.table::fread(file = Out$log.file)
Sink <- data.table::fread(file = file.path(Out$audit.dir, "PCG.reject.csv"))
DBPCG <- data.table::fread(file = file.path(Out$db.dir, "PCG.data.csv"))
DBPCV <- data.table::fread(file = file.path(Out$db.dir, "PCV.data.csv"))
PZ <- data.table::fread(file = file.path(Out$audit.dir, "PZ.data.csv"))
PZIndex <- data.table::fread(file = file.path(Out$audit.dir, "PZ.index.csv"))

## The INC engine run shares the project copy. It re-initializes
## audit/log.csv, so it runs only after every piezometer product above is
## already in memory.
OutINC <- auditInclinometer(project.path = Path)
LogINC <- data.table::fread(file = OutINC$log.file)
DBINC <- data.table::fread(file = file.path(OutINC$db.dir, "INC.data.csv"))
INCIndex <- data.table::fread(file = file.path(OutINC$db.dir, "INC.index.csv"))
AuditINC <- data.table::fread(file = file.path(OutINC$audit.dir, "INC.audit.csv"))

test_that("the truth manifest carries the approved matrix", {
  ## 15 approved injection events + 4 anti-ghost controls (event = NONE).
  expect_setequal(
    unique(Truth[event != "NONE", event]),
    c(
      "COMMA", "UNREADABLE", "MISLABELED", "REDATED", "DUPLICATED",
      "MIXED", "UNITLESS", "MISCOUNTED", "MALFORMED", "INCOMPLETE",
      "MISSING", "MISCLOSURE", "DRY"
    )
  )
  ## MISLABELED and DUPLICATED count twice (WARNING and ERROR variants).
  expect_identical(
    nrow(unique(Truth[event != "NONE", .(event, level)])), 15L
  )
  expect_identical(nrow(Truth[event == "NONE"]), 4L)
})

test_that("gate a: every injection detectable today fires with its level", {
  ## COMMA and UNREADABLE fire in the gate sink audit/PCG.reject.csv.
  for (i in which(Truth$event == "COMMA")) {
    AUX <- Sink[
      event == "COMMA" & level == "WARNING" &
        grepl("VP-1_", SourcePath) &
        date == .vegaSerial(Truth$row_or_date[i])
    ]
    expect_identical(nrow(AUX), 1L)
    expect_match(
      AUX$detail,
      sprintf("repaired=%s", Truth$correct_value[i]),
      fixed = TRUE
    )
  }
  for (i in which(Truth$event == "UNREADABLE")) {
    expect_identical(
      nrow(Sink[
        event == "UNREADABLE" & level == "ERROR" &
          grepl("VP-1_", SourcePath) &
          date == .vegaSerial(Truth$row_or_date[i])
      ]),
      1L
    )
  }
  ## MIXED and UNITLESS fire in log.csv.
  expect_identical(
    nrow(Log[event == "MIXED" & level == "INFO" &
               grepl("variable=pressure", detail)]),
    1L
  )
  expect_identical(
    nrow(Log[event == "UNITLESS" & level == "ERROR" &
               grepl("column=units.reading", detail, fixed = TRUE)]),
    1L
  )
  ## DUPLICATED record fires in log.csv keyed on the client's row
  ## identity — date + hora + stage wherever the sheet provides them
  ## (ruling 2026-08-18; the injection is an identical re-entry with
  ## the same hora, so it stays indistinguishable by the client's own
  ## columns). Deliberate flip 2026-08-18: formerly documented gap 1.
  AUX <- Log[event == "DUPLICATED" & level == "ERROR" & scope == "record"]
  expect_identical(nrow(AUX), 1L)
  expect_identical(AUX$HoleID, "VP-2")
  expect_identical(
    as.character(AUX$datetime),
    Truth[event == "DUPLICATED" & grepl("VP-2", file), row_or_date]
  )
  expect_match(AUX$detail, "rows=2", fixed = TRUE)
  ## MISSING fires from the source-to-raw census (deliberate flip
  ## 2026-08-18: formerly documented gap 2).
  AUX <- Log[event == "MISSING" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_identical(
    AUX$source,
    sub("^source/", "", Truth[event == "MISSING", file])
  )
  ## MALFORMED fires for the sheet that declares the monitoring marker
  ## but fails the data-sheet gate (deliberate flip 2026-08-18:
  ## formerly documented gap 3).
  AUX <- Log[event == "MALFORMED" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_identical(
    AUX$source,
    sprintf(
      "%s [VP-3 (2)]",
      basename(Truth[event == "MALFORMED", file])
    )
  )
})

test_that("gate b: nothing else fires (zero ghosts, gaps stay silent)", {
  ## The complete expected log after the 2026-08-18 gap closures: run
  ## marks, the two original file-scope findings, and the three flipped
  ## emissions (DUPLICATED record, MALFORMED sheet, MISSING census).
  ## Everything else in the matrix either lives in the gate sink, is
  ## INC-side, or is suspended.
  expect_identical(
    as.data.frame(Log[, .N, keyby = .(level, event)]),
    data.frame(
      level = c("ERROR", "ERROR", "ERROR", "ERROR", "INFO", "INFO", "INFO"),
      event = c("DUPLICATED", "MALFORMED", "MISSING", "UNITLESS",
                "DONE", "MIXED", "START"),
      N = c(1L, 1L, 1L, 1L, 1L, 1L, 1L)
    )
  )
  ## The complete expected gate sink: 3 COMMA + 2 UNREADABLE, PCG only.
  expect_identical(
    as.data.frame(Sink[, .N, keyby = .(level, event)]),
    data.frame(
      level = c("ERROR", "WARNING"),
      event = c("UNREADABLE", "COMMA"),
      N = c(2L, 3L)
    )
  )
  expect_false(file.exists(file.path(Out$audit.dir, "PCV.reject.csv")))
  ## Documented non-emissions, asserted so a future change is a deliberate
  ## re-record of this suite, never an accident:
  ## - MISCLOSURE is SUSPENDED (inferred implementation retired; fires
  ##   only after the row-local redesign);
  ## - DRY: flag D in PZ.data.csv, no log event;
  ## - MISLABELED/REDATED/MISCOUNTED/INCOMPLETE (INC side): they fire in
  ##   the auditInclinometer() log, never in the piezometer log.
  ## DUPLICATED record, MISSING and MALFORMED left this list on
  ## 2026-08-18 (deliberate flips; asserted as emissions in gate a).
  expect_identical(
    nrow(Log[event %in% c(
      "MISCLOSURE", "DRY",
      "MISLABELED", "REDATED", "MISCOUNTED", "INCOMPLETE"
    )]),
    0L
  )
})

test_that("gate c: corrected values equal the truth in the database", {
  for (i in which(Truth$event == "COMMA")) {
    AUX <- DBPCG[
      HoleID == "VP-1" & .vegaDate(datetime) == Truth$row_or_date[i]
    ]
    expect_identical(nrow(AUX), 1L)
    expect_identical(AUX$level, as.numeric(Truth$correct_value[i]))
  }
})

test_that("gate d: unreadable readings leave a visible gap", {
  DATES <- Truth[event == "UNREADABLE", row_or_date]
  ## No level value enters the database on either date.
  AUX <- DBPCG[HoleID == "VP-1" & .vegaDate(datetime) %in% DATES]
  expect_true(all(is.na(AUX$level)))
  ## The "s/l" campaign carried no other reading: the whole record is
  ## absent. The typo campaign keeps its depth/head reading with the
  ## level gap.
  expect_identical(nrow(AUX), 1L)
  expect_false(is.na(AUX$depth))
})

test_that("gate d: the duplicated record stays visible (both rows in db)", {
  DATE <- Truth[event == "DUPLICATED" & grepl("VP-2", file), row_or_date]
  expect_identical(
    nrow(DBPCG[HoleID == "VP-2" & .vegaDate(datetime) == DATE]),
    2L
  )
})

test_that("gate d: the misclosure corruption is visible in the database", {
  ## Row-local closure on channel A: depth + level = collar elevation.
  ## The corrupt rows break it by > 2 m; every clean row closes within
  ## rounding. MISCLOSURE itself is suspended (gate b), so this is the
  ## fixture evidence the future check will fire on.
  AUX <- DBPCV[
    HoleID == "VP-4" & SensorID == "A" & !is.na(depth) & !is.na(level)
  ]
  AUX[, closure := depth + level]
  Collar <- stats::median(AUX$closure)
  DATES <- Truth[event == "MISCLOSURE", row_or_date]
  BAD <- AUX[.vegaDate(datetime) %in% DATES]
  expect_identical(nrow(BAD), 2L)
  expect_true(all(abs(BAD$closure - Collar) > 2))
  expect_true(all(abs(AUX[!.vegaDate(datetime) %in% DATES, closure] - Collar) < 0.05))
  ## The typed depth differs from the truth's coherent value.
  for (i in which(Truth$event == "MISCLOSURE")) {
    expect_true(all(abs(
      AUX[.vegaDate(datetime) == Truth$row_or_date[i], depth] -
        as.numeric(Truth$correct_value[i])
    ) > 2))
  }
})

test_that("gate d: the missing file exists and its readings never load", {
  FILES <- list.files(
    file.path(Path, "source", "backup"),
    recursive = TRUE, full.names = TRUE
  )
  expect_identical(length(FILES), 1L)
  expect_match(basename(FILES), "^VP-2_")
  DATE <- Truth[event == "MISSING", row_or_date]
  expect_identical(nrow(DBPCG[.vegaDate(datetime) == DATE]), 0L)
  expect_true(max(DBPCG$datetime) < as.POSIXct(DATE, tz = "UTC"))
})

test_that("gate d: dry readings carry flag D in PZ.data", {
  DATES <- Truth[event == "DRY", row_or_date]
  AUX <- PZ[ID == "PCG" & HoleID == "VP-3" & flag == "D"]
  expect_setequal(.vegaDate(AUX$datetime), DATES)
  expect_identical(nrow(AUX), 4L)
  expect_true(all(is.na(AUX$level)))
  ## Deliberate flip 2026-08-18 (formerly documented gap 4): flag D now
  ## marks the dry condition only. The UNREADABLE typo campaign of VP-1
  ## (level rejected at the gate, depth kept) is a data gap, not a dry
  ## well, and carries no flag. 4 dry, 0 collateral.
  expect_identical(nrow(PZ[flag == "D"]), 4L)
  expect_identical(unique(PZ[flag == "D", HoleID]), "VP-3")
})

test_that("gate d: the malformed sheet exists and contributes nothing", {
  FILE <- list.files(
    file.path(Path, "source", "PCG", "Vega"),
    pattern = "^VP-3_", full.names = TRUE
  )
  expect_identical(length(FILE), 1L)
  expect_true("VP-3 (2)" %in% readxl::excel_sheets(FILE))
  ## Every VP-3 database record comes from the main sheet.
  expect_identical(nrow(DBPCG[HoleID == "VP-3"]), 36L)
  expect_false("VP-3 (2)" %in% PZIndex$SourceSheet)
})

test_that("the INC injections ship in the fixture with their known truth", {
  ## Fixture-side evidence: the corruption EXISTS in the source files the
  ## engine gates below fire on (deliberate flip 2026-08-19: formerly
  ## "validated by AR runner", now engine-side).
  ARN <- Truth[note == "validated engine-side by auditInclinometer()"]
  expect_identical(nrow(ARN), 6L)

  .field <- function(file, line, i) {
    strsplit(readLines(file.path(Root, file), n = line)[line], ";")[[1]][i]
  }
  ## MISLABELED WARNING: every VI-1 file declares the format variant
  ## VI-01 while folder and filename say VI-1.
  FILES <- list.files(
    file.path(Root, "source", "INC", "Vega", "VI-1"), full.names = TRUE
  )
  expect_identical(length(FILES), 37L)
  expect_true(all(vapply(
    X = FILES,
    FUN = function(f) strsplit(readLines(f, n = 2)[2], ";")[[1]][3] == "VI-01",
    FUN.VALUE = logical(1)
  )))
  ## MISLABELED ERROR: one VI-2 file declares an instrument that does
  ## not exist on the site.
  expect_identical(
    .field(ARN[event == "MISLABELED" & level == "ERROR", file], 2, 3),
    "VI-9"
  )
  ## REDATED: identical survey data republished under a different date.
  FILE <- ARN[event == "REDATED", file]
  ORIGINAL <- sub("_([0-9]{8})[.]csv$", "_20240616.csv", FILE)
  A <- readLines(file.path(Root, FILE))
  B <- readLines(file.path(Root, ORIGINAL))
  expect_identical(A[-4], B[-4])
  expect_false(identical(A[4], B[4]))
  ## DUPLICATED survey: byte-identical file under two names.
  FILE <- ARN[event == "DUPLICATED", file]
  expect_identical(
    unname(tools::md5sum(file.path(Root, FILE))),
    unname(tools::md5sum(file.path(Root, sub(" - copia", "", FILE, fixed = TRUE))))
  )
  ## MISCOUNTED: header declares 40 depths, the profile brings 38.
  FILE <- ARN[event == "MISCOUNTED", file]
  expect_identical(.field(FILE, 4, 4), "40")
  expect_identical(length(readLines(file.path(Root, FILE))) - 5L, 38L)
  ## INCOMPLETE: the Installation header lost the tube depth.
  expect_identical(.field(ARN[event == "INCOMPLETE", file], 2, 7), "")
})

test_that("INC gate a: every inclinometer injection fires with its level", {
  ## MISLABELED WARNING: all 37 VI-1 surveys declare the format variant
  ## VI-01; the identity check normalizes it.
  AUX <- LogINC[event == "MISLABELED" & level == "WARNING"]
  expect_identical(nrow(AUX), 1L)
  expect_match(AUX$detail, "field=Installation; count=37", fixed = TRUE)
  ## MISLABELED ERROR: one VI-2 survey declares VI-9, an instrument that
  ## does not exist on the site.
  AUX <- LogINC[event == "MISLABELED" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_match(AUX$detail, "count=1; different instrument declared", fixed = TRUE)
  ## REDATED: one VI-1 survey republished identical readings under a
  ## different date — one signature group of two surveys.
  AUX <- LogINC[event == "REDATED" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_match(AUX$detail, "groups=1; surveys=2", fixed = TRUE)
  ## DUPLICATED survey: the byte-identical "copia" pair is consolidated
  ## at build and the log records the dropped path. Which of the two
  ## basenames is dropped depends on the locale collation of sort(), so
  ## the assertion pins the pair, not the member.
  AUX <- LogINC[event == "DUPLICATED" & level == "WARNING" & scope == "survey"]
  expect_identical(nrow(AUX), 1L)
  expect_identical(AUX$HoleID, "VI-2")
  expect_match(AUX$detail, "dropped=VEGA_VI-2_Inclinometer_20240314.*[.]csv")
  ## MISCOUNTED: the header declares 40 depths, the profile brings 38.
  AUX <- LogINC[event == "MISCOUNTED" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_match(AUX$detail, "declared=40; observed=38", fixed = TRUE)
  ## INCOMPLETE: the Installation header lost the tube depth.
  AUX <- LogINC[event == "INCOMPLETE" & level == "ERROR"]
  expect_identical(nrow(AUX), 1L)
  expect_match(AUX$detail, "empty field=Depth Bottom; rows=1", fixed = TRUE)
})

test_that("INC gate b: nothing else fires in the inclinometer log", {
  ## The complete expected log: run marks plus the six INC emissions.
  ## In particular the source-to-raw census stays silent (every INC csv
  ## is walked), coverage finds no raw/db descuadre, DisplayUnits are
  ## stable per hole (no MIXED), and no duplicated depth survives the
  ## build (no DUPLICATED record).
  expect_identical(
    as.data.frame(LogINC[, .N, keyby = .(level, event)]),
    data.frame(
      level = c("ERROR", "ERROR", "ERROR", "ERROR",
                "INFO", "INFO", "WARNING", "WARNING"),
      event = c("INCOMPLETE", "MISCOUNTED", "MISLABELED", "REDATED",
                "DONE", "START", "DUPLICATED", "MISLABELED"),
      N = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L)
    )
  )
})

test_that("INC gate c: the database keeps the corrected identities", {
  ## The folder/filename identity wins over the mislabeled content: only
  ## the real instruments reach the database.
  expect_setequal(unique(DBINC$HoleID), c("VI-1", "VI-2"))
  ## The consolidated duplicate enters once: no two surveys share one
  ## (HoleID, datetime) pair.
  SURVEYS <- unique(DBINC[, .(HoleID, datetime, SurveyID)])
  expect_identical(anyDuplicated(SURVEYS[, .(HoleID, datetime)]), 0L)
  ## The BuildCheck block records the dropped member of the copia pair
  ## against the kept survey (locale collation decides which basename).
  DUP <- INCIndex[RawBlock == "BuildCheck" & RawLabel == "DUPLICATED"]
  expect_identical(nrow(DUP), 1L)
  expect_match(DUP$RawValue, "VEGA_VI-2_Inclinometer_20240314.*[.]csv$")
})

test_that("INC gate d: every uncorrectable injection stays visible", {
  ## REDATED: both surveys sit in the database with identical readings.
  DATES <- c("20240616", "20240623")
  SURVEYS <- lapply(X = DATES, FUN = function(d) {
    AUX <- DBINC[HoleID == "VI-1" & grepl(d, SurveyID)][order(depth)]
    expect_identical(nrow(AUX), 38L)
    AUX[, .(depth, A0, A180, B0, B180)]
  })
  expect_identical(SURVEYS[[1L]], SURVEYS[[2L]])
  ## Their audit rows carry the REDATED error.
  AUX <- AuditINC[HoleID == "VI-1" & grepl("20240616|20240623", SurveyID)]
  expect_identical(nrow(AUX), 76L)
  expect_true(all(AUX$status == "ERROR" & AUX$event == "REDATED"))
  ## MISCOUNTED: the short profile is in the database as observed.
  expect_identical(
    nrow(DBINC[HoleID == "VI-1" & grepl("20250313", SurveyID)]), 38L
  )
  ## INCOMPLETE: the empty Depth Bottom is visible in the index. Both
  ## holes surveyed that campaign day: the filter must pin the hole.
  AUX <- INCIndex[
    HoleID == "VI-2" & grepl("20250616", SurveyID) & RawLabel == "Depth Bottom"
  ]
  expect_identical(nrow(AUX), 1L)
  expect_true(is.na(AUX$RawValue) | !nzchar(trimws(as.character(AUX$RawValue))))
  ## MISLABELED ERROR: the declared VI-9 stays visible in the index and
  ## its survey is flagged in the audit table.
  BAD <- INCIndex[RawLabel == "Installation" & RawValue == "VI-9"]
  expect_identical(nrow(BAD), 1L)
  AUX <- AuditINC[SurveyID %in% BAD$SurveyID]
  expect_true(nrow(AUX) > 0L)
  expect_true(all(AUX$status == "WARNING" & AUX$event == "MISLABELED"))
})
