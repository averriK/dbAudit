# The input directory is found by convention, and source paths are
# recorded relative to the project root. Both broke on Windows: the
# prefix strip compared a backslash root against forward-slash walked
# paths, so products shipped absolute machine paths.

test_that("source paths are recorded relative to the project root", {
  root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  paths <- file.path(root, c("source/PCG/S/a.xlsx", "source/PCV/S/b.xlsx"))
  expect_identical(
    .relativeToRoot(paths, root),
    c("source/PCG/S/a.xlsx", "source/PCV/S/b.xlsx")
  )
})

test_that("a root that does not match is left whole, never truncated", {
  expect_identical(.relativeToRoot("/elsewhere/x.xlsx", tempdir()), "/elsewhere/x.xlsx")
})

test_that("either conventional input directory is found without a flag", {
  for (name in c("source", "data")) {
    root <- tempfile("proj")
    dir.create(file.path(root, name, "PCG"), recursive = TRUE)
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    expect_identical(
      .resolveSourceDir(root, "source", c("PCG", "PCV", "INC"), explicit = FALSE),
      file.path(root, name)
    )
  }
})

test_that("an explicit directory wins over the convention", {
  root <- tempfile("proj")
  dir.create(file.path(root, "data", "PCG"), recursive = TRUE)
  dir.create(file.path(root, "mine", "PCG"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_identical(
    .resolveSourceDir(root, "mine", c("PCG", "PCV", "INC"), explicit = TRUE),
    file.path(root, "mine")
  )
})
