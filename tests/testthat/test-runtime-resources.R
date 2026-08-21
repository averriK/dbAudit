# Runtime resources must resolve from the installation, not only from the
# R package: the documented install puts the command line on the machine
# and never installs the package, so system.file() answers "" there and
# every run that needed the catalog or the manifest stopped.

test_that("a resource unknown to the package resolves from DBAUDIT_HOME", {
  home <- tempfile("home")
  dir.create(file.path(home, "inst", "extdata"), recursive = TRUE)
  target <- file.path(home, "inst", "runtime-only.csv")
  writeLines("x", target)
  old <- Sys.getenv("DBAUDIT_HOME")
  Sys.setenv(DBAUDIT_HOME = home)
  on.exit({ Sys.setenv(DBAUDIT_HOME = old); unlink(home, recursive = TRUE) }, add = TRUE)

  found <- .dbauditResource("runtime-only.csv")
  expect_true(nzchar(found))
  expect_identical(normalizePath(found), normalizePath(target))
})

test_that("a resource that exists nowhere returns empty, never a bad path", {
  old <- Sys.getenv("DBAUDIT_HOME")
  Sys.setenv(DBAUDIT_HOME = tempfile("absent"))
  on.exit(Sys.setenv(DBAUDIT_HOME = old), add = TRUE)
  expect_identical(.dbauditResource("no-such-resource.csv"), "")
})

test_that("the catalog and the manifest are both reachable in this session", {
  expect_true(nzchar(.dbauditResource("events.csv")))
  expect_true(nzchar(.dbauditResource("extdata", "piezometer-manifest.json")))
})
