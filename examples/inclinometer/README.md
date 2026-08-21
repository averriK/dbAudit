# Inclinometer example

Runs the inclinometer engine (INC) on the Vega synthetic site shipped in
the repository under `inst/fixtures/Vega`. The fixture carries a
known-truth corruption matrix (`truth.csv`), so every event in the run log
is a planted injection, not noise.

The fixture's `source/` tree is copied into a temporary project; the runner
creates `raw/`, `db/` and `audit/` there and regenerates them on every run
(each run re-initializes `audit/log.csv`, so a piezometer run and an
inclinometer run on the same project do not share a log). The temporary
directory is removed when the script exits.

```sh
examples/inclinometer/run.sh
```

The script always runs this checkout's engine via `Rscript DBAudit`, so
the output matches this revision regardless of any installed `dbaudit`.

Expected output:

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
