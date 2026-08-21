# ----------------------------------------------------------------------
# eventLog.R — structured QA/QC event log, schema v3 (the mineralogy
# model). Contract: dev/SoT/PLAN-event-taxonomy.md (ruling 2026-08-17).
# Scope: monitoring domains (PCG, PCV, INC). The geochemistry pipeline
# keeps its own logger (.log in helpers.R).
#
# One record per observed fact:
#   ts, scope, SiteID, HoleID, datetime, source, level, event, detail
# level is STORED and primary, exactly as in the geochemistry audit:
#   INFO    = process marks and site conditions; nothing wrong with
#             the data (START, DONE, DRY).
#   WARNING = a data problem occurred and the pipeline RESOLVED it;
#             the database is consistent; the source practice still
#             needs correction.
#   ERROR   = a data problem occurred and could NOT be resolved;
#             human action required. level == "ERROR" is the work
#             list filter.
# Every emission is validated against the catalog (inst/events.csv,
# key = event x scope): an unknown event stops the run.

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
    "event", "scope", "class", "level", "flag", "approved",
    "meaning.en", "meaning.es", "expected.action.en", "expected.action.es"
  )
  if (!all(Required %in% names(Catalog))) {
    stop("events catalog is missing required columns", call. = FALSE)
  }
  .eventsCatalogCache$catalog <- Catalog
  Catalog
}

.eventLevels <- c("INFO", "WARNING", "ERROR")

.eventScopes <- c("run", "file", "survey", "record")

.logEventInit <- function(log.file) {
  if (!dir.exists(dirname(log.file))) {
    dir.create(dirname(log.file), recursive = TRUE, showWarnings = FALSE)
  }
  if (file.exists(log.file)) invisible(file.remove(log.file))
  fwrite(
    data.table(
      ts = character(), scope = character(), SiteID = character(),
      HoleID = character(), datetime = character(), source = character(),
      level = character(), event = character(), detail = character()
    ),
    log.file
  )
}

.logEvent <- function(log.file, scope, event, level = NULL,
                      SiteID = "", HoleID = "", datetime = "",
                      source = "", detail = "") {
  Catalog <- .eventsCatalog()
  if (!scope %in% .eventScopes) {
    stop(sprintf("invalid scope: %s", scope), call. = FALSE)
  }
  # Catalog key is the pair (event, scope): the same single-word event
  # can mean different facts at different scopes (e.g. DUPLICATED).
  # R-DATA-TABLE.md: inside i a bare name resolves to the column first,
  # so the lookup variable must carry a non-column name.
  EventKey <- event
  Rows <- Catalog[event == EventKey]
  Hit <- which(vapply(
    strsplit(Rows$scope, ";", fixed = TRUE),
    FUN = function(x) scope %in% x,
    FUN.VALUE = logical(1L)
  ))
  if (length(Hit) != 1L) {
    stop(
      sprintf(
        "unknown event: %s at scope %s (not in events.csv)",
        event, scope
      ),
      call. = FALSE
    )
  }
  Row <- Rows[Hit]
  if (is.null(level)) level <- Row$level
  if (!level %in% .eventLevels) {
    stop(sprintf("invalid level: %s", level), call. = FALSE)
  }
  # Vector arguments of equal length emit one record per element;
  # length-1 arguments recycle (data.table enforces the rest).
  .logRetryWrite(
    data.table(
      ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      scope = scope,
      SiteID = .asChar(SiteID),
      HoleID = .asChar(HoleID),
      datetime = .asChar(datetime),
      source = .asChar(source),
      level = level,
      event = event,
      detail = .asChar(detail)
    ),
    log.file
  )
}
