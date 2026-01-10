# ----------------------------------------------------------------------
# Validation helpers: Structure (Stage 1 & Stage 2) and Values (Stage 4)
# Both helpers read from paths, log to log.file, and return a list
# with updated DATA.lab and DATA.client (in-memory only).

auditStructure <- function(log.file, data.client, data.lab, fix = FALSE, file.id = file.path("data","proc","client.csv")) {
  DATA.lab <- data.lab
  DATA.client <- data.client
  # Stage 1: jobID mismatch (client jobID not in lab)
  jobID.lab <- unique(DATA.lab$jobID)
  sampleID.lab <- unique(DATA.lab$sampleID)

  jobID.missing <- unique(DATA.client[!(jobID %in% jobID.lab) & !is.na(jobID) & jobID != "", jobID])
  N.jobID.wrong <- length(jobID.missing)
  N.jobID.fixed <- 0L

  if (N.jobID.wrong > 0L) {
    .log(log.file, "WARNING", file.id, "JOBID_MISMATCH", sprintf("count=%d", N.jobID.wrong))

    # Attempt systematic correction only when sampleID exists in lab (so we can infer mapping).
    DT.client <- DATA.client[!(jobID %in% jobID.lab) & sampleID %in% sampleID.lab, .(sampleID, jobID.client = jobID)] |> unique()

    prefix <- character()
    suffix <- character()

    if (nrow(DT.client) > 0L) {
      sampleID.client <- unique(DT.client$sampleID)

      DT.lab <- DATA.lab[sampleID %in% sampleID.client, .(sampleID, jobID.lab = jobID)] |> unique()

      # Some sampleIDs can appear in multiple lab jobIDs (e.g., re-analyses). Exclude those to avoid cartesian joins.
      DT.multi <- DT.lab[, .(N.jobID = uniqueN(jobID.lab)), by = .(sampleID)][N.jobID > 1L]
      if (nrow(DT.multi) > 0L) {
        .log(log.file, "WARNING", file.id, "SAMPLEID_MULTI_JOBID", sprintf("count=%d", nrow(DT.multi)))
        DT.client <- DT.client[!(sampleID %chin% DT.multi$sampleID)]
        DT.lab <- DT.lab[!(sampleID %chin% DT.multi$sampleID)]
      }

      DT <- DT.client[DT.lab, on = "sampleID", nomatch = 0L] |> unique()
      DT[, c("prefix", "suffix") := {
        x <- .diffLcs(jobID.client, jobID.lab)
        list(x$dc, x$dl)
      }, by = .I] |> unique()
      prefix <- unique(DT$prefix)
      suffix <- unique(DT$suffix)

      if (isTRUE(fix)) {
        if (length(prefix) == 1 && nzchar(prefix)) {
          DATA.client[!(jobID %in% jobID.lab) & sampleID %in% sampleID.lab, jobID := sub(paste0("^", prefix), "", jobID)]
        }
        if (length(suffix) == 1 && nzchar(suffix)) {
          DATA.client[!(jobID %in% jobID.lab) & sampleID %in% sampleID.lab, jobID := sub(paste0(suffix, "$"), "", jobID)]
        }
      }
    }

    jobID.missing.after <- unique(DATA.client[!(jobID %in% jobID.lab) & !is.na(jobID) & jobID != "", jobID])
    N.jobID.fixed <- max(N.jobID.wrong - length(jobID.missing.after), 0L)
    prefix.msg <- if (length(prefix) == 1) prefix else ""
    suffix.msg <- if (length(suffix) == 1) suffix else ""
    .log(log.file, "INFO", file.id, "JOBID_FIXED", sprintf("fixed=%d; prefix=%s; suffix=%s", N.jobID.fixed, prefix.msg, suffix.msg))
  }

  # ERROR per remaining wrong jobID
  DT <- unique(DATA.client[!(jobID %in% jobID.lab) & !is.na(jobID) & jobID != "", .(jobID)])
  if (nrow(DT) > 0L) for (j in DT$jobID) .log(log.file, "ERROR", file.id, "WRONG_JOBID", sprintf("jobID=%s", j))

  # Stage 2: wrong sampleID (jobID exists in lab but sampleID not found)
  DT <- DATA.client[(jobID %in% jobID.lab) & !(sampleID %in% sampleID.lab)]
  N.sampleID.wrong <- DT[, uniqueN(sampleID)]
  N.sampleID.fixed <- 0L
  if (N.sampleID.wrong > 0L) {
    .log(log.file, "WARNING", file.id, "SAMPLEID_MISMATCH", sprintf("count=%d", N.sampleID.wrong))
    DT.client <- DT[, .(jobID, sampleID.client = sampleID)] |> unique()
    jobID.client <- unique(DT.client$jobID)
    DT.lab <- DATA.lab[jobID %in% jobID.client, .(jobID, sampleID.lab = sampleID)] |> unique()

    # Avoid cartesian join explosions: pair sampleIDs within each jobID by sorted rank.
    # This is sufficient for systematic prefix/suffix detection.
    max.k <- 50L

    setorder(DT.client, jobID, sampleID.client)
    DT.client[, k := seq_len(.N), by = .(jobID)]
    DT.client <- DT.client[k <= max.k]

    setorder(DT.lab, jobID, sampleID.lab)
    DT.lab[, k := seq_len(.N), by = .(jobID)]
    DT.lab <- DT.lab[k <= max.k]

    DT <- DT.client[DT.lab, on = c("jobID", "k"), nomatch = 0L] |> unique()
    DT[, k := NULL]
    DT[, c("prefix", "suffix") := {
      x <- .diffLcs(sampleID.client, sampleID.lab)
      list(x$dc, x$dl)
    }, by = .I] |> unique()
    prefix <- unique(DT$prefix)
    suffix <- unique(DT$suffix)
    if (isTRUE(fix)) {
      if (length(prefix) == 1 && nzchar(prefix)) {
        DATA.client[(jobID %in% jobID.lab) & !(sampleID %in% sampleID.lab), sampleID := sub(paste0("^", prefix), "", sampleID)]
      }
      if (length(suffix) == 1 && nzchar(suffix)) {
        DATA.client[(jobID %in% jobID.lab) & !(sampleID %in% sampleID.lab), sampleID := sub(paste0(suffix, "$"), "", sampleID)]
      }
    }
    DT <- DATA.client[(jobID %in% jobID.lab) & !(sampleID %in% sampleID.lab)]
    N.sampleID.fixed <- max(N.sampleID.wrong - DT[, uniqueN(sampleID)], 0L)
    prefix.msg <- if (length(prefix) == 1) prefix else ""
    suffix.msg <- if (length(suffix) == 1) suffix else ""
    .log(log.file, "INFO", file.id, "SAMPLEID_FIXED", sprintf("fixed=%d; prefix=%s; suffix=%s", N.sampleID.fixed, prefix.msg, suffix.msg))
  }
  # ERROR per remaining wrong sampleID
  DT <- unique(DATA.client[(jobID %in% jobID.lab) & !(sampleID %in% sampleID.lab), .(sampleID)])
  if (nrow(DT) > 0L) for (j in DT$sampleID) .log(log.file, "ERROR", file.id, "WRONG_SAMPLEID", sprintf("sampleID=%s", j))

  if (isTRUE(fix) && (N.jobID.fixed > 0L || N.sampleID.fixed > 0L)) {
    .log(log.file, "INFO", file.id, "STRUCTURE_APPLIED",
      sprintf("fixed_jobIDs=%d; fixed_sampleIDs=%d", N.jobID.fixed, N.sampleID.fixed))
  }
  return(list(data.client = DATA.client))
}

