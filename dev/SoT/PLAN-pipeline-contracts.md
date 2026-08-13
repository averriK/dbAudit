# PLAN: contratos de pipelines en dbAudit

## Objective

Definir como conviven en `dbAudit` dos contratos distintos:

1. Geoquimica: contraste entre una tabla del cliente y una tabla reconstruida
   desde certificados.
2. Piezometros: ingreso controlado a una base aprobada, sin tabla externa de
   referencia.

## Scope

- Reproducir un ejemplo completo geoquimico con los datos actuales de
  un repo de aplicacion del contrato geoquimico.
- Crear:
  - `examples/scripts/geochem/runGeochem.R`
  - `examples/scripts/geochem/runGeochem.json`
  - `examples/scripts/geochem/setup.R`
  - `examples/scripts/geochem/README.md`
- Preparar un ejemplo completo de piezometros usando la logica aprobada en
  `AR-S2L1X`, sin mezclarlo con el contrato geoquimico.
- Definir slugs o nombres de contrato para seleccionar pipeline.
- Definir estructura minima de ejemplos.
- Definir que pertenece a la libreria R y que pertenece al CLI.

## Out Of Scope

- Cambiar el contrato legacy `dbaudit --project <DATA_ROOT>`.
- Agregar verbos CLI antes de aprobar el contrato publico.
- Unificar auditorias incompatibles bajo una sola semantica falsa.
- Mover datos grandes sin inventario y presupuesto de lectura.
- Incorporar inclinometros en esta etapa.

## Current Plan

1. Auditar el contrato real del pipeline geoquimico actual.
2. Auditar el contrato real del pipeline de piezometros en `AR-S2L1X`.
3. Proponer nombres publicos y slugs solo despues de comparar contratos.
4. Documentar alternativas rechazadas.
5. Recien despues, implementar ejemplos y tests.
6. Crear `examples/scripts/geochem` con pipelines R que repliquen el contrato
   actual de `DBAudit()` sin pasar por el CLI.

## Status

Activo. Primera etapa de paquete R completada en `dev`:

- `d33f467 Convert dbAudit to R package skeleton`

Correccion de arquitectura:

- `AR-S2L1X` es el repo de aplicacion para piezometros e inclinometros.
- `PE-DBAudit` es el repo de aplicacion del contrato geoquimico viejo.
- `dbAudit/project/test-A` y `dbAudit/project/test-B` pueden quedar como
  fixtures internos o smoke tests, pero no deben confundirse con el repo de
  aplicacion geoquimico.

## Completed

- `dbAudit` ya carga como paquete R.
- `DBAudit()` es la API publica inicial.
- `R CMD check` termina `Status: OK`.
- Contrato geoquimico observado:
  - entrada principal: certificados de laboratorio bajo `raw/lab`;
  - entrada de contraste: tabla assay/client bajo `raw/assay`;
  - salida: `proc/lab.csv`, `proc/client.csv`, `proc/index.csv`,
    `proc/log.csv`;
  - semantica: certificados de laboratorio son respaldo; assay/client declara
    alcance y se audita contra el respaldo.
- Se creo una primera version de `examples/scripts/geochem` que reproduce
  `DBAudit()` desde R sin pasar por CLI usando fixtures internos. Debe ajustarse
  conceptualmente para que el repo de aplicacion geoquimico sea `PE-DBAudit`.
- Se agrego `examples/scripts/geochem/runGeochem.PE-DBAudit.json` como config
  de aplicacion geoquimica:
  - `~/github/projects/PE-DBAudit/project/BV`
  - `~/github/projects/PE-DBAudit/project/QV`
- Se observo `PE-DBAudit` de forma acotada:
  - `BV`: `raw/lab` con 11645 CSV, `raw/assay` con 2 CSV, `proc` sin CSV;
  - `QV`: `raw/lab` con 2552 CSV, `raw/assay` con 1 CSV, `proc` con 3 CSV.
- Contrato piezometrico observado en `AR-S2L1X`:
  - entrada source: `data/source`;
  - evidencia parseada: `data/raw`;
  - base aprobada actual/prototipo: `data/db`;
  - salida de auditoria exploratoria: `data/audit`;
  - semantica productiva corregida: la QA/QC debe actuar antes de aceptar
    observaciones en `db`, no solo despues.

