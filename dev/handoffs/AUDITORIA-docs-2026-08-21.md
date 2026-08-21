# AUDITORÍA de docs/ — inventario de brechas (2026-08-21)

Producida por cuatro auditorías independientes contrastadas contra el
código, el catálogo, la suite y el CLI instalado. Es el ANEXO DE
EVIDENCIA del plan `PLAN-documentacion.md`.

# INVENTARIO DE BRECHAS — documentación de dbAudit (`docs/`)

Base: repo `/Users/averrik/github/tools/dbAudit`, rama `dev`, HEAD `28e23db`. CLI instalado `892a246`. Cuatro auditorías independientes contrastadas contra `R/`, `inst/events.csv`, `tests/testthat/`, `install/`, `DBAudit` y la ayuda del CLI vivo.

---

## 1. VEREDICTO GLOBAL

**Se reescribe en su mayor parte, se corrige el eje de instalación y se borran dos archivos**: `docs/` describe con exactitud un producto de un solo dominio (geoquímica) congelado entre 2025-12-29 y 2026-01-17 — 12 de los 16 `.md` no se tocan desde enero — mientras el motor creció a tres dominios (geoquímica, piezómetros, inclinómetros), cambió el modelo de eventos, se convirtió en paquete R y adquirió despacho por subcomando; la mitad geoquímica sigue siendo correcta y sirve de base literal, pero ninguna página menciona `piezometer`, `inclinometer`, `source/`, `inst/events.csv`, `Vega` ni `testthat` (`grep -ril` sobre `docs/*.md` → 0 archivos).

---

## 2. POR ARCHIVO

