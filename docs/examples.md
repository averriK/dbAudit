---
layout: default
title: Examples
permalink: /docs/examples/
---

# Examples

`examples/` holds one runnable script per engine. Every script runs against
fixtures that ship in the repository — the synthetic certificate pairs under
`tests/testthat/fixtures/` and the Vega synthetic site under
`inst/fixtures/Vega` — so a plain clone is enough: no project data, no
external dependencies beyond the five required R packages.

Each script copies its fixture into a temporary project, runs the engine
there, prints the run log and a few product rows, and removes the temporary
directory on exit. Each always runs the checkout's own engine via
`Rscript DBAudit` — printing the resolved engine as its first line — so the
output matches this revision regardless of any installed `dbaudit`. Run
them from the repository root:

```sh
examples/geochemistry/run.sh
examples/piezometer/run.sh
examples/inclinometer/run.sh
```

The outputs below are verified captures of these runs. The input layouts
they exercise are described in
[Project layout]({{ "/docs/project-layout/" | relative_url }}); the event
model behind the log rows is described in
[Logging]({{ "/docs/logging/" | relative_url }}).

## Geochemistry

Runs both synthetic certificate fixtures — `synthetic-A` (type-A
certificate model) and `synthetic-B` (type-B model) — through the
geochemistry contract, each in a temporary project with the default
`raw/lab` + `raw/assay` layout:

```sh
dbaudit geochemistry --project <DATA_ROOT>     # per fixture, run by the script
```

Each fixture carries one deliberate value error; `synthetic-B` adds an
analyte present in the client file but absent from the lab certificate, so
the two runs contrast the two certificate models and their findings. The
type-A run prints harmless `longer object length` warnings to stderr from
the leading-index-column detector on files this small.

```text
engine: Rscript /path/to/dbAudit/DBAudit

== synthetic-A ==
-- proc/log.csv (level, event, message) --
level,event,message
INFO,FILE_START,begin; jobID=SYN0001.A25
INFO,PARSE_OK,rows=24; jobID=SYN0001.A25
INFO,CLIENT_FILE_START,begin
INFO,CLIENT_PARSE_OK,rows=24; jobIDs=1; sampleIDs=6
WARNING,VALUE_MISMATCH,count=1; tol=0.05
ERROR,WRONG_VALUE,jobID=SYN0001.A25; sampleID=SYN00000003; elementID=Zn; standardID=G0100; unitID=ppm; value.client=1400; value.lab=1266; tol=0.05
-- proc/lab.csv (first 3 rows) --
sampleID,value,standardID,elementID,minDL,maxDL,unitID,fileID,jobID,despatchID,dateReceived,dateFinalized,sampleN,tagDL
SYN00000001,1.24,G0100,Cu,0.01,15,pct,SYN0001.A25_ORSYN25000001.csv,SYN0001.A25,ORSYN25000001,2025-01-05,2025-01-12,6,+
SYN00000002,0.87,G0100,Cu,0.01,15,pct,SYN0001.A25_ORSYN25000001.csv,SYN0001.A25,ORSYN25000001,2025-01-05,2025-01-12,6,+
SYN00000003,2.1,G0100,Cu,0.01,15,pct,SYN0001.A25_ORSYN25000001.csv,SYN0001.A25,ORSYN25000001,2025-01-05,2025-01-12,6,+

== synthetic-B ==
-- proc/log.csv (level, event, message) --
level,event,message
INFO,FILE_START,begin; jobID=QS2500001
INFO,PARSE_OK,rows=20; jobID=QS2500001
INFO,CLIENT_FILE_START,begin
INFO,CLIENT_PARSE_OK,rows=20; jobIDs=1; sampleIDs=5
WARNING,CLIENT_ANALYTE_NOT_IN_LAB,groups=1
ERROR,MISSING_LAB_ANALYTE,jobID=QS2500001; elementID=Mo; unitID=pct
WARNING,VALUE_MISMATCH,count=1; tol=0.05
ERROR,WRONG_VALUE,jobID=QS2500001; sampleID=SYN25_00002; elementID=Cu; standardID=AAS41B; unitID=pct; value.client=1.5; value.lab=1.105; tol=0.05
-- proc/lab.csv (first 3 rows) --
sampleID,value,standardID,elementID,minDL,maxDL,unitID,fileID,jobID,despatchID,dateReceived,dateFinalized,sampleN,tagDL
SYN25_00001,0.412,AAS41B,Cu,0.001,40,pct,QS2500001.CSV,QS2500001,SYNQ00001A,2025-01-05,2025-01-12,5,+
SYN25_00002,1.105,AAS41B,Cu,0.001,40,pct,QS2500001.CSV,QS2500001,SYNQ00001A,2025-01-05,2025-01-12,5,+
SYN25_00003,0.001,AAS41B,Cu,0.001,40,pct,QS2500001.CSV,QS2500001,SYNQ00001A,2025-01-05,2025-01-12,5,<
```

## Piezometer

