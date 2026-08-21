# PLAN — Deck manual de usuario de dbAudit

Fecha: 2026-08-21. Estado: PARA RULING del dueño (cuatro decisiones al
final). Este plan define el CONTENIDO y la UBICACIÓN de un deck nuevo.
NO reemplaza `<proyecto>/_master/ppt.qmd` — ese es el deck de
capacidades para el cliente (por qué el sistema es confiable). Este es
el manual operativo: cómo se instala, dónde se guardan las cosas, cómo
se corre y cómo se lee el resultado.

## Distinción con el deck existente

| | Deck de capacidades (`ppt.qmd`) | Deck manual (este) |
|---|---|---|
| Audiencia | expertos del cliente | quien opera la herramienta |
| Pregunta | ¿por qué confiar en estos datos? | ¿cómo lo hago funcionar? |
| Material | tríadas planilla→log→producto, Vega, hallazgos | comandos, rutas, salidas reales |
| Prueba | evidencia y validación | reproducibilidad paso a paso |

Regla heredada: registro técnico declarativo, sin tono instruccional
vacío ni promocional. "Instruccional" aquí significa la mecánica real
—comando, ruta, salida—, no exhortaciones ni pedagogía de diccionario.

## Estructura propuesta (capítulos con portada + índice, idioma NGR)

### 1. Qué es y qué produce
Motor de auditoría de datos cargados a mano, con tres dominios
(certificados geoquímicos, piezómetros, inclinómetros). Entrada: los
archivos tal como llegan. Salida: base procesada + índice de
trazabilidad + log de tres niveles. Diagrama de la cadena
fuente → raw → base + auditoría + log, y quién consume cada producto.

### 2. Instalación
Requisitos (R y los paquetes que `--check` verifica), la instalación
por `sudo ./install.sh`, verificación con `dbaudit --check` y
`dbaudit --version`, y cómo saber si el binario instalado quedó
atrasado respecto del motor (el caso real del build viejo emitiendo
falsos MISSING sobre un fixture nuevo). Windows y macOS/Linux.

### 3. Dónde vive cada cosa — el contrato de carpetas
La lámina que hoy no existe en ninguna parte y es la más pedida:
- Geoquímica: `<raíz>/raw/lab/` (certificados), `<raíz>/raw/assay/`
  (base del cliente), productos en `<raíz>/proc/`.
- Monitoreo: `<raíz>/source/<TIPO>/<Sitio>/` (planillas tal como
  llegan, sin renombrar), productos en `<raíz>/raw`, `<raíz>/db`,
  `<raíz>/audit`.
- Qué crea la herramienta sola y qué debe existir antes.
- Qué NO se toca a mano nunca (los productos son regenerables; la
  fuente es el original del cliente).
Los defaults se citan del código (`.dbauditPathDefaults`,
`.piezometerPathDefaults`), no de memoria.

### 4. Ejemplo geoquímica
Tríada operativa: un certificado real del árbol de trabajo → comando
(`dbaudit geochemistry --project <raíz>`) → las filas de `proc/lab.csv`
e `index.csv` y las líneas de log del job. Cubre el caso de escala
(miles de certificados en una corrida), la corrección automática con
rendición (JOBID_FIXED), el contraste base-vs-certificado
(WRONG_VALUE) y el certificado que el parser no reconoce y excluye el
job completo.

### 5. Ejemplo piezómetros
`dbaudit piezometer --project <raíz>` sobre el sitio sintético Vega:
la coma decimal corregida con valor original retenido, la celda
ilegible que deja hueco visible, el pozo seco como condición con
bandera, el duplicado que la planilla no distingue. Cada uno con su
línea de log y su fila en la base.

### 6. Ejemplo inclinómetros
La cadena de campañas: identidad contenido-archivo, campaña
re-publicada con otra fecha, survey duplicado consolidado, header que
declara N profundidades y entrega otras, y el censo que detecta el
archivo que ningún parser recorrió. Con la salida real del dominio.

### 7. Leer el resultado y trabajar con él
El formato de línea del log, los tres niveles y su significado
operativo, el filtro por ERROR como lista de trabajo, y la
trazabilidad de cada línea a archivo y fila por el índice. Qué hace el
operador con cada evento (la tabla automático / supervisado /
condición).

### 8. El dato nuevo y la re-corrida
El archivo que llega mañana: dónde se guarda, qué comando regenera la
cadena, qué cambia en los productos y qué leen los consumidores
aguas abajo. Idempotencia y reproducibilidad.

### 9. Cuando algo falla
Los modos de falla reales y su lectura: dependencias ausentes, raíz
que no cumple el contrato, archivo fuera del recorrido (MISSING),
formato no reconocido, binario desactualizado. Cada uno con su
síntoma exacto y su acción.

## Requisitos de construcción

1. **Todo comando se verifica corriéndolo** antes de entrar a una
   lámina: se cita la salida real, nunca una salida plausible.
2. Los ejemplos usan los fixtures del repositorio (Vega,
   synthetic-A/B) y el árbol geoquímico de trabajo; ningún dato de
   cliente entra al deck.
3. Las rutas y defaults se citan del código, no de la documentación
   vigente — que esta misma sesión audita por obsoleta.
4. Formato de la casa: capítulos con portada `.coverChapter` + índice
   `.index`, tabsets para las tríadas, ventanas de terminal para las
   salidas, facsímil de planilla para los insumos.

## Dependencia: la documentación primero

El deck y `docs/` cuentan lo mismo a dos audiencias. Escribir el deck
antes de corregir `docs/` duplicaría los errores en un segundo lugar.
Orden propuesto: cerrar el plan de documentación (auditoría en curso),
corregir `docs/`, y construir el deck citando esa fuente ya sana.

## Rulings pedidos

1. **¿Dónde vive el deck?** Recomendación: en `dbAudit` — es el manual
   de la herramienta, no de un proyecto de cliente; requiere `qrt init`
   ahí (hoy el repo no tiene scaffold). Alternativa: en `el proyecto de monitoreo downstream`
   como `_master/ppt.manual.qmd`, reutilizando la infraestructura que
   ya funciona, al costo de acoplar el manual a un proyecto.
2. **¿Idioma?** El deck de capacidades es español. El repositorio y
   `docs/` están en inglés. ¿Manual en español, en inglés, o ambos?
3. **¿Alcance del ejemplo geoquímico?** Los datos de trabajo son de un
   proyecto real; ¿el manual usa solo los fixtures sintéticos, o el
   árbol real con la identidad del titular enmascarada?
4. **¿Incluye la operación por proyecto R** (el patrón `runAudit.R` de
   los repositorios de reporte) o se limita al CLI?
