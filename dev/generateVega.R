#!/usr/bin/env Rscript
## dev/generateVega.R
## Vega corrupt virtual site: deterministic generator of the engine
## acceptance fixture. Contract: dev/SoT/PLAN-virtual-site.md (RULINGS
## RESUELTOS 2026-08-18): SiteID Vega; lives in inst/fixtures/Vega; the
## approved corruption matrix (15 injections) plus 4 anti-ghost controls;
## truth manifest truth.csv (one row per injected fact, event = NONE for
## the anti-ghost controls).
##
## Seed series perturb the VALUE RANGES of the real client sheets (scale +
## offset + noise under one fixed seed); no client value is copied
## verbatim. Layouts replicate the client formats exactly so the parser
## exercises its real routes: PCG "MONITOREO DE PIEZÓMETROS" (header block
## rows 1-8, group/data headers rows 9-10, dates as Excel serials), PCV
## one sheet per channel "VP-4-A (12.50 m)" with the instrument header
## grid and the unit row under the data labels, INC "Installation v1" /
## "Survey v2" semicolon CSV. Rerunning overwrites inst/fixtures/Vega
## deterministically.

suppressPackageStartupMessages(library(data.table))
if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("writexl is required to write the xlsx fixtures", call. = FALSE)
}
if (!file.exists("DESCRIPTION")) {
  stop("run from the dbAudit package root", call. = FALSE)
}

SEED <- 20260818
set.seed(SEED)

Root <- file.path("inst", "fixtures", "Vega")
unlink(Root, recursive = TRUE)

.serial <- function(x) as.integer(as.Date(x) - as.Date("1899-12-30"))

.fm <- function(x, digits = 2L) {
  OUT <- sprintf(paste0("%.", digits, "f"), x)
  OUT[is.na(x)] <- ""
  OUT
}

## ---------------------------------------------------------------------
## Campaign calendar: 36 monthly field visits, 2023-01 .. 2025-12, day
## jittered around the 15th. Shared by every instrument (one site visit).
Dates <- seq(as.Date("2023-01-15"), by = "1 month", length.out = 36)
Dates <- Dates + sample(-4:4, size = 36, replace = TRUE)
SHEETDATE <- .serial(as.Date("2026-01-10"))

## ---------------------------------------------------------------------
## PCG (Casagrande): the water ELEVATION drives every sheet column, so a
## collar raise (anti-ghost 2) moves depth, tube and collar together
## while the level series stays continuous.
##
## blank = campaigns with no reading taken (level cell later corrupted to
## the client's "s/l"); dry = campaigns with the well dry (flag D case).
.pcgSeries <- function(collar, bottom, elev, hora, dry = integer(0),
                       blank = integer(0)) {
  Elev <- round(pmax(elev, bottom + 0.06), 2)
  Elev[dry] <- NA
  Elev[blank] <- NA
  Tube <- round(collar - bottom, 2)
  Depth <- round(collar - Elev, 2)
  Depth[dry] <- Tube[dry]
  Head <- round(Elev - bottom, 2)
  Head[dry] <- 0
  Change <- rep(NA_real_, length(Elev))
  Comment <- character(length(Elev))
  Last <- NA_real_
  LastDry <- FALSE
  for (i in seq_along(Elev)) {
    if (i %in% blank) {
      Comment[i] <- "Sin lectura"
      next
    }
    if (is.na(Elev[i])) {
      Comment[i] <- "Pozo seco"
      LastDry <- TRUE
      next
    }
    if (is.na(Last)) {
      Comment[i] <- "Primera lectura"
    } else if (LastDry) {
      ## Client convention (anti-ghost 1, the case that killed
      ## MISCOMPUTED): after a dry well the Variación is the recovery
      ## from the dry bottom, not a level difference.
      Change[i] <- Head[i]
      Comment[i] <- "Ascenso"
    } else {
      Change[i] <- round(Elev[i] - Last, 2)
      Comment[i] <- if (Change[i] > 0) {
        "Ascenso"
      } else if (Change[i] < 0) {
        "Descenso"
      } else {
        "Sin variación"
      }
    }
    Last <- Elev[i]
    LastDry <- FALSE
  }
  data.table(
    N = as.character(seq_along(Elev)),
    Fecha = as.character(.serial(Dates)),
    Hora = .fm(hora, digits = 5L),
    Tube = .fm(Tube),
    WaterDepth = .fm(Depth),
    Collar = .fm(collar),
    Bottom = .fm(rep(bottom, length(Elev))),
    Level = .fm(Elev),
    Head = .fm(Head),
    Change = .fm(Change),
    Comment = Comment,
    Plot = .fm(-Depth)
  )
}

