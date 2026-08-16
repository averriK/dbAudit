# ----------------------------------------------------------------------
# eventLog.R — structured QA/QC event log, schema v2.
# Contract: dev/SoT/PLAN-event-taxonomy.md (approved 2026-08-16).
# Scope: monitoring domains (PCG, PCV, INC). The geochemistry pipeline
# keeps the v1 logger (.log in helpers.R) until its own catalog ruling.
#
# One record per observed fact, orthogonal fields:
#   ts, scope, SiteID, HoleID, datetime, source, cause, disposition,
#   flag, detail
# Severity is NOT stored: readers derive it from disposition via
# .eventLevel(). Every emission is validated against the catalog
# (inst/events.csv) — an unknown cause stops the run: messages outside
# the ruled vocabulary cannot exist.

.eventsCatalogCache <- new.env(parent = emptyenv())

.eventsCatalog <- function() {
  if (!is.null(.eventsCatalogCache$catalog)) return(.eventsCatalogCache$catalog)
  FILE <- system.file("events.csv", package = "dbAudit")
  if (!nzchar(FILE)) FILE <- file.path("inst", "events.csv")
  if (!file.exists(FILE)) {
    stop("events catalog not found (inst/events.csv)", call. = FALSE)
  }
  Catalog <- fread(FILE)
  Required <- c(
    "cause", "class", "disposition.default", "flag", "approved",
    "meaning.en", "meaning.es", "expected.action.en", "expected.action.es"
  )
  if (!all(Required %in% names(Catalog))) {
    stop("events catalog is missing required columns", call. = FALSE)
  }
  .eventsCatalogCache$catalog <- Catalog
  Catalog
}

.eventDispositions <- c(
  "intact", "corrected", "estimated", "retained_suspect", "rejected"
)

.eventScopes <- c("run", "file", "survey", "record")

.eventLevel <- function(disposition) {
  data.table::fcase(
    disposition == "intact", "INFO",
    disposition %in% c("corrected", "estimated"), "WARNING",
    disposition %in% c("retained_suspect", "rejected"), "ERROR",
    default = NA_character_
  )
}

.logEventInit <- function(log.file) {
  if (!dir.exists(dirname(log.file))) {
    dir.create(dirname(log.file), recursive = TRUE, showWarnings = FALSE)
  }
  if (file.exists(log.file)) invisible(file.remove(log.file))
  fwrite(
    data.table(
      ts = character(), scope = character(), SiteID = character(),
      HoleID = character(), datetime = character(), source = character(),
      cause = character(), disposition = character(), flag = character(),
      detail = character()
    ),
    log.file
  )
}

.logEvent <- function(log.file, scope, cause, disposition = NULL,
                      flag = NULL, SiteID = "", HoleID = "",
                      datetime = "", source = "", detail = "") {
  Catalog <- .eventsCatalog()
  # R-DATA-TABLE.md: inside i a bare name resolves to the column first,
  # so the lookup variable must carry a non-column name.
  CauseKey <- cause
  Row <- Catalog[cause == CauseKey]
  if (nrow(Row) != 1L) {
    stop(sprintf("unknown event cause: %s (not in events.csv)", cause),
      call. = FALSE
    )
  }
  if (is.null(disposition)) disposition <- Row$disposition.default
  if (!disposition %in% .eventDispositions) {
    stop(sprintf("invalid disposition: %s", disposition), call. = FALSE)
  }
  if (!scope %in% .eventScopes) {
    stop(sprintf("invalid scope: %s", scope), call. = FALSE)
  }
  if (is.null(flag)) flag <- Row$flag
  # Vector arguments of equal length emit one record per element;
  # length-1 arguments recycle (data.table enforces the rest).
  fwrite(
    data.table(
      ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      scope = scope,
      SiteID = .asChar(SiteID),
      HoleID = .asChar(HoleID),
      datetime = .asChar(datetime),
      source = .asChar(source),
      cause = cause,
      disposition = disposition,
      flag = flag,
      detail = .asChar(detail)
    ),
    log.file,
    append = TRUE, col.names = FALSE
  )
}
