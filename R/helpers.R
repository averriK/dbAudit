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

.log <- function(log.file, level, file, event, message = "") {
  fwrite(
    data.table(
      ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      level = level,
      file = file,
      event = event,
      message = message
    ),
    log.file,
    append = TRUE, col.names = FALSE
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

# Internal helper: tolerant date parsing to ISO (YYYY-MM-DD)
.as.Date <- function(x) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  v <- trimws(gsub("[[:cntrl:]]", "", as.character(x)))
  if (!nzchar(v)) return(NA_character_)

  # Normalize common non-English month abbreviations to English to avoid locale dependence
  # Spanish and Portuguese abbreviations (case-insensitive)
  map <- c(
    "ENE" = "JAN", "FEB" = "FEB", "MAR" = "MAR", "ABR" = "APR", "MAY" = "MAY", "JUN" = "JUN",
    "JUL" = "JUL", "AGO" = "AUG", "SEP" = "SEP", "SET" = "SEP", "OCT" = "OCT", "NOV" = "NOV", "DIC" = "DEC",
    "JAN" = "JAN", "FEV" = "FEB", "ABR" = "APR", "MAI" = "MAY", "DEZ" = "DEC"
  )
  # Replace standalone month tokens regardless of separator
  v.up <- toupper(v)
  # Patterns like -ENE-, /ENE/, spaceENEspace, start/end boundaries
  for (k in unique(names(map))) {
    pat <- paste0("(?<=^|[ .,/\\-])", k, "(?=$|[ .,/\\-])")
    v.up <- stringr::str_replace_all(v.up, stringr::regex(pat, ignore_case = FALSE), map[[k]])
  }
  v.norm <- v.up

  # Try lubridate if available for robust multi-format parsing (after normalization)
  if (requireNamespace("lubridate", quietly = TRUE)) {
    orders <- c(
      # numeric year-month-day variants
      "Y-m-d", "Y/m/d", "Ymd",
      "d/m/Y", "m/d/Y", "dmY", "mdY",
      "d-m-Y", "m-d-Y",
      "d.m.Y",
      # month names (abbrev and full), 4-digit and 2-digit year
      "d-b-Y", "d-B-Y", "d-b-y", "d-B-y",
      "b-d-Y", "B-d-Y", "b-d-y", "B-d-y",
      "d*b*Y" # very tolerant: e.g., 6 May 24
    )
    dt <- suppressWarnings(lubridate::parse_date_time(v.norm, orders = orders, tz = "UTC", quiet = TRUE))
    if (!all(is.na(dt))) {
      d <- as.Date(dt)
      if (!is.na(d)) return(format(d, "%Y-%m-%d"))
    }
  }

  # Fallback to base R with a set of common formats
  fmts <- c(
    "%Y-%m-%d", "%Y/%m/%d",
    "%d/%m/%Y", "%m/%d/%Y",
    "%d-%m-%Y", "%m-%d-%Y",
    "%d.%m.%Y",
    # month names
    "%d-%b-%Y", "%d-%B-%Y", "%d-%b-%y", "%d-%B-%y",
    "%b-%d-%Y", "%B-%d-%Y", "%b-%d-%y", "%B-%d-%y",
    "%d %b %Y", "%d %B %Y", "%d %b %y", "%d %B %y"
  )
  for (f in fmts) {
    dt <- suppressWarnings(as.Date(v.norm, format = f))
    if (!is.na(dt)) return(format(dt, "%Y-%m-%d"))
  }
  # last resort: let as.Date try ISO-ish strings
  dt <- suppressWarnings(as.Date(v.norm))
  if (!is.na(dt)) return(format(dt, "%Y-%m-%d"))
  NA_character_
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
  v <- gsub("^ug/g$|^µg/g$|^mcg/g$", "ppm", v)
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
  ev <- c("PARSE_ERROR", "DUPLICATE_VID", "SAMPLEID_NOT_UNIQUE", "UNKNOWN_FORMAT")
  .extractJobIDsFromMessages(DT[level == "ERROR" & event %in% ev, message])
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