## Client PCG sheet grid: header block rows 1-8, group headers row 9,
## data headers row 10, data from row 11. dateless = TRUE reproduces the
## broken export that lost its Fecha column (MALFORMED injection): the
## Fecha data column and both "Fecha" labels are absent.
.pcgGrid <- function(holeID, tube, coords, DT, dateless = FALSE) {
  OUT <- matrix("", nrow = 10L + nrow(DT), ncol = 14L)
  OUT[1, 4] <- "MONITOREO DE PIEZÓMETROS"
  OUT[3, 1:2] <- c(
    "Proyecto:",
    "Monitoreo de Instrumentación Geotécnica del Depósito de Relaves Vega"
  )
  OUT[4, 1:2] <- c("Ubicación:", "Quebrada Vega - Provincia Sintética")
  OUT[5, c(1, 2, 5, 6, 9, 10)] <- c(
    "Piezómetro:", holeID, "Zona:", "Depósito de Relaves Vega",
    "N° Proyecto:", "26-V-100-01"
  )
  OUT[6, c(1, 2, 5, 6, 7, 8, 9, 10)] <- c(
    "Profundidad:", sprintf("%s m", tube), "Coordenadas:",
    coords[1], coords[2], coords[3], "Cliente:", "Minera Vega S.A."
  )
  OUT[7, c(1, 2, 5, 6, 9, 10)] <- c(
    "Operador:", "V.O.", "Revisado por:", "V.R.",
    "Fecha:", as.character(SHEETDATE)
  )
  OUT[9, c(1, 2, 6, 7, 8, 9, 10, 11)] <- c(
    "N°", "Registro de Campo", "Cota de boca del tubo (msnm)",
    "Cota del fondo de aforo (msnm)", "Cota del Nivel de Agua (msnm)",
    "Carga de agua sobre fondo (m)", "Variación (m)", "Comentarios"
  )
  OUT[10, c(2, 3, 4, 5, 14)] <- c(
    "Fecha", "Hora", "Profundidad Piezómetro (m)",
    "Prof. agua desde la boca del tubo (m)", "Profundidad (m)"
  )
  Rows <- 10L + seq_len(nrow(DT))
  OUT[Rows, 1] <- DT$N
  OUT[Rows, 2] <- DT$Fecha
  OUT[Rows, 3] <- DT$Hora
  OUT[Rows, 4] <- DT$Tube
  OUT[Rows, 5] <- DT$WaterDepth
  OUT[Rows, 6] <- DT$Collar
  OUT[Rows, 7] <- DT$Bottom
  OUT[Rows, 8] <- DT$Level
  OUT[Rows, 9] <- DT$Head
  OUT[Rows, 10] <- DT$Change
  OUT[Rows, 11] <- DT$Comment
  OUT[Rows, 14] <- DT$Plot
  if (dateless) {
    OUT[7, 9:10] <- ""
    OUT[10, 2] <- ""
    OUT[Rows, 2] <- ""
  }
  OUT
}

.writeSheets <- function(path, sheets) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writexl::write_xlsx(
    x = lapply(X = sheets, FUN = as.data.frame, stringsAsFactors = FALSE),
    path = path,
    col_names = FALSE
  )
}

Truth <- list()
.truth <- function(file, row_or_date, event, level, correctable,
                   correct_value, note) {
  Truth[[length(Truth) + 1L]] <<- data.table(
    file = file, row_or_date = row_or_date, event = event, level = level,
    correctable = correctable, correct_value = correct_value, note = note
  )
}

NOTE.arn <- "validated engine-side by auditInclinometer()"

