# PLAN — Taxonomía de eventos de dbAudit (v2, fundada en evidencia)

Fecha: 2026-08-16. Estado: PROPUESTA v2 para ruling del usuario.
Reemplaza la v1 (que era invención sin fuentes — ver historial git).
Evidencia: `EVIDENCE-qaqc-standards.md` (USGS GWSI/NWIS, EPA NFG, WMO
168 cap.9, Dunnicliff cap.18/7, MHRA; ledger con acceso declarado).
Todo trabajo de reporting sigue detenido hasta aprobar esto.

## La lección estructural de la evidencia

Los sistemas maduros de QA/QC de datos NO usan una lista plana de
"eventos de error": usan DIMENSIONES ORTOGONALES sobre cada registro.
La v1 de este plan (un código OBJETO_CONDICION que mezclaba hecho,
acción y severidad) repetía el error del vocabulario viejo con nombres
nuevos. La v2 separa las dimensiones.

## El registro de auditoría propuesto (cómo logear)

Un registro por hecho, con campos ortogonales:

| Campo | Contenido | Molde en la evidencia |
|---|---|---|
| `ts` | timestamp del run | práctica general |
| `scope` | `run` / `file` / `survey` / `record` | granularidad declarada (v1 sostenida) |
| `SiteID, HoleID, datetime, source` | identidad completa + archivo de origen | trazabilidad ALCOA / hoja de campo Dunnicliff 18.1.4 |
| `cause` | QUÉ se observó (catálogo abajo) | Dunnicliff cap.7 (clases de error); EPA Parte B (causa en estructura) |
| `disposition` | qué quedó del dato: `intact` / `corrected` / `estimated` / `retained_suspect` / `rejected` | EPA (sin calif./estimado/R); WMO §9.5.6, 9.7.2, 10.2.3.4 |
| `flag` | calificador de UNA LETRA sobre el valor cuando aplica: `D` seco, `E` estimado, `U` incierto, `V` verificado-fuera-de-rango | USGS lev_status/uv_rmk; WMO §9.3.5 |
| `detail` | valores verificables (tipeado vs recalculado, fechas del grupo, unidades halladas) | EPA narrative; WMO "mostrar la razón del flag" |

La SEVERIDAD deja de ser un campo primario: WARNING/ERROR se DERIVAN de
`disposition` (corrected/estimated → clase advertencia; rejected /
retained_suspect sin resolución → clase error). La filosofía del
usuario (WARNING = ocurrió y se reparó; ERROR = irrecuperable)
sobrevive intacta como VISTA, ahora con molde EPA/WMO. Los dos casos
que la violaban se resuelven solos: cada hecho declara su disposición
real en vez de heredar un nivel arbitrario.

## Catálogo de causas propuesto (qué logear)

`cause` en UPPER_SNAKE (convención local declarada; ni USGS ni WMO ni
EPA norman el naming del catálogo — WMO §9.3.2(c) manda adoptar/adaptar
sistemas existentes y DECLARAR el propio):

| Causa | Clase Dunnicliff | Disposición típica | Hoy (viejo nombre) |
|---|---|---|---|
| `VALUE_COMMA_DECIMAL` | gruesa (tipeo) | corrected | NUMERIC_COMMA_FIXED |
| `VALUE_UNREADABLE` | gruesa (tipeo) | rejected | NUMERIC_PARSE_ERROR |
| `FILE_ID_CONFLICT` | gruesa (archivo) | corrected | ID_FIXED + ID_MISMATCH (fusión) |
| `SURVEY_REDATED` | gruesa (archivo/fecha) | retained_suspect | SURVEY_REDATED |
| `SURVEY_DUPLICATED` | gruesa (archivo) | corrected (dedup) | DuplicateSurveyDropped |
| `CHANGE_INCONSISTENT` | gruesa (cálculo manual) | (ruling: ¿corrected recalculando, o retained_suspect?) | DERIVED_FIELD_MISMATCH |
| `UNITS_MIXED` | sistemática | retained_suspect | UNIT_MISMATCH |
| `DEPTH_COUNT_CONFLICT` | de conformancia | retained_suspect | NumDepthsMismatch |
| `SCHEMA_COLUMNS_MISSING` | de conformancia | rejected (scope file) | RAW/DB_COLUMNS_MISSING |
| `WELL_DRY` | condición (no error) | intact + flag `D` | (implícito hoy: level NA) |
| `RUN_START` / `RUN_DONE` | — | — (scope run) | AUDIT_START/DONE |

Nota WELL_DRY: siguiendo a USGS (§3.14, status D sin valor), el pozo
seco pasa de convención implícita (NA) a condición declarada con flag —
no es un error, es un estado del sitio en la medición.

## El catálogo es datos (sostenido de v1)

`inst/events.csv`: `cause, class, disposition.default, flag,
meaning.en, meaning.es, expected.action.en, expected.action.es`.
Fuente única; la leyenda del deck se GENERA de esta tabla; las columnas
EN/ES son el ledger de traducción pedido por el usuario. Código nuevo =
fila nueva + ruling.

## Estado de revisión (nivel III, futuro)

Molde USGS S/R/Q (in-review / aprobado / rechazado) por registro: es la
casilla natural donde los gates predictivos (espacial/temporal) y la
revisión del experto escribirán su veredicto. NO se implementa ahora;
se reserva el campo.

## Migración

Sin transición: dbAudit emite el esquema nuevo en un release; goldens,
harness de estrés, runners de AR-S2L1X y loaders del deck se actualizan
en el mismo cambio. La tabla vieja→nueva de arriba queda como registro.

## Rulings pedidos

1. ¿Registro ortogonal (cause/disposition/flag) aprobado?
2. ¿Vocabulario de disposición (intact/corrected/estimated/
   retained_suspect/rejected) aprobado?
3. Nombres del catálogo de causas — reescribí los que quieras.
4. `CHANGE_INCONSISTENT`: ¿corrected recalculando el campo derivado
   (molde EPA: la corrección es del productor), o retained_suspect sin
   tocar?
5. ¿`WELL_DRY` como condición declarada con flag D?
6. ¿events.csv con EN/ES como ledger de traducción?

## RULINGS RESUELTOS (usuario, 2026-08-16) — Fase 1 CERRADA

1. Esquema ortogonal (cause / disposition / flag): APROBADO.
2. CHANGE_INCONSISTENT: la base guarda el valor RECALCULADO (aritmetica
   de las cotas); el tipeado queda en el log como evidencia.
   Disposicion: corrected. (Se alinea con la filosofia: reparado.)
3. WELL_DRY: estado explicito con flag D (molde USGS: sin valor de
   nivel cuando el estado es seco). No es error ni faltante.
4. inst/events.csv con columnas EN/ES = el ledger de traduccion.
   Los logs emiten EN hoy; ES sale leyendo la otra columna.

Con esto queda definida la FASE 2 (emision dbAudit): crear
inst/events.csv; nuevo esquema de registro (ts, scope, SiteID, HoleID,
datetime, source, cause, disposition, flag, detail); renombrar la
emision al catalogo nuevo; reparar change recalculando en el build;
WELL_DRY con flag D; actualizar goldens + harness de estres + runners
de AR-S2L1X + loaders del deck en el mismo cambio. FASE 3 (deck v5 =
las seis preguntas del dueno, leyenda generada del catalogo) despues.
