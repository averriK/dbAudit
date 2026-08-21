# PLAN — Un log por dominio, con un solo formato

Fecha: 2026-08-21. Estado: PROPUESTA para ruling del dueño.
Ruling ya dado (2026-08-21): **un log único por geoquímica, por
piezómetros y por inclinómetros**. Este plan lo desarrolla.

## Los hechos que lo motivan (medidos, no supuestos)

1. **El log de monitoreo no registra el procesamiento.** Geoquímica
   emite un recibo por archivo — `FILE_START` con su ruta y su jobID, y
   `PARSE_OK` con las filas que rindió: 46.624 líneas para 23.285
   certificados. Monitoreo procesó 954 archivos de un proyecto real y
   **ninguno aparece**: la columna `source` solo cita productos. No hay
   forma de responder "¿se leyó mi planilla?".
2. **Los hallazgos se agregan en vez de enumerarse.** Una línea dice
   `REDATED; groups=98; surveys=211`. Dice cuántos, nunca cuáles. El
   detalle queda en tablas de 61.000 filas por 17 columnas, que no son
   una lista de trabajo.
3. **Los dominios se pisan el log.** Cada runner reinicializa
   `audit/log.csv`, así que auditar un sitio completo deja solo las
   líneas del último dominio corrido. Verificado: tras correr
   piezómetros e inclinómetros sobre el mismo proyecto, el log no
   conserva ni un evento de piezómetros.
4. **Dos formatos conviven**: geoquímica 5 columnas
   (`ts, level, file, event, message`), monitoreo 9
   (`ts, scope, SiteID, HoleID, datetime, source, level, event, detail`).

## Lo que se propone

### Un log por dominio

Tres archivos, uno por dominio, cada uno dueño de su archivo — con lo
que el punto 3 desaparece por construcción: ningún runner escribe el
log de otro.

| Dominio | Log | Junto a |
|---|---|---|
| Geoquímica | `GEO.log.csv` | sus productos (`proc/`) |
| Piezómetros (PCG + PCV) | `PZ.log.csv` | sus productos (`audit/`) |
| Inclinómetros | `INC.log.csv` | sus productos (`audit/`) |

Los nombres siguen la convención de los productos que ya existen
(`PZ.data.csv`, `INC.data.csv`).

### Un solo formato

Núcleo común, idéntico en los tres:

    ts, scope, level, event, source, detail

más un bloque de identidad cuyas columnas se llenan cuando aplican y
quedan vacías cuando no — igual que hoy monitoreo deja vacío el pozo en
un evento de ámbito `run`:

    ID, SiteID, HoleID, SensorID, datetime, jobID, sampleID

Geoquímica llena `ID`, `jobID` y `sampleID`; monitoreo llena `ID`,
`SiteID`, `HoleID`, `SensorID` y `datetime`. Un consumidor lee un solo
esquema y filtra `level == ERROR` para obtener la lista de trabajo del
proyecto entero, sin importar el dominio.

### Ámbito (`scope`): la diferencia por tipo de problema

`scope` declara a qué se le atribuye el hecho, y es lo que distingue un
problema de otro. Monitoreo ya lo tiene; geoquímica lo gana:

- `run` — la corrida (START, DONE)
- `file` — un archivo o certificado completo
- `survey` — una campaña (solo monitoreo)
- `record` — una lectura
- `sample` — una muestra (solo geoquímica)
- `value` — una determinación (solo geoquímica)

El catálogo `inst/events.csv` pasa a cubrir también los eventos de
geoquímica, con la misma clave `(event, scope)` y el mismo contrato:
emitir un par que no resuelva a una fila detiene la corrida.

### Granularidad

- **Recibo por archivo** en los tres dominios: una línea al abrir y una
  al cerrar cada archivo, con su ruta y cuánto rindió.
- **Un hallazgo, una línea**: 98 campañas re-fechadas son 98 líneas,
  cada una con su pozo y sus dos fechas; nunca un contador.

Efecto esperado sobre un proyecto real de monitoreo: el log pasa de 8
líneas a algunos miles — grande, completo y filtrable, como el de
geoquímica.

## Fuera de alcance (declarado)

El **forecast no entra al log**: vive en tablas espejo del dato
(`PCG.forecast.csv`, `PCG.spatial.csv`) con las claves de la lectura,
porque es dato inferido, no un hecho de auditoría. Lo que sí sería un
hecho —una lectura fuera de su banda— exige un evento nuevo del
catálogo y su validación en Vega: se planifica aparte.

## Consumidores a migrar

El deck y el reporte leen `audit/log.csv`; el dashboard lo declara como
sexto archivo requerido de su contrato. Los tres se actualizan en el
mismo movimiento, y el ledger EN/ES de la leyenda pasa a cubrir los
eventos de geoquímica.

## Validación

- Vega, con su verdad conocida, gana las aserciones de recibo por
  archivo y de enumeración: cada inyección aparece como su propia línea.
- Un test que corre los tres dominios sobre un mismo proyecto y verifica
  que los tres logs coexisten completos.
- Suite completa y goldens byte-idénticos en los productos de datos.

## Rulings pedidos

1. ¿Se aprueban los tres nombres y su ubicación junto a los productos
   de cada dominio?
2. ¿Los códigos de geoquímica se migran a la convención de una palabra
   (`DUPLICATED`, `MISLABELED`…) o conservan su forma actual
   (`SAMPLEID_NOT_UNIQUE`) dentro del formato común?
3. ¿`audit/log.csv` se conserva un tiempo como copia consolidada de los
   tres, para no romper consumidores de golpe?
