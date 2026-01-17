#!/usr/bin/env Rscript

# verifyDocs.R
# Guard against documentation drift for dbAudit path defaults.
#
# Usage:
#   Rscript R/verifyDocs.R

.fail <- function(msg) {
  writeLines(paste0("ERROR: ", msg), con = stderr())
  quit(save = "no", status = 1)
}

.ok <- function(msg) {
  writeLines(paste0("OK: ", msg))
}

.readText <- function(path) {
  if (!file.exists(path)) .fail(sprintf("Missing file: %s", path))
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

.containsAny <- function(text, patterns) {
  any(vapply(patterns, function(p) grepl(p, text, fixed = TRUE), logical(1)))
}

.mustContainAny <- function(label, text, patterns) {
  if (!.containsAny(text, patterns)) {
    .fail(sprintf("%s: expected one of [%s]", label, paste(patterns, collapse = ", ")))
  }
}

.mustNotContainAny <- function(label, text, patterns) {
  bad <- patterns[vapply(patterns, function(p) grepl(p, text, fixed = TRUE), logical(1))]
  if (length(bad)) {
    .fail(sprintf("%s: contains forbidden token(s): %s", label, paste(bad, collapse = ", ")))
  }
}

.getScriptFile <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  hit <- grep("^--file=", args, value = TRUE)
  if (!length(hit)) return(NA_character_)
  sub("^--file=", "", hit[1])
}

script <- .getScriptFile()
if (is.na(script) || !nzchar(script)) {
  .fail("Cannot locate script path (--file=... missing). Run via Rscript R/verifyDocs.R")
}

root <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)

# Load canonical defaults (single source of truth)
source(file.path(root, "R", "dbAudit.R"))

if (!exists(".dbauditPathDefaults", mode = "any")) {
  .fail(".dbauditPathDefaults not found after sourcing R/dbAudit.R")
}

def <- get(".dbauditPathDefaults", mode = "any")
if (!is.list(def) || is.null(def$lab.dir.name) || is.null(def$assay.dir.name) || is.null(def$proc.dir.name)) {
  .fail(".dbauditPathDefaults must be a list with lab.dir.name, assay.dir.name, proc.dir.name")
}

lab.def <- as.character(def$lab.dir.name)
assay.def <- as.character(def$assay.dir.name)
proc.def <- as.character(def$proc.dir.name)

docs.url <- if (exists(".dbauditDocsUrl", mode = "any")) as.character(get(".dbauditDocsUrl", mode = "any")) else ""
if (!nzchar(docs.url)) docs.url <- "https://averrik.github.io/dbAudit/docs/"

# Folder defaults may appear with or without trailing slash in docs.
lab.tokens <- unique(c(lab.def, paste0(lab.def, "/")))
assay.tokens <- unique(c(assay.def, paste0(assay.def, "/")))
proc.tokens <- unique(c(proc.def, paste0(proc.def, "/")))

# ----------------------------------------------------------------------
# Validate CLI help output matches canonical defaults
# NOTE: Do NOT call bin/dbaudit from inside R, because R subprocesses may not inherit
# a PATH that can resolve Rscript. Instead, call the entrypoint script using an
# absolute Rscript path from R.home().

rscript.bin <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
if (!file.exists(rscript.bin)) {
  .fail(sprintf("Cannot locate Rscript under R.home('bin'): %s", rscript.bin))
}

entrypoint <- file.path(root, "DBAudit")
if (!file.exists(entrypoint)) .fail("Missing CLI entrypoint script: DBAudit")

help.out <- tryCatch(
  paste(system2(rscript.bin, c(entrypoint, "--help"), stdout = TRUE, stderr = TRUE), collapse = "\n"),
  error = function(e) paste("", conditionMessage(e))
)

.mustContainAny("CLI help (lab default)", help.out, lab.tokens)
.mustContainAny("CLI help (assay default)", help.out, assay.tokens)
.mustContainAny("CLI help (proc default)", help.out, proc.tokens)
.mustContainAny("CLI help (docs url)", help.out, c(docs.url))
.ok("CLI help defaults and docs URL")

# ----------------------------------------------------------------------
# Validate repo docs + README contain canonical defaults
checks <- list(
  list(path = "README.md", require = c(lab.tokens, assay.tokens, proc.tokens), forbid = c("raw/assays", "raw/labs")),
  list(path = "docs/quickstart.md", require = c(lab.tokens, assay.tokens, proc.tokens), forbid = c("raw/assays", "raw/labs")),
  list(path = "docs/project-layout.md", require = c(lab.tokens, assay.tokens, proc.tokens), forbid = c("raw/assays", "raw/labs")),
  list(path = "docs/home.md", require = c("--project", proc.tokens), forbid = character()),
  list(path = "docs/macos.md", require = c("install/uninstall.sh"), forbid = c("uninstall.bash.sh")),
  list(path = "install/install.sh", require = c(docs.url), forbid = c("https://averrik.github.io/dbAudit/\"")),
  # Windows: discourage documenting non-canonical launcher names (case variants)
  list(path = "docs/windows.md", require = c("install\\install.ps1", "install\\uninstall.ps1", "dbaudit"), forbid = c("dbAudit.cmd", "DBAudit.cmd"))
)

for (c in checks) {
  p <- file.path(root, c$path)
  txt <- .readText(p)
  if (length(c$require)) {
    .mustContainAny(sprintf("%s", c$path), txt, c$require)
  }
  if (!is.null(c$forbid) && length(c$forbid)) {
    .mustNotContainAny(sprintf("%s", c$path), txt, c$forbid)
  }
  .ok(sprintf("Checked %s", c$path))
}

.ok("Doc drift guard passed")
