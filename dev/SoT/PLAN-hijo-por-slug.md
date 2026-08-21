# PLAN — Qué hijo busca cada slug

Fecha: 2026-08-21. Estado: APROBADO por el dueño ("aplica los cambios")
e IMPLEMENTADO el mismo día, en su variante aditiva.

## El problema

Cada subcomando buscaba un hijo distinto, sin regla común:

| Slug | Entrada | Productos |
|---|---|---|
| geochemistry | `raw/lab/`, `raw/assay/` | `proc/` |
| piezometer | `source/PCG/`, `source/PCV/` | `raw/`, `db/`, `audit/` |
| inclinometer | `source/INC/` | `raw/`, `db/`, `audit/` |

Con tres asimetrías, y la primera grave: **`raw/` significa lo opuesto
en cada dominio** — entrada en geoquímica, producto en monitoreo. Además
geoquímica no tenía directorio por ID mientras monitoreo sí, y el
usuario terminaba nombrando rutas a mano en cada corrida, que es un
parche disfrazado de opción.

## La regla

Cada slug busca su propio hijo del directorio de entrada:

    data/GEO/lab/      data/GEO/assay/      → geochemistry
    data/PCG/<Sitio>/  data/PCV/<Sitio>/    → piezometer
    data/INC/<Sitio>/                       → inclinometer

Los tres dominios comparten una raíz sin pisarse: cada uno lee solo su
hijo y escribe sus productos. Los comandos no llevan opciones de ruta.

## Aditiva por decisión

Los layouts anteriores siguen resolviendo: `raw/lab` + `raw/assay` para
geoquímica, `source/<ID>` para monitoreo. Ningún proyecto en marcha
—los del repositorio privado, el reporte, el dashboard— tiene que mover
un archivo. Un directorio nombrado explícitamente por opción siempre
gana sobre la convención.

## Verificado

- Geoquímica con `data/GEO` y con `raw/lab`, sin banderas: ambas
  producen `proc/` completo.
- Monitoreo con `data/<ID>` y con `source/<ID>`, sin banderas.
- Los tres dominios sobre una misma raíz: `data/{GEO,PCG,PCV,INC}` de
  entrada, productos en `raw/`, `db/`, `audit/`, `proc/`; los tres
  comandos exit 0 y las seis tablas de monitoreo presentes.
- Suite completa en verde, goldens byte-idénticos.

## Pendiente declarado

Los productos siguen repartidos: `proc/` en geoquímica, `raw/`+`db/`+
`audit/` en monitoreo. Unificarlos rompe consumidores (el reporte, el
deck, el dashboard leen rutas fijas) y va en su propio plan con
migración; la entrada, que es lo que el usuario escribe, ya es una sola
regla.
