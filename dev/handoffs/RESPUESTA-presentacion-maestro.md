# RESPUESTA del maestro — el CONTENIDO de la presentación de dbAudit

Fecha: 2026-08-19. Para el agente del deck de features: tu nota de
tarea muestra que dominás la mecánica (typewriter, rulings, qrt). Lo
que te falta es el contenido. Acá está: qué es dbAudit, qué historia
contás, y el ejemplo concreto de cada lámina. Nada de esto es
invento: cada demo sale de fixtures del repo y podés verificarla
corriéndola.

## Qué es dbAudit (interiorizá esto antes de escribir una lámina)

dbAudit audita datos cargados A MANO — lecturas de instrumentación de
campo y certificados de laboratorio — ANTES de que lleguen a un
reporte. Parsea los formatos reales del cliente (planillas Excel de
piezómetros, CSVs de inclinómetro, certificados de lab), y sobre eso:
corrige lo corregible al ingreso dejando registro del valor original;
rechaza lo ilegible dejando el hueco visible; detecta inconsistencias
de identidad, fecha, unidades y estructura; y emite un log de tres
niveles donde ERROR es literalmente la lista de trabajo del dueño de
los datos. Filosofía (ganada a golpes, no negociable): lo dudoso se
RETIENE marcado, jamás se borra solo — "lo cuestionable puede ser
real"; y el invariante lo define la convención del CLIENTE, no el
auditor (el evento MISCOMPUTED murió por violar esto: acusaba como
error la convención legítima de variación tras pozo seco).

## La regla de oro de cada lámina de demo

Cada feature se presenta como TRÍADA: (1) el fragmento de planilla
corrupta (el insumo), (2) el log que dbAudit emite (typewriter en
vivo / ventana estática de fallback), (3) el producto resultante (el
valor corregido, el hueco, el flag, la consolidación). Sin la tríada,
la lámina es relleno. Los expertos creen cuando ven entrada, juicio y
salida juntos.

## El guion (arco de ~14 láminas)

1. EL PROBLEMA: gente midiendo en terreno y tipeando a mano; comas
   decimales, valores ilegibles, archivos con el instrumento
   equivocado, campañas re-publicadas con otra fecha, unidades
   mezcladas. Nadie lo ve hasta que un reporte miente.
2. LA RESPUESTA: tres niveles — INFO (marcas y condiciones del
   sitio), WARNING (ocurrió y el pipeline lo RESOLVIÓ; queda rendido),
   ERROR (no se pudo resolver; exige acción humana). El consumidor
   filtra por ERROR y tiene su lista de trabajo. Mostrar el formato
   de línea real: LEVEL | SITE | INSTRUMENT | DATE | EVENT | DETAIL.
3. DEMO CERTIFICADOS (typewriter en vivo): correr el pipeline
   geoquímico sobre los fixtures sintéticos del repo
   (tests/testthat/fixtures, formatos A/B) y tipear su log:
   PARSE_OK, DUPLICATE_VID, SAMPLEID_NOT_UNIQUE,
   CLIENT_MISSING_COLUMNS. El punto para expertos de lab: un
   certificado roto EXCLUYE el job completo — dbAudit no inventa
   valores que faltan.
4. DEMO PIEZÓMETROS — la coma (Vega VP-1): planilla con "3594,53" →
   log COMMA WARNING → db con 3594.53 exacto. La tríada completa.
5. DEMO PIEZÓMETROS — lo ilegible (Vega VP-1): "s/l" y "3594..88" →
   UNREADABLE ERROR → el HUECO queda visible en la serie (mostrar el
   plot: falta el punto). No se rellena, no se interpola.
6. DEMO PIEZÓMETROS — el pozo seco (Vega VP-3): 4 lecturas secas →
   flag D → en el plot aparecen como RESULTADO (marcadores "D (seco)"
   a su profundidad), no como ausencia. Para el hidrogeólogo: seco es
   dato, no falta.