Runs the Vega synthetic site (PCG Casagrande + PCV vibrating-wire) through
the piezometer contract. Vega carries a known-truth corruption matrix
(`inst/fixtures/Vega/truth.csv`), so every event in the log is a planted
injection, not noise:

```sh
dbaudit piezometer --project <DATA_ROOT>       # run by the script on a copy of Vega
```

The output shows the repaired decimal comma end to end: the source sheet
holds `3594,53`, the gate records the `COMMA` repair in
`audit/PCG.reject.csv`, and the database row (RecordID 5, 2023-05-14)
carries `3594.53`.

```text
engine: Rscript /path/to/dbAudit/DBAudit
-- audit/log.csv (timestamp column dropped) --
scope,SiteID,HoleID,datetime,source,level,event,detail
run,"","","",auditPiezometer,INFO,START,""
file,"","","",backup/PCG/Vega/VP-2_Depósito_de_Relaves_Vega.xlsx,ERROR,MISSING,data file under the source root never parsed
file,Vega,VP-3,"",VP-3_Depósito_de_Relaves_Vega.xlsx [VP-3 (2)],ERROR,MALFORMED,ID=PCG; declared monitoring sheet fails the data-sheet gate; readings skipped
record,Vega,VP-2,2023-12-14,data/raw,ERROR,DUPLICATED,"ID=PCG; SensorID=0; rows=2; SourceRow=22/23; variables=change, depth, head, level"
file,"","","",data/raw,INFO,MIXED,"ID=PCV; variable=pressure; units=kPa, MPa"
file,"","","",data/db,ERROR,UNITLESS,column=units.reading; rows=74
run,"","","",auditPiezometer,INFO,DONE,PZ.data=218; PZ.index=218
-- db/PCG.data.csv rows 4-6: RecordID 5 carries the repaired decimal comma --
RecordID,ID,SiteID,HoleID,SensorID,datetime,index,comment,depth,units.depth,level,units.level,head,units.head,change,units.change
4,PCG,Vega,VP-1,0,2023-04-19T12:33:00Z,4,Ascenso,18.12,m,3594.3,m,0.53,m,0.13,m
5,PCG,Vega,VP-1,0,2023-05-14T09:54:00Z,5,Ascenso,17.89,m,3594.53,m,0.76,m,0.23,m
6,PCG,Vega,VP-1,0,2023-06-18T09:18:00Z,6,Ascenso,17.67,m,3594.75,m,0.98,m,0.22,m
-- audit/PCG.reject.csv: the COMMA repair record for that row --
COMMA,WARNING,"value=3594,53; repaired=3594.53; inserted into db",PCG,Vega,VP-1,0,source/PCG/Vega/VP-1_Depósito_de_Relaves_Vega.xlsx,VP-1,15,5,,45060,0.4125,Ascenso,level,"3594,53",m
```

## Inclinometer

Runs the same Vega site through the inclinometer contract (INC):

```sh
dbaudit inclinometer --project <DATA_ROOT>     # run by the script on a copy of Vega
```

Each monitoring run re-initializes `audit/log.csv`, which is why the
piezometer and inclinometer examples work on separate copies of the
fixture.

```text
engine: Rscript /path/to/dbAudit/DBAudit
-- audit/log.csv (timestamp column dropped) --
scope,SiteID,HoleID,datetime,source,level,event,detail
run,"","","",auditInclinometer,INFO,START,""
survey,Vega,VI-2,"",data/db/INC.index.csv,WARNING,DUPLICATED,ID=INC; SurveyID=VI-2@20240314T101300; identical file consolidated; dropped=VEGA_VI-2_Inclinometer_20240314.csv
survey,Vega,VI-1,"",data/db/INC.index.csv,ERROR,MISCOUNTED,ID=INC; SurveyID=VI-1@20250313T120500; declared=40; observed=38
survey,"","","",data/db/INC.index.csv,WARNING,MISLABELED,ID=INC; field=Installation; count=37; format variant normalized
survey,"","","",data/db/INC.index.csv,ERROR,MISLABELED,ID=INC; field=Installation; count=1; different instrument declared
survey,"","","",data/db/INC.index.csv,ERROR,INCOMPLETE,ID=INC; empty field=Depth Bottom; rows=1
survey,"","","",data/db/INC.data.csv,ERROR,REDATED,ID=INC; groups=1; surveys=2; identical readings under different dates
run,"","","",auditInclinometer,INFO,DONE,INC.audit=3134
-- db/INC.data.csv (first 3 rows) --
SurveyID,RecordID,ID,SiteID,HoleID,SensorID,datetime,depth,units.depth,A0,A180,B0,B180
VI-1@20230111T125900,1,INC,Vega,VI-1,0,2023-01-11T12:59:00Z,0.5,Meters,-571344,629630,-139564,197724
VI-1@20230111T125900,2,INC,Vega,VI-1,0,2023-01-11T12:59:00Z,1,Meters,-696079,750495,104135,-54280
VI-1@20230111T125900,3,INC,Vega,VI-1,0,2023-01-11T12:59:00Z,1.5,Meters,-142869,197689,240878,-196460
```
