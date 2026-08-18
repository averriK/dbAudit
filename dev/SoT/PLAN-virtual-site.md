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
