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

  # Without an explicit library, a non-interactive R on Windows has
  # nowhere writable to install into and cannot ask: it fails and the
  # user never gets the packages. Ensure the personal library exists and
  # install there.
  Lib <- .libPaths()[1L]
  Writable <- !is.na(Lib) && dir.exists(Lib) && file.access(Lib, mode = 2L) == 0L
  if (!isTRUE(Writable)) {
    Personal <- Sys.getenv("R_LIBS_USER")
    if (nzchar(Personal)) {
      Personal <- strsplit(Personal, .Platform$path.sep, fixed = TRUE)[[1L]][1L]
      Personal <- path.expand(Personal)
      if (!dir.exists(Personal)) {
        dir.create(Personal, recursive = TRUE, showWarnings = FALSE)
      }
      if (dir.exists(Personal)) {
        .libPaths(c(Personal, .libPaths()))
        Lib <- Personal
      }
    }
  }
  if (!dir.exists(Lib) || file.access(Lib, mode = 2L) != 0L) {
    stop(paste(
      "No writable R library to install into.\n",
      "Create one and try again, for example:\n",
      "  Rscript -e 'dir.create(Sys.getenv(\"R_LIBS_USER\"), recursive = TRUE)'"
    ), call. = FALSE)
  }

  if (.Platform$OS.type == "windows") {
    message("Note: Installing pre-compiled binaries (Windows does not compile from source)\n")
    utils::install.packages(pkgs, lib = Lib, type = "binary")
  } else {
    utils::install.packages(pkgs, lib = Lib)
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
