# A transient log-write failure must not destroy completed work
# (plan: dev/SoT/PLAN-log-reintentos.md). The observed cause was a
# shared filesystem answering the per-event open burst with sharing
# violations; the failure was recorded as a parse defect until one
# escaped and aborted the run.

test_that(".log drops the record and counts it instead of throwing", {
  .logResetDropped()
  bad <- file.path(tempfile("nodir"), "log.csv")   # directory does not exist
  expect_no_error(.log(bad, "INFO", "f.csv", "PARSE_OK", "rows=1"))
  expect_identical(.dbauditLogState$dropped, 1L)
  .logResetDropped()
  expect_identical(.dbauditLogState$dropped, 0L)
})

test_that("a certificate still parses when its log line cannot be written", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c(
    'LabjobNo:,SYN0003.R25,"",""',
    'DespatchNo:,SYND202500003,"",""',
    '# of SAMPLES:,1,"",""',
    'DATE RECEIVED:,18/02/2025,"",""',
    'DATE FINALIZED:,27/02/2025,"",""',
    'ESTADO:,Terminado,"",""',
    '"","",G0100,G0200',
    'SAMPLE,Analysis Order,Au,Cu',
    'DESCRIPTION,"",PPM,PCT',
    'MIN DETECTION,"",0.005,0.01',
    'MAX DETECTION,"",10,50',
    'SYN00000004,1,0.031,1.11'
  ), f)
  .logResetDropped()
  unreachable <- file.path(tempfile("nodir"), "log.csv")
  out <- .parseLabDataA(f, log.file = unreachable)

  expect_identical(nrow(out$DATA), 2L)          # the assay values ingest
  expect_identical(out$INDEX$jobID[1], "SYN0003.R25")
  expect_gt(.dbauditLogState$dropped, 0L)       # and the gap is counted
  .logResetDropped()
})

test_that("the monitoring logger survives the same failure", {
  .logResetDropped()
  bad <- file.path(tempfile("nodir"), "log.csv")
  expect_no_error(
    .logEvent(bad, scope = "run", event = "START", source = "test")
  )
  expect_gt(.dbauditLogState$dropped, 0L)
  .logResetDropped()
})