## Approved Naming

Decidido por el usuario el 2026-08-12. Cierra el item de slugs que estaba
pendiente.

Runners R, uno por dominio:

```r
auditGeochem(project.path = ...)
auditPiezometer(project.path = ...)
auditInclinometer(project.path = ...)
```

`DBAudit()` se mantiene exportada como alias fino de `auditGeochem()`. La
llaman el CLI instalado y `PE-DBAudit`; retirarla seria un cambio rompiente.

El verbo `audit` es consistente con la familia ya existente en `R/audit.R`
(`auditStructure()`, `auditValues()`). El rechazo registrado mas abajo es a un
contrato unico llamado genericamente `audit`, no al verbo: tres funciones
calificadas por dominio mantienen la distincion entre contraste contra
referencia e ingreso controlado.

Slugs de CLI, un solo binario con dispatch por primer token:

```sh
dbaudit --project X                            # legacy, sin cambio
dbaudit geochem      --project X
dbaudit piezometer   --project X --id PCG,PCV
dbaudit inclinometer --project X
```

Regla de compatibilidad: si el primer argumento empieza con `-`, la invocacion
es geoquimica legacy. Si no, es un slug. `PE-DBAudit` no se ve afectado.

Los slugs nombran el dominio, no la operacion. Se descartaron `audit`,
`ingest` y `gate` porque nombran la operacion y colapsan la distincion entre
contratos; `pz`, `inc` y `gq` porque son cripticos en terminal, y los IDs
cortos ya son vocabulario en `--id`; `lab` y `assay` porque son carpetas de
entrada, no dominios.

## Etapas Del Producto

Marco del usuario, 2026-08-12. Objetivo global: auditores de productos de
lecturas de terreno/laboratorio con errores humanos, sistematicos y de naming.
La API debe detectar y loguear, corregir lo corregible, y loguear lo
irrecuperable.

- Etapa I geoquimica: resuelta y en produccion.
- Etapa I piezometros: avanzada, no cerrada. Falta: correccion de lo
  corregible (politica nunca aprobada), logueo de irrecuperables sin abortar
  la corrida (hoy un valor invalido mata `runData.R` sin dejar log), backfill
  de `header.csv`, y ruling de persistencia de fixes.
- Etapa I inclinometros: abierta; requiere contexto del usuario.
- Nivel III (vision del usuario, 2026-08-12): validar la ULTIMA lectura de un
  piezometro con dos gates predictivos: (1) espacial — correlaciones entre el
  piezometro i y los demas piezometros j a la fecha de la lectura, prediccion
  desde la distribucion espacial de niveles freaticos; el modelo ML ya existe
  en `~/github/libraries/ssel` y solo debe aplicarse; (2) temporal, el
  dificil — forecast desde la historia del propio piezometro. Una lectura
  fuera de ambos intervalos de confianza se marca como probable dato malo.
  Todo lo que se construye ahora es QA/QC de niveles I y II. No disenar el
  nivel III todavia; los requisitos que impone hoy estan registrados en
  `AR-S2L1X/dev/SoT/PLAN-agent-boundary.md` (coordenadas de instrumento como
  producto de db, series por sensor, vocabulario de log extensible con
  veredicto probabilistico). `PLAN-ingest-gate-contract.md` es su esqueleto.

## Roadmap Arquitectura (validado 2026-08-12)

Secuencia validada contra `R-PIPELINES.md`, `CONFIG.md`, `COMPATIBILITY.md` y
`PRACTICE.md`, mas revision adversarial con verificacion en codigo. Cada paso
es reversible y se valida antes del siguiente.

Estado de ejecucion, 2026-08-12:

- A1 hecho: `e7d1524`. Checkout `FAIL 0 PASS 5`; check `Status: OK` con los
  goldens saltando limpio en el tarball.
- A2 pendiente: ruling del usuario sobre `.Rbuildignore ^examples$`. No
  bloquea: A3 uso el gate relativo al baseline.
- A3 hecho: `a7a58dc`. Goldens `FAIL 0 PASS 5` contra el paquete renombrado
  reinstalado; check `Status: OK` con los chequeos code/doc pasando.
