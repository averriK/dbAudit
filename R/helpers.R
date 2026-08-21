.logInit <- function(log.file) {
  if (!dir.exists(dirname(log.file))) dir.create(dirname(log.file), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(log.file)) invisible(file.remove(log.file))
  fwrite(
    data.table(
      ts = character(), level = character(), file = character(),
      event = character(), message = character()
    ),
    log.file
  )
}

# Log writes must never destroy work already done. The loggers open the
# file once per event — a geochemistry run does roughly seven hundred
# opens — and a shared or network filesystem answers that burst with
# intermittent sharing violations. Observed on a shared checkout: the
# failure surfaced inside the per-certificate handler and was recorded
# as PARSE_ERROR, attributing a defect to a sound certificate, until one
# escaped and killed the run. Retry briefly; on exhaustion drop the line
# and count it, and let the run declare the gap at the end.
.dbauditLogState <- new.env(parent = emptyenv())
.dbauditLogState$dropped <- 0L

.logRetryWrite <- function(DT, log.file) {
  for (k in seq_len(5L)) {
    ok <- tryCatch({
      fwrite(DT, log.file, append = TRUE, col.names = FALSE)
      TRUE
    }, error = function(e) FALSE)
    if (isTRUE(ok)) return(invisible(TRUE))
    Sys.sleep(0.05 * k)
  }
  .dbauditLogState$dropped <- .dbauditLogState$dropped + nrow(DT)
  invisible(FALSE)
}

.logResetDropped <- function() {
  .dbauditLogState$dropped <- 0L
  invisible(NULL)
}

# Declares an incomplete log rather than presenting it as whole.
.logDeclareDropped <- function(log.file) {
  n <- .dbauditLogState$dropped
  if (n > 0L) {
    message(sprintf(
      paste("dbaudit: %d log record(s) could not be written to %s.",
            "The audit completed; the log is incomplete.",
            "A data root on a shared or network filesystem is the known cause."),
      n, log.file
    ))
  }
  invisible(n)
}

.log <- function(log.file, level, file, event, message = "") {
  .logRetryWrite(
    data.table(
      ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      level = level,
      file = file,
      event = event,
      message = message
    ),
    log.file
  )
}


# ----------------------------------------------------------------------

# Internal helper: safe numeric parsing without warnings
.as.numeric <- function(x) {
  y <- x
  y <- stringr::str_replace_all(y, "\u00A0", " ")
  y <- stringr::str_trim(y)
  y <- stringr::str_replace_all(y, " ", "")
  both <- stringr::str_detect(y, ",") & stringr::str_detect(y, "\\.")
  both[is.na(both)] <- FALSE
  y[both] <- stringr::str_replace_all(y[both], ",", "")
  only.comma <- stringr::str_detect(y, ",") & !stringr::str_detect(y, "\\.")
  only.comma[is.na(only.comma)] <- FALSE
  y[only.comma] <- stringr::str_replace_all(y[only.comma], ",", ".")
  y <- stringr::str_replace_all(y, "[^0-9eE+.-]", "")
  suppressWarnings(as.numeric(y))
}

# A missing input directory is the most common way a run stops, and the
# path alone is a dead end: the user cannot tell whether the root is
# wrong, the layout differs, or the data belongs to another domain. The
# message states the expected layout, lists what the root actually
# holds, and names the domain the contents look like.
.missingDirMessage <- function(project.path, missing, expected, domain) {
  Shown <- normalizePath(missing, winslash = "/", mustWork = FALSE)
  Root <- normalizePath(project.path, winslash = "/", mustWork = FALSE)

  Have <- tryCatch(
    sort(list.files(project.path, include.dirs = TRUE, no.. = TRUE)),
    error = function(e) character()
  )
  Listed <- if (length(Have) == 0L) {
    "    (the project directory is empty)"
  } else {
    paste0("    ", paste(utils::head(Have, 20L), collapse = "  "))
  }

  Hint <- if (dir.exists(file.path(project.path, "source"))) {
    paste(
      "\n  This root holds source/, the monitoring layout.",
      "Audit it with 'dbaudit piezometer' or 'dbaudit inclinometer'."
    )
  } else if (any(c("raw", "lab", "assay", "proc") %in% Have) ||
             any(c("PCG", "PCV", "INC") %in% Have)) {
    paste(
      "\n  The root holds data directories but not the expected layout.",
      "Point --project at the data root itself, or pass the directory",
      "options to match your layout."
    )
  } else {
    "\n  Point --project at the data root, not at the repository or project folder."
  }

  sprintf(
    paste0(
      "%s not found: %s\n\n",
      "  The %s contract expects, under --project:\n%s\n\n",
      "  --project resolved to: %s\n",
      "  which holds:\n%s\n%s"
    ),
    sub(paste0("^", .escapeRegex(normalizePath(project.path, winslash = "/", mustWork = FALSE)), "/?"),
        "", Shown),
    Shown, domain,
    paste0("    ", paste(expected, collapse = "\n    ")),
    Root, Listed, Hint
  )
}

