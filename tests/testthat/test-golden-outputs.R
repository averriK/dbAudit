## Golden regression for the geochemical pipeline.
##
## Runs DBAudit() on the bundled fixtures and compares the durable outputs
## against values recorded 2026-08-12 from fresh runs proven independent of
## the project path. lab.csv, index.csv and client.csv are compared by md5
## because bytes are the contract; log.csv is compared as event counts by
## (level, event) because its ts column varies and its file column embeds
## absolute paths.
##
## These tests skip outside a hydrated source checkout: project/ is excluded
## from the build tarball by .Rbuildignore and its contents are stored in Git
## LFS, so an unhydrated clone holds pointer files that dir.exists() cannot
## distinguish from data. Expect several minutes per fixture when they run.

.goldenRoot <- function() {
  normalizePath(file.path(test_path(), "..", ".."), mustWork = TRUE)
}

.isLfsPointer <- function(path) {
  line <- tryCatch(
    readLines(path, n = 1L, warn = FALSE),
    error = function(e) character(0)
  )
  length(line) == 1L && startsWith(line, "version https://git-lfs")
}

.skipUnlessFixture <- function(path.source, probe) {
  skip_if_not(dir.exists(path.source), "fixture not present (build tarball)")
  skip_if(
    .isLfsPointer(file.path(path.source, probe)),
    "fixture is an unhydrated LFS pointer"
  )
}

.runGolden <- function(path.source, lab.dir.name, assay.dir.name) {
  path <- file.path(tempdir(), paste0("golden-", basename(path.source)))
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
  DBAudit(
    project.path = path,
    lab.dir.name = lab.dir.name,
    assay.dir.name = assay.dir.name
  )
}

.expectGolden <- function(out, md5, counts) {
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

test_that("test-A reproduces the recorded golden outputs", {
  path.source <- file.path(.goldenRoot(), "project", "test-A")
  .skipUnlessFixture(path.source, file.path("assay", "_Assay_Comp.csv"))

  out <- .runGolden(path.source, lab.dir.name = "raw", assay.dir.name = "assay")
  .expectGolden(
    out,
    md5 = c(
      lab = "d8961fa0251f4b79659ddb445bd3f5f1",
      index = "1fa47dfda4e7e42191192e55847b6569",
      client = "d89bf9828a9bfe534eeae385e6e7995c"
    ),
    counts = data.frame(
      level = c("ERROR", "INFO", "INFO", "INFO", "INFO", "INFO", "WARNING"),
      event = c(
        "WRONG_JOBID", "CLIENT_FILE_START", "CLIENT_PARSE_OK", "FILE_START",
        "JOBID_FIXED", "PARSE_OK", "JOBID_MISMATCH"
      ),
      N = c(1507L, 1L, 1L, 1L, 1L, 1L, 1L)
    )
  )
})

test_that("test-B reproduces the recorded golden outputs", {
  path.source <- file.path(.goldenRoot(), "project", "test-B")
  .skipUnlessFixture(path.source, file.path("assay", "AAQ_Sample_Assay.csv"))

  out <- .runGolden(path.source, lab.dir.name = "raw", assay.dir.name = "assay")
  .expectGolden(
    out,
    md5 = c(
      lab = "d2cd25793e865743709280d8e8f382ab",
      index = "1203704ef05dceab1545e075ff6be604",
      client = "b478a39eadbe0a0f3046550472de1eba"
    ),
    counts = data.frame(
      level = c(
        "ERROR", "ERROR", "ERROR", "ERROR", "ERROR",
        "INFO", "INFO", "INFO", "INFO", "INFO", "INFO",
        "WARNING", "WARNING", "WARNING", "WARNING", "WARNING"
      ),
      event = c(
        "MISSING_LAB_ANALYTE", "SAMPLEID_NOT_UNIQUE", "WRONG_JOBID",
        "WRONG_TAGDL", "WRONG_VALUE",
        "CLIENT_FILE_START", "CLIENT_PARSE_OK", "FILE_START", "JOBID_FIXED",
        "METHOD_INFERRED", "PARSE_OK",
        "CLIENT_ANALYTE_NOT_IN_LAB", "CLIENT_EMPTY_JOBID", "JOBID_MISMATCH",
        "TAGDL_MISMATCH", "VALUE_MISMATCH"
      ),
      N = c(
        16066L, 1L, 2429L, 10L, 26L,
        1L, 1L, 1L, 1L, 2L, 1L,
        1L, 1L, 1L, 1L, 1L
      )
    )
  )
})

test_that("a missing project path fails with the declared error", {
  expect_error(
    DBAudit(project.path = file.path(tempdir(), "golden-does-not-exist")),
    "project.path not found"
  )
})