- A4 hecho: `7bb3445`. Paridad legacy y slug sobre test-A: md5 identicos a
  los goldens, exit 0 ambos; slug desconocido exit 1; `verify-docs` pasa sin
  cambios.
- A5 hecho: reinstalado por el usuario el 2026-08-12 18:34 UTC. `.version`
  registra `73dc2fa (dev)`, que existe en git — la deriva del build `ac4001e`
  quedo cerrada. Cero drift entre `/usr/local/libexec/dbAudit` y el checkout.
  Cierre verificado: `dbaudit --project <copia test-A> --lab-dir raw
  --assay-dir assay` exit 0 con los tres md5 identicos a los goldens; el
  dispatch (`geochem --help` exit 0, slug desconocido exit 1) funciona en el
  binario instalado.

El roadmap A quedo completo salvo el ruling A2, que no bloquea nada.

A1. Harness golden `tests/testthat/test-golden-outputs.R`:

- copiar SOLO `raw/` y `assay/` de `project/test-A` y `test-B` a tempdir (no
  copiar `proc/`: evita la contaminacion `*.A.csv` y la mitad del I/O);
- invocar `DBAudit(project.path = ..., lab.dir.name = "raw",
  assay.dir.name = "assay")` — los fixtures NO usan los defaults del CLI;
- comparar md5 de `lab.csv`/`index.csv`/`client.csv` y la tabla de conteos del
  log por `(level, event)`. El md5 del log es imposible como golden: la
  columna `ts` varia y `file` lleva rutas absolutas; la tabla de conteos es
  determinista tras el dedup;
- `skip` con mensaje claro cuando `project/` falta (el tarball lo excluye via
  `.Rbuildignore ^project$`) o cuando los fixtures son punteros LFS sin
  hidratar (`project/**` esta en LFS; `dir.exists` pasa igual);
- una asercion de fallo esperado;
- en el mismo paso, registrar el baseline de `R CMD check` (no hay evidencia
  de que HEAD pase check; sin baseline, un fallo preexistente se culparia al
  rename).

Goldens registrados 2026-08-12 (path-independientes, verificado en dos rutas):

```text
test-A  lab d8961fa0251f4b79659ddb445bd3f5f1  index 1fa47dfda4e7e42191192e55847b6569  client d89bf9828a9bfe534eeae385e6e7995c
test-B  lab d2cd25793e865743709280d8e8f382ab  index 1203704ef05dceab1545e075ff6be604  client b478a39eadbe0a0f3046550472de1eba
```

A2. Decidir `.Rbuildignore ^examples$` antes de A3, o definir el gate de A3
como "sin hallazgos nuevos vs baseline". Sin esta decision, el gate de A3
depende en silencio de un ruling no tomado.

A3. Rename: `auditGeochem()` pasa a ser la funcion real en `R/dbAudit.R`;
`DBAudit <- auditGeochem` como copia de binding (preserva formals; un
forwarder `function(...)` rompe el chequeo codoc contra `man/DBAudit.Rd`).
Editar `NAMESPACE` a mano (agregar `export(auditGeochem)`) y agregar
`\alias{auditGeochem}` a `man/DBAudit.Rd`. NO roxygenizar: el unico roxygen
del repo es `R/dbAudit-package.R` y roxygenizar reescribiria `NAMESPACE` con
export vacio. Gate doble: harness verde en contexto checkout
(`testthat::test_local`) Y `R CMD check` sin hallazgos nuevos vs baseline —
el check solo no prueba byte-identidad porque el test golden se salta dentro
del tarball.

A4. Dispatch CLI en el entrypoint `DBAudit`: pelar `args[1]` solo si no
empieza con `-`; validar contra `{geochem}`; slug desconocido termina con
`stop()` y exit distinto de cero; decidir explicitamente la semantica de
`dbaudit geochem --help` (los early-exits actuales escanean todos los args
con `any()`). Tests de paridad de AMBOS caminos, legacy y slug, con exit
status + md5 sobre fixtures. La aceptacion nunca es "el dispatch llego a la
funcion": cada ruta valida salida terminal + artefactos. `bin/verify-docs`
pasa sin cambios si el help conserva las lineas de defaults y la URL de docs.