| Archivo | Última edición | Destino |
|---|---|---|
| `docs/install.md` | 2026-08-14 | **CORREGIR** — base sana; faltan cinco agregados: `--skip-packages` / `-SkipPackages` (`install/install.sh:18`), `dbaudit --check` (el propio instalador lo recomienda en `install.sh:241-242` y no aparece en ningún `.md`), versión mínima de R, `dbaudit --version` + manifiesto `.version`, y el aviso de que reinstalar abre un prompt interactivo (`install.sh:80-119`, `read -r -p`, cuelga bajo sudo no interactivo). Además: distinguir CLI de paquete R. |
| `docs/windows.md` | 2026-08-14 | **CONSERVAR** — coincide punto por punto con `install.ps1` (rutas, launchers `dbaudit.cmd` + shim, User PATH). Único agregado: en "Verify", `--check` y `-SkipPackages` (hoy sólo propone `--help`, que prueba el launcher pero no R). |
| `docs/macos.md` | 2026-01-17 | **CORREGIR (quirúrgico)** — dos defectos: lista de paquetes 3 → 5 (`R/setup.R:1` incluye `readxl` y `jsonlite`) y el "layout determinístico" omite `inst/` y `.version`, que el instalador sí copia (`install.sh:180-186`) y que son runtime obligatorio (catálogo de eventos, manifiesto de parseo, Vega). El resto está verificado correcto. |
| `docs/troubleshooting.md` | 2026-01-17 | **REESCRIBIR** — la ruta del launcher Windows es inexistente y contradice a `windows.md`; la lista de paquetes es la vieja; nunca nombra `--check`, que resuelve de una sola vez casi todas sus secciones; y no tiene sección para el modo de falla más silencioso de hoy (build instalado viejo). Las tres secciones válidas (`command not found`, permisos/sudo, verificación de Rscript) se reusan literalmente. |
| `docs/installers.md` | 2026-01-17 | **BORRAR** — 9 líneas que declaran fuente de verdad a un documento externo (Warp Drive) que el lector no puede abrir, con "Last synced: 2026-01-17" mientras `install/install.sh` cambió el 2026-08-14 (`692baa3`). |
| `docs/quickstart.md` | 2026-01-17 | **REESCRIBIR** — el parche no alcanza porque el comando central es inejecutable: no existe en el repo ningún proyecto con el layout `project/<PROJECT>/data` (`project/` está gitignoreado: `git ls-files project/` → 0), y no contempla el despacho por subcomando. El bloque de opciones geoquímicas (`--lab-format`, `--tol 0.05`, defaults `raw/lab`/`raw/assay`/`proc`) está verificado correcto y se conserva. |
| `docs/project-layout.md` | 2026-01-17 | **REESCRIBIR** — describe un solo árbol de entrada (`raw/lab`, `raw/assay`, `proc/`), que es sólo el contrato de geoquímica; falta entero el layout de monitoreo (`source/`, `raw/`, `db/`, `audit/`, `.piezometerPathDefaults`, `R/auditPiezometer.R:10-15`), falta la quinta regla real de autodetección de assay (fallback de un único CSV, `R/dbAudit.R:55-57`) y falta la advertencia de destructividad. |
| `docs/logging.md` | 2026-01-10 | **REESCRIBIR** — presenta un esquema de 5 columnas como *el* esquema cuando hoy conviven dos loggers; da una ruta de log que no es ninguna de las dos vigentes; y desconoce el catálogo, `scope`, `class` y la semántica de niveles. Los 43 códigos de geoquímica están verificados uno por uno y se conservan como capítulo. |
| `docs/audit.md` | 2026-01-10 | **CORREGIR y AMPLIAR** — el cuerpo geoquímico es exacto contra el código (auditStructure/auditValues, votos, `min.votes = 2L`, `tol = 5e-2`, regla de no-fallback). Sólo caduca la frase de encuadre (línea 8: "auditing is implemented in `R/audit.R`"): hay tres módulos de auditoría y cuatro entrypoints exportados. Reencuadrar como capítulo de geoquímica y escribir el de monitoreo aparte. |
| `docs/conventions.md` | 2026-01-10 | **REESCRIBIR** — obsolescencia dura acumulada: sección dedicada a `R/wip.R`, que no existe; mapa de módulos de 4 sobre 16; entrypoints encabezados por `DBAudit()` cuando el canónico es `auditGeochemistry()` y `DBAudit` es alias; y el contrato "el CLI llama exactamente un entrypoint público", superado por el despacho de subcomandos. Falta además la convención más consecuente del año (nombres de evento de una palabra, catálogo como contrato). |
| `docs/parsers.md` | 2025-12-29 | **CORREGIR y AMPLIAR** — tres correcciones puntuales: la "garantía de regresión tipo A" ya no la ejerce ninguna suite versionada (vive en `project/test-A/run.R`, gitignoreado); `Labjob_*` no es un mapeo genérico sino cuatro columnas cableadas Cu/Mo; y presenta como públicas funciones que `NAMESPACE` no exporta. Las firmas y la semántica de lab/assay A/B están verificadas literal. Los tres parsers de monitoreo requieren páginas nuevas. |
| `docs/tests.md` | 2026-01-10 | **REESCRIBIR ENTERO** — su premisa ("dos suites ejecutables bajo `project/`") es falsa para cualquiera que clone: 0 archivos versionados bajo `project/`, además excluido del tarball (`^project$` en `.Rbuildignore`). La suite real —`tests/testthat`, 5 archivos, 823 líneas— no se nombra. |
| `docs/plan.md` | 2026-01-17 | **BORRAR o ARCHIVAR fuera de `docs/`** — historia congelada ("Última verificación: 2025-12-27") de un repo que aún no era paquete R; no es documentación de usuario y hoy sólo desinforma (CWD obligatorio, `DBAudit()` como sede de la lógica). |
| `docs/index.md` | 2025-12-29 | **REESCRIBIR** — hub que presenta siete páginas como la documentación de usuario completa; no hay entrada para dos de los tres dominios ni para la API de R. |
| `docs/home.md` | 2026-06-26 | **CORREGIR (una línea)** — define el producto entero como "Geochemical certificate parser and audit pipeline (type A / type B)". El resto (`dbaudit --project <DATA_ROOT>`, salidas en `proc/`) sigue siendo válido: la invocación sin subcomando conserva el contrato legacy. |
| `docs/_config.yml` | 2026-04-30 | **CORREGIR** — repite el mismo subtítulo de un solo dominio; es lo primero que ve el sitio publicado. |
| `docs/README.md` | 2026-01-17 | **BORRAR (fusionar en `index.md`)** — tercera superficie de índice, duplicada con `index.md` y `home.md`, con una lista de "Chapters" de 9 sobre 16 archivos. Mantener tres landings garantiza que dos queden desincronizadas. |

---

## 3. LO QUE FALTA POR COMPLETO

Capacidades reales del motor sin **ninguna** cobertura documental (verificado: `grep -ril "piezometer|inclinometer|PCG|PCV|events.csv|Vega|testthat|auditPiezometer|auditInclinometer" docs/*.md README.md` → 0 archivos):

