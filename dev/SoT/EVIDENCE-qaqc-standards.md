# EVIDENCIA — Estándares y práctica para la taxonomía de eventos

Fecha: 2026-08-16. Ledger de evidencia (RESEARCH.md): fuente, acceso
REAL, hallazgos con cita, y lo que la fuente NO respalda. Las lecturas
las ejecutaron agentes de investigación con instrucción de acceso
honesto; los archivos de estudio completos son efímeros — este ledger
es el registro durable.

## Fuentes de dominio QA/QC (aprobadas por el usuario)

### USGS — GWSI/NWIS (niveles de agua subterránea)
Acceso: texto completo de OFR 2005-1251 Secc. 2-3 (manual GWSI 4.4),
memos técnicos OGW 2015.01/2017.02/2017.04, TM 1-A1 (GWPD 1-2 con
formulario 9-1904-A), esquemas del API moderno y definiciones de
calificadores extraídas de respuestas WaterML vivas. FALLÓ el acceso a
las páginas legacy de help (404) — vocabularios verificados por el
manual.
Hallazgos clave:
- Dimensiones ORTOGONALES, no lista plana: status/causa al momento de
  la medición (lev_status_cd: P bombeado, C hielo, D seco, O
  obstrucción...; §3.14), método con confianza (lev_meth_cd: V cinta
  calibrada vs E estimado vs R reportado vs U desconocido; §3.15),
  clase de precisión (lev_acy_cd 0/1/2/9; §3.17), procedencia con
  ordenamiento de confiabilidad (lev_src_cd; "memoria menos confiable
  que log del perforista"; §3.18), estado de revisión por registro
  (S in-review / R aprobado / Q rechazado / T histórico; OGW 2015.01
  p.2), y alcance de publicación (lev_web_cd).
- POZO SECO es un STATUS (D), y con status D/O/W NO se puede cargar
  valor de nivel (§3.14) — el seco no es un número.
- Continuo/diario: calificadores P provisional / A aprobado / e
  estimado adjuntos al VALOR como array.
NO respalda: una lista única de "eventos de error"; severidades tipo
syslog; naming UPPER_SNAKE de hechos.

### EPA — CLP National Functional Guidelines (nov 2020, inorg+org)
Acceso: texto completo de ambos PDFs oficiales.
Hallazgos clave:
- Calificadores de UNA LETRA con tabla de definiciones (Gral. Tabla 1
  p.6): U no detectado, J estimado, J+/J- sesgo, UJ, R "data are
  unusable... rejected"; orgánico agrega NJ/C/X (confianza de
  identificación).
- TRES DISPOSICIONES explícitas: sin calificación (usable), estimado-
  pero-usable (J...), rechazado-inusable (R). La CORRECCIÓN es
  disposición del laboratorio AGUAS ARRIBA de la validación (paquete de
  reconciliación), no un calificador del validador.
- La CAUSA vive en la estructura del documento (Parte B por método ×
  elemento QC con esqueleto Review/Objective/Criteria/Evaluation/
  Action), no en el código; cada Action termina en una TABLA DE
  DECISIÓN (violación × tipo de resultado → calificador) con umbrales
  moderado→estimado / extremo→rechazado ("Expanded Acceptance Limit").
- Precedencia: ante calificadores en competencia gana el más protector.
- Trazabilidad documental: Data Review Narrative con identificadores,
  métodos, extensión del problema, calificadores y fuente de criterios.
NO respalda: flags de causa en el código; severidades WARNING/ERROR.