A5. Reinstalar el CLI desde HEAD (accion del usuario, sudo). Precondicion:
arbol limpio con A3+A4 commiteados — instalar desde arbol sucio recrea la
deriva `ac4001e` (un `.version` apuntando a un commit que no contiene el
codigo instalado). Cierre obligatorio: invocacion legacy del binario
INSTALADO sobre fixtures, md5 contra goldens.

A6. Toda afirmacion de paridad se declara "sobre fixtures". El commit del
build instalado de enero no existe en git; la equivalencia general es
indemostrable por construccion.

Reglas de arquitectura para los tres runners (extraidas de contratos):

- cada slug rutea a la funcion publica exportada; nunca logica slug-local;
- los defaults por runner viven en las funciones R de entrada y el CLI los
  lee (patron `.dbauditPathDefaults`); nada CLI-only;
- API R funcionando antes de su ruta CLI, siempre;
- el `setup.R` de ejemplos no acumula logica de dominio; los helpers de
  traduccion van a ubicacion testeada antes de escribir el runner
  piezometrico (`.jsonGet`/`.jsonRequire` hoy no tienen test);
- claves JSON lowerCamel, enums kebab estables; `labFormat auto|A|B` no se
  re-casea (seria migracion de interfaz).

## Precondiciones Para La Migracion Piezometrica

La fase `auditPiezometer()` no arranca hasta que Etapa I piezometrica cierre
en `AR-S2L1X`, y exige resolver antes:

- relacion final productor-consumidor declarada: `AR-S2L1X` llama
  `dbAudit::auditPiezometer()` y retira su copia local en el mismo cambio
  (nada de logica duplicada tras dos entradas);
- alcance acotado: helpers estables + UNA API exportada; `runParse.R`,
  `runData.R` y `runAudit.R` siguen siendo runners finos locales — el harness
  de estres contamina entre etapas y necesita rutas independientes;
- modelo de rutas resuelto: `DBAudit()` usa raiz + dir-names relativos y no
  acepta rutas absolutas por dir-name; los runners piezometricos usan rutas
  independientes `raw=`/`db=`/`audit=`. Elegir uno y migrar el harness si
  corresponde;
- reconciliacion de loggers explicita: `.logInit` difiere entre repos
  (dbAudit borra el archivo; AR-S2L1X trunca en el lugar) y la Etapa I
  piezometrica extendera el esquema con la decision pass/repair/reject. Dos
  loggers con namespace o uno parametrizado probado byte-neutral para los
  goldens geochem;
- mecanismo de pin: cuando los runners llamen a la libreria instalada,
  `stressAudit.R` ejercitaria una version divergente del checkout — la misma
  deriva `ac4001e`. Asercion de version en runners o reinstalacion mandatoria
  en la receta de validacion;
- ruling de procedencia de fixtures, decidido 2026-08-12: el repo publico no
  lleva fixtures derivados de clientes. `project/test-A` y `test-B` fueron
  des-trackeados en `f4de24d` (quedan en disco, los goldens los leen
  localmente y saltan limpio si faltan; `project/` esta ignorado). Los
  fixtures piezometricos futuros se SINTETIZAN — el patron es
  `AR-S2L1X/dev/SoT/buildCorruptSource.R`. Pendiente derivado: generador de
  fixtures geoquimicos sinteticos para que los clones frescos recuperen
  cobertura de regresion. Letra chica abierta: la historia publicada y el
  remoto LFS todavia contienen test-A/test-B; una purga real exige
  reescritura de historia + force push + purga LFS en GitHub (operacion
  destructiva, decision separada del usuario, no tomada);
- ruling semantico: ¿`auditPiezometer()` envuelve el gate de ingreso o la
  revision post-db? Pregunta 5 de `PLAN-ingest-gate-contract.md`, aun
  abierta.

## Pending

- Definir el contrato publico para geoquimica sin romper `DBAudit()`.
- Definir el contrato publico para piezometros.
- Definir ubicacion de ejemplos completos.
- Definir pruebas de regresion por contrato.
- Definir si `auditPiezometer()` necesita seleccion de etapa. `DBAudit()` corre
  parse y audit en una llamada cerrada; `AR-S2L1X` mantiene tres entradas
  separadas a proposito, por trazabilidad y porque re-parsear es caro.
