## Golden regression on the synthetic fixtures.
##
## The synthetic fixtures under tests/testthat/fixtures/ carry no client
## material and ship with the package, so unlike the local-only real
## fixtures these goldens run everywhere, including R CMD check. Values
## recorded 2026-08-12 from fresh runs proven independent of the project
## path. The generator is dev/buildFixtures.R; regenerating the fixtures is
## an intentional contract change and re-records these values.
##
## DBAudit() is wrapped in suppressWarnings: the type-A leading-index-column
## detector recycles a comparison on files this small, which is harmless
## noise; the assertions here are the md5s and the log event counts.

.syntheticGolden <- function(name, lab.dir.name, assay.dir.name) {
  path.source <- test_path("fixtures", name)
  path <- file.path(tempdir(), paste0("golden-", name))
  if (dir.exists(path)) unlink(path, recursive = TRUE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  file.copy(
    c(
      file.path(path.source, lab.dir.name),
      file.path(path.source, assay.dir.name)
    ),
    path,
    recursive = TRUE
  )
  suppressWarnings(DBAudit(
    project.path = path,
    lab.dir.name = lab.dir.name,
    assay.dir.name = assay.dir.name
  ))
}

.expectSyntheticGolden <- function(out, md5, counts) {
  observed <- tools::md5sum(c(out$lab.file, out$index.file, out$client.file))
  expect_identical(unname(observed), unname(md5))

  log <- data.table::fread(out$log.file)
  observed.counts <- log[, .N, by = .(level, event)]
  data.table::setorder(observed.counts, level, event)
  expected.counts <- data.table::as.data.table(counts)
  data.table::setorder(expected.counts, level, event)
  expect_equal(
    as.data.frame(observed.counts),
    as.data.frame(expected.counts)
  )
}

test_that("synthetic-A reproduces the recorded golden outputs", {
  out <- .syntheticGolden("synthetic-A", lab.dir.name = "raw", assay.dir.name = "assay")
  .expectSyntheticGolden(
    out,
    md5 = c(
      lab = "c79782c6db0b658b65024995c3a4c092",
      index = "900e2da08077c094f764b5318d438792",
      client = "347dab27b8bea96b1210973df446b82d"
    ),
    counts = data.frame(
      level = c("ERROR", "INFO", "INFO", "INFO", "INFO", "WARNING"),
      event = c(
        "WRONG_VALUE", "CLIENT_FILE_START", "CLIENT_PARSE_OK", "FILE_START",
        "PARSE_OK", "VALUE_MISMATCH"
      ),
      N = c(1L, 1L, 1L, 1L, 1L, 1L)
    )
  )
})

test_that("synthetic-B reproduces the recorded golden outputs", {
  out <- .syntheticGolden("synthetic-B", lab.dir.name = "raw", assay.dir.name = "assay")
  .expectSyntheticGolden(
    out,
    md5 = c(
      lab = "cab24c6639b75cc0438e4314208c24cb",
      index = "a3854b238bfb2762da1ca4f6fad3c32e",
      client = "ad6d173cb56e1e550eb33e3a5ad409e1"
    ),
    counts = data.frame(
      level = c(
        "ERROR", "ERROR",
        "INFO", "INFO", "INFO", "INFO",
        "WARNING", "WARNING"
      ),
      event = c(
        "MISSING_LAB_ANALYTE", "WRONG_VALUE",
        "CLIENT_FILE_START", "CLIENT_PARSE_OK", "FILE_START", "PARSE_OK",
        "CLIENT_ANALYTE_NOT_IN_LAB", "VALUE_MISMATCH"
      ),
      N = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L)
    )
  )
})
