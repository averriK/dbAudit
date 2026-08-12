.scriptFile <- function() {
  Args <- commandArgs(trailingOnly = FALSE)
  Hit <- grep(pattern = "^--file=", x = Args, value = TRUE)
  if (!length(Hit)) return(NA_character_)
  sub(pattern = "^--file=", replacement = "", x = Hit[1L])
}

.scriptDir <- function() {
  File <- .scriptFile()
  if (is.na(File) || !nzchar(File)) return(getwd())
  dirname(normalizePath(path = File, mustWork = TRUE))
}

.repoRoot <- function() {
  normalizePath(
    path = file.path(.scriptDir(), "..", "..", ".."),
    mustWork = TRUE
  )
}

.resolvePath <- function(path, root = .repoRoot(), mustWork = FALSE) {
  if (is.null(path) || !length(path) || is.na(path) || !nzchar(path)) {
    return(NULL)
  }
  PATH <- path.expand(path)
  if (!grepl(pattern = "^(/|[A-Za-z]:[/\\\\])", x = PATH)) {
    PATH <- file.path(root, PATH)
  }
  normalizePath(path = PATH, mustWork = mustWork)
}

.readJson <- function(path, simplifyVector = FALSE) {
  if (!requireNamespace(package = "jsonlite", quietly = TRUE)) {
    stop("Missing R package: jsonlite", call. = FALSE)
  }
  jsonlite::read_json(path = path, simplifyVector = simplifyVector)
}

.jsonHas <- function(x, key) {
  OUT <- x
  for (Part in key) {
    if (!is.list(OUT) || !(Part %in% names(OUT))) return(FALSE)
    OUT <- OUT[[Part, exact = TRUE]]
  }
  TRUE
}

.jsonGet <- function(x, key, default = NULL) {
  OUT <- x
  for (Part in key) {
    if (!is.list(OUT) || !(Part %in% names(OUT))) return(default)
    OUT <- OUT[[Part, exact = TRUE]]
  }
  OUT
}

.jsonRequire <- function(x, key, path = NULL) {
  if (.jsonHas(x = x, key = key)) return(.jsonGet(x = x, key = key))
  Label <- paste(key, collapse = ".")
  if (!is.null(path)) Label <- sprintf("%s in %s", Label, path)
  stop(sprintf("Missing required JSON key: %s", Label), call. = FALSE)
}

.scalar <- function(x, field) {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("%s must be one value", field), call. = FALSE)
  }
  x
}

.runOneGeochem <- function(config, root, path) {
  ProjectPath <- .resolvePath(
    path = .scalar(.jsonRequire(config, c("projectPath"), path), "projectPath"),
    root = root,
    mustWork = TRUE
  )
  AssayFile <- .jsonGet(config, c("assayFile"), default = NULL)
  if (!is.null(AssayFile)) {
    AssayFile <- .resolvePath(path = .scalar(AssayFile, "assayFile"),
                              root = ProjectPath, mustWork = TRUE)
  }

  OUT <- DBAudit(
    project.path = ProjectPath,
    lab.dir.name = as.character(.jsonGet(config, c("labDir"), default = "raw/lab")),
    assay.dir.name = as.character(.jsonGet(config, c("assayDir"), default = "raw/assay")),
    proc.dir.name = as.character(.jsonGet(config, c("procDir"), default = "proc")),
    assay.file = AssayFile,
    lab.format = as.character(.jsonGet(config, c("labFormat"), default = "auto")),
    assay.format = as.character(.jsonGet(config, c("assayFormat"), default = "auto")),
    tol = as.numeric(.jsonGet(config, c("tol"), default = 5e-2))
  )

  data.table::data.table(
    projectPath = OUT$project.path,
    labFile = OUT$lab.file,
    indexFile = OUT$index.file,
    clientFile = OUT$client.file,
    logFile = OUT$log.file
  )
}

.runGeochem <- function(config, root, path) {
  Runs <- .jsonRequire(config, c("runs"), path)
  if (!is.list(Runs) || !length(Runs)) {
    stop("runs must be a non-empty list", call. = FALSE)
  }
  data.table::rbindlist(
    l = lapply(X = Runs, FUN = function(Run) {
      .runOneGeochem(config = Run, root = root, path = path)
    }),
    use.names = TRUE
  )
}
