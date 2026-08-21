# PLAN DEL MENSAJE — presentación dbAudit al cliente

Fecha: 2026-08-20, rev. 1 (rulings del dueño incorporados: auditoría
como capítulo propio ANTES de los instrumentos; cada instrumento con
sus tabsets/slides de auditoría; registro profesional para audiencia
experta — prohibido el tono instruccional o promocional).

Audiencia: expertos del cliente. Registro: técnico declarativo —
se enuncia qué hace el sistema, bajo qué condición y con qué
evidencia. Sin exhortaciones, sin promesas, sin definiciones de
diccionario.

## Estructura

1. El problema
2. La auditoría (el sistema)
3. Certificados geoquímicos
4. Piezómetros
5. Inclinómetros
6. Validación predictiva
7. Cierre

Cada capítulo: slide de título (.coverChapter) + índice propio
(.index), formato NGR.qmd.

## Capítulo 1 — El ingreso manual (plan por lámina, rev. 2026-08-20, aprobado "avansa")

Título «El ingreso manual», subtítulo «Modos de falla del dato cargado
y nombrado a mano». Función del capítulo: cada modo de falla mostrado
aquí es la motivación de un código del catálogo de eventos — lo que el
sistema corrige y reporta (WARNING), lo que reporta sin poder corregir
(ERROR), y lo sutil que motiva el capítulo final de forecast. Tres
láminas tabset, viñetas genéricas (sin nombres, sin sitios, sin
atribución):

1. «La celda» — tabs Separador / Ilegible / Unidades / Columnas,
   viñetas ASCII en typewriter con marcas `^^^`.
2. «El archivo» — tabs Identidad / Re-publicado / Copias / Fuera de
   recorrido, mismas viñetas typewriter.
3. «La planilla» — tabs Re-entrada / Conteos / Certificado, en
   facsímil Excel (ruling 2026-08-20: la representación de planilla
   usada en Casagrande es la manera correcta). Línea de cierre: estos
   defectos no se manifiestan en el ingreso — aguas abajo, números
   plausibles.

Ampliación propuesta (PENDIENTE de aprobación del dueño): (a) cada tab
cierra con su ancla de catálogo — evento, nivel, respuesta del sistema
(Separador→COMMA, Ilegible→UNREADABLE, Unidades→MIXED/UNITLESS,
Columnas→MALFORMED, Identidad→MISLABELED, Re-publicado→REDATED,
Copias→DUPLICATED survey, Fuera de recorrido→MISSING,
Re-entrada→DUPLICATED record, Conteos→MISCOUNTED, Certificado→log
geoquímico); (b) tab nuevo «Encabezado» en La planilla
(facsímil→INCOMPLETE); (c) lámina de cierre «Lo sutil»: MISCLOSURE
(número plausible, referencia mezclada) + DRY (condición, no defecto)
+ puente al forecast.

## Capítulo 2 — La auditoría (plan por lámina, rev. 2026-08-20, aprobado "avansa")

Se presenta ANTES de los instrumentos: define el marco que los
capítulos de dominio aplican. Tres láminas tabset:

1. «El registro» — tabs Resumen (tres niveles almacenados; filtro
   ERROR = lista de trabajo; trazabilidad a archivo y fila; alcance:
   registra y clasifica, no altera la física, no elimina, no decide) /
   El log (las líneas reales del engagement, typewriter) / La línea
   (anatomía campo a campo de una línea real) / La lista de trabajo
   (filtro ERROR real).
2. «El catálogo» — tabs Resumen / Catálogo (leyenda generada) / El
   archivo (`inst/events.csv` crudo, typewriter).
3. «Vega» — tabs Resumen (conteos computados de truth.csv, cuatro
   condiciones de la suite) / La verdad (tabla truth.csv) / El
   registro (log de la corrida Vega).

Puntos de contenido que el capítulo debe conservar:

1. El modelo de registro: tres niveles almacenados. INFO — condición
   del sitio o del registro; WARNING — defecto detectado y resuelto
   por el pipeline, con el valor original retenido; ERROR — defecto
   detectado y no resuelto, pendiente de decisión del responsable de
   los datos. El filtro por ERROR produce la lista de trabajo.
   Formato de línea: LEVEL | SITE | INSTRUMENT | DATE | EVENT |
   DETAIL, con trazabilidad a archivo y fila de origen.
2. El catálogo de eventos: generado de `inst/events.csv` — clave
   (evento, ámbito), nivel por defecto, descripción EN/ES e impacto.
   La leyenda de cualquier salida se genera del catálogo; no existe
   una segunda fuente.
3. El método de demostración de los capítulos siguientes — la tríada:
   fragmento de la planilla origen (facsímil), líneas de log
   emitidas, producto resultante en la base.
