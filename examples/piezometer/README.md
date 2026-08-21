# Piezometer example

Runs the piezometer engine (PCG Casagrande + PCV vibrating-wire) on the
Vega synthetic site shipped in the repository under `inst/fixtures/Vega`.
The fixture carries a known-truth corruption matrix (`truth.csv`), so every
event in the run log is a planted injection, not noise.

The fixture's `source/` tree is copied into a temporary project; the runner
creates `raw/`, `db/` and `audit/` there and regenerates them on every run.
The temporary directory is removed when the script exits.

```sh
examples/piezometer/run.sh
```

The script always runs this checkout's engine via `Rscript DBAudit`, so
the output matches this revision regardless of any installed `dbaudit`.

The output shows the repaired decimal comma end to end: the source sheet
holds `3594,53`, the gate records the `COMMA` repair in
`audit/PCG.reject.csv`, and the database row (RecordID 5, 2023-05-14)
carries `3594.53`.

Expected output:

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