auditValues <- function(
  log.file,
  data.lab,
  data.client,
  index.lab = NULL,
  format = c("A", "B"),
  fix = FALSE,
  min.votes = 2L,
  tol = 5e-2,
  file.id = file.path("data", "proc", "client.csv")
) {
  DATA.lab <- data.lab
  DATA.client <- data.client

  format <- match.arg(format)

  if (!is.numeric(tol) || length(tol) != 1L || is.na(tol) || !is.finite(tol) || tol < 0) {
    stop(sprintf("Invalid tol: %s (expected a non-negative number)", as.character(tol)))
  }

  if (identical(format, "A")) {
    return(.auditValuesA(
      log.file = log.file,
      data.lab = DATA.lab,
      data.client = DATA.client,
      fix = fix,
      tol = tol,
      file.id = file.id
    ))
  }

  if (identical(format, "B")) {
    if (is.null(index.lab)) {
      stop("auditValues(format='B') requires index.lab (lab-derived index.csv)")
    }
    return(.auditValuesB(
      log.file = log.file,
      data.lab = DATA.lab,
      data.client = DATA.client,
      index.lab = index.lab,
      fix = fix,
      min.votes = min.votes,
      tol = tol,
      file.id = file.id
    ))
  }

  stop("Invalid format")
}