**Superficie de ejecución**
1. Subcomando `dbaudit piezometer --project <DATA_ROOT>` y sus opciones propias `--id <PCG,PCV>` y `--manifest <PATH>` (`DBAudit:229-231`, bloque PIEZOMETER OPTIONS de `--help`).
2. Los entrypoints públicos `auditPiezometer()` y `auditInclinometer()` (`NAMESPACE`, 4 exports).
3. La asimetría INC: `auditInclinometer()` está exportado y validado, pero **no tiene subcomando** y el CLI ni siquiera hace `source` de los cuatro archivos INC — la única vía es `library(dbAudit)` (`DBAudit:229-231`, `:264-274`).
4. El paquete R como superficie distinta del CLI: `install.sh` nunca ejecuta `R CMD INSTALL` (`grep -c 'R CMD INSTALL' install/install.sh` = 0), luego quien siga `docs/install.md` queda sin acceso a inclinómetros.
5. `dbaudit --check`, `dbaudit --version` y el manifiesto `.version` (commit/branch/install_date). Nota: dbAudit **no** usa el `BUILD_INFO` de las herramientas hermanas — documentarlo sería un error nuevo.

**Contrato de datos de entrada**
6. Layout de monitoreo: `source/<ID>/<Sitio>/…` como entrada del usuario, `raw/`, `db/`, `audit/` como salidas (`R/auditPiezometer.R:10-15`).
7. Parser PCG (piezómetro Casagrande, Excel).
8. Parser PCV (**cuerda vibrante**, Excel multi-hoja: tablas `hydraulic` + `instrument`, cabecera Modelo/N° Serie/Rango/Sensor/Tk/CF, `SensorID` derivado del nombre de hoja, bloque de calibración excluido). Es el parser más complejo del motor y la expresión "cuerda vibrante" no aparece en ningún `.md`.
9. Parser INC (export CSV delimitado por `;`, bloques `Headings`/`Installation v1`/`Survey v2`, cabecera `Depth,A0,A180,B0,B180`).
10. Rechazo duro de archivos nativos `.gkn`/`.dux` con `stop()` (`R/inclinometerParse.R:24-39`) — limitación de usuario de primer orden.
11. Parseo dirigido por manifiesto JSON versionado (`inst/extdata/piezometer-manifest.json`): alias multilingües de cabecera, claves, columnas, exclusiones.
12. Quinta regla de autodetección de assay: un único CSV se usa aunque la detección de formato sea inconclusa.
13. Qué carpetas crea el usuario y cuáles el runner (`raw/lab` y `source/` son error duro si faltan; `proc/`, `raw/`, `db/`, `audit/` los crea la herramienta).

**Modelo de eventos v3**
14. El segundo logger: 9 columnas `ts, scope, SiteID, HoleID, datetime, source, level, event, detail` (`R/eventLog.R:46-60`), y el hecho de que geoquímica conserva el suyo de 5.
15. `level` almacenado con semántica cerrada: INFO = marca de proceso o condición de sitio; WARNING = problema **resuelto** por el pipeline (base consistente, corregir la práctica en origen); ERROR = **no resuelto**, es la lista de trabajo.
16. Catálogo `inst/events.csv` con clave compuesta `(event, scope)`; emitir un par que no resuelva a exactamente una fila **detiene la corrida**.
17. `scope` cerrado (`run`, `file`, `survey`, `record`) y `class` (`gross`, `systematic`, `conformance`, `condition`, `run`), más `flag`, `approved` y textos bilingües.
18. Los 15 eventos del catálogo, ninguno documentado: COMMA, UNREADABLE, MISLABELED, REDATED, DUPLICATED (dos scopes, dos niveles), MIXED, UNITLESS, MISCOUNTED, MALFORMED, INCOMPLETE, MISSING, MISCLOSURE, DRY, START, DONE.
19. El nivel del catálogo es un **default sobreescribible**: el mismo evento se emite con dos niveles según si el pipeline pudo resolver el hecho (caso canónico MISLABELED).
20. Dos eventos catalogados que hoy **no se emiten**: DRY se materializa como flag `D` en `PZ.data.csv`; MISCLOSURE está suspendido a la espera del rediseño row-local.
21. Convención de nombres: evento de UNA palabra en mayúsculas en monitoreo, frente al SCREAMING_SNAKE de geoquímica; el detalle libre va en `detail`.

