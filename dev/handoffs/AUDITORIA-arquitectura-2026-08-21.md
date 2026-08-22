# AUDITORÍA DE ARQUITECTURA — dbAudit, 2026-08-21

Pedida por el dueño tras una jornada de fallas en Windows: "no está bien
hecho... hay parches y cosas mal hechas. Ahora funciona pero de una
manera ridícula". Este documento no defiende el código: enumera lo que
está mal, con archivo y línea, incluidos los parches que agregué HOY.

## 0. El caso que el dueño usó como prueba

    dbaudit piezometer --project project/Catalina/data   → funciona
    dbaudit piezometer --project project/data            → falla

Verificado: `project/data` NO EXISTE (los proyectos son `project/BV`,
`Catalina`, `QV`, `Vega`, `Yumpag`), así que el motor responde
`project.path not found`, que es literalmente correcto.

Pero el diagnóstico del dueño es acertado igual, y por una razón más
seria que el mensaje: **hoy no existe UNA regla de dónde está la
entrada, existen varias, acumuladas por parches**. Un usuario no puede
predecir qué rutas funcionan; las prueba. Eso es el síntoma de §1.

## 1. Tres formas distintas de decir "dónde está la entrada"

| Dominio | Cómo se declara | Dónde vive |
|---|---|---|
| Geoquímica | nombres relativos MULTI-SEGMENTO: `lab.dir.name = "raw/lab"` | `R/dbAudit.R:13-17` |
| Piezómetros | un contenedor `source` + subdirectorios de ID CABLEADOS | `R/auditPiezometer.R:10-15`, `R/piezometerParse.R:.parseAll` |
| Inclinómetros | los defaults DEL OTRO dominio | `R/auditInclinometer.R:17-19` |

Tres mecanismos para el mismo concepto. Geoquímica mete dos niveles
dentro de un "nombre"; monitoreo separa contenedor e ID; inclinómetros
no tiene identidad propia y toma prestada la de piezómetros.

Encima, yo agregué HOY una cuarta forma: sondeo por convención
(`source` o `data`, el que tenga IDs adentro, `R/helpers.R
.resolveSourceDir`) más `.resolveInputDir` para geoquímica. Resuelven
el síntoma del usuario y **empeoran la arquitectura**: ahora la
respuesta a "¿dónde busca?" es un algoritmo de búsqueda, no un
contrato. Es el parche que el dueño está señalando.

## 2. Inclinómetros no existe como dominio propio

- Usa `.piezometerPathDefaults` (`auditInclinometer.R:17-19`).
- Usa `piezometer-manifest.json` (`auditInclinometer.R:50`, `DBAudit:53`,
  `DBAudit:351`) — el archivo de configuración de OTRO dominio.
- Su ID va cableado en tres lugares (`auditInclinometer.R:31,54,59`).

Un dominio de primera clase debería declarar su nombre, su ID, su
manifiesto y sus rutas en un solo lugar. Hoy no declara ninguno.

## 3. Los IDs están cableados, no registrados

`"PCG"`, `"PCV"`, `"INC"` aparecen como literales en al menos ocho
lugares (`auditPiezometer.R:23,33,34,40,131,134`,
`auditInclinometer.R:31,54,59`, `inclinometerParse.R:67`,
`helpers.R:232`, y el despacho de `.parseAll`). Agregar un cuarto tipo
de instrumento obliga a tocar todos. No hay registro de dominios.

## 4. Dos piezómetros, dos parsers paralelos

`parsePCG` (95 líneas) y `parsePCV` (105) resuelven el mismo problema
—abrir un Excel, ubicar campos por rótulos declarados, extraer cabecera
y tablas— con código paralelo y divergente. `parseINC` (55) hace lo
mismo para CSV. La estructura común (localizar, extraer, clavear,
emitir) no está factorizada: está copiada con variaciones, y por eso un
defecto se corrige en un parser y sobrevive en el otro. La búsqueda de
rutas difiere entre ellos, que es exactamente lo que el dueño observó.

