# PLAN — Subcomando `inclinometer` en el CLI

Fecha: 2026-08-21. Estado: APROBADO por el dueño (2026-08-21,
"implementa") e IMPLEMENTADO: patch re-aplicado desde ce0342d,
re-verificado (corrida Vega INC completa contra verdad conocida,
no-regresion piezometer, suite entera en verde, help con los tres
dominios). Ruling 2 resuelto como propuesto: sin --id hasta que
exista mas de un tipo INC. Resta la reinstalacion del dueño.
Precedente de proceso: el cambio se implementó sin plan de registro,
fue RECHAZADO por el dueño y revertido (`ce0342d` implementación,
`a155ad2` revert; origin/dev = revert verificado). Este plan es la vía
correcta; nada se re-aplica sin el ruling.

## Motivación (regla operativa del dueño, 2026-08-21)

"Nunca usamos funciones R directamente; usamos dbAudit." El motor
audita tres dominios pero el lanzador expone dos: `geochemistry` y
`piezometer`. `auditInclinometer()` está exportado y validado
(absorbido al motor con la suite Vega), pero el CLI ni acepta el slug
ni carga los cuatro módulos INC (`DBAudit:229-231` y `:264-274` en
28e23db). Para el operador, el dominio inclinómetros es inalcanzable.

## Diseño propuesto

Espejar el bloque `piezometer` exactamente:

1. Slug `inclinometer` admitido en el despacho y en el mensaje de
   error de comando desconocido.
2. `source()` de los cuatro módulos INC junto a los de piezómetro:
   `inclinometerParse.R`, `inclinometerBuild.R`,
   `inclinometerAudit.R`, `auditInclinometer.R`.
3. Bloque de argumentos con `--project` (obligatorio) y `--manifest`
   (override opcional; default `NULL` → el del paquete), mismos
   mensajes de error que el bloque piezometer.
4. Ayuda: uso `[geochemistry|piezometer|inclinometer]` y sección
   `INCLINOMETER OPTIONS` con `--manifest`.
5. Dependencias verificadas en el bloque: `jsonlite` (el manifiesto);
   los CSV INC no requieren `readxl`.

Sin cambios en el motor, en los entrypoints R ni en el contrato de
carpetas (`source/ → raw/ db/ audit/`, el de `.piezometerPathDefaults`).

## Validación (ejecutada sobre el spike revertido — evidencia vigente)

El patch exacto vive en el commit `ce0342d` (revertido, recuperable
con `git show ce0342d -- DBAudit`). Sobre ese estado se verificó:

- `Rscript DBAudit inclinometer --project <copia de Vega>`: log INC
  completo contra la verdad conocida — MISLABELED WARNING y ERROR,
  REDATED, DUPLICATED survey, MISCOUNTED, INCOMPLETE, START/DONE —
  y productos `db/INC.data.csv` (3.135 filas), `db/INC.index.csv`,
  `audit/INC.audit.csv`.
- No-regresión: `dbaudit piezometer` intacto sobre el mismo árbol;
  suite completa del motor en verde (dbaudit, golden-outputs,
  synthetic-fixtures, vega — 103 aserciones Vega, 0 fallos).
- `--help` y el error de slug desconocido muestran los tres dominios.

Criterio de aceptación para la re-aplicación: repetir esas tres
verificaciones sobre el árbol con el plan aprobado, más
`dbaudit --check` tras reinstalar.

## Interacciones conocidas

- El runner de cada dominio reinicializa `audit/log.csv`: correr
  `inclinometer` después de `piezometer` sobre el mismo proyecto deja
  el log solo con las filas INC (comportamiento vigente del motor,
  no lo introduce este cambio; queda para el plan de documentación).
- El plan de documentación (`dev/handoffs/PLAN-documentacion.md`)
  tiene su ruling #2 condicionado a este plan: si se aprueba, la
  documentación se escribe con tres subcomandos.

## Rulings pedidos

1. ¿Se aprueba el subcomando con el diseño espejo de arriba?
2. ¿`--id` para INC? (hoy INC no discrimina tipos como PCG/PCV;
   propuesta: sin `--id`, se agrega el día que exista más de un tipo).
3. Tras la aprobación: re-aplicar desde `ce0342d`, re-verificar, y
   recién entonces reinstalar (`sudo ./install.sh`, del dueño).
