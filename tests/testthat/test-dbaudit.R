test_that("DBAudit is exported", {
  expect_true(is.function(DBAudit))
})

test_that("checkout examples can run when available", {
  root <- normalizePath(file.path(test_path(), "..", ".."), mustWork = TRUE)
  path.source <- file.path(root, "project", "test-A")
  skip_if_not(dir.exists(path.source))

  path <- file.path(tempdir(), paste0("dbAudit-", basename(path.source)))
  if (dir.exists(path)) unlink(path, recursive = TRUE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  file.copy(
    list.files(path.source, all.files = TRUE, no.. = TRUE, full.names = TRUE),
    path,
    recursive = TRUE
  )

  out <- DBAudit(
    project.path = path,
    lab.dir.name = "raw",
    assay.dir.name = "assay"
  )
  expect_true(file.exists(out$log.file))
  expect_true(file.exists(out$lab.file))
  expect_true(file.exists(out$client.file))
})
