#!/usr/bin/env Rscript

# verifyDocs.R
# Guard against documentation drift across the three dbAudit domains:
# path defaults, subcommands, required packages, the event catalog table,
# and a local (never versioned) forbidden-pattern list.
#
# Usage:
#   Rscript inst/scripts/verifyDocs.R

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

.mustContainAll <- function(label, text, patterns) {
  miss <- patterns[!vapply(patterns, function(p) grepl(p, text, fixed = TRUE), logical(1))]
  if (length(miss)) {
    .fail(sprintf("%s: missing required token(s): %s", label, paste(miss, collapse = ", ")))
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
  .fail("Cannot locate script path (--file=... missing). Run via Rscript inst/scripts/verifyDocs.R")
}

root <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)

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

# ----------------------------------------------------------------------
# Subcommand coverage: derive the list from the live CLI usage line so a
# new subcommand extends the doc requirements without editing this guard.

.mustContainAll("CLI help (subcommands)", help.out, c("geochemistry", "piezometer", "inclinometer"))

usage <- regmatches(help.out, regexpr("dbaudit \\[[a-z|]+\\]", help.out))
if (!length(usage)) .fail("CLI help: cannot locate the 'dbaudit [sub|sub|...]' usage line")
subcommands <- strsplit(gsub("^dbaudit \\[|\\]$", "", usage), "|", fixed = TRUE)[[1]]
subcommand.tokens <- paste("dbaudit", subcommands)

# ----------------------------------------------------------------------
# Monitoring path defaults (single source of truth, like the geochemistry
# defaults above) and required R packages.

source(file.path(root, "R", "auditPiezometer.R"))
if (!exists(".piezometerPathDefaults", mode = "any")) {
  .fail(".piezometerPathDefaults not found after sourcing R/auditPiezometer.R")
}
mon <- get(".piezometerPathDefaults", mode = "any")
mon.names <- c("source.dir.name", "raw.dir.name", "db.dir.name", "audit.dir.name")
if (!is.list(mon) || !all(mon.names %in% names(mon))) {
  .fail(sprintf(".piezometerPathDefaults must be a list with %s", paste(mon.names, collapse = ", ")))
}
mon.tokens <- paste0(as.character(unlist(mon[mon.names])), "/")

source(file.path(root, "R", "setup.R"))
if (!exists(".dbauditRequiredPkgs", mode = "any")) {
  .fail(".dbauditRequiredPkgs not found after sourcing R/setup.R")
}
pkgs <- as.character(get(".dbauditRequiredPkgs", mode = "any"))

# Pages that document the executable surface carry every subcommand and
# both input layouts; pages on the installation axis carry the full
# package list (the 3-package stale list survived here for seven months).
checks <- list(
  list(path = "docs/quickstart.md", require = c(subcommand.tokens, lab.def, assay.def, proc.def, mon.tokens)),
  list(path = "docs/project-layout.md", require = c(subcommand.tokens, lab.def, assay.def, proc.def, mon.tokens)),
  list(path = "docs/install.md", require = pkgs),
  list(path = "docs/macos.md", require = pkgs),
  list(path = "docs/troubleshooting.md", require = pkgs),
  list(path = "docs/windows.md", require = pkgs)
)

for (c in checks) {
  txt <- .readText(file.path(root, c$path))
  .mustContainAll(sprintf("%s", c$path), txt, c$require)
  .ok(sprintf("Checked %s (three-domain tokens)", c$path))
}

# ----------------------------------------------------------------------
# Event catalog table in docs/logging.md must match inst/events.csv
# exactly, pair by pair (event, scope). The reference list is derived
# from the CSV here, never hardcoded.

catalog <- utils::read.csv(file.path(root, "inst", "events.csv"), stringsAsFactors = FALSE)
if (!all(c("event", "scope") %in% names(catalog))) {
  .fail("inst/events.csv: expected columns event, scope")
}
pairs.catalog <- paste0(catalog$event, " @ ", gsub(";", ", ", catalog$scope, fixed = TRUE))

logging.lines <- readLines(file.path(root, "docs", "logging.md"), warn = FALSE)
rows <- grep("^\\|\\s*`[A-Z]+`\\s*\\|", logging.lines, value = TRUE)
if (!length(rows)) .fail("docs/logging.md: event catalog table not found (no | `EVENT` | rows)")

pairs.docs <- vapply(rows, function(s) {
  cells <- trimws(strsplit(sub("^\\|", "", s), "|", fixed = TRUE)[[1]])
  paste0(gsub("`", "", cells[1], fixed = TRUE), " @ ", cells[2])
}, character(1), USE.NAMES = FALSE)

miss <- setdiff(pairs.catalog, pairs.docs)
extra <- setdiff(pairs.docs, pairs.catalog)
if (length(miss)) {
  .fail(sprintf("docs/logging.md: catalog rows missing from the event table: %s", paste(miss, collapse = "; ")))
}
if (length(extra)) {
  .fail(sprintf("docs/logging.md: event table rows not in inst/events.csv: %s", paste(extra, collapse = "; ")))
}
.ok(sprintf("docs/logging.md event table matches inst/events.csv (%d rows)", length(pairs.catalog)))

# ----------------------------------------------------------------------
# Forbidden patterns: engagement identities must never appear in the
# published documentation surface. The pattern list lives OUTSIDE the
# repository (~/.dbaudit-forbidden-patterns.txt, one case-insensitive
# fixed substring per line, # comments allowed) precisely so the names
# themselves are never published. Missing file = skip with a note.

patterns.file <- path.expand("~/.dbaudit-forbidden-patterns.txt")
if (!file.exists(patterns.file)) {
  writeLines("NOTE: forbidden-pattern check skipped (~/.dbaudit-forbidden-patterns.txt not found)")
} else {
  patterns <- trimws(readLines(patterns.file, warn = FALSE))
  patterns <- patterns[nzchar(patterns) & !startsWith(patterns, "#")]
  if (!length(patterns)) {
    writeLines("NOTE: forbidden-pattern check skipped (pattern file is empty)")
  } else {
    scan.files <- c(
      file.path(root, "README.md"),
      list.files(file.path(root, "docs"), pattern = "\\.(md|yml|html)$", recursive = TRUE, full.names = TRUE)
    )
    hits <- character(0)
    for (f in scan.files) {
      txt <- tolower(.readText(f))
      bad <- patterns[vapply(patterns, function(p) grepl(tolower(p), txt, fixed = TRUE), logical(1))]
      if (length(bad)) {
        rel <- sub(paste0(root, "/"), "", f, fixed = TRUE)
        hits <- c(hits, sprintf("%s: %s", rel, paste(bad, collapse = ", ")))
      }
    }
    if (length(hits)) {
      .fail(sprintf("forbidden pattern(s) found in the documentation surface:\n  %s", paste(hits, collapse = "\n  ")))
    }
    .ok(sprintf("Forbidden-pattern scan clean (%d patterns over %d files)", length(patterns), length(scan.files)))
  }
}

.ok("Doc drift guard passed")