## ---------------------------------------------------------------------
## VP-1: COMMA x3, UNREADABLE x2, anti-ghost 3 (exact level repeat).
Hora <- round(runif(36, 0.35, 0.55) * 1440) / 1440
Elev <- 3594.55 + 0.45 * sin(2 * pi * (seq_len(36) - 5) / 12) + rnorm(36, 0, 0.06)
Elev[32] <- Elev[31]
VP1 <- .pcgSeries(
  collar = rep(3612.42, 36), bottom = 3593.77, elev = Elev, hora = Hora,
  blank = 9L
)
FILE.vp1 <- "source/PCG/Vega/VP-1_Depósito_de_Relaves_Vega.xlsx"
for (i in c(5L, 14L, 27L)) {
  .truth(
    file = FILE.vp1, row_or_date = as.character(Dates[i]), event = "COMMA",
    level = "WARNING", correctable = "yes", correct_value = VP1$Level[i],
    note = "fires in gate sink audit/PCG.reject.csv; value repaired into db"
  )
  VP1[i, Level := sub(pattern = ".", replacement = ",", x = Level, fixed = TRUE)]
}
VP1[9L, Level := "s/l"]
VALUE <- VP1$Level[21L]
VP1[21L, Level := sub(pattern = ".", replacement = "..", x = Level, fixed = TRUE)]
.truth(
  file = FILE.vp1, row_or_date = as.character(Dates[9]), event = "UNREADABLE",
  level = "ERROR", correctable = "no", correct_value = "",
  note = "fires in gate sink audit/PCG.reject.csv; no reading enters db"
)
.truth(
  file = FILE.vp1, row_or_date = as.character(Dates[21]), event = "UNREADABLE",
  level = "ERROR", correctable = "no", correct_value = "",
  note = sprintf(
    "fires in gate sink audit/PCG.reject.csv; level gap in db (typed %s)",
    VALUE
  )
)
.truth(
  file = FILE.vp1, row_or_date = as.character(Dates[32]), event = "NONE",
  level = "", correctable = "", correct_value = "",
  note = "anti-ghost: level repeats the previous month exactly (real piezometer persistence); must not fire"
)
.writeSheets(
  path = file.path(Root, FILE.vp1),
  sheets = list(
    "VP-1" = .pcgGrid(
      holeID = "VP-1", tube = "18.65",
      coords = c("E: 512384.612", "N: 8127455.238", "Z: 3612.420"),
      DT = VP1
    )
  )
)

## ---------------------------------------------------------------------
## VP-2: DUPLICATED record (identical re-entry: the same reading typed
## twice — same date, same hora, same values; only the sheet row
## differs, modeling the real client error per the 2026-08-18 ruling),
## anti-ghost 2 (legitimate collar raise +2.00 m with the collar column
## updated), and the MISSING backup file the parser never walks.
Hora <- round(runif(36, 0.35, 0.55) * 1440) / 1440
Collar <- rep(3598.35, 36)
Collar[19:36] <- 3600.35
Elev <- 3576.95 + 0.55 * sin(2 * pi * (seq_len(36) - 3) / 12) + rnorm(36, 0, 0.07)
VP2 <- .pcgSeries(collar = Collar, bottom = 3575.95, elev = Elev, hora = Hora)
FILE.vp2 <- "source/PCG/Vega/VP-2_Depósito_de_Relaves_Vega.xlsx"
VP2 <- rbindlist(l = list(VP2[1:12], VP2[12L], VP2[13:36]), use.names = TRUE)
.truth(
  file = FILE.vp2, row_or_date = as.character(Dates[12]), event = "DUPLICATED",
  level = "ERROR", correctable = "no", correct_value = "",
  note = "fires in log.csv: DUPLICATED record keyed on the client's row identity (date+hora+stage, ruling 2026-08-18); identical re-entry, same hora; both rows stay visible in db"
)
.truth(
  file = FILE.vp2, row_or_date = as.character(Dates[19]), event = "NONE",
  level = "", correctable = "", correct_value = "",
  note = "anti-ghost: legitimate collar raise +2.00 m with the declared collar column updated; MISCLOSURE must not fire"
)
.writeSheets(
  path = file.path(Root, FILE.vp2),
  sheets = list(
    "VP-2" = .pcgGrid(
      holeID = "VP-2", tube = "24.40",
      coords = c("E: 512501.844", "N: 8127238.905", "Z: 3600.350"),
      DT = VP2
    )
  )
)

