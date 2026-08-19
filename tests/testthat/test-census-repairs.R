## Census vs systematic filename repairs: unit contract of the rekey
## (ruling 2026-08-19, dev/SoT/PLAN-virtual-site.md). The Vega fixture
## can only prove the anti-ghost side — a repaired record that reaches
## the db must not fire MISSING — because the gate's conservation stop
## makes losing a record mid-pipeline impossible there. This synthetic
## test pins the DISCRIMINATING half of the ruling: a repaired record
## LOST on the way to db must still fire MISSING. The rejected
## alternative (discounting repaired sources from both census sides)
## passes Vega but fails here — this is the guard against
## reintroducing that blind spot.

.censusTables <- function() {
  RAW <- data.table::data.table(
    ID = "PCG",
    SiteID = "Vega",
    HoleID = c("VP-50", "VP-50", "VP-2"),
    SensorID = "0",
    SourcePath = c(
      "source/PCG/Vega/VP-5_x.xlsx",
      "source/PCG/Vega/VP-5_x.xlsx",
      "source/PCG/Vega/VP-2_x.xlsx"
    ),
    SourceSheet = c("VP-50", "VP-50", "VP-2"),
    SourceRow = c(11L, 12L, 11L)
  )
  DB <- data.table::copy(RAW)
  DB[SourcePath == "source/PCG/Vega/VP-5_x.xlsx", HoleID := "VP-5"]
  REPAIRS <- data.table::data.table(
    ID = "PCG",
    SourcePath = "source/PCG/Vega/VP-5_x.xlsx",
    FileKey = "VP-5"
  )
  list(raw = RAW, db = DB, repairs = REPAIRS)
}

.censusLog <- function(rawData, dbIndex, repairs) {
  Log <- tempfile(fileext = ".csv")
  dbAudit:::.logEventInit(log.file = Log)
  dbAudit:::.checkRawDBKeys(
    log = Log, rawData = rawData, dbIndex = dbIndex, repairs = repairs
  )
  data.table::fread(file = Log)
}

test_that("a repaired record that reached the db does not fire MISSING", {
  AUX <- .censusTables()
  Log <- .censusLog(rawData = AUX$raw, dbIndex = AUX$db, repairs = AUX$repairs)
  expect_identical(nrow(Log[event == "MISSING"]), 0L)
})

test_that("a repaired record lost on the way to db still fires MISSING", {
  ## The exact blind spot the discount design would hide: one repaired
  ## row never lands in db. The census, comparing raw under the
  ## repaired key, must see exactly that one raw record as missing.
  AUX <- .censusTables()
  Log <- .censusLog(
    rawData = AUX$raw,
    dbIndex = AUX$db[!(SourcePath == "source/PCG/Vega/VP-5_x.xlsx" &
                         SourceRow == 12L)],
    repairs = AUX$repairs
  )
  MISS <- Log[event == "MISSING"]
  expect_identical(nrow(MISS), 1L)
  expect_identical(MISS$source, "data/db")
  expect_match(MISS$detail, "raw records missing in db; count=1", fixed = TRUE)
})

test_that("without the repairs table the typed key still mismatches", {
  ## The pre-fix behavior, pinned so the rekey's effect stays
  ## observable at the unit level: raw typed vs db repaired emits the
  ## two mirrored MISSING.
  AUX <- .censusTables()
  Log <- .censusLog(rawData = AUX$raw, dbIndex = AUX$db, repairs = NULL)
  expect_identical(
    Log[event == "MISSING", .N], 2L
  )
})

test_that("the caller's raw table keeps the typed key after the census", {
  ## The rekey operates on the census's owned projection; data/raw
  ## evidence (and every downstream check reading it) stays typed.
  AUX <- .censusTables()
  invisible(.censusLog(rawData = AUX$raw, dbIndex = AUX$db, repairs = AUX$repairs))
  expect_identical(unique(AUX$raw[grepl("VP-5_", SourcePath), HoleID]), "VP-50")
})
