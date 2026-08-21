# Locale-independent date parsing (plan: dev/SoT/PLAN-parse-locale-tipoA.md).
# The observed failure: English month abbreviations unparseable under a
# Spanish system locale because %b/%B are locale-dependent.

test_that(".as.Date resolves month names to ISO regardless of language", {
  expect_identical(.as.Date("10-Apr-2025"), "2025-04-10")
  expect_identical(.as.Date("31-Mar-2025"), "2025-03-31")
  expect_identical(.as.Date("10-ABR-2025"), "2025-04-10")
  expect_identical(.as.Date("1-dic-2024"), "2024-12-01")
  expect_identical(.as.Date("15 AGO 2023"), "2023-08-15")
  expect_identical(.as.Date("6 May 24"), "2024-05-06")
  expect_identical(.as.Date("18/02/2025"), "2025-02-18")
  expect_identical(.as.Date("2025-04-10"), "2025-04-10")
  expect_identical(.as.Date(""), NA_character_)
})

test_that(".as.Date is immune to a Spanish LC_TIME", {
  old <- Sys.getlocale("LC_TIME")
  on.exit(suppressWarnings(Sys.setlocale("LC_TIME", old)), add = TRUE)
  ok <- FALSE
  for (loc in c("es_ES.UTF-8", "es_PE.UTF-8", "es_AR.UTF-8", "Spanish")) {
    if (!inherits(try(suppressWarnings(Sys.setlocale("LC_TIME", loc)), silent = TRUE), "try-error") &&
        identical(Sys.getlocale("LC_TIME"), loc)) { ok <- TRUE; break }
  }
  skip_if_not(ok, "no Spanish LC_TIME available on this host")
  expect_identical(.as.Date("10-Apr-2025"), "2025-04-10")
  expect_identical(.as.Date("31-Mar-2025"), "2025-03-31")
  expect_identical(.as.Date("10-Abr-2025"), "2025-04-10")
})

test_that(".as.Date degrades to NA on unsupported languages, never throws", {
  expect_no_error(v <- .as.Date("05-Avr-2025"))
  expect_identical(v, NA_character_)
  expect_identical(.as.Date("05-Okt-2025"), NA_character_)
  expect_identical(.as.Date("not a date"), NA_character_)
})
