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

## FASE 2 EJECUTADA (2026-08-16) — pendiente de aceptacion

Emision v2 implementada y verificada punta a punta:

- dbAudit: inst/events.csv (16 causas, 12 approved + 4 proposed),
  eventLog.R, gates y checks reescritos, .repairPCGChange,
  .checkFileIDResidual, WELL_DRY flag D. Tests: fixtures 4 PASS,
  goldens 5 PASS, test-dbaudit 4 PASS; R CMD check exit 0.
- AR-S2L1X: runners (runAudit.R, runData.R), loaders del deck
  (setup/audit.R, setup/auditDumps.R), harness (stressAudit.R) y
  leyenda GENERADA del catalogo (_slides/aud.dumps.qmd) en el mismo
  cambio. Pipeline completo corrido contra dbAudit v2 en libreria
  scratch: mapa viejo->nuevo cierra exacto (ID_MISMATCH 2 ->
  FILE_ID_CONFLICT 2; UNIT_MISMATCH 1 -> UNITS_MIXED 1;
  SURVEY_REDATED 1; 39 DERIVED -> sink CHANGE_INCONSISTENT corrected;
  flag D en 394/2403 registros PZ). Bug cazado por el propio esquema:
  el lector de cobertura INC buscaba la etiqueta vieja
  DuplicateSurveyDropped (falso RECORD_UNRECONCILED); corregido.

ACEPTACION (usuario, 2026-08-16): muestra del log v2 ACEPTADA.
dbAudit reinstalado (CLI por install.sh; el paquete R se instalo
aparte con R CMD INSTALL desde el checkout dev — hallazgo: install.sh
solo despliega /usr/local/libexec y nunca actualiza la libreria R que
importan los runners AR via .importDbAudit). Pipeline AR completo
verificado contra el namespace instalado real: mismos conteos que la
verificacion scratch (log 6 eventos; sink 39 CHANGE_INCONSISTENT
corrected; flag D 394/2403). FASE 2 CERRADA.

Pendiente (fase 3 y ruling): (a) ruling de las 4 causas "proposed":
RECORD_UNRECONCILED, OBSERVATION_DUPLICATED, UNITS_MISSING,
HEADER_INCOMPLETE; (b) deck v5 (seis preguntas del dueno, leyenda
generada — ya implementada en _slides/aud.dumps.qmd).

## RULING: codigos de UNA palabra (usuario, 2026-08-16) — APLICADO

El usuario rechazo los codigos compuestos OBJETO_CONDICION: el objeto
ya vive en `scope` (el registro es ortogonal), meterlo en el codigo
duplicaba informacion. Esquema aprobado: TODO el vocabulario del log
es de una palabra.

- Codigos: COMMA, UNREADABLE, MISLABELED, REDATED, DUPLICATED,
  MISCOMPUTED, MIXED, UNITLESS, MISCOUNTED, MALFORMED, INCOMPLETE,
  MISSING, DRY, START, DONE.
- Disposiciones: intact, corrected, estimated, suspect (antes
  retained_suspect), rejected.
- La clave del catalogo es el par (cause, scope): DUPLICATED en
  survey = archivos identicos consolidados (corrected); en record =
  dos lecturas mismo instrumento y fecha (suspect). events.csv gano
  la columna `scope` (lista separada por ";"); .logEvent valida el
  par. Los 4 codigos antes "proposed" quedaron aprobados con el
  esquema (MISSING, DUPLICATED record, UNITLESS, INCOMPLETE).
- Ademas: sin jerga en los textos del catalogo (orden del usuario:
  nada de "metadatos", "capa de procesamiento", "linaje").

Mapa v2 dos-palabras -> v2.1 una-palabra: VALUE_COMMA_DECIMAL->COMMA;
VALUE_UNREADABLE->UNREADABLE; FILE_ID_CONFLICT->MISLABELED;
SURVEY_REDATED->REDATED; SURVEY_DUPLICATED->DUPLICATED(survey);
OBSERVATION_DUPLICATED->DUPLICATED(record, scope normalizado);
CHANGE_INCONSISTENT->MISCOMPUTED; UNITS_MIXED->MIXED;
UNITS_MISSING->UNITLESS; DEPTH_COUNT_CONFLICT->MISCOUNTED;
SCHEMA_COLUMNS_MISSING->MALFORMED; HEADER_INCOMPLETE->INCOMPLETE;
RECORD_UNRECONCILED->MISSING; WELL_DRY->DRY; RUN_START/DONE->
START/DONE.

Verificacion: tests dbAudit 13 PASS; pipeline AR completo contra el
namespace instalado — log 6 eventos (START, MIXED, MISLABELED x2,
REDATED, DONE), sink 39 MISCOMPUTED corrected, flag D 394/2403,
index DUPLICATED 2. Pendiente del usuario: rerun de
install/install.sh (el CLI en /usr/local/libexec quedo con el
catalogo viejo; requiere sudo).

## RULING v3 (usuario, 2026-08-17): volver al modelo de mineralogia

El esquema v2 (disposition de 5 valores, severidad derivada invisible)
fue RECHAZADO: "un hibrido que no se entiende; no se sabe si son
errores o fueron corregidos". La referencia es el pipeline de
mineralogia (parseAssay/parseLab/helpers): level ALMACENADO + codigo
del problema + filtro de una linea por ERROR.

Definiciones fijadas (ruling 4):
- INFO    = marcas de proceso y condiciones del sitio; nada esta mal
            en los datos (START, DONE, DRY). DRY no es un problema de
            datos (ruling 3): flag D en el producto, INFO si se marca.
- WARNING = ocurrio un problema y el pipeline lo RESOLVIO; la base
            quedo consistente; falta corregir la practica en origen.
- ERROR   = ocurrio y NO pudo resolverse; requiere accion humana.
            level == "ERROR" es la lista de trabajo.

Esquema v3 del log: ts, scope, SiteID, HoleID, datetime, source,
level, event, detail. La columna se llama `event` (como mineralogia).
Un solo codigo por problema; el level dice si quedo resuelto
(MISLABELED WARNING = reparado / ERROR = sin reparar). disposition y
flag SALEN del log; la disposicion sobrevive solo como prosa del
catalogo; el catalogo events.csv conserva ledger EN/ES + impacto +
accion, con clave (event, scope) y columna `level` (default).

IMPLEMENTADO en dbAudit (este commit): events.csv v3, eventLog.R
(level almacenado, sin derivacion), emitters y sink (columnas
event/level), .readRejects filtra event=="UNREADABLE". Tests 13/13
PASS; smoke verificado (defaults, override, stop fuera de catalogo).

PENDIENTE (un solo cambio cuando cierre el agente de plots que hoy
edita el deck): reinstalar el paquete R; migrar AR — runAudit.R,
runData.R (labels quedan iguales), loaders del deck (leer level/event,
borrar la derivacion), leyenda (columna Nivel en vez de Disposicion),
stressAudit.R, y corrida completa con comparacion de conteos. Hasta
esa migracion NO reinstalar: el namespace instalado v2 mantiene
coherentes a los runners y al deck actuales.