.auditValuesA <- function(log.file, data.lab, data.client, fix = FALSE, tol = 5e-2, file.id = file.path("data","proc","client.csv")) {
  DATA.lab <- data.lab
  DATA.client <- data.client

  keys <- c("jobID", "sampleID", "elementID", "standardID", "unitID")
  DT.client <- unique(DATA.client[, .(jobID, sampleID, elementID, standardID, unitID, value.client = value)])
  DT.lab <- unique(DATA.lab[, .(jobID, sampleID, elementID, standardID, unitID, value.lab = value)])
  DT <- DT.lab[DT.client, on = keys, nomatch = 0L] |> unique()

  OUT <- .auditValuesNumericJoin(
    log.file = log.file,
    file.id = file.id,
    DATA.client = DATA.client,
    DT = DT,
    keys = keys,
    tol = tol,
    fix = fix
  )

  return(list(data.client = OUT$data.client))
}


.auditValuesNumericJoin <- function(log.file, file.id, DATA.client, DT, keys, tol = 5e-2, fix = FALSE) {
  DT <- DT[!is.na(value.client) & !is.na(value.lab)]
  DT[, OK.value := .valuesEqual(value.client, value.lab, tol = tol)]

  N.value.wrong <- DT[OK.value == FALSE, .N]
  if (N.value.wrong > 0L) {
    .log(log.file, "WARNING", file.id, "VALUE_MISMATCH", sprintf("count=%d; tol=%g", N.value.wrong, tol))
    idx <- which(DT$OK.value == FALSE)
    if (length(idx)) {
      if (isTRUE(fix)) {
        for (k in idx) {
          .log(log.file, "INFO", file.id, "VALUE_FIXED",
            sprintf("jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s; value.client=%g; value.lab=%g; tol=%g",
              DT$jobID[k], DT$sampleID[k], DT$elementID[k], DT$standardID[k], DT$unitID[k], DT$value.client[k], DT$value.lab[k], tol))
        }
        DATA.client[DT[OK.value == FALSE, .(jobID, sampleID, elementID, standardID, unitID, value.lab)], on = keys, value := i.value.lab]
        .log(log.file, "INFO", file.id, "VALUES_APPLIED", sprintf("fixed=%d; tol=%g", N.value.wrong, tol))
      } else {
        for (k in idx) {
          .log(log.file, "ERROR", file.id, "WRONG_VALUE",
            sprintf("jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s; value.client=%g; value.lab=%g; tol=%g",
              DT$jobID[k], DT$sampleID[k], DT$elementID[k], DT$standardID[k], DT$unitID[k], DT$value.client[k], DT$value.lab[k], tol))
        }
      }
    }
  }

  list(data.client = DATA.client)
}

# ----------------------------------------------------------------------
# Type-B: infer standardID (method) from lab data and owner assay values.
# - No fallback: if method cannot be inferred unambiguously, log ERROR.
# - Require >= min_votes discriminative votes.

