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

## Pending

- Definir el contrato publico para geoquimica sin romper `DBAudit()`.
- Definir el contrato publico para piezometros.
- Definir como el CLI selecciona contrato sin afectar usuarios actuales.
- Definir ubicacion de ejemplos completos.
- Definir pruebas de regresion por contrato.
- Decidir si los slugs publicos son `geochem` y `piezometer`, o si se usa otra
  nomenclatura aprobada.
- Implementar `examples/scripts/geochem` despues de aplicar el contrato
  canonico `/Users/averrik/github/agents/R-PIPELINES.md`.
- Revisar `PE-DBAudit/project/BV` y `PE-DBAudit/project/QV` como aplicaciones
  geoquimicas reales, sin escribir en ese repo mientras este sucio.
- Ejecutar `runGeochem.PE-DBAudit.json` solo sobre una copia temporal o despues
  de resolver el estado sucio del repo de aplicacion.

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
- El checkout `~/github/projects/PE-DBAudit` esta sucio; tiene muchas bajas
  registradas y `project/QV/proc` no trackeado. No escribir ahi hasta que el
  usuario decida como tratar ese estado.

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