## The valid January-2026 delivery that never got merged: it sits under
## source/backup/, which the parser does not walk (it only walks
## source/PCG and source/PCV), so its readings never reach the database.
DATE <- as.Date("2026-01-14")
Elev <- round(3576.95 + 0.55 * sin(2 * pi * (37 - 3) / 12) + rnorm(1, 0, 0.07), 2)
BACKUP <- data.table(
  N = "37", Fecha = as.character(.serial(DATE)), Hora = .fm(0.44236, digits = 5L),
  Tube = "24.40", WaterDepth = .fm(3600.35 - Elev), Collar = "3600.35",
  Bottom = "3575.95", Level = .fm(Elev), Head = .fm(Elev - 3575.95),
  Change = .fm(round(Elev - as.numeric(VP2$Level[37L]), 2)),
  Comment = if (Elev >= as.numeric(VP2$Level[37L])) "Ascenso" else "Descenso",
  Plot = .fm(-(3600.35 - Elev))
)
FILE.backup <- "source/backup/PCG/Vega/VP-2_Depósito_de_Relaves_Vega.xlsx"
.truth(
  file = FILE.backup, row_or_date = as.character(DATE), event = "MISSING",
  level = "ERROR", correctable = "no", correct_value = "",
  note = "fires in log.csv: source-to-raw census (gap closed 2026-08-18); the file outside the walked roots never reaches raw and its readings never load"
)
.writeSheets(
  path = file.path(Root, FILE.backup),
  sheets = list(
    "VP-2" = .pcgGrid(
      holeID = "VP-2", tube = "24.40",
      coords = c("E: 512501.844", "N: 8127238.905", "Z: 3600.350"),
      DT = BACKUP
    )
  )
)

## ---------------------------------------------------------------------
## VP-3: DRY x4 (campaigns 7-10, flag D), anti-ghost 1 (client-style
## Variación recovery on campaign 11), and the MALFORMED second sheet
## (broken export without the Fecha column, silently skipped today).
Hora <- round(runif(36, 0.35, 0.55) * 1440) / 1440
Elev <- 3592.35 + 0.85 * sin(2 * pi * (seq_len(36) - 8) / 12) + rnorm(36, 0, 0.05)
VP3 <- .pcgSeries(
  collar = rep(3606.88, 36), bottom = 3591.58, elev = Elev, hora = Hora,
  dry = 7:10
)
FILE.vp3 <- "source/PCG/Vega/VP-3_Depósito_de_Relaves_Vega.xlsx"
for (i in 7:10) {
  .truth(
    file = FILE.vp3, row_or_date = as.character(Dates[i]), event = "DRY",
    level = "INFO", correctable = "no", correct_value = "",
    note = "no log emission today; flag D in audit/PZ.data.csv is the record"
  )
}
.truth(
  file = FILE.vp3, row_or_date = as.character(Dates[11]), event = "NONE",
  level = "", correctable = "", correct_value = "",
  note = "anti-ghost: client-style Variación after a dry well (recovery from the dry bottom, the case that killed MISCOMPUTED); must not fire"
)
.truth(
  file = FILE.vp3, row_or_date = "sheet VP-3 (2)", event = "MALFORMED",
  level = "ERROR", correctable = "no", correct_value = "",
  note = "fires in log.csv: the sheet declares the monitoring marker but fails the data-sheet gate (gap closed 2026-08-18); its readings never enter the db"
)
.writeSheets(
  path = file.path(Root, FILE.vp3),
  sheets = list(
    "VP-3" = .pcgGrid(
      holeID = "VP-3", tube = "15.30",
      coords = c("E: 512297.410", "N: 8127601.577", "Z: 3606.880"),
      DT = VP3
    ),
    "VP-3 (2)" = .pcgGrid(
      holeID = "VP-3", tube = "15.30",
      coords = c("E: 512297.410", "N: 8127601.577", "Z: 3606.880"),
      DT = VP3, dateless = TRUE
    )
  )
)