4. Validación del auditor: sitio sintético Vega con verdad conocida —
   defectos inyectados y casos de control legítimos que no deben
   emitir (conteos computados de truth.csv, nunca tipeados). Cuatro condiciones verificadas por la suite: cada
   inyección emite su evento y nivel; ningún caso de control emite;
   cada corrección reproduce el valor de la verdad; cada defecto no
   corregible permanece visible en los productos. Ningún evento del
   catálogo emite en datos de un cliente sin haber pasado por Vega.
5. Alcance declarado: el sistema registra y clasifica; no altera la
   física de la lectura, no elimina registros, no sustituye la
   decisión del responsable de los datos.

## Capítulo 3 — Certificados geoquímicos

- El pipeline: parseo de certificados de laboratorio (formatos A/B),
  validación estructural, ingreso a la base.
- Auditoría del dominio (tabsets, demo typewriter sobre los fixtures
  sintéticos del repositorio): PARSE_OK, DUPLICATE_VID,
  SAMPLEID_NOT_UNIQUE, CLIENT_MISSING_COLUMNS. Un certificado que no
  supera la validación excluye el job completo del ingreso; la causa
  queda registrada. No se ingresa un job parcial.
- Material: exclusivamente fixtures sintéticos (ruling R3, pendiente
  de confirmación).

## Capítulo 4 — Piezómetros

- El dato y su parseo: planillas Excel del cliente; Casagrande (PCG:
  profundidad, nivel, carga, variación por campaña) y cuerda vibrante
  (PCV: dígitos, frecuencia, temperatura, presión por canal y stage).
  Localización de campos por rótulos declarados, con las variantes de
  tipeo registradas; identidad del contenido cotejada contra la del
  archivo.
- Auditoría del dominio (tabsets, material Vega):
  - separador decimal corregido al ingreso, valor original retenido
    (VP-1);
  - celda ilegible: registro rechazado, hueco visible en la serie —
    sin relleno ni interpolación (VP-1);
  - pozo seco declarado en planilla: condición con bandera D,
    graficada como resultado (VP-3);
  - registros que la propia planilla no distingue (misma fecha, hora
    y stage): ambos retenidos, ERROR pendiente (VP-2); la identidad
    de duplicado es la que define la planilla del cliente;
  - unidad declarada por canal, consistente: constancia INFO, no
    defecto (VP-4).
- Resultados reales del dominio (ruling del dueño 2026-08-20: la
  auditoría real se muestra junto a la sintética): el log del
  engagement filtrado a piezómetros — los registros duplicados
  retenidos y toda otra línea vigente — con mecanismo neutral y
  trazabilidad a archivo y fila.
- Casos reales citados como patrón, sin identidad: la identidad de
  duplicados según la convención del cliente eliminó 21 falsos
  positivos de prácticas legítimas de campo; un evento del catálogo
  fue retirado cuando la planilla demostró que el supuesto defecto
  era una convención del cliente.

## Capítulo 5 — Inclinómetros

- El dato y su parseo: exportaciones CSV por campaña (survey);
  identidad, header de instalación y perfil por profundidad;
  desplazamientos calculados de las caras A/B.
- Auditoría del dominio (tabsets, material Vega):
  - identidad contenido-archivo: variante de formato normalizada con
    evidencia sistemática (WARNING); instrumento declarado
    inexistente, sin reparación (ERROR) (VI-1/VI-2);
  - campaña re-publicada con otra fecha, tabla de lecturas idéntica:
    ERROR con ambas fechas en el detalle; el mecanismo (re-exportación
    del equipo o copia manual) se determina caso a caso (VI-1);
  - mismo archivo bajo dos nombres: consolidado (WARNING) (VI-2);
  - header que declara N profundidades y entrega N−k: ERROR
    (VI-1); header incompleto: ERROR (VI-2);
  - censo fuente→base: archivo presente bajo la raíz y ausente del
    recorrido de parseo emite MISSING (ERROR).
- Resultados reales del dominio (mismo ruling): el log del engagement
  filtrado a inclinómetros — las campañas re-publicadas con otra
  fecha, los surveys consolidados, las identidades normalizadas, el
  archivo censado como no recorrido — con mecanismo neutral y
  trazabilidad a archivo y fila.

## Capítulo 6 — Validación predictiva (plan por lámina, rev. 2026-08-20)

Fuente única de cifras: `AR-S2L1X/dev/handoffs/DOC-forecast-para-slides.md`;
§7 del DOC gobierna lo que no se afirma. Registro declarativo estricto.
RULING DEFINITIVO (dueño, 2026-08-20, vía ssel): NINGÚN número medido
sobre el banco temporal anterior es citable — ni coberturas "reales",
ni MAE, ni tasas de detección, ni conteos de validación. Lo único
usable del lado temporal: la tabla espejo `data/db/PCG.forecast.csv`
como DATOS (bandas en plots con la cobertura NOMINAL de su columna
`coverage`). El estado temporal se declara como "implementado en el
motor; validación formal en curso". Los números espaciales de las
corridas auditadas vigentes sí son citables (fuente distinta).

