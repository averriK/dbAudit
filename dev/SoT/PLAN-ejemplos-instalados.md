# PLAN — Ejemplos ejecutables en la instalación

Fecha: 2026-08-21. Estado: PROPUESTA para ruling del dueño.

## Hecho observado

`examples/` tiene un ejemplo por dominio (geoquímica, piezómetros,
inclinómetros), cada uno con su script y su README, verificados por
corrida. Ninguno llega al usuario: el instalador copia `DBAudit`, `R/`,
`inst/` y `bin/dbaudit` — `examples/` y `tests/` quedan afuera
(`install.sh:166-169`, `install.ps1:187-196`).

De los datos que los ejemplos necesitan, solo uno viaja: el sitio
sintético Vega, porque vive en `inst/fixtures/`. Los certificados
sintéticos de geoquímica están en `tests/testthat/fixtures/`, que no se
instala. Hoy un usuario instalado no puede correr ningún ejemplo sin
clonar el repositorio.

## Qué se propone

1. **Los datos de ejemplo viajan**: los certificados sintéticos A y B
   pasan a `inst/fixtures/` junto a Vega. Los tests los siguen usando
   desde ahí (una sola copia; los goldens no cambian).
2. **Los ejemplos viajan**: `examples/` se instala bajo el runtime.
3. **Un verbo del CLI los materializa**:

   ```
   dbaudit example --list
   dbaudit example <geochemistry|piezometer|inclinometer> [--to <DIR>]
   ```

   `--list` enumera los ejemplos instalados con una línea cada uno.
   El segundo copia el conjunto de datos del ejemplo a `<DIR>`
   (default: `./dbaudit-example-<dominio>`) y imprime el comando exacto
   que el usuario corre a continuación — el comando REAL del dominio,
   no un modo especial: el ejemplo enseña el flujo de trabajo de
   verdad.

## Reglas de diseño

- El runtime instalado es de solo lectura: el ejemplo se materializa
  siempre en un directorio del usuario, nunca dentro de la instalación.
- Destino no vacío: se rechaza, salvo `--force`. Un ejemplo no pisa
  datos de nadie.
- El directorio materializado es una raíz de datos completa y
  autocontenida (`source/` para monitoreo; `raw/lab` + `raw/assay`
  para geoquímica), de modo que el comando que se imprime es el mismo
  que el usuario usará con sus datos reales.
- Vega viaja con su `truth.csv`: el ejemplo de monitoreo puede
  contrastarse contra la verdad conocida, que es su valor didáctico.
- Cero datos de cliente: los ejemplos son sintéticos por construcción.

## Validación

Un test por dominio que materializa el ejemplo en un directorio
temporal, corre el runner correspondiente y verifica los eventos
esperados. Con eso los ejemplos dejan de ser documentación que se
oxida: si un ejemplo se rompe, falla la suite. Más la suite completa y
los goldens byte-idénticos.

## Rulings pedidos

1. ¿Se aprueba el verbo `dbaudit example` con esa forma?
2. ¿Se aprueba mover los fixtures sintéticos de geoquímica a `inst/`
   (una sola copia, usada por tests y ejemplos)?
3. ¿Directorio destino por defecto `./dbaudit-example-<dominio>`, o se
   exige `--to` siempre?