## ---------------------------------------------------------------------
## VP-4 (vibrating wire, channels A/B): MIXED (A in kPa, B in MPa, each
## channel consistent = anti-ghost 4), UNITLESS (no unit declared for the
## R column in either sheet), MISCLOSURE x2 (depth typed against a wrong
## reference on channel A; check suspended today).
TERRAIN <- 3584.20
Level <- round(3576.50 + 1.10 * sin(2 * pi * (seq_len(36) - 4) / 12) + rnorm(36, 0, 0.05), 2)

.pcvTable <- function(level, sensorElev, r0, cf, mpa = FALSE) {
  Head <- round(level - sensorElev, 2)
  Pressure <- round(Head * 9.80665, 2)
  Reading <- round(r0 - Pressure / cf, 1)
  data.table(
    Stage = "",
    Fecha = as.character(.serial(Dates)),
    R = .fm(Reading, digits = 1L),
    Freq = .fm(sqrt(Reading * 1000), digits = 4L),
    T = .fm(15.8 + 1.5 * sin(2 * pi * (seq_len(36) - 2) / 12) + rnorm(36, 0, 0.2), digits = 1L),
    Pres = if (mpa) .fm(Pressure / 1000, digits = 4L) else .fm(Pressure),
    Head = .fm(Head),
    Level = .fm(level),
    WaterDepth = .fm(TERRAIN - level)
  )
}

## Client PCV sheet grid: title row 1, header block rows 5-8 (SONDEO
## label with the hole below it), instrument header rows 9-11, data
## labels row 12, unit row 13, data from row 14 (Zero Reading first).
## The unit cell under R (row 13, col 4) is left empty in BOTH sheets:
## that is the UNITLESS injection.
.pcvGrid <- function(sensor, hoja, geometry, pressureUnit, zero, DT) {
  OUT <- matrix("", nrow = 13L + 1L + nrow(DT), ncol = 15L)
  OUT[1, 2] <- "MONITOREO DE PIEZÓMETRO DE CUERDA VIBRANTE"
  OUT[5, c(2, 4)] <- c(
    "PROYECTO:",
    "Monitoreo de Instrumentación Geotécnica del Depósito de Relaves Vega"
  )
  OUT[6, c(2, 4, 8, 10, 11, 12)] <- c(
    "CLIENTE:", "Minera Vega S.A.", "REALIZADO POR:", "V.O.", "HOJA:", hoja
  )
  OUT[7, c(2, 4, 8, 10, 11)] <- c(
    "UBICACIÓN:", "Depósito de Relaves Vega", "REVISADO POR:", "V.R.", "SONDEO"
  )
  OUT[8, c(2, 4, 5, 6, 8, 10, 11)] <- c(
    "COORDENADAS (E, N, Z):", "512440.286", "8127350.114", .fm(TERRAIN, 3L),
    "SENSOR:", sensor, "VP-4"
  )
  OUT[9, c(2, 3, 4, 6, 8, 9, 10, 11, 12)] <- c(
    "Modelo", "No. Serie", "Rango", "Zero Reading", "Tk", "CF",
    "Prof. Instalación", "Inclinac.", "Cota del sensor"
  )
  OUT[10, c(4, 5, 6, 7, 8, 9, 10, 11, 12)] <- c(
    "(kPa)", "(psi)", "R (B)", "Ti (ºC)", "(kPa/ºC)", "(kPa/B)",
    "(m)", "(º)", "(msnm)"
  )
  OUT[11, c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)] <- c(
    "VW2100-RST", geometry$serialNo, "350", "50.763", zero$r, zero$t,
    geometry$tk, geometry$cf, geometry$installDepth, "90",
    geometry$sensorElev
  )
  OUT[12, c(1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15)] <- c(
    "Hora", "Etapa de Instalación", "Fecha", "R", "Frecuencia", "T",
    "Presión", "Factor de conversión", "Carga de Agua",
    "Elevación Nivel Piezométrico", "Nivel de agua", "Cota de instalación",
    "Cota de terreno"
  )
  OUT[13, c(5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)] <- c(
    "(Hz)", "(ºC)", pressureUnit, "(PSI)", "(kg/m2)", "(m/kPa)", "(m)",
    "(msnm)", "(m)", "(msnm)", "(msnm)"
  )
  OUT[14, c(2, 3, 4, 5, 6)] <- c(
    "Zero Reading", as.character(.serial(as.Date("2022-12-10"))),
    zero$r, zero$freq, zero$t
  )
  Rows <- 14L + seq_len(nrow(DT))
  OUT[Rows, 2] <- DT$Stage
  OUT[Rows, 3] <- DT$Fecha
  OUT[Rows, 4] <- DT$R
  OUT[Rows, 5] <- DT$Freq
  OUT[Rows, 6] <- DT$T
  OUT[Rows, 7] <- DT$Pres
  OUT[Rows, 10] <- "0.10197"
  OUT[Rows, 11] <- DT$Head
  OUT[Rows, 12] <- DT$Level
  OUT[Rows, 13] <- DT$WaterDepth
  OUT[Rows, 14] <- geometry$sensorElev
  OUT[Rows, 15] <- .fm(TERRAIN)
  OUT
}

