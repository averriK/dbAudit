test_that("docs drift guard passes on the checkout", {
  root <- normalizePath(file.path(test_path(), "..", ".."), mustWork = TRUE)
  script <- file.path(root, "inst", "scripts", "verifyDocs.R")

  # The guard audits the checkout documentation surface; installed-package
  # runs have no docs/ tree to audit.
  skip_if_not(file.exists(script))
  skip_if_not(dir.exists(file.path(root, "docs")))

  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  out <- suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")

  expect_true(is.null(status) || identical(status, 0L), info = paste(out, collapse = "\n"))
  expect_true(any(grepl("Doc drift guard passed", out, fixed = TRUE)))
})
