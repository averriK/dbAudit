# HANDOFF (Fable) — Consolidación de dbAudit: absorber lo que vive en AR y cerrar pendientes

Fecha: 2026-08-18. Repo de trabajo: `~/github/tools/dbAudit` (branch
dev). Proyecto consumidor: `~/Cloud/github/projects/AR-S2L1X`. Aplica
el router `~/github/agents/AGENTS.md`. Dirección, no autoridad.

## Respuesta directa a las preguntas del dueño

**¿Qué implementamos en AR que se llama/activa/analiza desde
dbAudit?** El pipeline INC vive PARTIDO: dbAudit aporta el motor
(parse/build/audit de piezómetros, eventLog v3, catálogo
inst/events.csv, gates) y AR aporta en `scripts/runAudit.R` una capa
de checks INC que DEBERÍA ser del motor:

- `.checkINCNaming` (MISLABELED con normalización de variantes),
- `.checkINCRedated` (REDATED por firma de contenido),
- `.checkINCDuplicates` (DUPLICATED record INC),
- `.checkINCConsolidated` (DUPLICATED survey desde BuildCheck),
- `.checkINCCounts` (MISCOUNTED desde BuildCheck),
- `.checkINCHeader` (INCOMPLETE, con Depth Bottom),
- `.checkINCCoverage` (MISSING INC),
- más `.checkPCVClosure` (MISCLOSURE, SUSPENDIDO — ver abajo) y el
  wiring de `.checkSourceCensus`/`.checkFileIDResidual`/
  `.repairPCGChange` (muerto) importados vía `.importDbAudit`.

Consecuencia: el fixture Vega (inst/fixtures/Vega + test-vega) solo
valida el lado PCG/PCV en el motor; las corrupciones INC se validan
recién en la corrida AR. TAREA CENTRAL: promover `auditInclinometer()`
al motor absorbiendo esos checks (respetando PROMOTION.md y los
rulings registrados en dev/SoT/PLAN-event-taxonomy.md), extender
test-vega para validar INC engine-side, y dejar en AR solo el runner
fino de proyecto.

**¿Hay que reinstalar dbAudit?** Estado verificado 2026-08-18:
- Paquete R instalado: AL DÍA (última R CMD INSTALL durante el cierre
  de la identidad de duplicados). Tras CUALQUIER cambio de este
  handoff: reinstalar de nuevo.
- CLI `/usr/local/libexec/dbAudit`: DESACTUALIZADO (quedó en el
  esquema v2; es de root — requiere `sudo bash install/install.sh`
  del dueño). Además `install.sh` NO instala el paquete R (brecha
  documentada; hay un chip de tarea pendiente del dueño para
  agregarlo al instalador).

## Pendientes de motor registrados (con su SoT)

1. MISCLOSURE fila-local: rediseño reglado en
   `AR-S2L1X/dev/SoT/PROPOSAL-gate-checks.md` — el parser debe
   acarrear la geometría declarada por lectura (columna de boca del
   cliente en PCG; instalación del sensor PCV del encabezado) y el
   cierre se verifica fila a fila; jerarquía de referencias reglada
   (declarada > gemelo PCG > historial en params > inferencia marcada).
   La corrupción ya está inyectada en Vega esperando el check.
2. flag D: refinamiento ya aplicado (excluye rechazos del gate);
   revisar que el criterio sea "seco declarado", no "NA de nivel".
3. Regla permanente Vega: todo evento nuevo = inyección +
   anti-fantasma + 4 gates ANTES de producción
   (dev/SoT/PLAN-virtual-site.md). Todo cambio de check = flip
   deliberado en test-vega.
4. Identidad de duplicados = la de la planilla del cliente
   (fecha+hora+stage); una serie de comisionado del engagement (13
   lecturas sin hora) espera convención del dueño.
5. REDATED: acción neutral al mecanismo; el árbitro pendiente es el
   registro de equipos del cliente (archivo censado hoy como MISSING) — la
   ingesta es ruling del dueño; si la regla, cruzar sonda/datalogger
   por campaña contra los 98 grupos (mitad concentrada en 2022).

## Aceptación

Suite completa verde con los flips deliberados documentados; corrida
AR completa con conteos comparados antes/después (la absorción NO
debe cambiar ningún conteo del log real — si cambia, explicar cada
diferencia); reinstalación del paquete; muestra del log al dueño.
Preservar el docx sucio ajeno de AR y el trabajo de otras tareas.