CHA <- .pcvTable(level = Level, sensorElev = 3571.70, r0 = 8975.4, cf = 0.1183)
CHB <- .pcvTable(
  level = Level, sensorElev = 3560.20, r0 = 9142.7, cf = 0.1207, mpa = TRUE
)
FILE.vp4 <- "source/PCV/Vega/Piezómetro CV-VP-4.xlsx"
for (i in c(8L, 20L)) {
  .truth(
    file = FILE.vp4, row_or_date = as.character(Dates[i]), event = "MISCLOSURE",
    level = "ERROR", correctable = "no", correct_value = CHA$WaterDepth[i],
    note = "check suspended; fires after row-local redesign"
  )
  CHA[i, WaterDepth := .fm(as.numeric(WaterDepth) + 2.35)]
}
.truth(
  file = FILE.vp4, row_or_date = "", event = "MIXED",
  level = "INFO", correctable = "no", correct_value = "",
  note = "fires in log.csv: pressure declared in kPa on channel A and MPa on channel B"
)
.truth(
  file = FILE.vp4, row_or_date = "", event = "UNITLESS",
  level = "ERROR", correctable = "no", correct_value = "",
  note = "fires in log.csv: no unit declared for the R column in either channel sheet"
)
.truth(
  file = FILE.vp4, row_or_date = "", event = "NONE",
  level = "", correctable = "", correct_value = "",
  note = "anti-ghost: units differ per channel but each channel declares its unit consistently (the case that degraded MIXED to INFO); nothing beyond MIXED INFO may fire"
)
.writeSheets(
  path = file.path(Root, FILE.vp4),
  sheets = list(
    "VP-4-A (12.50 m)" = .pcvGrid(
      sensor = "A / PE-21", hoja = "1 / 2",
      geometry = list(
        serialNo = "VW201184", tk = "-0.0058712", cf = "0.1183",
        installDepth = "12.50", sensorElev = "3571.70"
      ),
      pressureUnit = "(kPa)",
      zero = list(r = "8975.4", freq = .fm(sqrt(8975.4 * 1000), 4L), t = "15.6"),
      DT = CHA
    ),
    "VP-4-B (24.00 m)" = .pcvGrid(
      sensor = "B / PE-22", hoja = "2 / 2",
      geometry = list(
        serialNo = "VW201185", tk = "-0.0060241", cf = "0.1207",
        installDepth = "24.00", sensorElev = "3560.20"
      ),
      pressureUnit = "(MPa)",
      zero = list(r = "9142.7", freq = .fm(sqrt(9142.7 * 1000), 4L), t = "14.9"),
      DT = CHB
    )
  )
)

## ---------------------------------------------------------------------
## INC (VI-1, VI-2): monthly Installation v1 / Survey v2 CSV surveys.
## auditPiezometer() does not cover INC; every INC injection ships in the
## fixture for the AR runner (truth note "validated by AR runner").

.incProfile <- function(n) {
  OUT <- as.integer(round(cumsum(rnorm(n, 0, 260000))))
  OUT <- OUT - as.integer(round(mean(OUT)))
  as.integer(pmax(pmin(OUT, 1800000L), -1800000L))
}

