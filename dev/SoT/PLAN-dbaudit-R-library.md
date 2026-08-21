# PLAN: convertir dbAudit en libreria R

Status: COMPLETADO.
Cierre 2026-08-21: `DESCRIPTION`, `NAMESPACE`, `man/`, `tests/testthat.R` y
`tests/testthat/` existen en el repositorio, y la decision pendiente de
exports quedo tomada: se exportan los 4 runners (`DBAudit`,
`auditGeochemistry`, `auditPiezometer`, `auditInclinometer`) y los helpers
quedan internos. Las secciones siguientes, incluido el "Estado actual
observado" de 2026-06-26, se conservan como historia del plan.
Fecha: 2026-06-26.
Rama de trabajo: `dev`.

## Decision aprobada

`dbAudit` debe pasar de ser solo un CLI con scripts R cargados por `source()` a una libreria R. El CLI debe usar la libreria, no duplicar la logica.

Antes de esta fase se dejo `main` y `dev` en el mismo commit:

- `15ec756` (plan de compuerta de ingesta de la aplicacion downstream)

## Restricciones

- No cambiar el contrato legacy del CLI actual.
- No romper `dbaudit --project <DATA_ROOT>`.
- No tocar la semantica de los pipelines geoquimicos existentes en la primera etapa.
- No introducir verbos CLI nuevos hasta que el contrato este aprobado.
- No usar subdirectorios anidados bajo `dev/SoT` para este trabajo.
- No usar nombres de dominio no aprobados como abstracciones publicas.

## Estado actual observado

El repositorio tiene:

- `R/*.R`: helpers, parsers, auditor y runner.
- `DBAudit`: entrypoint Rscript del CLI.
- `bin/dbaudit`: wrapper bash que ejecuta `Rscript DBAudit`.
- `project/test-A` y `project/test-B`: proyectos de prueba.
- `docs/`: documentacion humana.

El repositorio no tiene todavia:

- `DESCRIPTION`.
- `NAMESPACE`.
- `man/`.
- `tests/testthat.R`.
- `tests/testthat/`.

Por lo tanto aun no es paquete R.

## Objetivo de la primera etapa

Crear un paquete R minimo sin cambiar comportamiento:

- `library(dbAudit)` debe cargar.
- `dbAudit::DBAudit(project.path = ...)` debe ejecutar el pipeline actual.
- `bin/dbaudit` debe seguir funcionando como antes.
- Los ejemplos `project/test-A` y `project/test-B` deben seguir pasando.

## API inicial

API publica estable en la primera etapa:

- `DBAudit()`.

Funciones existentes que deben mantenerse, pero no necesariamente exportarse todavia:

- `parseLabData()`.
- `parseAssayData()`.
- `auditStructure()`.
- `auditValues()`.

Decision pendiente:

- decidir si esos helpers se exportan como API publica o quedan internos hasta tener ejemplos R aprobados.

## Dependencias

Dependencias actuales observadas:

- `data.table`.
- `stringr`.
- `lubridate`.

Politica propuesta:

- declararlas en `DESCRIPTION`.
- no instalar paquetes desde codigo de libreria.
- mantener diagnostico de dependencias en CLI si hace falta.
- revisar `R/setup.R`: debe quedar como compatibilidad CLI o desaparecer del runtime cuando el paquete cargue por `library(dbAudit)`.

## Plan de implementacion

1. Crear esqueleto de paquete:
   - `DESCRIPTION`.
   - `NAMESPACE`.
   - `R/dbAudit-package.R` si se usa roxygen.
   - `tests/testthat.R`.
   - `tests/testthat/`.

2. Adaptar carga de dependencias:
   - quitar dependencia de `source(R/setup.R)` para uso como libreria.
   - usar llamadas calificadas o imports declarados.
   - mantener `R/setup.R` solo si el CLI legacy lo necesita temporalmente.

3. Mantener CLI compatible:
   - `bin/dbaudit` sigue resolviendo `DBAUDIT_HOME`.
   - `DBAudit` intenta cargar la libreria instalada cuando sea posible.
   - si se ejecuta desde checkout sin instalar, conserva fallback por `source()`.

4. Agregar tests minimos:
   - carga de paquete.
   - `DBAudit(project.path = project/test-A, lab.dir.name = "raw", assay.dir.name = "assay")` genera `proc/log.csv`.
   - `DBAudit(project.path = project/test-B, lab.dir.name = "raw", assay.dir.name = "assay")` genera `proc/log.csv`.
   - el CLI `bin/dbaudit --check` sigue funcionando.

5. Validar sin tocar comportamiento:
   - `R CMD check` o `devtools::check()` si el entorno lo permite.
   - `Rscript -e 'library(dbAudit)'`.
   - `bin/dbaudit --project project/test-A --lab-dir raw --assay-dir assay`.
   - `bin/dbaudit --project project/test-B --lab-dir raw --assay-dir assay`.

## Integracion posterior con la aplicacion downstream

Despues de tener paquete R estable:

- mover o reimplementar helpers aprobados de la aplicacion downstream dentro de `dbAudit`.
- construir ejemplos R separados por tipo de problema, no mezclar geoquimica con piezometros.
- mantener el pipeline geoquimico actual como contrato legacy.
- agregar el nuevo pipeline de base de datos solo despues de aprobar su contrato publico.

## Riesgos

- El CLI actual auto-instala dependencias desde `R/setup.R`; eso no es aceptable como comportamiento normal de libreria.
- Exportar demasiados helpers ahora puede congelar APIs inmaduras.
- Mover archivos R de lugar puede romper instaladores; la primera etapa debe evitar movimientos innecesarios.

## Criterio de aceptacion

Se acepta la primera etapa solo si:

- `main` queda intacto hasta PR o commit aprobado desde `dev`.
- `dbaudit --project` produce los mismos archivos que antes.
- `library(dbAudit)` funciona.
- los tests de `project/test-A` y `project/test-B` pasan usando sus overrides legacy.
- no se introducen comandos CLI nuevos.