**Auditoría y productos**
22. Censo fuente→base `.checkSourceCensus()`: compara archivos bajo `source/` contra los efectivamente parseados y emite MISSING/ERROR.
23. Conciliación `raw`↔`db` `.checkRawDBKeys()` y lectura de reparaciones `.readRepairs()`.
24. Etapa de gate y rechazos (`.gatePiezometers()`), esquema de base (`.dbSchema()`), productos `PZ.data`/`PZ.index`/`INC.data`/`INC.index`/`*.audit.csv`.
25. **Destructividad del runner**: borra y regenera `raw/<ID>` en cada corrida y reinicializa `audit/log.csv`. Consecuencia verificada: correr `auditInclinometer()` después de `auditPiezometer()` en el mismo proyecto deja el log con sólo las filas de INC.
26. El sitio sintético **Vega** (`inst/fixtures/Vega`, tres dominios + `source/backup` + `truth.csv`): único ejemplo ejecutable del layout real, viaja en el repo *y* en toda instalación.
27. La suite de aceptación `tests/testthat/test-vega.R` y sus cuatro compuertas (toda inyección dispara con su nivel / cero fantasmas / la corrección deja el valor correcto / lo incorregible queda visible) — 103 aserciones, 0 fallos.
28. `test-census-repairs.R` (la mitad discriminante del fallo 2026-08-19) y los fixtures sintéticos con md5 (`test-synthetic-fixtures.R`), reemplazo versionado de `project/test-A|B`.

---

## 4. LOS TRES ERRORES MÁS PELIGROSOS

**1. Todos los ejemplos ejecutables apuntan a `project/`, que no existe en un clon.**
`quickstart.md` manda correr `dbaudit --project project/<PROJECT>/data`; `project-layout.md` describe ese árbol; `tests.md` afirma "the repo includes two runnable test suites under `project/`"; `plan.md` cierra reportando que ambas pasaron. Evidencia: `git ls-files project/ | wc -l` → **0** sobre 172 archivos versionados; `git check-ignore -v project/test-A/run.R` → `.gitignore:2:project/`; `.Rbuildignore` contiene `^project$`. Y aunque el usuario tuviera los directorios locales, el comando documentado igual falla: `project/test-A` usa `raw/ + assay/ + proc/` sin nivel `data/` ni `raw/lab`, y la corrida verificada aborta con `Error … lab.dir not found: …/test-A/raw/lab`. Un usuario nuevo falla en el primer comando y no tiene ningún ejemplo alternativo señalado, pese a que el repo trae Vega.

**2. La lista de dependencias R está desactualizada y omite justamente las dos que sostienen los dominios nuevos.**
`macos.md:34` y `troubleshooting.md:77-81` declaran tres paquetes: `data.table`, `stringr`, `lubridate`. Evidencia: `R/setup.R:1` → `c("data.table","stringr","lubridate","readxl","jsonlite")`; `install/install.sh:218` la misma lista de cinco; `dbaudit --check` reporta los cinco con versión. `readxl` es la única vía de lectura de los Excel PCG/PCV y `jsonlite` la del manifiesto de parseo: en un entorno gestionado, offline o con `--skip-packages` —el caso exacto en que un administrador lee esta lista para preinstalar— el CLI queda sin poder abrir ningún archivo de monitoreo.

**3. La ruta del launcher de Windows en `troubleshooting.md` no existe, y el archivo hermano dice lo contrario.**
`troubleshooting.md:24` envía al usuario a `%LOCALAPPDATA%\Programs\dbAudit\bin\dbaudit.cmd`. Evidencia: `install/install.ps1:129` escribe `$cmdPath = Join-Path $UserBinDir "dbaudit.cmd"` con `$UserBinDir = …\Programs` (`install.ps1:32`), y el runtime va aparte en `…\Programs\_runtime\dbAudit` (`install.ps1:28`). `docs/windows.md:20-21`, actualizado en agosto, ya documenta lo correcto. Un usuario que diagnostica un `command not found` en Windows verifica una ruta inventada, la encuentra vacía y concluye que la instalación falló cuando está sana — y las dos páginas se contradicen sin marca de cuál manda.

*Cuarto, a un paso de estos:* `logging.md:11` da `project/<PROJECT>/data/proc/log.csv`, que no es ninguna de las dos rutas vigentes (`<project>/proc/log.csv` para geoquímica, `<project>/audit/log.csv` para monitoreo).

---

## 5. ORDEN DE TRABAJO PROPUESTO