.inferMethodVotesB <- function(DT.client, DT.lab, candidates, tol = 5e-2) {
  # DT.client: sampleID, value.client, tagDL.client
  # DT.lab: sampleID, standardID, value.lab, tagDL.lab
  # candidates: character vector of candidate standardIDs

  if (length(candidates) < 2L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.sample = 0L, N.owner = nrow(DT.client)))
  }

  # Keep only relevant standards and non-missing values/tags
  DT.client <- DT.client[!is.na(value.client) & !is.na(tagDL.client) & nzchar(tagDL.client)]
  DT.lab <- DT.lab[standardID %chin% candidates & !is.na(value.lab) & !is.na(tagDL.lab) & nzchar(tagDL.lab)]

  if (nrow(DT.client) == 0L || nrow(DT.lab) == 0L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.sample = 0L, N.owner = nrow(DT.client)))
  }

  # Resolve duplicate (sampleID, standardID) outputs in lab.
  # If multiple distinct (tagDL,value) exist, exclude those sampleIDs from inference (conservative).
  DT <- DT.lab[, .(N.out = uniqueN(paste(tagDL.lab, value.lab, sep = "\t"))), by = .(sampleID, standardID)][N.out > 1L]
  sampleID.bad <- if (nrow(DT)) unique(DT$sampleID) else character()
  if (length(sampleID.bad)) {
    DT.lab <- DT.lab[!(sampleID %chin% sampleID.bad)]
    DT.client <- DT.client[!(sampleID %chin% sampleID.bad)]
  }

  if (nrow(DT.client) == 0L || nrow(DT.lab) == 0L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.sample = 0L, N.owner = nrow(DT.client)))
  }

  # Use only samples where all candidates are present in lab
  DT.have <- DT.lab[, .(N.std = uniqueN(standardID)), by = .(sampleID)][N.std == length(candidates), sampleID]
  if (length(DT.have) == 0L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.sample = 0L, N.owner = nrow(DT.client)))
  }

  DT.client <- DT.client[sampleID %chin% DT.have]
  DT.lab <- DT.lab[sampleID %chin% DT.have]

  if (nrow(DT.client) == 0L || nrow(DT.lab) == 0L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.sample = 0L, N.owner = nrow(DT.client)))
  }

  DT <- DT.client[DT.lab, on = "sampleID", allow.cartesian = TRUE] |> unique()

  # Vote on exact matches by (tagDL,value): if exactly one candidate matches, it wins that sample.
  DT[, OK := (tagDL.client == tagDL.lab) & .valuesEqual(value.client, value.lab, tol = tol)]

  V <- DT[, .(
    N.match = sum(OK, na.rm = TRUE),
    winner = if (sum(OK, na.rm = TRUE) == 1L) standardID[OK == TRUE][1] else NA_character_
  ), by = .(sampleID)]

  votes <- V[!is.na(winner), .N, by = .(standardID = winner)][order(-N)]

  list(votes = votes, N.vote = nrow(V[!is.na(winner)]), N.sample = length(DT.have), N.owner = nrow(DT.client))
}

.inferMethodVotesDlB <- function(DT.client, IDX, tol = 5e-2) {
  # DT.client: sampleID, value.client, tagDL.client
  # IDX: standardID, minDL, maxDL
  # Vote only when owner explicitly provides < or > and exactly one candidate matches the DL.

  DT.client <- DT.client[
    !is.na(value.client) & (tagDL.client %chin% c("<", ">"))
  ]

  if (nrow(DT.client) == 0L || nrow(IDX) == 0L) {
    return(list(votes = data.table(standardID = character(), N = integer()), N.vote = 0L, N.owner = nrow(DT.client)))
  }

  WIN <- rep(NA_character_, nrow(DT.client))

  for (k in seq_len(nrow(DT.client))) {
    tagDL <- DT.client$tagDL.client[k]
    valueDL <- DT.client$value.client[k]

    if (is.na(valueDL) || !nzchar(tagDL)) next

    if (identical(tagDL, "<")) {
      ok <- .valuesEqual(rep(valueDL, nrow(IDX)), IDX$minDL, tol = tol)
      pick <- IDX$standardID[ok]
      if (length(pick) == 1L) WIN[k] <- pick
    }

    if (identical(tagDL, ">")) {
      ok <- .valuesEqual(rep(valueDL, nrow(IDX)), IDX$maxDL, tol = tol)
      pick <- IDX$standardID[ok]
      if (length(pick) == 1L) WIN[k] <- pick
    }
  }

  votes <- data.table(standardID = WIN)[!is.na(standardID), .N, by = standardID][order(-N)]
  list(votes = votes, N.vote = sum(!is.na(WIN)), N.owner = nrow(DT.client))
}


