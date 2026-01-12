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
  message("This may take a few minutes on first run...\n")

  # Determine if we're on Windows (use binaries only, no compilation)
  is_windows <- .Platform$OS.type == "windows"

  if (is_windows) {
    message("Note: Installing pre-compiled binaries (Windows does not compile from source)\n")
  }

  install_success <- tryCatch({
    if (is_windows) {
      # Windows: ALWAYS use binaries, never compile from source (would require Rtools)
      install.packages(.missingPkgs, type = "binary")
    } else {
      # macOS/Linux: can compile from source if needed
      install.packages(.missingPkgs)
    }
    TRUE
  }, error = function(e) {
    message("\nERROR: Failed to install R packages automatically.")
    message("Error details: ", conditionMessage(e))
    message("\nTroubleshooting:")
    message("  1. Check internet connectivity")
    message("  2. Verify CRAN mirror is accessible: https://cloud.r-project.org")

    if (is_windows) {
      message("  3. Check if binary packages are available for your R version")
      message("  4. Try manual installation in R console:")
      message("       install.packages(c(\"", paste(.missingPkgs, collapse = "\", \""), "\"), type=\"binary\")")
      message("  5. Check library path permissions: .libPaths()")
      message("\nNOTE: Windows cannot compile R packages from source without Rtools.")
      message("      If binaries are unavailable, upgrade R to a version with binary packages.")
    } else {
      message("  3. Try manual installation in R console:")
      message("       install.packages(c(\"", paste(.missingPkgs, collapse = "\", \""), "\"))")
      message("  4. Check library path permissions: .libPaths()")
      message("  5. If using corporate network, check proxy settings")
    }
    FALSE
  })

  if (!install_success) {
    stop("Cannot proceed without required R packages. See troubleshooting steps above.")
  }

  # Verify all packages installed successfully
  still_missing <- .missingPkgs[!vapply(.missingPkgs, requireNamespace, logical(1), quietly = TRUE)]

  if (length(still_missing) > 0L) {
    stop(sprintf(
      "Package installation reported success but packages still missing: %s\n\nPlease install manually.",
      paste(still_missing, collapse = ", ")
    ))
  }

  message("Packages installed successfully.\n")
}

suppressPackageStartupMessages({
  library(data.table)
  library(stringr)
  library(lubridate)
})