# Internal helper: tolerant date parsing to ISO (YYYY-MM-DD).
# Locale-independent by construction: every month-name token (English,
# Spanish, Portuguese; abbreviated and full) is normalized to its NUMBER
# before parsing, and only numeric formats are attempted. %b/%B and
# lubridate month-name orders depend on the system locale and are the
# documented failure mode (a Spanish-locale host cannot parse "Apr").
.as.Date <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  v <- trimws(gsub("[[:cntrl:]]", "", as.character(x)))
  if (!nzchar(v)) return(NA_character_)

  map <- c(
    "JAN" = "01", "ENE" = "01", "JANUARY" = "01", "ENERO" = "01", "JANEIRO" = "01",
    "FEB" = "02", "FEV" = "02", "FEBRUARY" = "02", "FEBRERO" = "02", "FEVEREIRO" = "02",
    "MAR" = "03", "MARCH" = "03", "MARZO" = "03", "MARÇO" = "03", "MARCO" = "03",
    "APR" = "04", "ABR" = "04", "APRIL" = "04", "ABRIL" = "04",
    "MAY" = "05", "MAI" = "05", "MAYO" = "05", "MAIO" = "05",
    "JUN" = "06", "JUNE" = "06", "JUNIO" = "06", "JUNHO" = "06",
    "JUL" = "07", "JULY" = "07", "JULIO" = "07", "JULHO" = "07",
    "AUG" = "08", "AGO" = "08", "AUGUST" = "08", "AGOSTO" = "08",
    "SEP" = "09", "SET" = "09", "SEPTEMBER" = "09", "SEPTIEMBRE" = "09",
    "SETIEMBRE" = "09", "SETEMBRO" = "09",
    "OCT" = "10", "OUT" = "10", "OCTOBER" = "10", "OCTUBRE" = "10", "OUTUBRO" = "10",
    "NOV" = "11", "NOVEMBER" = "11", "NOVIEMBRE" = "11", "NOVEMBRO" = "11",
    "DEC" = "12", "DIC" = "12", "DEZ" = "12", "DECEMBER" = "12",
    "DICIEMBRE" = "12", "DEZEMBRO" = "12"
  )
  v.up <- toupper(v)
  for (k in names(map)) {
    pat <- paste0("(?<=^|[ .,/\\-])", k, "(?=$|[ .,/\\-])")
    v.up <- stringr::str_replace_all(v.up, stringr::regex(pat, ignore_case = FALSE), map[[k]])
  }
  v.norm <- v.up

  if (requireNamespace("lubridate", quietly = TRUE)) {
    orders <- c(
      "Y-m-d", "Y/m/d", "Ymd",
      "d/m/Y", "m/d/Y", "dmY", "mdY",
      "d-m-Y", "m-d-Y",
      "d.m.Y", "d m Y", "dmy", "d-m-y", "d/m/y", "d m y"
    )
    dt <- suppressWarnings(lubridate::parse_date_time(v.norm, orders = orders, tz = "UTC", quiet = TRUE))
    if (!all(is.na(dt))) {
      d <- as.Date(dt)
      if (!is.na(d)) return(format(d, "%Y-%m-%d"))
    }
  }

  fmts <- c(
    "%Y-%m-%d", "%Y/%m/%d",
    "%d/%m/%Y", "%m/%d/%Y",
    "%d-%m-%Y", "%m-%d-%Y",
    "%d.%m.%Y", "%d %m %Y",
    "%d-%m-%y", "%d/%m/%y", "%d %m %y"
  )
  for (f in fmts) {
    dt <- suppressWarnings(as.Date(v.norm, format = f))
    if (!is.na(dt)) return(format(dt, "%Y-%m-%d"))
  }
  # Last resort throws charToDate on unresolvable input (an error, not a
  # warning): an unparseable date must degrade to NA, never abort the
  # certificate that carries it.
  dt <- suppressWarnings(tryCatch(as.Date(v.norm), error = function(e) NA))
  if (!is.na(dt)) return(format(dt, "%Y-%m-%d"))
  NA_character_
}