- Definir el significado de `--project` para piezometros. En geoquimica es la
  raiz que contiene `raw/lab`. `AR-S2L1X` toma rutas independientes `raw=`,
  `db=` y `audit=`, y su harness de estres las pone deliberadamente en
  sistemas de archivos distintos; una sola raiz no puede expresar eso.
- Definir defaults de rutas por runner. `.dbauditPathDefaults` es geoquimico
  (`raw/lab`, `raw/assay`, `proc`); el juego piezometrico seria `source`,
  `raw`, `db`, `audit`.
- Actualizar `Title` y `Description` de `DESCRIPTION`. Hoy dicen "Geochemical
  Certificate Parser and Validator", que deja de ser cierto con tres dominios.
  El nombre `dbAudit` si se sostiene.
- Implementar `examples/scripts/geochem` despues de aplicar el contrato
  canonico `/Users/averrik/github/agents/R-PIPELINES.md`.
- Revisar `PE-DBAudit/project/BV` y `PE-DBAudit/project/QV` como aplicaciones
  geoquimicas reales.
- Ejecutar `runGeochem.PE-DBAudit.json` solo sobre una copia temporal. El
  motivo ya no es el estado del repo sino que la corrida escribe `proc/`
  dentro de el.

## Rejected

- Un solo contrato llamado genericamente `audit`: rechazado porque en
  geoquimica se contrasta contra referencia y en piezometros se controla el
  ingreso a una base aprobada.
- Un CLI con verbos nuevos sin contrato escrito: rechazado.
- Subdirectorios anidados bajo `dev/SoT`: rechazado.
- Nombres publicos basados en dominios no aprobados: rechazado.
- Modelar piezometros como `parse -> db -> audit` para produccion: rechazado si
  `db` significa base aprobada.
- Tratar `PCG` y `PCV` como pipelines publicos separados: rechazado como
  primera opcion porque el objetivo aprobado es una base piezometrica comun con
  IDs separados dentro de la tabla.
- Tocar el CLI antes de tener pipelines R reproducibles: rechazado.
- Usar `AR-S2L1X` como aplicacion geoquimica: rechazado; su rol es
  piezometros/inclinometros.
- Tratar los fixtures internos `project/test-A` y `project/test-B` como la
  aplicacion geoquimica real: rechazado.

## Risks

- Romper usuarios actuales si `dbaudit --project` deja de apuntar al pipeline
  geoquimico legacy.
- Congelar nombres publicos inmaduros si se exportan demasiadas funciones.
- Confundir "auditoria contra referencia" con "control de ingreso a db".
- Corregido 2026-08-12: `~/github/projects/PE-DBAudit` ya no esta sucio.
  `git status` limpio desde `e07be87` (2026-06-27), 14206 de 14209 archivos en
  LFS. Lo que si queda pendiente ahi: `project/QV/proc` esta trackeado en
  git+LFS (~49 MB) mientras `project/BV/proc` no lo esta, porque el
  `.gitignore` de `PE-DBAudit` no tiene la regla `project/*/proc/` que si
  tiene el de `dbAudit`.
- `DBAudit()` inicializa `proc/log.csv` solo si no existe (`R/dbAudit.R:127`) y
  luego deduplica. Un `proc/` preexistente mezcla corridas en silencio. Si
  produccion no limpia `proc/` entre corridas, el `log.csv` entregado ya viene
  mezclado. No inspeccionado.

## Validation

- Todo cambio de contrato debe tener al menos un ejemplo reproducible.
- Todo ejemplo debe correr desde R y, cuando se apruebe, desde CLI.
- Los tests deben cubrir que el pipeline geoquimico legacy sigue funcionando.
- Validado:
  - `R CMD build /Users/averrik/github/tools/dbAudit --no-build-vignettes`
  - `R CMD check /private/tmp/dbAudit_0.0.0.9000.tar.gz --no-manual --no-build-vignettes`
  - status final de check: `OK`.
- Validacion previa del runner:
  - `runGeochem.R` sobre copias temporales de `project/test-A` y
    `project/test-B` produjo `lab.csv`, `index.csv`, `client.csv`, `log.csv`;
  - `lab.csv`, `index.csv`, `client.csv` fueron iguales al CLI;
  - `log.csv` tuvo iguales conteos por `level,event`; las filas completas
    difieren por rutas/timestamps de las copias temporales.

## Exact Next Command

```sh
git status --short --branch
```