**Paso 0 — Decisiones del dueño, antes de redactar nada** (cada una cambia lo que se escribe; no son de redacción):
- **Versión mínima de R**: `install/install.sh:157-161` exige y verifica `>= 3.5`; `DESCRIPTION` declara `R (>= 4.1.0)`. Contradicción real en el repo; documentar cualquiera de las dos sin resolverla propaga el error.
- **INC**: ¿recibe subcomando en el CLI, o se documenta explícitamente como API de R únicamente? Hoy la asimetría existe y no está escrita en ningún lado.
- **Ejemplos**: ¿`project/` vuelve a versionarse, o Vega pasa a ser el ejemplo canónico? (Vega ya viaja en el repo y en toda instalación; es la opción sin costo.)
- **Instalación del paquete R**: ¿`install.sh` pasa a instalarlo, o `docs/` declara las dos superficies por separado?
- **Reinstalar antes de escribir**: el CLI de esta máquina es `892a246` y HEAD es `28e23db` (difieren `auditPiezometer.R`, `piezometerAudit.R` y el fixture Vega). Toda verificación copiable debe redactarse contra un CLI reinstalado, o el lector reproducirá otra cosa.

**Paso 1 — Eje de instalación** (`install.md`, `macos.md`, `troubleshooting.md`, `windows.md`; borrar `installers.md` en el mismo commit). Es por donde entra el usuario nuevo, es el único cluster con dos archivos ya sanos de agosto, y contiene los errores 2 y 3 de la sección anterior. `README.md` de la raíz es hoy la documentación de instalación más actual: `docs/` se alinea con él o remite a él, pero no puede seguir divergiendo.

**Paso 2 — Primer contacto ejecutable** (`quickstart.md`, `project-layout.md`) con Vega como ejemplo verificado de los tres dominios, los dos layouts (`raw/lab|assay|proc` y `source/raw/db/audit`), el despacho por subcomando, y la advertencia de destructividad del runner. Cierra el error 1.

**Paso 3 — Modelo de eventos** (`logging.md` reescrito, `audit.md` reencuadrado + capítulo de monitoreo). Es contrato de datos, no prosa: la tabla de eventos se deriva mecánicamente de `inst/events.csv` y los recuentos por `(level, event)` de `tests/testthat/test-vega.R`, no se transcribe a mano. Incluir las dos no-emisiones deliberadas (DRY, MISCLOSURE) para que el catálogo no prometa filas que nunca aparecen.

**Paso 4 — Parsers** (`parsers.md` corregido + páginas PCG, PCV, INC + manifiesto). Incluye el rechazo de `.gkn`/`.dux`, que hoy es una sorpresa en tiempo de ejecución.

**Paso 5 — Validación y convenciones** (`tests.md` reescrito desde `tests/testthat`; `plan.md` archivado; `conventions.md` reescrito con el mapa real de 16 módulos y la convención de nombres de evento).

**Paso 6 — Hub** (`index.md`, `home.md`, `_config.yml`; fusionar `docs/README.md`). Va último a propósito: un índice sólo puede escribirse bien cuando existe lo que indexa.

**Paso 7 — Cerrar la deriva en el guard.** `inst/scripts/verifyDocs.R:105-113` sólo valida tokens de geoquímica (`raw/lab`, `raw/assay`, `proc`, URL de docs) sobre seis archivos. Por eso el cluster quedó verde siete meses mientras el producto crecía dos dominios. Sin extenderlo a `source/`, `db/`, `audit/`, los subcomandos y los nombres del catálogo, esta misma auditoría vuelve a hacer falta en seis meses.

**Paso 8 — Deriva documental fuera de `docs/`, en el mismo barrido:**
- `R/auditPiezometer.R:6-7` — comentario que aún dice `AUDIT_START`/`AUDIT_DONE` con columna `file`; en v3 son `START`/`DONE` y el valor viaja en `source`. Último rastro de la nomenclatura vieja en `R/`.
- `R/dbAudit.R:4` — repite el claim caduco del CWD obligatorio, ya desmentido por el wrapper (`/usr/local/bin/dbaudit`, resolución de `DBAUDIT_HOME`).
- `README.md:652` — última referencia a `R/wip.R`, archivo inexistente.
- `dev/SoT/PLAN-dbaudit-R-library.md:3` — "Status: activo" afirmando que el repo "no tiene todavía DESCRIPTION, NAMESPACE, man/, tests/testthat" y dejando pendiente la decisión de exportar helpers. Los cinco artefactos existen y la decisión ya se tomó (internos; se exportan cuatro runners). Es el único documento del repo que arrastra pendientes falsos, y es SoT: corregirlo tiene prioridad sobre cualquier página de `docs/`.
