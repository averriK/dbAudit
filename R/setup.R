# Dependencies
# This file is sourced by the CLI (`DBAudit`) and by interactive sessions.
# It installs missing packages (first run only) and then loads them.

.requiredPkgs <- c("data.table", "stringr", "lubridate")

.missingPkgs <- .requiredPkgs[!vapply(.requiredPkgs, requireNamespace, logical(1), quietly = TRUE)]

if (length(.missingPkgs) > 0L) {
  repos <- getOption("repos")
  if (is.null(repos) || length(repos) == 0L || isTRUE(all(repos == "@CRAN@"))) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  message("Installing missing R packages: ", paste(.missingPkgs, collapse = ", "))
  install.packages(.missingPkgs)
}

suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(lubridate)
})
