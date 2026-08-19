# PLAN — Sitio virtual corrupto (validación con verdad conocida)

Fecha: 2026-08-18. Estado: PROPUESTA para ruling del dueño.
Objetivo: un sitio sintético completo, con datos realistas y errores
inyectados con verdad conocida, que ejercite CADA evento del catálogo
en ambas direcciones: dispara lo que debe (sensibilidad) y NO dispara
lo que no (especificidad — el anti-fantasma). Responde de forma
ejecutable a la regla de primera-aparición verificada.

## Diseño del sitio

- SiteID propuesto: `Vega` (ruling de nombre abierto). Instrumentos:
  3 Casagrande (VP-1..VP-3), 1 cuerda vibrante bicanal (VP-4: A/B),
  2 inclinómetros (VI-1, VI-2). ~36 campañas mensuales (3 años).
- Semilla realista: series copiadas de un pozo real del proyecto y
  PERTURBADAS (escala + offset + ruido con semilla fija) — forma real,
  valores no atribuibles al cliente.
- Formatos de planilla EXACTOS del cliente (headers "MONITOREO DE
  PIEZÓMETROS...", "Survey v2;..." de inclinómetro): el parser
  ejercita sus rutas reales, no atajos.
- Generador determinista (script R, semilla fija) que escribe las
  planillas + el manifiesto de verdad.

## Matriz de corrupción (una inyección por evento del catálogo)

| Evento (nivel esperado) | Inyección | Visible en datos |
|---|---|---|
| COMMA (WARNING) | VP-1: 3 celdas "3585,64" | valor corregido en db |
| UNREADABLE (ERROR) | VP-1: celdas "s/l", "3585..64" | hueco en la serie |
| MISLABELED (WARNING) | VI-1: contenido declara "VI-01" | normalizado |
| MISLABELED (ERROR) | VI-2: un archivo declara "VI-9" (no existe) | sin reparar |
| REDATED (ERROR) | VI-1: campaña idéntica re-publicada con otra fecha | 2 campañas iguales |
| DUPLICATED survey (WARNING) | VI-2: mismo archivo, dos nombres | consolidado |
| DUPLICATED record (ERROR) | VP-2: misma fecha, dos filas distintas | ambas quedan |
| MIXED (INFO) | VP-4: canal A kPa, canal B MPa | constancia |
| UNITLESS (ERROR) | VP-4: planilla sin unidad declarada | valor ininterpretable |
| MISCOUNTED (ERROR) | VI-1: header declara 40 prof., trae 38 | perfil corto |
| MALFORMED (ERROR) | VP-3: planilla sin columna de fecha | 0 lecturas entran |
| INCOMPLETE (ERROR) | VI-2: header sin profundidad del tubo | metadatos incompletos |
| MISSING (ERROR) | VP-2: archivo válido en subcarpeta que el parser no ve | descuadre raw/db |
| MISCLOSURE (ERROR) | VP-4: 2 filas con profundidad incoherente con carga+geometría declarada (cierre FILA-LOCAL, versión reglada) | referencia rota |
| DRY (INFO, flag D) | VP-3: 4 lecturas secas | estado, no hueco |

## Casos control anti-fantasma (NO deben disparar NADA)

1. Variación tras pozo seco a la usanza del cliente (el caso que mató
   a MISCOMPUTED).
2. Recrecimiento de collar legítimo (+2 m) con su columna de boca
   declarada actualizada — MISCLOSURE no debe sonar.
3. Nivel de agua que repite exactamente el del mes anterior
   (persistencia real de piezómetro).
4. Unidad distinta por canal declarada consistentemente (el caso que
   degradó a MIXED).

## Verdad conocida y aceptación

`truth.csv`: una fila por inyección (archivo, fila/fecha, evento
esperado, nivel, ¿corregible?, valor correcto). El test de validación
compara log vs verdad en cuatro gates: (a) todo lo inyectado dispara
su evento y nivel; (b) NADA más dispara (cero fantasmas); (c) toda
corrección deja el valor correcto en db; (d) todo no-corregible queda
visible en los datos. Integrado a testthat de dbAudit.

## Dónde vive y cómo se ve

- dbAudit `inst/fixtures/<sitio>/` + generador en `dev/` + test en
  `tests/testthat/` (recomendado: es la suite de aceptación del
  MOTOR, reutilizable por todos los proyectos).
- Para VERLO: mini-deck en AR apuntando el data root al fixture
  (qrt, mismas láminas v7 + plots) — el sitio virtual se audita y se
  mira igual que uno real.

## Regla permanente propuesta

Todo evento nuevo del catálogo exige, ANTES de emitir en producción:
su inyección en el sitio virtual + su caso anti-fantasma + pasar los
cuatro gates. La primera aparición deja de ser en datos del cliente.

## Rulings pedidos

1. ¿Nombre del sitio? (propuesto: Vega)
2. ¿Vive en dbAudit como fixture del motor (recomendado) o en AR?
3. ¿Mini-deck para verlo: sí/no?
4. ¿La matriz de corrupción de arriba está completa o agregás casos?

## RULINGS RESUELTOS (usuario, 2026-08-18: "ok. tu recomendación")

1. SiteID: Vega. 2. Vive en dbAudit (inst/fixtures/Vega + generador
en dev/ + test en tests/testthat). 3. Mini-deck: sí (AR apunta el
data root al fixture). 4. Matriz de corrupción: aprobada como está
(15 inyecciones + 4 anti-fantasma). Implementación autorizada.

## CONSTRUIDO Y VERIFICADO (2026-08-18) — 4 gates PASS, 68/68 tests

dev/generateVega.R (determinista, seed 20260818, formatos reales
replicados, cero valores del cliente — verificado por spot-check);
inst/fixtures/Vega/ (80 archivos, 15 inyecciones + 4 anti-fantasma);
truth.csv (26 filas, generada de los mismos valores que las
planillas); tests/testthat/test-vega.R (55 aserciones, corrida real
en tempdir). Gates: (a) sensibilidad PASS; (b) especificidad PASS —
cero fantasmas, log exacto START/MIXED/UNITLESS/DONE + sink 3 COMMA
2 UNREADABLE; (c) correcciones exactas contra truth; (d) todo lo
incorregible visible en productos.

BRECHAS DE DETECCION DOCUMENTADAS (el hallazgo importante — la
inyeccion existe y espera el fix; el test las fija como no-emision
deliberada):
1. DUPLICATED record no puede disparar: .checkDuplicateRaw clava por
   (file, sheet, SourceRow), no por fecha — dos filas de una misma
   hoja jamas son duplicadas para el.
2. MISSING no puede disparar: no hay censo source->raw; un archivo
   fuera de las raices caminadas nunca llega a conciliarse.
3. MALFORMED de hoja fuente no dispara: la hoja sin fecha falla
   IsDataSheet y se SALTA EN SILENCIO (conecta con el grave-sin-log
   "instrumento sin lectura").
4. flag D colateral: la regla marca D todo NA de nivel, incluida la
   fila UNREADABLE (4 secos + 1 colateral, fijado en test como
   refinamiento futuro).
Lado INC (MISLABELED/REDATED/DUPLICATED survey/MISCOUNTED/
INCOMPLETE): corrupciones presentes en el fixture, validacion vive en
el runner AR — anotado en truth, jamas fingido. MISCLOSURE: inyectado,
truth nota el check suspendido; espera el rediseño fila-local.

PENDIENTE: mini-deck de Vega (lado AR, data root al fixture).

## BRECHAS DEL MOTOR CERRADAS (2026-08-18) — verificado independiente

Las 4 brechas del motor quedaron cerradas y volteadas a conciencia en
test-vega (suite 76/76): DUPLICATED record re-clavado por identidad
de lectura (ID, sitio, pozo, canal, FECHA — hora excluida por
catalogo); censo fuente->raw (.checkSourceCensus) emitiendo MISSING;
.hasSheetMarker + .checkSourceSheets emitiendo MALFORMED por marcador
declarado del cliente; flag D limpiado de colaterales UNREADABLE via
rejects. Vega: log completo 11 eventos mapeados 1:1 a truth, cero
fantasmas, anti-fantasmas mudos. MISCLOSURE y DRY siguen como
no-emision deliberada (esperan el rediseño fila-local / son flag).
