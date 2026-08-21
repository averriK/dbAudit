# Runtime resources must resolve from the installation, not from the R
# package: the documented install puts the command line on the machine
# and never installs the package, so system.file() answers "" there and
# every run that needed the catalog or the manifest stopped.

test_that("a resource resolves from DBAUDIT_HOME when the package is absent", {
  home <- tempfile("home")
  dir.create(file.path(home, "inst", "extdata"), recursive = TRUE)
  writeLines("x", file.path(home, "inst", "events.csv"))
  old <- Sys.getenv("DBAUDIT_HOME")
  Sys.setenv(DBAUDIT_HOME = home)
  on.exit({ Sys.setenv(DBAUDIT_HOME = old); unlink(home, recursive = TRUE) }, add = TRUE)

  found <- .dbauditResource("events.csv")
  expect_true(nzchar(found))
  expect_identical(normalizePath(found), normalizePath(file.path(home, "inst", "events.csv")))
})

test_that("a resource that exists nowhere returns empty, never a bad path", {
  old <- Sys.getenv("DBAUDIT_HOME")
  Sys.setenv(DBAUDIT_HOME = tempfile("absent"))
  on.exit(Sys.setenv(DBAUDIT_HOME = old), add = TRUE)
  expect_identical(.dbauditResource("no-such-resource.csv"), "")
})

test_that("the event catalog is reachable in this session", {
  expect_true(nzchar(.dbauditResource("events.csv")))
})