### WMO — Guía de Prácticas Hidrológicas No. 168 Vol. I, cap. 9
Acceso: texto completo del capítulo 9 (y 10.2.3.4).
Hallazgos clave:
- Flags de UNA LETRA en dos grupos (§9.3.5): STATUS/confiabilidad del
  valor (E estimado, U incierto, G/L censurado en límite, V fuera de
  rango verificado) y CONDICIÓN de fondo (I hielo, S nieve, D estación
  sumergida...); listas EXPLÍCITAMENTE ejemplares ("typically"/"may
  be"); §9.3.2(c) recomienda adoptar sistemas existentes.
- ESTADO por lote/registro separado de los flags (§9.5.9): working /
  in-review / approved (cita el ADAPS del USGS).
- Disposiciones (§9.5.6, 9.7.2, 9.8.1, 10.2.3.4): corregido (flaggeado
  con justificación documentada), estimado/rellenado (flaggeado o
  archivo aparte; rellenar con dato sintético por correlación NO es
  permisible en el archivo), sospechoso-RETENIDO (los valores que
  fallan checks "should generally still be stored... but flagged as
  suspect"), y el hidrólogo decide aceptar/rechazar/corregir — nunca
  auto-rechazo.
- Checks automáticos clasificados: absolutos / relativos / fisico-
  estadísticos (§9.8.2); el output debe mostrar LA RAZÓN de cada flag.
- Precisión como incertidumbre estadística al 95% (§9.10, GUM).
NO respalda: tabla de códigos obligatoria; severidades; naming de
eventos.

### Dunnicliff — Geotechnical Instrumentation (cap. 18 + cap. 7)
Acceso: secciones dirigidas/extractos, NO texto continuo completo.
Hallazgos clave:
- NO define vocabulario de flags; su clasificación es POR CAUSA de
  error de medición (cap. 7): gruesos, sistemáticos, de conformancia,
  ambientales, observacionales.
- QC por FASE de proceso (colección→procesamiento→interpretación→
  reporte) con responsabilidades por rol (Tablas 18.1-18.2) y
  procedimientos escritos previos al trabajo de campo.
- "Datos cuestionables pueden ser reales y portar un mensaje
  importante" (p.384) — evaluar hipótesis antes de rechazar; sustenta
  detección-sin-exclusión.
- Trazabilidad por registros: hoja de campo con fecha/hora/observador/
  equipo/lecturas/remarks/checks (18.1.4), hoja de cálculo por
  instrumento, registros de instalación como mecanismo de reach-back;
  el check-sum del inclinómetro como validación integrada (§12.8.9).
- Reporte interino periódico con "comentario breve señalando todos los
  cambios significativos desde el reporte anterior" (p.384) — el "qué
  hay de nuevo" es contenido de REPORTE, no acumulación de logs.

## Fuentes IT (leídas antes del reencuadre; peso marginal)

- RFC 5424 (texto completo): NO define taxonomía (MSGID "sin
  semántica"); severidades "no normativas" y "muy subjetivas"; sin
  noción reparado/irrecuperable. Aporta: registro estructurado.
- NIST SP 800-92 2006 (texto completo; Rev.1 2023 solo metadata): NO
  define naming; "no hay estándares de logging" para la mayoría de
  fuentes; la selección de eventos es política organizacional.
- OWASP Logging + Vocabulary (texto completo): el Vocabulary sí
  prescribe naming `prefijo_accion[:params]` para eventos de SEGURIDAD;
  ninguno define semántica de severidades.
- MHRA GXP Data Integrity 2018 (texto completo): audit trail = "who,
  what, when and why" sin oscurecer el original (§6.13); revisión por
  EXCEPTION REPORTING (herramienta validada que identifica datos
  anormales predeterminados); atribuibilidad individual (§6.16); ALCOA
  textual (§6.1). Directamente pertinente a dbAudit como auditoría.
- pointblank / Great Expectations (docs): checks nombrados por
  sujeto+condición; severidad como superación de UMBRAL (warn/stop/
  notify) sobre unidades falladas; filas fallidas re-localizables por
  clave; identidad de checks por hash.

## Convergencia estructural (síntesis)

1. DIMENSIONES ORTOGONALES en el registro, no lista plana: causa /
   método-confianza / precisión / disposición / estado de revisión.
2. Flags de UNA LETRA sobre el VALOR + catálogo definido en tabla; la
   causa detallada vive en estructura aparte (EPA) o en flags de
   condición (USGS/WMO).
3. DISPOSICIÓN con vocabulario convergente: usable sin calificar /
   corregido (flaggeado+justificado) / estimado-usable / sospechoso-
   retenido / rechazado-inusable. La filosofía WARNING=reparado del
   usuario ES una vista de la disposición — legítima y ahora fundada.
4. ESTADO DE REVISIÓN separado (in-review/aprobado/rechazado) — el
   futuro nivel III de dbAudit ya tiene molde (USGS S/R/Q).
5. Nunca auto-rechazo silencioso: sospechoso se retiene flaggeado
   (WMO), lo cuestionable puede ser real (Dunnicliff) — la política
   detección-solo de dbAudit está respaldada por ambas.
6. Las listas son adaptables (WMO: adoptar sistemas existentes; EPA:
   calificadores adicionales permitidos con explicación) — dbAudit
   puede definir su catálogo propio DECLARADO, citando estos moldes.