.inferStandardIdB <- function(log.file, DATA.lab, DATA.client, INDEX.lab,
                             min.votes = 2L, tol = 5e-2,
                             file.id = file.path("data", "proc", "client.csv")) {
  IDX <- unique(INDEX.lab[, .(jobID, elementID, unitID, standardID, minDL, maxDL)])

  CNT <- IDX[, .(
    N.std = uniqueN(standardID),
    standard.single = if (uniqueN(standardID) == 1L) standardID[1] else NA_character_
  ), by = .(jobID, elementID, unitID)]

  GRP <- unique(DATA.client[, .(jobID, elementID, unitID)])
  GRP <- CNT[GRP, on = c("jobID", "elementID", "unitID")]

  # Groups that exist in client but not in lab index
  GRP.missing <- GRP[is.na(N.std), .(jobID, elementID, unitID)]
  if (nrow(GRP.missing) > 0L) {
    .log(log.file, "WARNING", file.id, "CLIENT_ANALYTE_NOT_IN_LAB",
      sprintf("groups=%d", nrow(GRP.missing))
    )
    for (k in seq_len(nrow(GRP.missing))) {
      .log(log.file, "ERROR", file.id, "MISSING_LAB_ANALYTE",
        sprintf(
          "jobID=%s; elementID=%s; unitID=%s",
          GRP.missing$jobID[k], GRP.missing$elementID[k], GRP.missing$unitID[k]
        )
      )
    }
  }

  MAP <- GRP[!is.na(N.std), .(jobID, elementID, unitID, standardID = NA_character_)]

  # Single-method groups
  MAP.single <- GRP[!is.na(N.std) & N.std == 1L & !is.na(standard.single),
    .(jobID, elementID, unitID, standardID = standard.single)
  ]
  if (nrow(MAP.single) > 0L) {
    MAP[MAP.single, on = c("jobID", "elementID", "unitID"), standardID := i.standardID]
  }

  # Ambiguous groups: vote using (1) explicit DL tags vs index, and (2) exact match to lab values
  GRP.amb <- GRP[!is.na(N.std) & N.std > 1L, .(jobID, elementID, unitID)]

  if (nrow(GRP.amb) > 0L) {
    for (k in seq_len(nrow(GRP.amb))) {
      j <- GRP.amb$jobID[k]
      e <- GRP.amb$elementID[k]
      u <- GRP.amb$unitID[k]

      IDX.g <- unique(IDX[jobID == j & elementID == e & unitID == u, .(standardID, minDL, maxDL)])
      candidates <- sort(unique(IDX.g$standardID))

      # Owner values/tags for this group
      DT.client <- unique(DATA.client[
        jobID == j & elementID == e & unitID == u,
        .(sampleID, value.client = value, tagDL.client = tagDL)
      ])

      # Votes from explicit DL tags in owner
      out.dl <- .inferMethodVotesDlB(DT.client = DT.client, IDX = IDX.g, tol = tol)
      votes.dl <- out.dl$votes
      if ("N" %in% names(votes.dl)) setnames(votes.dl, "N", "N.dl")

      # Votes from exact match to lab values
      sampleID.client <- unique(DT.client$sampleID)
      DT.lab <- unique(DATA.lab[
        jobID == j & elementID == e & unitID == u &
          (sampleID %chin% sampleID.client) & (standardID %chin% candidates),
        .(sampleID, standardID, value.lab = value, tagDL.lab = tagDL)
      ])

      out.lab <- .inferMethodVotesB(DT.client = DT.client, DT.lab = DT.lab, candidates = candidates, tol = tol)
      votes.lab <- out.lab$votes
      if ("N" %in% names(votes.lab)) setnames(votes.lab, "N", "N.lab")

      votes <- merge(votes.lab, votes.dl, by = "standardID", all = TRUE)
      if (nrow(votes) == 0L) {
        votes <- data.table(standardID = character(), N.lab = integer(), N.dl = integer())
      }
      votes[is.na(N.lab), N.lab := 0L]
      votes[is.na(N.dl), N.dl := 0L]
      votes[, N := N.lab + N.dl]
      votes <- votes[order(-N)]

      dl.msg <- paste(sprintf("%s:%g", IDX.g$standardID, IDX.g$minDL), collapse = ",")
      votes.msg <- if (nrow(votes)) paste(sprintf("%s:%d", votes$standardID, votes$N), collapse = ",") else ""

      if (nrow(votes) > 0L && votes$N[1] >= min.votes && (nrow(votes) == 1L || votes$N[1] > votes$N[2])) {
        inferred <- votes$standardID[1]
        .log(log.file, "INFO", file.id, "METHOD_INFERRED",
          sprintf(
            "jobID=%s; elementID=%s; unitID=%s; standardID=%s; votes=%d; votes_lab=%d; votes_dl=%d; voteN_lab=%d; voteN_dl=%d; sampleN=%d; candidates=[%s]; dl=[%s]; votes_all=[%s]",
            j, e, u, inferred,
            votes$N[1], votes$N.lab[1], votes$N.dl[1],
            out.lab$N.vote, out.dl$N.vote, out.lab$N.sample,
            paste(candidates, collapse = ","), dl.msg, votes.msg
          )
        )
        MAP[jobID == j & elementID == e & unitID == u, standardID := inferred]
        next
      }

      if (nrow(votes) >= 2L && votes$N[1] >= min.votes && votes$N[1] == votes$N[2]) {
        .log(log.file, "ERROR", file.id, "METHOD_AMBIGUOUS",
          sprintf(
            "jobID=%s; elementID=%s; unitID=%s; candidates=[%s]; dl=[%s]; votes=[%s]; voteN_lab=%d; voteN_dl=%d; sampleN=%d; min_votes=%d",
            j, e, u,
            paste(candidates, collapse = ","), dl.msg, votes.msg,
            out.lab$N.vote, out.dl$N.vote, out.lab$N.sample, min.votes
          )
        )
      } else {
        .log(log.file, "ERROR", file.id, "METHOD_UNDETERMINED",
          sprintf(
            "jobID=%s; elementID=%s; unitID=%s; candidates=[%s]; dl=[%s]; votes=[%s]; voteN_lab=%d; voteN_dl=%d; sampleN=%d; min_votes=%d",
            j, e, u,
            paste(candidates, collapse = ","), dl.msg, votes.msg,
            out.lab$N.vote, out.dl$N.vote, out.lab$N.sample, min.votes
          )
        )
      }
    }
  }

  MAP
}


