# PLAN — Taxonomía de eventos de dbAudit (rediseño)

Fecha: 2026-08-16. Estado: PROPUESTA para ruling del usuario. Motiva:
el vocabulario actual de eventos es acreción histórica sin diseño
("una completa alucinación heredada del viejo dbAudit" — usuario). Todo
trabajo de reporting sobre los logs queda DETENIDO hasta aprobar esta
taxonomía.

## Diagnóstico del vocabulario actual

1. Estilos mezclados: `SURVEY_REDATED` (UPPER_SNAKE) convive con
   `DuplicateSurveyDropped` (CamelCase) y `NumDepthsMismatch`.
2. Semántica inconsistente: unos nombres describen la ACCIÓN del
   pipeline (`NUMERIC_COMMA_FIXED`), otros la OBSERVACIÓN
   (`DERIVED_FIELD_MISMATCH`), otros el ESTADO (`SURVEY_REDATED`).
3. Pares redundantes: `ID_FIXED` (gate) e `ID_MISMATCH` (audit) nombran
   el mismo hecho en dos etapas — el lector no sabe si son dos
   problemas o uno.
4. Severidades que violan la filosofía WARNING=reparado /
   ERROR=irrecuperable: `DERIVED_FIELD_MISMATCH` y `UNIT_MISMATCH`
   (WARNING sin reparación).
5. Granularidad dispar: eventos por corrida, por archivo y por registro
   sin campo que lo declare.

## Principios de la taxonomía nueva

1. Un código nombra UN hecho observable sobre los datos — nunca la
   acción del pipeline. La acción es un CAMPO aparte.
2. Formato único: `OBJETO_CONDICION` en UPPER_SNAKE ASCII
   (`SURVEY_REDATED` ya cumple y sobrevive).
3. La severidad no va en el nombre: la lleva el campo `level`, regido
   por la filosofía (WARNING = ocurrió y se reparó; ERROR =
   irrecuperable).
4. Registro de log enriquecido (structured logging): campos
   `ts, level, event, action, scope, SiteID, HoleID, datetime, source,
   message` donde `action ∈ {repaired, rejected, reported}` y
   `scope ∈ {run, file, survey, record}`. Los dumps del deck se
   construyen por slicing directo, sin reconstrucción.
5. EL CATÁLOGO ES DATOS: una tabla única en dbAudit
   (`inst/events.csv`: event, object, condition, meaning.en,
   meaning.es, level, action, expected.action.en, expected.action.es)
   es la fuente de verdad. La leyenda del deck se GENERA de esa tabla —
   ningún texto de leyenda vuelve a escribirse a mano. Un código nuevo
   requiere fila nueva + ruling.

## Catálogo propuesto (mapa viejo → nuevo)

| Actual | Propuesto | Level | Action |
|---|---|---|---|
| NUMERIC_COMMA_FIXED | VALUE_COMMA_DECIMAL | WARNING | repaired |
| NUMERIC_PARSE_ERROR | VALUE_UNREADABLE | ERROR | rejected |
| ID_FIXED + ID_MISMATCH (fusión) | FILE_ID_CONFLICT | WARNING | repaired |
| SURVEY_REDATED | SURVEY_REDATED | ERROR | reported |
| DuplicateSurveyDropped | SURVEY_DUPLICATED | WARNING | repaired |
| NumDepthsMismatch | DEPTH_COUNT_CONFLICT | (ruling) | reported |
| DERIVED_FIELD_MISMATCH | CHANGE_INCONSISTENT | (ruling: ¿reparar y WARNING, o ERROR?) | (ruling) |
| UNIT_MISMATCH | UNITS_MIXED | (ruling: ¿ERROR?) | reported |
| RAW/DB_COLUMNS_MISSING | SCHEMA_COLUMNS_MISSING | ERROR | reported |
| AUDIT_START / AUDIT_DONE | RUN_START / RUN_DONE | INFO | reported |

## Migración

- dbAudit emite SOLO el vocabulario nuevo; sin período de transición:
  los productos son regenerables y el switch es un solo release.
- La tabla de equivalencia de arriba queda en este plan como registro
  histórico; los goldens y el harness de estrés se actualizan en el
  mismo cambio.
- Consumidores a actualizar en el mismo cambio: runners de AR-S2L1X,
  loaders del deck (`scripts/setup/audit*`), RATIONALE (menciona
  SURVEY_REDATED — sobrevive).

## Rulings pedidos

1. Formato y principio 1-5: ¿aprobados?
2. Los nombres propuestos del catálogo (columna "Propuesto") — el
   usuario puede reescribir cualquiera.
3. Los tres (ruling) abiertos: CHANGE_INCONSISTENT (¿reparar el campo
   derivado y WARNING, o ERROR sin reparar?), UNITS_MIXED (¿ERROR?),
   DEPTH_COUNT_CONFLICT (¿WARNING o ERROR?).
4. ¿La tabla `inst/events.csv` con textos EN y ES es el ledger de
   traducción que pediste, o el ledger va aparte?
