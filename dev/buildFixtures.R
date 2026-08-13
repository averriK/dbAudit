#!/usr/bin/env Rscript
## dev/buildFixtures.R
## Deterministic synthetic fixtures for the geochemical pipeline.
##
## Writes tests/testthat/fixtures/synthetic-A and synthetic-B: one type-A
## and one type-B certificate with matching assay tables. Every identifier
## is invented; no client material is used. The fixtures are tiny so the
## golden tests can run inside R CMD check, where the local-only real
## fixtures skip.

Root <- file.path("tests", "testthat", "fixtures")

.writeFixture <- function(name, raw, assay, assayName) {
  PATH.raw <- file.path(Root, name, "raw")
  PATH.assay <- file.path(Root, name, "assay")
  dir.create(path = PATH.raw, recursive = TRUE, showWarnings = FALSE)
  dir.create(path = PATH.assay, recursive = TRUE, showWarnings = FALSE)
  writeLines(text = raw$lines, con = file.path(PATH.raw, raw$name))
  writeLines(text = assay, con = file.path(PATH.assay, assayName))
}

## Type A: fixed-offset layout. jobID comes from the LabjobNo line.

CertA <- list(
  name = "SYN0001.A25_ORSYN25000001.csv",
  lines = c(
    "LabjobNo:,SYN0001.A25,\"\",\"\",\"\",\"\"",
    "DespatchNo:,ORSYN25000001,\"\",\"\",\"\",\"\"",
    "# of SAMPLES:,6,\"\",\"\",\"\",\"\"",
    "DATE RECEIVED:,05-Jan-2025,\"\",\"\",\"\",\"\"",
    "DATE FINALIZED:,12-Jan-2025,\"\",\"\",\"\",\"\"",
    "ESTADO:,Terminado,\"\",\"\",\"\",\"\"",
    "\"\",\"\",G0100,G0100,G0200,G0200",
    "SAMPLE,Analysis Order,Cu,Zn,Pb,Ag",
    "DESCRIPTION,\"\",PCT,PPM,PPM,PPM",
    "MIN DETECTION,\"\",0.01,2,0.5,0.1",
    "MAX DETECTION,\"\",15,10000,10000,100",
    "SYN00000001,1,1.24,835,12.5,3.4",
    "SYN00000002,2,0.87,412,8.0,1.2",
    "SYN00000003,3,2.10,1266,44.7,7.9",
    "SYN00000004,4,<0.01,96,2.1,0.3",
    "SYN00000005,5,0.55,720,15.3,2.8",
    "SYN00000006,6,1.61,958,31.0,5.5"
  )
)

## The assay declares the same scope; one Zn value diverges beyond the 5%
## audit tolerance on purpose so the value audit has a deterministic finding.

AssayA <- c(
  "Sample_Id,Certificate,Cu_G0100_pct,Zn_G0100_ppm,Pb_G0200_ppm,Ag_G0200_ppm",
  "SYN00000001,SYN0001.A25,1.24,835,12.5,3.4",
  "SYN00000002,SYN0001.A25,0.87,412,8.0,1.2",
  "SYN00000003,SYN0001.A25,2.10,1400,44.7,7.9",
  "SYN00000004,SYN0001.A25,<0.01,96,2.1,0.3",
  "SYN00000005,SYN0001.A25,0.55,720,15.3,2.8",
  "SYN00000006,SYN0001.A25,1.61,958,31.0,5.5"
)

## Type B: marker-driven layout. jobID comes from the file basename.

CertB <- list(
  name = "QS2500001.CSV",
  lines = c(
    "Laboratorio Sintetico S.A.C.,,,,,,,",
    "Proyecto Sintetico,PROJECT,SINTETICO,,,,,",
    "QS2500001,Received:,05/01/2025,Date Completed:,12/01/2025,,,",
    "DespatchNo:,SYNQ00001A,,,,,,",
    "Laboratory:,SYN LIM,,,SYN-LAB,SYN-LAB,SYN-LAB,SYN-LAB",
    "Method:,,,,Cu-AAS41B,Mo-AAS42C,CuCn-CSC65G,CuS-AAS74B",
    "Digestion:,,,,DIG1,DIG1,DIG1,DIG1",
    "Acid/Strenght:,,,,,,,",
    "Sample Wt (grams):,,,,0.25,0.5,0.25,0.2",
    "Units:,,,,%,ppm,%,%",
    "Det. Lim:,,,,0.001,2,0.01,0.001",
    "Upper Lim:,,,,40,10000,100,20",
    ",,,,,,,",
    "ELEMENT,SYN-LAB,Sample,Analytical,Cu,Mo,CuCn,CuS",
    "SAMPLES,Batch No,Wt. g,Order,%,ppm,%,%",
    "SYN25_00001,QS2500001,,1,0.412,158,0.05,0.031",
    "SYN25_00002,QS2500001,,2,1.105,64,0.12,0.088",
    "SYN25_00003,QS2500001,,3,<0.001,<2,<0.01,<0.001",
    "SYN25_00004,QS2500001,,4,0.238,231,0.03,0.017",
    "SYN25_00005,QS2500001,,5,0.771,95,0.08,0.052"
  )
)

## Mo is reported in ppm by the certificate and declared in pct by the
## assay, exercising the unit conversion. One Cu value diverges on purpose.

AssayB <- c(
  paste0(
    "\"Sample_Id\",\"Certificate\",\"Labjob_CuT\",\"Labjob_Mo\",",
    "\"Labjob_CuCN\",\"Labjob_CuS\",\"Cu_pct\",\"Mo_pct\",\"CuCn_pct\",\"CuS_pct\""
  ),
  "\"SYN25_00001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",0.412,0.0158,0.05,0.031",
  "\"SYN25_00002\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",1.500,0.0064,0.12,0.088",
  "\"SYN25_00003\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",<0.001,<0.0002,<0.01,<0.001",
  "\"SYN25_00004\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",0.238,0.0231,0.03,0.017",
  "\"SYN25_00005\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",\"QS2500001\",0.771,0.0095,0.08,0.052"
)

.writeFixture(name = "synthetic-A", raw = CertA, assay = AssayA, assayName = "_Assay_Comp.csv")
.writeFixture(name = "synthetic-B", raw = CertB, assay = AssayB, assayName = "AAQ_Sample_Assay.csv")

cat(sprintf("Fixtures written under %s\n", Root))