# ----------------------------------------------------------------------
# Values audit for type B: infer standardID first, then compare values.
# NOTE: No fallback method selection. If ambiguous/undetermined -> ERROR and skip value audit for that group.

.auditValuesB <- function(log.file, data.lab, data.client, index.lab, fix = FALSE,
                        file.id = file.path("data", "proc", "client.csv"),
                        min.votes = 2L, tol = 5e-2) {
  DATA.lab <- data.lab
  DATA.client <- copy(data.client)

  # Ensure character type for standardID (type B assay often has all-missing standardID -> fread guesses logical)
  DATA.client[, standardID := as.character(standardID)]

  # Use lab-derived index (DL + method info) as the source of candidates.
  INDEX.lab <- copy(index.lab)
  INDEX.lab[, standardID := as.character(standardID)]

  # Infer method per (jobID, elementID, unitID)
  MAP <- .inferStandardIdB(
    log.file = log.file,
    DATA.lab = DATA.lab,
    DATA.client = DATA.client,
    INDEX.lab = INDEX.lab,
    min.votes = min.votes,
    tol = tol,
    file.id = file.id
  )

  if (nrow(MAP) > 0L) {
    MAP <- MAP[!is.na(standardID) & nzchar(standardID)]
    if (nrow(MAP) > 0L) {
      DATA.client[MAP, on = c("jobID", "elementID", "unitID"), standardID := i.standardID]
    }
  }

  # Audit tags and values for rows where standardID is known
  keys <- c("jobID", "sampleID", "elementID", "standardID", "unitID")

  DT.client <- unique(DATA.client[!is.na(standardID) & nzchar(standardID),
    .(jobID, sampleID, elementID, standardID, unitID, value.client = value, tagDL.client = tagDL)
  ])

  DT.lab <- unique(DATA.lab[, .(jobID, sampleID, elementID, standardID, unitID, value.lab = value, tagDL.lab = tagDL)])

  # Missing rows in lab for inferred method
  DT.missing <- DT.client[!DT.lab, on = keys]
  if (nrow(DT.missing) > 0L) {
    .log(log.file, "WARNING", file.id, "CLIENT_ROWS_NOT_IN_LAB",
      sprintf("count=%d", nrow(DT.missing))
    )
    Nmax <- 50L
    nlog <- min(nrow(DT.missing), Nmax)
    for (k in seq_len(nlog)) {
      .log(log.file, "ERROR", file.id, "MISSING_LAB_VALUE",
        sprintf(
          "jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s",
          DT.missing$jobID[k], DT.missing$sampleID[k], DT.missing$elementID[k], DT.missing$standardID[k], DT.missing$unitID[k]
        )
      )
    }
    if (nrow(DT.missing) > Nmax) {
      .log(log.file, "ERROR", file.id, "MISSING_LAB_VALUE_TRUNCATED",
        sprintf("logged=%d; total=%d", Nmax, nrow(DT.missing))
      )
    }
  }

  DT <- DT.lab[DT.client, on = keys, nomatch = 0L] |> unique()
  DT <- DT[!is.na(value.client) & !is.na(value.lab)]

  # Add DL metadata from index for explicit DL checks
  IDX <- unique(INDEX.lab[, .(jobID, elementID, unitID, standardID, minDL, maxDL)])
  DT <- IDX[DT, on = c("jobID", "elementID", "unitID", "standardID")]

  # Tag audit: owner should be consistent with lab tags
  DT[, OK.tag := (tagDL.client == tagDL.lab)]
  N.tag.wrong <- DT[OK.tag == FALSE, .N]
  if (N.tag.wrong > 0L) {
    .log(log.file, "WARNING", file.id, "TAGDL_MISMATCH", sprintf("count=%d", N.tag.wrong))
    idx <- which(DT$OK.tag == FALSE)
    if (length(idx)) {
      for (k in idx) {
        .log(log.file, "ERROR", file.id, "WRONG_TAGDL",
          sprintf(
            "jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s; tagDL.client=%s; tagDL.lab=%s",
            DT$jobID[k], DT$sampleID[k], DT$elementID[k], DT$standardID[k], DT$unitID[k], DT$tagDL.client[k], DT$tagDL.lab[k]
          )
        )
      }
    }
  }

  # Explicit DL checks (only when owner declares < or >)
  idx.lt <- DT$tagDL.client == "<" & !is.na(DT$minDL)
  idx.lt[is.na(idx.lt)] <- FALSE
  if (any(idx.lt)) {
    OK <- .valuesEqual(DT$value.client[idx.lt], DT$minDL[idx.lt], tol = tol)
    bad <- which(idx.lt)[OK == FALSE]
    if (length(bad)) {
      for (k in bad) {
        .log(log.file, "ERROR", file.id, "WRONG_MIN_DL",
          sprintf(
            "jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s; value.client=%g; minDL=%g",
            DT$jobID[k], DT$sampleID[k], DT$elementID[k], DT$standardID[k], DT$unitID[k], DT$value.client[k], DT$minDL[k]
          )
        )
      }
    }
  }

  idx.gt <- DT$tagDL.client == ">" & !is.na(DT$maxDL)
  idx.gt[is.na(idx.gt)] <- FALSE
  if (any(idx.gt)) {
    OK <- .valuesEqual(DT$value.client[idx.gt], DT$maxDL[idx.gt], tol = tol)
    bad <- which(idx.gt)[OK == FALSE]
    if (length(bad)) {
      for (k in bad) {
        .log(log.file, "ERROR", file.id, "WRONG_MAX_DL",
          sprintf(
            "jobID=%s; sampleID=%s; elementID=%s; standardID=%s; unitID=%s; value.client=%g; maxDL=%g",
            DT$jobID[k], DT$sampleID[k], DT$elementID[k], DT$standardID[k], DT$unitID[k], DT$value.client[k], DT$maxDL[k]
          )
        )
      }
    }
  }

  # Numeric audit: compare only where tags match
  DT <- DT[OK.tag == TRUE]
  OUT <- .auditValuesNumericJoin(
    log.file = log.file,
    file.id = file.id,
    DATA.client = DATA.client,
    DT = DT,
    keys = keys,
    tol = tol,
    fix = fix
  )
  DATA.client <- OUT$data.client

  return(list(data.client = DATA.client))
}
