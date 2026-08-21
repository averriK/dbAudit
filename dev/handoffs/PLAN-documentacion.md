# PLAN — Actualización de la documentación de dbAudit

Fecha: 2026-08-21. Estado: PARA RULING del dueño (cinco decisiones en
el Paso 0). Evidencia: `AUDITORIA-docs-2026-08-21.md` (este directorio)
— cuatro auditorías independientes contra `R/`, `inst/events.csv`,
`tests/testthat/`, `install/` y el CLI instalado. 24 afirmaciones
obsoletas, 45 capacidades sin cobertura.

## Diagnóstico

`docs/` describe con exactitud un producto de UN dominio (geoquímica)
congelado entre diciembre y enero: 12 de 16 archivos no se tocan desde
enero de 2026. El motor, entretanto, creció a tres dominios, cambió el
modelo de eventos, se convirtió en paquete R y adquirió despacho por
subcomando. Ninguna página menciona `piezometer`, `inclinometer`,
`source/`, `inst/events.csv`, `Vega` ni `testthat`.

La mitad geoquímica sigue siendo correcta y verificada línea por línea:
se conserva como base literal, no se tira.

## Los tres errores que hacen fallar a un usuario hoy

1. **Todo ejemplo ejecutable apunta a `project/`, que no existe en un
   clon.** `quickstart.md` manda `dbaudit --project project/<P>/data`;
   `tests.md` promete dos suites ahí. `git ls-files project/` → 0; el
   directorio está en `.gitignore` y en `.Rbuildignore`. El usuario
   nuevo falla en el primer comando, y el repositorio trae Vega —un
   ejemplo real de los tres dominios— sin que ninguna página lo nombre.
2. **La lista de dependencias omite las dos que sostienen los dominios
   nuevos.** `macos.md` y `troubleshooting.md` declaran tres paquetes;
   `R/setup.R` y el instalador exigen cinco: faltan `readxl` (única vía
   de lectura de los Excel de piezómetro) y `jsonlite` (manifiesto de
   parseo). Quien preinstale siguiendo esa lista queda sin poder abrir
   un solo archivo de monitoreo.
3. **La ruta del launcher de Windows en `troubleshooting.md` no
   existe**, y `windows.md` —actualizado en agosto— dice lo contrario
   sin marca de cuál manda. Un usuario que diagnostica un
   `command not found` verifica una ruta inventada y concluye que la
   instalación falló cuando está sana.

## Paso 0 — Decisiones previas a redactar (rulings)

Cada una cambia lo que se escribe; ninguna es de redacción.

1. **Versión mínima de R**: `install/install.sh` exige `>= 3.5`;
   `DESCRIPTION` declara `>= 4.1.0`. Contradicción real en el repo:
   documentar cualquiera sin resolverla propaga el error.
2. **Inclinómetros**: `auditInclinometer()` está exportado y validado
   pero **no tiene subcomando** — la única vía es `library(dbAudit)`.
   ¿Se le da subcomando al CLI, o se documenta explícitamente como API
   de R? Hoy la asimetría existe y no está escrita en ningún lado.
3. **Ejemplo canónico**: ¿vuelve `project/` al control de versiones, o
   Vega pasa a ser el ejemplo de la documentación? Vega ya viaja en el
   repositorio y en toda instalación: es la opción sin costo.
4. **Paquete R**: `install.sh` nunca ejecuta `R CMD INSTALL`. Quien
   siga `docs/install.md` queda sin acceso a inclinómetros. ¿El
   instalador lo instala, o `docs/` declara las dos superficies?
5. **Reinstalar antes de escribir**: el CLI de esta máquina es
   `892a246` y HEAD es `28e23db`. Toda verificación copiable debe
   redactarse contra un CLI reinstalado, o el lector reproducirá otra
   cosa.

## Orden de trabajo

**Paso 1 — Eje de instalación.** `install.md`, `macos.md`,
`troubleshooting.md`, `windows.md`; `installers.md` se borra en el
mismo commit (declara fuente de verdad a un documento externo que el
lector no puede abrir). Es por donde entra el usuario nuevo y contiene
los errores 2 y 3.

**Paso 2 — Primer contacto ejecutable.** `quickstart.md` y
`project-layout.md` reescritos con Vega como ejemplo verificado, los
DOS layouts (`raw/lab|assay|proc` para geoquímica; `source/`, `raw/`,
`db/`, `audit/` para monitoreo), el despacho por subcomando y la
advertencia de destructividad del runner (borra y regenera `raw/<ID>`
y reinicializa el log en cada corrida). Cierra el error 1.

**Paso 3 — Modelo de eventos.** `logging.md` reescrito; `audit.md`
reencuadrado como capítulo de geoquímica más un capítulo de monitoreo
nuevo. Es contrato de datos, no prosa: la tabla de eventos se DERIVA
mecánicamente de `inst/events.csv` y los recuentos por `(level, event)`
de `tests/testthat/test-vega.R` — no se transcribe a mano. Incluye las
dos no-emisiones deliberadas (DRY como bandera; MISCLOSURE suspendido)
para que el catálogo no prometa filas que nunca aparecen.

**Paso 4 — Parsers.** `parsers.md` corregido más páginas de PCG, PCV
(el más complejo del motor: Excel multi-hoja con cabecera de
calibración; la expresión "cuerda vibrante" no aparece hoy en ningún
documento) e INC, y el manifiesto JSON de parseo. Incluye el rechazo
duro de archivos nativos `.gkn`/`.dux`, hoy una sorpresa en tiempo de
ejecución.

**Paso 5 — Validación y convenciones.** `tests.md` reescrito desde
`tests/testthat` (5 archivos, 823 líneas, con las cuatro compuertas de
Vega); `plan.md` archivado fuera de `docs/`; `conventions.md` reescrito
con el mapa real de módulos y la convención de nombres de evento.

**Paso 6 — Hub.** `index.md`, `home.md`, `_config.yml`; `docs/README.md`
se fusiona en `index.md` (tres landings garantizan que dos queden
desincronizadas). Va último: un índice se escribe bien solo cuando
existe lo que indexa.

**Paso 7 — Cerrar la deriva en el guard.** `inst/scripts/verifyDocs.R`
solo valida tokens de geoquímica sobre seis archivos: por eso el
cluster quedó verde siete meses mientras el producto crecía dos
dominios. Extenderlo a `source/`, `db/`, `audit/`, los subcomandos y
los nombres del catálogo. Sin esto, la misma auditoría vuelve a hacer
falta en seis meses.

**Paso 8 — Deriva fuera de `docs/`, en el mismo barrido.**
`R/auditPiezometer.R` (comentario con la nomenclatura vieja
AUDIT_START/AUDIT_DONE), `R/dbAudit.R` (claim caduco del CWD
obligatorio), `README.md` (referencia a `R/wip.R`, inexistente) y
`dev/SoT/PLAN-dbaudit-R-library.md`, que declara pendientes ya
resueltos — es SoT, y corregirlo tiene prioridad sobre cualquier
página de `docs/`.

## Relación con el deck manual

`PLAN-deck-manual-usuario.md` cuenta lo mismo a otra audiencia.
Construir el deck antes de sanear `docs/` duplicaría los errores en un
segundo lugar: la documentación va primero, el deck cita esa fuente.