.incLines <- function(hole, sn, dt, depths, a0, b0, declared, bottom) {
  A180 <- -a0 + 50000L + as.integer(round(rnorm(length(a0), 0, 6000)))
  B180 <- -b0 + 48000L + as.integer(round(rnorm(length(b0), 0, 6000)))
  DEPTH <- ifelse(
    depths %% 1 == 0,
    sprintf("%d", as.integer(depths)),
    sprintf("%.1f", depths)
  )
  c(
    paste0(
      "Headings;Site;Installation;Description;A0Dir;Depth Top;",
      "Depth Bottom;Depth Interval;Depth Offset;Latitude;Longitude;",
      "Elevation;Instrument Constant;Orientation Correction;DepthUnits;",
      "DisplayUnits"
    ),
    sprintf(
      "Installation v1;VEGA;%s;;0;1;%s;0.5;0;0;0;0;25000;0;Meters;mm",
      hole, bottom
    ),
    paste0(
      "Headings;Survey DateTime;Num Passes;Num Depths;Sensor SN;",
      "Actl Cnst;Rotation A;Rotation B;Bias A;Bias B;Sensitivity A;",
      "Sensitivity B;Operator;SurveyType;Settlement Corrected;",
      "CutAtBottom;Water Level"
    ),
    sprintf(
      "Survey v2;%s;2;%d;%s;50000000;0.0000;0.0000;0.0;0.0;1.000;1.000;;0;False;False;0",
      dt, declared, sn
    ),
    "Depth;A0;A180;B0;B180",
    sprintf("%s;%d;%d;%d;%d", DEPTH, a0, A180, b0, B180)
  )
}

.incDatetime <- function(date, h, m) {
  sprintf(
    "%d/%02d/%d %02d:%02d:00",
    as.integer(format(date, "%d")), as.integer(format(date, "%m")),
    as.integer(format(date, "%Y")), h, m
  )
}

.writeInc <- function(hole, holeContent, sn, bottom) {
  Depths <- seq(0.5, bottom, by = 0.5)
  n <- length(Depths)
  BaseA <- .incProfile(n)
  BaseB <- .incProfile(n) - 400000L
  Drift <- as.integer(round(600 * rev(seq_len(n)) / n))
  DIR <- file.path(Root, "source", "INC", "Vega", hole)
  dir.create(DIR, recursive = TRUE, showWarnings = FALSE)
  Hours <- sample(9:16, size = 36, replace = TRUE)
  Minutes <- sample(0:59, size = 36, replace = TRUE)
  invisible(lapply(X = seq_len(36), FUN = function(i) {
    A0 <- BaseA + Drift * i + as.integer(round(rnorm(n, 0, 2500)))
    B0 <- BaseB + Drift * i + as.integer(round(rnorm(n, 0, 2500)))
    FILE <- file.path(
      DIR,
      sprintf("VEGA_%s_Inclinometer_%s.csv", hole, format(Dates[i], "%Y%m%d"))
    )
    writeLines(
      text = .incLines(
        hole = holeContent, sn = sn,
        dt = .incDatetime(date = Dates[i], h = Hours[i], m = Minutes[i]),
        depths = Depths, a0 = A0, b0 = B0, declared = n, bottom = bottom
      ),
      con = FILE
    )
  }))
  DIR
}

## VI-1: every file declares "VI-01" (systematic format variant of the
## folder/filename identity VI-1) = MISLABELED WARNING for the AR runner.
DIR <- .writeInc(hole = "VI-1", holeContent = "VI-01", sn = "DP45VEGA1,C", bottom = 19)
.truth(
  file = "source/INC/Vega/VI-1", row_or_date = "", event = "MISLABELED",
  level = "WARNING", correctable = "yes", correct_value = "VI-1",
  note = NOTE.arn
)

## REDATED: the June-2024 survey (campaign 18) republished a week later
## with a different declared date and identical data rows.
FILE <- file.path(
  DIR, sprintf("VEGA_VI-1_Inclinometer_%s.csv", format(Dates[18], "%Y%m%d"))
)
LINES <- readLines(FILE)
LINES[4] <- sub(
  pattern = "^(Survey v2;)[^;]*;",
  replacement = sprintf(
    "\\1%s;", .incDatetime(date = Dates[18] + 7, h = 10, m = 5)
  ),
  x = LINES[4]
)
FILE.redated <- file.path(
  DIR, sprintf("VEGA_VI-1_Inclinometer_%s.csv", format(Dates[18] + 7, "%Y%m%d"))
)
writeLines(text = LINES, con = FILE.redated)
.truth(
  file = sub(paste0(Root, "/"), "", FILE.redated), row_or_date = as.character(Dates[18] + 7),
  event = "REDATED", level = "ERROR", correctable = "no", correct_value = "",
  note = NOTE.arn
)