## 5. Dos contratos de producto

- Geoquímica: `proc/` con 4 archivos planos.
- Monitoreo: `raw/` (árbol por ID/sitio/pozo/sensor), `db/`, `audit/`.

Y `raw/` significa lo OPUESTO en cada uno: entrada en geoquímica,
producto en monitoreo. Un proyecto con ambos dominios tiene entrada y
salida mezcladas bajo el mismo nombre.

## 6. Dos loggers, dos vocabularios

5 columnas y códigos SCREAMING_SNAKE contra 9 columnas y eventos de una
palabra con catálogo. Ya está planificado
(`dev/SoT/PLAN-log-unificado.md`) y sin implementar. Consecuencia viva:
no se puede filtrar una sola lista de trabajo del proyecto entero.

## 7. Los parches que agregué hoy, declarados como tales

1. `.resolveSourceDir` / `.resolveInputDir` — sondeo por convención en
   vez de contrato (§1).
2. `--source-dir/--raw-dir/--db-dir/--audit-dir` en monitoreo — paridad
   con geoquímica, pero perpetúa que la ubicación sea configurable en
   vez de derivada.
3. `.dbauditResource` — resolvedor único de recursos; correcto, pero
   nació porque había DOS formas ad-hoc de encontrar el mismo tipo de
   archivo.
4. `.relativeToRoot` / `.relativeParts` — hoy conviven dos funciones
   para "restar la raíz", una en helpers y otra en el parser, con
   contratos casi iguales. Deberían ser una.
5. Retrocompatibilidad de layouts — necesaria para no romper, pero
   suma permanentemente formas válidas: hoy `source/`, `data/`,
   `raw/lab` y `data/GEO/lab` son todas correctas.

## 8. Defectos de fondo que la caza confirmó (16 confirmados, 7 refutados)

Todos comparten forma: **tratar una ruta como texto con separador `/`**,
invisible en POSIX. Corregidos hoy: la rama de escape que devolvía la
ruta absoluta; el identificador de pozo sin sanear para Windows; el
censo restando un prefijo normalizado; el log de geoquímica y el
detector de formato fuera del blindaje; la instalación de paquetes sin
biblioteca fijada.

Sin corregir (menores, con su lugar):
- `piezometerParse.R:221` — `sort(list.files())` ordena por locale y ese
  orden se propaga al orden de filas de los productos.
- `piezometerAudit.R:95-138` — los lectores de rechazos confían en que
  la corrida anterior limpió su sumidero, sin marca de frescura.
- `auditPiezometer.R:72-74`, `auditInclinometer.R:63`,
  `piezometerBuild.R:349-351` — valores de retorno de `unlink` y
  `file.remove` descartados: un borrado fallido pasa inadvertido.

## 9. Qué haría una arquitectura coherente

Un **registro de dominios**, una fila por dominio, declarando: nombre,
ID, subdirectorio de entrada, parser, manifiesto, productos. El CLI, los
runners, el censo, los mensajes de error y la documentación se derivan
de esa tabla. Consecuencias: los IDs dejan de estar cableados; agregar
un instrumento es una fila; inclinómetros deja de tomar prestada la
identidad de piezómetros; "dónde busca cada slug" es un dato, no un
algoritmo; y el sondeo por convención se retira porque ya no hace falta.

Sobre los parsers: extraer la estructura común (localizar por rótulos,
extraer, clavear, emitir) a una capa compartida y dejar en cada parser
solo lo que de verdad difiere — el formato del archivo.

## 10. Rulings pedidos

1. ¿Se aprueba el registro de dominios como pieza central?
2. ¿Se retira el sondeo por convención una vez que exista, aceptando
   declarar UNA forma de entrada y migrar los proyectos?
3. ¿Se unifican los productos (`proc/` dentro de `db/`+`audit/`) o se
   deja esa asimetría?
4. ¿Se factoriza la capa común de parsers, o se acepta el código
   paralelo por ahora?
5. ¿Se cierran los cuatro menores de §8 en el mismo movimiento?