CUERPO — título + índice + UNA lámina ("Bandas de confianza", tabset):
- Mensaje del capítulo: cada lectura ingresa acompañada de dos bandas
  de confianza independientes — del historial del propio pozo y de los
  vecinos del depósito en la misma campaña; la lectura fuera de banda
  queda señalada para revisión; la cobertura es empírica, medida y
  declarada; ningún resultado participa de los reportes mensuales.
- Tabs: Resumen (el mensaje + estado, viñetas declarativas) · Banda
  temporal (plot solo) · Banda espacial (plot solo) · Ejemplo (tabla
  CR7_PZ-1 sola). Sin prosa flotante bajo artefactos.

APÉNDICE (cap. 8) — título + índice + CUATRO láminas:
1. "Dos bandas por lectura": la construcción independiente por diseño;
   los forzantes compartidos del depósito justifican la vía espacial.
2. "Banda temporal — construcción": leave-present-out; ensamble
   ponderado 1/RMSE; cuantiles de residuos fuera de muestra por sitio
   y brecha; proyección a límites físicos; cobertura medida 80≈77 %,
   95=84–90 %.
3. "Banda espacial — construcción": predicción desde vecinos del
   mismo depósito en la misma campaña; mismo ensamble; residuos
   prospectivos; nominal 80 % por sitio; sin cruce de depósitos.
4. "Interpretación conjunta": las cuatro configuraciones (fuera de
   ambas / solo temporal / solo espacial / dentro de ambas) y su
   significado; la disposición de toda lectura señalada corresponde al
   revisor. Declarativo — no manual de uso.
Los borradores fuera de este plan (fcbody1/fcbody2 y variantes) no
forman parte del deck.

## Capítulo 7 — Cierre

- Operación por repositorio (lámina agregada por orden del dueño,
  2026-08-20): el motor es un paquete R instalado una vez, con el
  catálogo de eventos adentro; cada repositorio de proyecto lleva una
  corrida corta propia — monitoreo: `Rscript scripts/runAudit.R`
  (fuente → base + auditoría + log); geoquímica:
  `DBAudit(project.path = ...)` por dataset (certificados + contraste
  → proc/); el sitio sintético corre con la misma mecánica en la
  suite. Los consumidores (reporte, deck, dashboard) leen los
  productos; ninguno recalcula.
- El dato nuevo (lámina agregada por orden del dueño, 2026-08-20):
  flujo del archivo que llega mañana — se guarda en
  `data/source/<TIPO>/<Sitio>/` tal como llega, sin renombrar; una
  corrida regenera base+auditoría+log; reporte y dashboard leen los
  productos regenerados. Los pronósticos viven en tablas espejo
  `*.forecast`/`*.spatial` con las mismas claves — nunca mezclados
  con lo medido; el consumidor los une por clave.
- Dashboard en vivo (misma orden): ventana (iframe, idioma NGR) al
  dashboard Dash servido localmente — series PZ/INC filtrables y el
  panel de errores del log como lista de trabajo navegable.
- Trazabilidad: cada línea del log resuelve a archivo y fila.
- Reproducibilidad: una corrida regenera la base, el log y los
  productos.
- Validación permanente: la suite con Vega acompaña cada release.
- Síntesis de operación en tres columnas: automático (parseo,
  corrección documentada, normalización con evidencia, consolidación,
  censo, banderas, regeneración), supervisado (los ERROR: fecha real
  de una campaña re-publicada, recuperación de valores ilegibles,
  resolución de duplicados indistinguibles, disposición de archivos
  no recorridos, reposición de certificados), condición (INFO).

## Rulings

- RESUELTO (dueño, 2026-08-20): la presentación muestra la auditoría
  REAL y la SINTÉTICA — Vega demuestra los errores posibles con
  verdad conocida; el log real del engagement muestra lo encontrado,
  por dominio, dentro del capítulo de cada instrumento.
- Certificados: fixtures sintéticos únicamente (los certificados
  reales del repo pertenecen a otro cliente). Default vigente salvo
  orden contraria del dueño.
- Capítulo 6, antecedente: por defecto NO se cita la aplicación del
  motor ssel en otras memorias de cálculo; solo el estado del piloto.
  El dueño puede ordenar incluir una frase anonimizada.
- Capítulo 6, posición: capítulo propio (default), con la lámina de
  estado y el mecanismo en apéndice.