# Escape regex metacharacters so an inferred literal (e.g., an LCS prefix)
# can be anchored inside a pattern without changing its meaning
.escapeRegex <- function(x) {
  gsub("([][{}()*+?.^$|\\\\])", "\\\\\\1", x)
}

# Clean identifier strings like jobID and despatchID by removing ':' and ',' tokens and trimming spaces
.cleanId <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  v <- as.character(x)
  v <- gsub("[,:]", "", v)
  v <- trimws(v)
  ifelse(nzchar(v), v, NA_character_)
}

# Reconcile AUX (data block) to match the expected schema derived from valueIDs
# - Ensures column count is exactly 1 + length(valueIDs): first for sampleID, rest for analytes
# - Drops extra trailing columns with WARNING EXTRA_COLS_DROPPED
# - Pads missing columns with NA with WARNING MISSING_COLS_PADDED
.reconcileColumns <- function(AUX, valueIDs, FILE, log.file, jobID = NA_character_) {
  expected <- 1L + length(valueIDs)
  actual <- ncol(AUX)
  if (actual > expected) {
    .log(log.file,
      "WARNING", FILE, "EXTRA_COLS_DROPPED",
      sprintf("Dropped %d trailing columns; cols=%d expected=%d; jobID=%s", actual - expected, actual, expected, jobID)
    )
    AUX <- AUX[, seq_len(expected), with = FALSE]
  }
  if (actual < expected) {
    missing <- expected - actual
    for (i in seq_len(missing)) {
      AUX[, paste0("..PAD", i) := NA_character_]
    }
    .log(log.file,
      "WARNING", FILE, "MISSING_COLS_PADDED",
      sprintf("Added %d missing columns; cols=%d expected=%d; jobID=%s", missing, actual, expected, jobID)
    )
  }
  AUX
}


.drop <- function(.x) {
  NROWS <- 11L
  DROP <- 0
  AUX <- fread(.x, nrows = NROWS, header = FALSE, colClasses = "character", select = 1L, fill = TRUE)
  COL <- as.character(AUX[[1]])
  COL <- sub("^\ufeff", "", COL) # strip BOM if present
  COL <- trimws(COL)
  # Coerce to integer safely to ignore stray non-digit characters
  COL <- suppressWarnings(as.integer(COL))
  if (all(!is.na(COL) & COL == seq_len(NROWS))) DROP <- 1
  return(DROP)
}

# Summarize differences as blocks outside the LCS (Longest Common Subsequence)
.diffLcs <- function(a, b) {
  # Split into character vectors
  CA <- strsplit(a, "", fixed = TRUE)[[1]]
  CB <- strsplit(b, "", fixed = TRUE)[[1]]
  nA <- length(CA)
  nB <- length(CB)

  # Dynamic programming table for LCS length
  DP <- matrix(0L, nA + 1L, nB + 1L)
  for (i in seq_len(nA)) for (j in seq_len(nB))
    DP[i + 1L, j + 1L] <- if (CA[i] == CB[j]) DP[i, j] + 1L else max(DP[i, j + 1L], DP[i + 1L, j])

  # Backtrack indices of the LCS in both strings
  i <- nA + 1L
  j <- nB + 1L
  IA <- integer()
  IB <- integer()
  while (i > 1L && j > 1L) {
    if (CA[i - 1L] == CB[j - 1L]) {
      IA <- c(i - 1L, IA)
      IB <- c(j - 1L, IB)
      i <- i - 1L
      j <- j - 1L
    } else if (DP[i - 1L, j] >= DP[i, j - 1L]) {
      i <- i - 1L
    } else {
      j <- j - 1L
    }
  }

  # Helper: collapse runs that are outside the LCS into blocks
  takeBlocks <- function(CH, KEEP) {
    N <- length(CH)
    if (N == 0L) return("")
    MASK <- rep(FALSE, N)
    if (length(KEEP)) MASK[KEEP] <- TRUE
    if (!any(!MASK)) return("")
    POS <- which(!MASK)
    SPLIT <- c(0L, which(diff(POS) > 1L), length(POS))
    OUT <- character()
    for (k in seq_len(length(SPLIT) - 1L)) {
      SEG <- POS[(SPLIT[k] + 1L):SPLIT[k + 1L]]
      OUT <- c(OUT, paste0(CH[SEG], collapse = ""))
    }
    paste(OUT, collapse = " | ")
  }

  DC <- takeBlocks(CA, IA) # differences in a (client)
  DL <- takeBlocks(CB, IB) # differences in b (lab)

  # Normalized Levenshtein similarity
  ED <- as.integer(adist(a, b))
  SIM <- 1 - ED / max(nchar(a), nchar(b))

  list(dc = DC, dl = DL, sim = SIM)
}


