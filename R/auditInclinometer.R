## R/auditInclinometer.R
## Public inclinometer runner: parse -> build -> audit in one call, the
## inclinometer sibling of auditPiezometer() (engine consolidation of the
## INC chain formerly split into el proyecto de monitoreo downstream runParse/runData/runAudit). The
## project root holds source/, raw/, db/ and audit/; the runner owns
## raw/db/audit for INC and regenerates them on every run. As in
## auditPiezometer(), two intentional differences from the el proyecto de monitoreo downstream
## application runners are declared: the START/DONE log rows carry
## source = "auditInclinometer", and SourcePath cells are relative to the
## project root rather than to the application repository root. The runner
## initializes <audit>/log.csv, so a combined PCG/PCV/INC project run that
## needs one shared log belongs to the application runner, not to chained
## engine runners.

auditInclinometer <- function(
  project.path,
  source.dir.name = .piezometerPathDefaults$source.dir.name,
  raw.dir.name = .piezometerPathDefaults$raw.dir.name,
  db.dir.name = .piezometerPathDefaults$db.dir.name,
  audit.dir.name = .piezometerPathDefaults$audit.dir.name,
  manifest = NULL
) {
  project.path <- path.expand(project.path)
  if (!dir.exists(project.path)) {
    stop(sprintf("project.path not found: %s", project.path), call. = FALSE)
  }
  project.path <- normalizePath(project.path, mustWork = TRUE)

  source.dir <- .resolveSourceDir(
    project.path = project.path, source.dir.name = source.dir.name,
    ids = c("INC"),
    explicit = !identical(source.dir.name, .piezometerPathDefaults$source.dir.name)
  )
  raw.dir <- file.path(project.path, raw.dir.name)
  db.dir <- file.path(project.path, db.dir.name)
  audit.dir <- file.path(project.path, audit.dir.name)
  if (!dir.exists(source.dir)) {
    stop(.missingDirMessage(
      project.path = project.path, missing = source.dir,
      expected = c(
        paste0(source.dir.name, "/<ID>/<Site>/   client files as received"),
        paste0(raw.dir.name, "/, ", db.dir.name, "/, ", audit.dir.name,
               "/   products, created by the run")
      ),
      domain = "inclinometer"
    ), call. = FALSE)
  }

  if (is.null(manifest)) {
    manifest <- .dbauditResource("extdata", "piezometer-manifest.json")
  }
  Manifest <- loadParserManifest(path = manifest)

  unlink(file.path(raw.dir, "INC"), recursive = TRUE)
  dir.create(path = raw.dir, recursive = TRUE, showWarnings = FALSE)

  ## Parse stage. SourcePath cells are recorded relative to the project
  ## root so the products stay portable across machines.
  Parsed <- parseINC(path = file.path(source.dir, "INC"), manifest = Manifest)
  ## The parse layer knows exactly which files it walked; the census
  ## needs those paths in their absolute pre-rewrite form.
  Walked <- unique(Parsed$index$SourcePath)
  Parsed <- lapply(X = Parsed, FUN = function(DT) {
    if ("SourcePath" %in% names(DT)) {
      DT[, SourcePath := .relativeToRoot(SourcePath, project.path)]
    }
    DT
  })
  .writeParseOutput(x = list(INC = Parsed), raw = raw.dir)

  ## Build stage
  Tables <- list(INC = .incTables(raw = raw.dir))
  .writeDBTables(tables = Tables, db = db.dir)

  ## Audit stage
  dir.create(path = audit.dir, recursive = TRUE, showWarnings = FALSE)
  Log <- file.path(audit.dir, "log.csv")
  .logEventInit(log.file = Log)
  .logResetDropped()
  .logEvent(log.file = Log, scope = "run", event = "START", source = "auditInclinometer")

  .checkSourceCensus(
    log = Log, source = source.dir, walked = Walked, pattern = "[.](csv)$"
  )
  AuditINC <- .auditINC(log = Log, raw = raw.dir, db = db.dir, audit = audit.dir)

  .logEvent(
    log.file = Log, scope = "run", event = "DONE", source = "auditInclinometer",
    detail = sprintf("INC.audit=%d", nrow(AuditINC))
  )
  .logDeclareDropped(Log)

  invisible(list(
    project.path = project.path,
    source.dir = source.dir,
    raw.dir = raw.dir,
    db.dir = db.dir,
    audit.dir = audit.dir,
    log.file = Log
  ))
}
