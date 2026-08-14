## R/auditPiezometer.R
## Public piezometer runner: parse -> gate -> database -> audit in one call,
## per the 2026-08-14 full-runner ruling. The project root holds source/,
## raw/, db/ and audit/; the runner owns raw/db/audit for its ids and
## regenerates them on every run. Two intentional differences from the
## AR-S2L1X application runners are declared: the AUDIT_START/AUDIT_DONE log
## rows carry file = "auditPiezometer", and SourcePath cells are relative to
## the project root rather than to the application repository root.

.piezometerPathDefaults <- list(
  source.dir.name = "source",
  raw.dir.name = "raw",
  db.dir.name = "db",
  audit.dir.name = "audit"
)

auditPiezometer <- function(
  project.path,
  source.dir.name = .piezometerPathDefaults$source.dir.name,
  raw.dir.name = .piezometerPathDefaults$raw.dir.name,
  db.dir.name = .piezometerPathDefaults$db.dir.name,
  audit.dir.name = .piezometerPathDefaults$audit.dir.name,
  id = c("PCG", "PCV"),
  manifest = NULL
) {
  project.path <- path.expand(project.path)
  if (!dir.exists(project.path)) {
    stop(sprintf("project.path not found: %s", project.path), call. = FALSE)
  }
  project.path <- normalizePath(project.path, mustWork = TRUE)

  id <- unique(toupper(trimws(id)))
  if (!all(id %in% c("PCG", "PCV"))) {
    BadID <- setdiff(id, c("PCG", "PCV"))
    stop(sprintf("unsupported ID: %s", paste(BadID, collapse = ", ")), call. = FALSE)
  }

  source.dir <- file.path(project.path, source.dir.name)
  raw.dir <- file.path(project.path, raw.dir.name)
  db.dir <- file.path(project.path, db.dir.name)
  audit.dir <- file.path(project.path, audit.dir.name)
  if (!dir.exists(source.dir)) {
    stop(sprintf("source.dir not found: %s", source.dir), call. = FALSE)
  }

  if (is.null(manifest)) {
    manifest <- system.file("extdata", "piezometer-manifest.json", package = "dbAudit")
  }
  Manifest <- loadParserManifest(path = manifest)

  invisible(lapply(X = id, FUN = function(idOne) {
    unlink(file.path(raw.dir, idOne), recursive = TRUE)
  }))
  dir.create(path = raw.dir, recursive = TRUE, showWarnings = FALSE)

  ## Parse stage. SourcePath cells are recorded relative to the project
  ## root so the products stay portable across machines.
  Parsed <- .parseAll(source = source.dir, manifest = Manifest, id = id)
  Prefix <- paste0(project.path, "/")
  Parsed <- lapply(X = Parsed, FUN = function(tables) {
    lapply(X = tables, FUN = function(DT) {
      if ("SourcePath" %in% names(DT)) {
        DT[, SourcePath := sub(pattern = Prefix, replacement = "", x = SourcePath, fixed = TRUE)]
      }
      DT
    })
  })
  .writeParseOutput(x = Parsed, raw = raw.dir)

  ## Gate and database stage
  DATA <- data.table::rbindlist(
    l = lapply(X = id, FUN = function(ID) {
      .readRawTable(raw = raw.dir, id = ID, name = "data")
    }),
    use.names = TRUE
  )
  INDEX <- data.table::rbindlist(
    l = lapply(X = id, FUN = function(ID) .readRawIndex(raw = raw.dir, id = ID)),
    use.names = TRUE
  )
  .checkRawIndex(data = DATA, index = INDEX)
  DATA <- .gatePiezometers(data = DATA, raw = raw.dir, audit = audit.dir, id = id)
  DATA <- .cleanRawData(data = DATA)
  Tables <- .buildDBTables(data = DATA, id = id, schema = .dbSchema())
  .writeDBTables(tables = Tables, db = db.dir)

  ## Audit stage
  dir.create(path = audit.dir, recursive = TRUE, showWarnings = FALSE)
  Log <- file.path(audit.dir, "log.csv")
  .logInit(log.file = Log)
  .log(log.file = Log, level = "INFO", file = "auditPiezometer", event = "AUDIT_START")

  RawData <- .readAllRaw(raw = raw.dir, id = id, name = "data")
  RawHeader <- .readAllHeader(raw = raw.dir, id = id)
  DBData <- .readDBList(db = db.dir, id = id, name = "data")
  DBIndex <- .readAllDB(db = db.dir, id = id, name = "index")
  Rejects <- .readRejects(audit = audit.dir, id = id)
  Audit <- .initAudit(data = DBData)

  .checkRawDBKeys(log = Log, rawData = RawData, dbIndex = DBIndex, rejects = Rejects)
  .checkDuplicateRaw(log = Log, rawData = RawData)
  .checkRawUnits(log = Log, rawData = RawData)
  invisible(lapply(X = id, FUN = function(ID) {
    .checkDBUnits(log = Log, data = Audit[[ID]])
  }))
  .checkIDMismatches(log = Log, raw = raw.dir, id = id)
  if ("PCV" %in% id) {
    .checkPCVHeader(log = Log, header = RawHeader)
  }
  if ("PCG" %in% id) {
    .checkPCGChange(log = Log, data = Audit$PCG)
  }

  PZ <- .pzTables(data = Audit, index = DBIndex)
  .writeAudit(path = audit.dir, id = id, data = Audit, pz = PZ)
  .log(
    log.file = Log, level = "INFO", file = "auditPiezometer", event = "AUDIT_DONE",
    message = sprintf("PZ.data=%d; PZ.index=%d", nrow(PZ$data), nrow(PZ$index))
  )

  invisible(list(
    project.path = project.path,
    source.dir = source.dir,
    raw.dir = raw.dir,
    db.dir = db.dir,
    audit.dir = audit.dir,
    log.file = Log
  ))
}