# ------------------------------------------------------------------
# Helpers for unit normalization and conversion (local to validator)
.normUnit <- function(u) {
  v <- tolower(trimws(as.character(u)))
  v <- gsub("\\u00A0", " ", v) # non-breaking space
  v <- gsub("\\s+", "", v)
  # normalize common synonyms
  v <- gsub("^g/t$|^gpt$|^g\\/t$", "ppm", v)
  v <- gsub("^mg/kg$", "ppm", v)
  v <- gsub("^ug/g$|^\\u00B5g/g$|^mcg/g$", "ppm", v)
  v <- gsub("^percent$|^%$|^wt%$", "pct", v)
  v
}

.unitFactor <- function(from, to) {
  f <- .normUnit(from)
  t <- .normUnit(to)
  if (!nzchar(f) || !nzchar(t)) return(NA_real_)
  if (f == t) return(1.0)
  # map common conversions
  if (f == "ppb" && t == "ppm") return(0.001)
  if (f == "ppm" && t == "ppb") return(1000.0)
  if (f == "pct" && t == "ppm") return(10000.0)
  if (f == "ppm" && t == "pct") return(1 / 10000.0)
  # These were normalized to ppm already and equalities handled above
  # Unknown mapping
  NA_real_
}

# Robust numeric equality with tolerance and DL handling
.valuesEqual <- function(a, b, tol = 1e-2) {
  # Robust numeric equality using relative tolerance only
  if (length(a) != length(b)) stop(".valuesEqual: length mismatch")

  EQ <- rep(FALSE, length(a))
  EQ[is.na(a) & is.na(b)] <- TRUE
  OK <- !(is.na(a) | is.na(b))
  if (any(OK)) {
    DIFF <- abs(a[OK] - b[OK])
    SCALE <- pmax(1.0, pmax(abs(a[OK]), abs(b[OK])))
    REL <- DIFF / SCALE
    EQ[OK] <- REL <= tol
  }
  EQ
}


.extractJobIDsFromMessages <- function(msg) {
  if (is.null(msg) || length(msg) == 0L) return(character())
  msg <- as.character(msg)
  m <- regexec("jobID=([^; ,]+)", msg)
  hits <- regmatches(msg, m)
  job <- vapply(
    hits,
    FUN = function(x) if (length(x) >= 2L) x[2L] else NA_character_,
    FUN.VALUE = character(1)
  )
  job <- job[!is.na(job) & nzchar(job) & job != "NA"]
  unique(job)
}

.jobIDsWithLabParseErrors <- function(log.file = "data/proc/log.csv") {
  DT <- data.table::fread(log.file, colClasses = "character")

  # NOTE: This helper is used to decide which lab jobIDs to exclude from audit.
  # Treat only truly fatal parsing outcomes as exclusion-worthy.
  fatal.events <- c("PARSE_ERROR", "DUPLICATE_VID", "UNKNOWN_FORMAT")

  job.fatal <- .extractJobIDsFromMessages(DT[level == "ERROR" & event %in% fatal.events, message])
  job.ok <- .extractJobIDsFromMessages(DT[level == "INFO" & event == "PARSE_OK", message])

  # Be conservative: if a jobID has PARSE_OK, do not exclude it even if other ERROR
  # diagnostics were logged (e.g. SAMPLEID_NOT_UNIQUE).
  setdiff(job.fatal, job.ok)
}

.jobIDsWithClientParseErrors <- function(log.file = "data/proc/log.csv") {
  DT <- data.table::fread(log.file, colClasses = "character")
  ev <- c("CLIENT_PARSE_ERROR", "CLIENT_MISSING_COLUMNS")
  .extractJobIDsFromMessages(DT[level == "ERROR" & event %in% ev, message])
}

.jobIDsWithErrors <- function(log.file = "data/proc/log.csv") {
  DT <- data.table::fread(log.file, colClasses = "character")
  .extractJobIDsFromMessages(DT[level == "ERROR", message])
}

.jobIDsWithWarnings <- function(log.file = "data/proc/log.csv") {
  DT <- data.table::fread(log.file, colClasses = "character")
  .extractJobIDsFromMessages(DT[level == "WARNING", message])
}
