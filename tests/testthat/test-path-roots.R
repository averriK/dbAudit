# Deriving the site from a path must not treat the root as a pattern
# (plan: dev/SoT/PLAN-site-from-path.md). On Windows the root carries
# backslashes and a drive colon — regex metacharacters — so the strip
# matched nothing, the whole absolute path became the SiteID, and it
# then became a directory name under raw/: invalid on Windows, a nested
# tree on POSIX.

test_that("the site is the first segment below the root", {
  root <- file.path(tempfile("root"), "source")
  f <- file.path(root, "PCG", "Vega", "VP-1.xlsx")
  dir.create(dirname(f), recursive = TRUE)
  file.create(f)
  on.exit(unlink(dirname(root), recursive = TRUE), add = TRUE)

  expect_identical(siteFromPath(path = f, root = root), "PCG")
  expect_identical(.relativeParts(file = f, root = root), c("PCG", "Vega", "VP-1.xlsx"))
})

test_that("a root holding regex metacharacters still strips", {
  # A real client tree carries dots, parentheses and plus signs; a
  # Windows root carries a drive colon and backslashes.
  root <- file.path(tempfile("r.oot(1)+"), "source")
  f <- file.path(root, "Site.A", "Hole+1", "file.xlsx")
  dir.create(dirname(f), recursive = TRUE)
  file.create(f)
  on.exit(unlink(dirname(root), recursive = TRUE), add = TRUE)

  expect_identical(siteFromPath(path = f, root = root), "Site.A")
  expect_identical(.relativeParts(file = f, root = root)[2L], "Hole+1")
})

test_that("the site is never a path", {
  root <- file.path(tempfile("root"), "source")
  f <- file.path(root, "INC", "Vega", "s.csv")
  dir.create(dirname(f), recursive = TRUE)
  file.create(f)
  on.exit(unlink(dirname(root), recursive = TRUE), add = TRUE)

  site <- siteFromPath(path = f, root = root)
  expect_false(grepl("[/\\\\:]", site))
})
