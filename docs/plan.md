---
layout: default
title: Plan / history
permalink: /docs/plan/
---

# Plan, pruebas y resultados
Este documento resume el plan aplicado al repositorio para:
- consolidar implementaciones canónicas (parsers/audits/helpers),
- normalizar naming (sin snake_case, sin variables efímeras),
- y dejar pruebas reproducibles para tipo A y tipo B.

## Objetivos
1. Unificar implementaciones para evitar código duplicado entre `R/` y `test-*`.
2. Mantener comportamiento:
   - Tipo A: el parser universal debe replicar el parser A original.
   - Tipo B: parse + auditoría con inferencia de método debe funcionar end-to-end.
3. Aplicar política de naming:
   - Variables: preferir `log.file`, `data.file`, `index.file` (estilo con `.`).
   - Helpers/verbos: camelCase.
   - Funciones internas con prefijo `.` para no pisar funciones públicas o de R.
   - Excepción permitida: `.as.numeric` y `.as.Date` (mismo patrón que helpers conocidos).

## Cambios de estructura
### Código canónico en `R/`
Las implementaciones “de verdad” viven directamente en:
- `R/helpers.R`
- `R/parseLab.R`
- `R/parseAssay.R`
- `R/audit.R`

### Legacy (layout anterior)
Se conserva el layout anterior (wrappers mínimos) en:
- `R/legacy/`

También se conserva un snapshot del runner antiguo para comparación:
- `R/legacy/run.snapshot.R`

Nota: `R/legacy/*` existe solo para referencia/historial y no debe ser usado por los runners.

### Runner / CLI (contrato)
- El working directory debe ser el root del repo.
- Entry point: `dbaudit --project project/<PROJECT>/data`.
- La lógica vive en `R/dbAudit.R` (función `DBAudit()`) con defaults para `raw/lab`, `raw/assay` y `proc`.
- El assay CSV se detecta dentro de `raw/assay/` con reglas determinísticas.

### Tests sin parsers duplicados
Se eliminaron `test-A/parseLab.R`, `test-A/parseAssay.R`, `test-B/parseLab.R`, `test-B/parseAssay.R`.
Los runners `test-A/run.R` y `test-B/run.R` sourcean directamente desde `R/*`.

## Cambios de naming (resumen)
- Parsers tipo A “original” (para regresión):
  - `parseLabDataA()`
  - `parseAssayDataA()`
- Parsers universales:
  - `parseLabData(format=c("auto","A","B"), ...)`
  - `parseAssayData(format=c("auto","A","B"), ...)`
- Auditoría valores (A y B):
  - `auditValues(..., format=c("A","B"), ...)` (en B usa inferencia de método)

## Pruebas
### Test A (regresión)
Comando:
- `Rscript test-A/run.R`

Qué valida:
- Ejecuta el parser A original y el parser universal con `format="A"`.
- Verifica igualdad por conjunto (set-equality) para `index.csv`, `lab.csv` y `client.csv`.

### Test B (smoke test)
Comando:
- `Rscript test-B/run.R`

Qué valida:
- Parse lab tipo B (`parseLabData(format="B")`).
- Parse assay tipo B (`parseAssayData(format="B")`).
- Corre auditoría:
  - `auditStructure()` (estructura)
  - `auditValues(format="B")` (infiere `standardID` por (jobID, elementID, unitID) y luego audita tags/valores)

## Resultados
Última verificación:
- 2025-12-27: `Rscript test-A/run.R` pasó (exit 0).
- 2025-12-27: `Rscript test-B/run.R` pasó (exit 0).

## Notas
- Los logs generados por las pruebas no se consideran artefactos de código y no deberían formar parte del commit (son outputs de ejecución).