7. DEMO PIEZÓMETROS — el duplicado (Vega VP-2): dos filas que la
   PROPIA planilla no distingue (misma fecha, misma hora) →
   DUPLICATED ERROR con ambas filas retenidas y visibles. Punto
   experto: la identidad de duplicado es la de la planilla del
   cliente (fecha+hora+stage) — las series intradía legítimas y los
   pares Zero/Field Reading NO disparan.
8. DEMO INCLINÓMETROS — identidad (Vega VI-1 y VI-2): el contenido
   declara "VI-01" con archivo "VI-1" → variante de formato,
   NORMALIZADA (WARNING); el contenido declara "VI-9" que no existe →
   ERROR sin reparar. Reparar solo con evidencia sistemática.
9. DEMO INCLINÓMETROS — la campaña re-fechada (Vega VI-1): dos
   archivos formalmente distintos con la tabla de lecturas
   byte-idéntica → REDATED ERROR con las dos fechas en el detalle.
   Contar el mecanismo con neutralidad (re-exportación del equipo o
   copia manual — la acción es determinarlo y decidir la fecha real).
10. DEMO INCLINÓMETROS — estructura: el archivo duplicado consolidado
    (DUPLICATED survey WARNING), el header que declara 40
    profundidades y trae 38 (MISCOUNTED ERROR), el campo de
    encabezado vacío (INCOMPLETE ERROR), y el archivo que ningún
    parser caminó (MISSING ERROR — el censo fuente→raw).
11. EL CATÁLOGO: la leyenda GENERADA de inst/events.csv (Evento |
    Nivel | Qué significa | Impacto) — cero tipeo, una sola fuente de
    verdad, ledger EN/ES.
12. LA JOYA — VEGA: cómo se audita al auditor. Un sitio sintético con
    15 corrupciones inyectadas de verdad conocida Y 4 anti-fantasmas
    (casos legítimos que NO deben disparar: la variación tras seco,
    el recrecimiento de collar declarado, la persistencia, las
    unidades por canal). Cuatro gates: todo lo inyectado dispara;
    NADA más dispara; lo corregido queda exacto; lo incorregible
    queda visible. Regla de la casa: ningún evento nuevo emite en
    producción sin nacer y probarse en Vega — la primera aparición
    jamás es en datos de un cliente.
13. QUÉ NO HACE (honestidad ante expertos): no juzga la física de la
    lectura (la validación predictiva por vecinos e historia es un
    frente en diseño, motor ssel); no borra nada; no decide — marca y
    rinde cuentas para que decida el profesional.
14. CIERRE: trazabilidad total (cada línea del log → su planilla y
    fila), reproducibilidad total (una corrida regenera todo), y el
    auditor auditado (suite con Vega en cada release).

## Los comandos que generan cada demo (verificalos corriendo)

- Certificados: el pipeline geoquímico sobre sus fixtures del repo
  (mirá cómo los invoca tests/testthat/test-dbaudit.R y los goldens).
- Piezómetros e inclinómetros: `auditPiezometer()` y
  `auditInclinometer()` sobre una COPIA en tempdir de
  system.file("fixtures/Vega") — tu propia nota ya verificó que el
  log INC sale en segundos. La verdad para anotar cada lámina:
  system.file("fixtures/Vega/truth.csv").
- Los plots de la tríada: los builders de el proyecto de monitoreo downstream sobre data/vega
  (el mini-deck _master/vega.qmd ya los renderiza — reusá el patrón,
  no lo reinventes).

## Historias reales permitidas (sin identidad de cliente)

Podés contar como PATRONES, sin nombres ni sitios: "el censo encontró
un registro de equipos que ningún parser caminaba"; "la identidad de
duplicados evitó 21 falsos positivos de prácticas legítimas de
campo"; "un evento del catálogo murió cuando la planilla del cliente
demostró que su 'error' era una convención" — son la mejor prueba de
madurez del sistema ante expertos. Datos, fechas y nombres: SOLO de
Vega.
