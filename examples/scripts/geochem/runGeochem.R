#!/usr/bin/env Rscript

ArgsAll <- commandArgs(trailingOnly = FALSE)
Hit <- grep(pattern = "^--file=", x = ArgsAll, value = TRUE)
if (!length(Hit)) stop("Cannot locate runGeochem.R path", call. = FALSE)
Script <- sub(pattern = "^--file=", replacement = "", x = Hit[1L])
source(file = file.path(dirname(normalizePath(path = Script, mustWork = TRUE)), "setup.R"))

suppressPackageStartupMessages({
  library(data.table)
  library(dbAudit)
})

Root <- .repoRoot()
Args <- commandArgs(trailingOnly = TRUE)
PATH.config <- .resolvePath(
  path = if (length(Args)) Args[1L] else file.path("examples", "scripts", "geochem", "runGeochem.json"),
  root = Root,
  mustWork = TRUE
)
Config <- .readJson(path = PATH.config, simplifyVector = FALSE)

OUT <- .runGeochem(config = Config, root = Root, path = PATH.config)
print(OUT)
