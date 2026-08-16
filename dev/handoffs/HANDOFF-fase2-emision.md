# HANDOFF — Fase 2: emisión del esquema de eventos v2

Para: sesión fresca (Claude o Codex). Fecha: 2026-08-16.
Repositorio: `~/github/tools/dbAudit` (rama dev). Consumidor a
actualizar en el mismo cambio: `~/Cloud/github/projects/AR-S2L1X`.

## Autoridad y contexto (leer primero, en este orden)

1. `dev/SoT/PLAN-event-taxonomy.md` — la taxonomía v2 APROBADA con los
   4 rulings del usuario (sección final "RULINGS RESUELTOS"). Es la
   especificación; no reabrir decisiones.
2. `dev/SoT/EVIDENCE-qaqc-standards.md` — el fundamento; solo consulta.
3. `dev/SoT/PLAN-pipeline-contracts.md` — contratos del pipeline,
   naming ratificado, harness golden y de estrés.
4. En AR-S2L1X: `dev/SoT/PLAN-logging.md` (marco de tres problemas,
   las seis preguntas del dueño, reglas del deck).

## Alcance exacto

1. Crear `inst/events.csv`: cause, class, disposition.default, flag,
   meaning.en, meaning.es, expected.action.en, expected.action.es —
   una fila por causa del catálogo aprobado (tabla en el plan).
2. Nuevo esquema de registro de log: ts, scope, SiteID, HoleID,
   datetime, source, cause, disposition, flag, detail. La severidad
   NO se almacena: se deriva (corrected/estimated→advertencia;
   rejected/retained_suspect→error) en la capa de lectura.
3. Renombrar la emisión al catálogo nuevo (mapa viejo→nuevo en el
   plan). FILE_ID_CONFLICT fusiona ID_FIXED+ID_MISMATCH: un solo
   hecho, emitido una vez.
4. CHANGE_INCONSISTENT: el build GUARDA el change recalculado
   (head - lag(head)); el tipeado va al detail del log. corrected.
5. WELL_DRY: condición explícita con flag D; sin valor de nivel cuando
   está seco (molde USGS). Revisar el producto PZ.data.csv para que la
   condición viaje declarada, no como NA implícito.
6. Actualizar en el MISMO cambio: goldens (tests/testthat/
   test-golden-outputs.R — los md5 cambiarán: regenerarlos con el
   procedimiento documentado en el SoT), fixtures sintéticos, harness
   de estrés de AR (dev/SoT/stressAudit.R), runners de AR
   (scripts/run*.R), loaders del deck de AR (scripts/setup/audit*.R).

## Reglas

- Verificar por ejecución en cada paso (lección de la sesión: nunca
  afirmar sin correr). Paridad byte donde el contrato no cambia.
- Git: mensajes imperativos, SIN atribución de IA. dbAudit en rama dev;
  AR-S2L1X en main; push normal de rama actual.
- Nada de texto inventado: todo mensaje sale de events.csv.

## Aceptación

- `Rscript scripts/runParse.R && runData && runAudit` en AR produce el
  log con el esquema nuevo; conteos equivalentes al mapa viejo→nuevo.
- R CMD check de dbAudit PASS; goldens regenerados y verdes.
- El usuario revisa una muestra del log nuevo antes de cerrar.
