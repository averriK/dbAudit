# Type-A header sub-variant (plan: dev/SoT/PLAN-parse-locale-tipoA.md):
# keys with a space before the colon, extra CLIENT/PROJECT/CERTIFICATE
# COMMENTS rows (the comment spans raw lines inside quotes), a labeled
# METHOD row, and numeric dates. Synthetic fixture, known truth.

test_that("the type-A sub-variant parses with correct metadata and values", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c(
    'LabjobNo :,SYN0001.R25,"",""',
    'DespatchNo :,SYND202500001,"",""',
    'CLIENT :,SYNTHETIC MINING CO.,"",""',
    '# of SAMPLES :,2,"",""',
    'DATE RECEIVED :,18/02/2025,"",""',
    'DATE FINALIZED :,27/02/2025,"",""',
    'PROJECT :,SYNPRJ / TST,"",""',
    'CERTIFICATE COMMENTS :,"comment line one',
    'comment line two","",""',
    '"","","",""',
    'METHOD,"",G0100,G0200',
    'SAMPLE,Analysis Order,Au,Cu',
    'DESCRIPTION,"",PPM,PCT',
    'MIN DETECTION,"",0.005,0.01',
    'MAX DETECTION,"",10,50',
    'SYN00000001,1,0.013,1.29',
    'SYN00000002,2,<0.005,0.61'
  ), f)
  lg <- tempfile(fileext = ".csv")
  out <- .parseLabDataA(f, log.file = lg)

  expect_identical(nrow(out$INDEX), 2L)
  expect_identical(out$INDEX$jobID[1], "SYN0001.R25")
  expect_identical(out$INDEX$despatchID[1], "SYND202500001")
  expect_identical(out$INDEX$dateReceived[1], "2025-02-18")
  expect_identical(out$INDEX$dateFinalized[1], "2025-02-27")
  expect_identical(out$INDEX$sampleN[1], 2)

  expect_identical(nrow(out$DATA), 4L)
  au <- out$DATA[elementID == "Au"][order(sampleID)]
  expect_identical(au$value, c(0.013, 0.005))
  expect_identical(au$tagDL, c("+", "<"))

  log.lines <- readLines(lg)
  expect_true(any(grepl("PARSE_OK", log.lines)))
  expect_false(any(grepl("PARSE_ERROR", log.lines)))
})

test_that("an unresolvable date degrades to NA without killing the certificate", {
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines(c(
    'LabjobNo:,SYN0002.R25,"",""',
    'DespatchNo:,SYND202500002,"",""',
    '# of SAMPLES:,1,"",""',
    'DATE RECEIVED:,05-Avr-2025,"",""',
    'DATE FINALIZED:,quince de marzo,"",""',
    'ESTADO:,Terminado,"",""',
    '"","",G0100,G0200',
    'SAMPLE,Analysis Order,Au,Cu',
    'DESCRIPTION,"",PPM,PCT',
    'MIN DETECTION,"",0.005,0.01',
    'MAX DETECTION,"",10,50',
    'SYN00000003,1,0.021,0.87'
  ), f)
  lg <- tempfile(fileext = ".csv")
  out <- .parseLabDataA(f, log.file = lg)

  expect_identical(nrow(out$DATA), 2L)
  expect_identical(out$INDEX$dateReceived[1], NA_character_)
  expect_identical(out$INDEX$dateFinalized[1], NA_character_)
  log.lines <- readLines(lg)
  expect_true(any(grepl("PARSE_OK", log.lines)))
  expect_false(any(grepl("PARSE_ERROR", log.lines)))
})