## MISCOUNTED: the March-2025 survey (campaign 27) declares 40 depths and
## brings 38 rows.
FILE <- file.path(
  DIR, sprintf("VEGA_VI-1_Inclinometer_%s.csv", format(Dates[27], "%Y%m%d"))
)
LINES <- readLines(FILE)
LINES[4] <- sub(pattern = ";2;38;", replacement = ";2;40;", x = LINES[4], fixed = TRUE)
writeLines(text = LINES, con = FILE)
.truth(
  file = sub(paste0(Root, "/"), "", FILE), row_or_date = as.character(Dates[27]),
  event = "MISCOUNTED", level = "ERROR", correctable = "no", correct_value = "38",
  note = NOTE.arn
)

## VI-2: normal content identity; three injected files.
DIR <- .writeInc(hole = "VI-2", holeContent = "VI-2", sn = "DP45VEGA2,C", bottom = 24)

## MISLABELED ERROR: the September-2024 survey (campaign 21) declares an
## instrument that does not exist on the site.
FILE <- file.path(
  DIR, sprintf("VEGA_VI-2_Inclinometer_%s.csv", format(Dates[21], "%Y%m%d"))
)
LINES <- readLines(FILE)
LINES[2] <- sub(pattern = ";VI-2;", replacement = ";VI-9;", x = LINES[2], fixed = TRUE)
writeLines(text = LINES, con = FILE)
.truth(
  file = sub(paste0(Root, "/"), "", FILE), row_or_date = as.character(Dates[21]),
  event = "MISLABELED", level = "ERROR", correctable = "no", correct_value = "",
  note = NOTE.arn
)

## DUPLICATED survey: the March-2024 file (campaign 15) exists
## byte-identical under a second name.
FILE <- file.path(
  DIR, sprintf("VEGA_VI-2_Inclinometer_%s.csv", format(Dates[15], "%Y%m%d"))
)
FILE.copy <- sub(pattern = "[.]csv$", replacement = " - copia.csv", x = FILE)
invisible(file.copy(from = FILE, to = FILE.copy, overwrite = TRUE))
.truth(
  file = sub(paste0(Root, "/"), "", FILE.copy), row_or_date = as.character(Dates[15]),
  event = "DUPLICATED", level = "WARNING", correctable = "yes", correct_value = "",
  note = NOTE.arn
)

## INCOMPLETE: the June-2025 survey (campaign 30) lost the tube depth
## (Depth Bottom) in its Installation header.
FILE <- file.path(
  DIR, sprintf("VEGA_VI-2_Inclinometer_%s.csv", format(Dates[30], "%Y%m%d"))
)
LINES <- readLines(FILE)
LINES[2] <- sub(pattern = ";0;1;24;0.5;", replacement = ";0;1;;0.5;", x = LINES[2], fixed = TRUE)
writeLines(text = LINES, con = FILE)
.truth(
  file = sub(paste0(Root, "/"), "", FILE), row_or_date = as.character(Dates[30]),
  event = "INCOMPLETE", level = "ERROR", correctable = "no", correct_value = "",
  note = NOTE.arn
)

## ---------------------------------------------------------------------
## Truth manifest.
TRUTH <- rbindlist(l = Truth, use.names = TRUE)
setorder(TRUTH, file, row_or_date, event)
fwrite(x = TRUTH, file = file.path(Root, "truth.csv"))

cat(sprintf(
  "Vega fixture written under %s: %d truth rows (%d injection rows over %d events + %d anti-ghost)\n",
  Root, nrow(TRUTH), nrow(TRUTH[event != "NONE"]),
  nrow(unique(TRUTH[event != "NONE", .(event, level)])),
  nrow(TRUTH[event == "NONE"])
))
