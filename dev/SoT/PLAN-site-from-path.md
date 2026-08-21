# PLAN — La raíz es una ruta, no un patrón

Fecha: 2026-08-21. Estado: DEFECTO CONFIRMADO Y CORREGIDO.
Reportado por el dueño desde Windows, con el error del motor a la vista.

## El defecto

`siteFromPath()` y `.relativeParts()` (`R/piezometerParse.R`) quitaban
la raíz del proyecto de la ruta de cada archivo usando la raíz COMO
PATRÓN de expresión regular, y partían el resto por `/`:

    sub(paste0("^", normalizePath(root), "/?"), "", normalizePath(path))
    strsplit(Rel, "/", fixed = TRUE)[[1L]][1L]

En Windows la ruta normalizada trae contrabarras y los dos puntos de
la unidad — todos metacaracteres — de modo que el patrón no coincide
con nada, no se quita nada, y el resto no tiene `/` para partir. El
resultado: **la ruta absoluta completa queda como SiteID**.

Ese SiteID se usa como nombre de directorio al escribir los productos
crudos (`raw/<ID>/<SiteID>/<HoleID>/<SensorID>`), así que el motor
intenta crear un directorio cuyo nombre es una ruta con dos puntos:
inválido en Windows, y la corrida muere. Error observado:

    Invalid argument: '...\data/raw/PCG/C:\...\VP-1_....xlsx/VP-1/0/data.csv'

En POSIX no falla ruidosamente: crea un árbol anidado absurdo o deja
el directorio vacío. El defecto es de las dos plataformas; solo se ve
en una.

Verificado en aislamiento antes de corregir: con una raíz de estilo
Windows, el `sub()` deja la cadena intacta y el SiteID devuelto es la
ruta entera.

## La corrección

Una sola implementación (`.relativeParts`), de la que `siteFromPath`
pasa a ser el primer segmento:

- la raíz se quita POR LONGITUD, comparando prefijos normalizados —
  nunca como patrón;
- la comparación es insensible a mayúsculas en Windows, donde las
  rutas lo son;
- el resto se parte por cualquiera de los dos separadores.

## Validación

`tests/testthat/test-path-roots.R`: el sitio es el primer segmento bajo
la raíz; una raíz con metacaracteres (`.`, `(`, `)`, `+`) igual se
quita; y el sitio nunca contiene un separador ni dos puntos — la
aserción que habría atrapado esto. Suite completa en verde, goldens
byte-idénticos.

## Pendiente del dueño

Los productos ya escritos con el SiteID corrupto (si alguna corrida
POSIX dejó árboles anidados) se regeneran corriendo de nuevo; no hay
que repararlos a mano.
