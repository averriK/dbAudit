# Geochemistry example

Runs the geochemistry engine on the two synthetic certificate fixtures
shipped in the repository under `tests/testthat/fixtures/`: `synthetic-A`
(type-A certificate model) and `synthetic-B` (type-B certificate model).
Each fixture carries one deliberate value error, and `synthetic-B` adds an
analyte present in the client file but absent from the lab certificate, so
the two runs contrast the two certificate models and their audit findings.

Each fixture is copied into a temporary project with the default input
layout (`raw/lab` + `raw/assay`); the run writes `proc/lab.csv`,
`proc/index.csv`, `proc/client.csv` and `proc/log.csv` there, and the
temporary directory is removed when the script exits.

```sh
examples/geochemistry/run.sh
```

The script always runs this checkout's engine via `Rscript DBAudit`, so
the output matches this revision regardless of any installed `dbaudit`. The type-A run
prints harmless `longer object length` warnings to stderr from the
leading-index-column detector on files this small; the outputs below are
unaffected.

Expected output:

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
