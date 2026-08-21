# HANDOFF — Sesión dedicada dbAudit (cierre a producción + taller)

Fecha: 2026-08-21. Para la próxima sesión parada en
`~/github/tools/dbAudit` (rama dev). Autocontenido. Aplicar el router
`~/github/agents/AGENTS.md`; para el sitio del paquete leer
`R-PACKAGE-SITE.md` y `R-PACKAGE-DOCUMENTATION.md` (filas del router).

## EL OBJETIVO (del dueño, 2026-08-21, verbatim en esencia)

Usar la documentación de dbAudit como **presentación para un taller de
uso**, con ejemplos en geochem, piezometer e inclinometer, usando los
skills de ssel de forecast; todo documentado con ejemplos en los
**workflows del pkgdown**. Ese es el objetivo de trabajo.

Traducción operativa:
1. Sitio pkgdown del paquete con **artículos de workflow** (vignettes)
   que sirven como material del taller — uno por dominio (certificados
   geoquímicos, piezómetros, inclinómetros) + uno del flujo forecast
   (bandas de confianza sobre las lecturas, motor ssel).
2. Cada artículo es EJECUTABLE contra los fixtures que viajan en el
   repo (Vega, synthetic-A/B) — cero datos de cliente, cero
   dependencias de repos privados. El patrón de cada ejemplo ya
   existe en `examples/` (tres scripts verificados por corrida).
3. La documentación `docs/` (Jekyll/Pages) recién reescrita es la BASE
   FACTUAL: los artículos cuentan el workflow del taller; docs/ la
   referencia. No duplicar contra fuentes distintas — misma verdad,
   dos formas.

## Reglas que NO se negocian (rulings vigentes del dueño)

1. **Forecast**: ningún número medido del banco temporal anterior es
   citable (coberturas "reales", MAE, tasas, conteos). El artículo de
   forecast muestra el MECANISMO y las bandas con cobertura NOMINAL
   (columna `coverage` de las tablas espejo `*.forecast`). El modelo
   temporal se declara "implementado; validación formal en curso".
   Los números espaciales de las corridas auditadas vigentes sí son
   citables (fuentes en AR: `dev/handoffs/DOC-forecast-para-slides.md`
   y `dev/SoT/REPORT-investigacion-espacial.md` — movido a AR el
   2026-08-21 porque la librería ssel quedó limpia de objetos de
   proyecto, por orden del dueño).
2. **Confidencialidad** (`dev/SoT/PLAN-datos-confidenciales.md`):
   nada de nombres de cliente, sitios reales, IDs reales ni repos
   privados en el árbol público. El guard anti-fuga lee patrones de
   un archivo local no versionado.
3. **Los usuarios operan por CLI** (`dbaudit <dominio> --project`),
   jamás funciones R directas — los tres subcomandos existen desde
   7fe0d0d. El paquete R es la superficie de los runners de proyecto.
4. Cambios de motor/producción nacen en `dev/SoT` con ruling del
   dueño (precedente: PLAN-cli-inclinometer).
5. Todo comando documentado se corre antes de documentarse.

## Estado al momento del handoff

- CLI con tres subcomandos, suite completa en verde (Vega 4 gates).
- Árbol público saneado de identidades (HEAD; la HISTORIA sigue
  pendiente de ruling: filter-repo o aceptación — PLAN-datos-
  confidenciales, rulings 3-5).
- `docs/` + `examples/` + guard + paridad de instaladores: reescritos
  por el workflow de producción (ver el commit correspondiente y
  `dev/SoT/EVIDENCE-instaladores-paridad.md`).
- El instalado en la máquina del dueño puede estar viejo: verificar
  `dbaudit --version` contra el checkout antes de cualquier demo;
  reinstalación = `sudo ./install.sh` (del dueño).

## Trabajo de la sesión (en orden)

1. Verificar el estado real del árbol y de los commits del workflow
   (no re-derivar: leer el diff/commits).
2. Montar pkgdown (`_pkgdown.yml`, articles/) — leer R-PACKAGE-SITE.md
   ANTES; los artículos de workflow del taller: geochem, piezometer,
   inclinometer, forecast-ssel. Reusar `examples/` como chunks.
3. El artículo forecast-ssel se coordina con la librería ssel (los
   builders/espejos viven en AR y ssel; qué se muestra viene de la
   regla 1). Ante duda de alcance: elevar al dueño, no autoconcederse.
4. Build del sitio, revisión del dueño, y publicación SOLO con su
   orden (deployment = trigger Tier 2 del router).

## Abiertos del dueño (no resolver sin él)

- Historia del repo público (filter-repo vs residual) y fork del Dash.
- Reinstalación del CLI en su máquina.
- Dónde publica el sitio pkgdown (Pages actual vs otro destino).
