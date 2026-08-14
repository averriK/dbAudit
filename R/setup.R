.dbauditRequiredPkgs <- c("data.table", "stringr", "lubridate", "readxl", "jsonlite")

.dbauditMissingPkgs <- function() {
  .dbauditRequiredPkgs[!vapply(.dbauditRequiredPkgs, requireNamespace, logical(1), quietly = TRUE)]
}

.dbauditInstallPkgs <- function(pkgs) {
  repos <- getOption("repos")
  if (is.null(repos) || length(repos) == 0L || isTRUE(all(repos == "@CRAN@"))) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }

  message("Installing missing R packages: ", paste(pkgs, collapse = ", "))
  message("This may take a few minutes on first run...\n")

  if (.Platform$OS.type == "windows") {
    message("Note: Installing pre-compiled binaries (Windows does not compile from source)\n")
    utils::install.packages(pkgs, type = "binary")
  } else {
    utils::install.packages(pkgs)
  }
}

.dbauditLoadRuntime <- function(install = TRUE) {
  missing <- .dbauditMissingPkgs()

  if (length(missing) > 0L && isTRUE(install)) {
    ok <- tryCatch({
      .dbauditInstallPkgs(missing)
      TRUE
    }, error = function(e) {
      message("\nERROR: Failed to install R packages automatically.")
      message("Error details: ", conditionMessage(e))
      message("\nTroubleshooting:")
      message("  1. Check internet connectivity")
      message("  2. Verify CRAN mirror is accessible: https://cloud.r-project.org")
      if (.Platform$OS.type == "windows") {
        message("  3. Check if binary packages are available for your R version")
        message("  4. Try manual installation in R console:")
        message("       install.packages(c(\"", paste(missing, collapse = "\", \""), "\"), type=\"binary\")")
        message("  5. Check library path permissions: .libPaths()")
        message("\nNOTE: Windows cannot compile R packages from source without Rtools.")
      } else {
        message("  3. Try manual installation in R console:")
        message("       install.packages(c(\"", paste(missing, collapse = "\", \""), "\"))")
        message("  4. Check library path permissions: .libPaths()")
      }
      FALSE
    })

    if (!isTRUE(ok)) {
      stop("Cannot proceed without required R packages. See troubleshooting steps above.")
    }

    missing <- .dbauditMissingPkgs()
  }

  if (length(missing) > 0L) {
    stop(sprintf(
      "Missing required R packages: %s",
      paste(missing, collapse = ", ")
    ))
  }

  suppressPackageStartupMessages({
    library(data.table)
    library(stringr)
    library(lubridate)
  })

  invisible(TRUE)
}
