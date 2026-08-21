# PLAN — Parseo de fechas independiente del locale y sub-variante Tipo A

Fecha: 2026-08-21. Estado: APROBADO ("prepara el fix") e IMPLEMENTADO
el mismo día. Validación ejecutada: suite completa en verde con goldens
byte-idénticos; 23 aserciones nuevas (test-parse-dates.R con locale
español forzado, test-parse-labA-variant.R con fixture sintético de la
sub-variante); re-corrida del proyecto del reporte: PARSE_ERROR 3→0
local, 405/405 PARSE_OK — pendiente la confirmación 79→0 del dueño en
Windows tras reinstalar. WRONG_JOBID (161) queda como hallazgo de
datos, fuera de este plan.
Origen: reporte de usuarios de un proyecto geoquímico privado nuevo
(~40 certificados no ingresados); diagnóstico completo con
reproducción en el repo privado del proyecto (`dev/bugfix/
DIAGNOSTICO-2026-08-21.md`). Este plan no repite identidades.

## Defecto 1 — fechas dependientes del locale (el mayor)

`.as.Date()` (`R/helpers.R:47`) normaliza abreviaturas de mes
españolas/portuguesas a INGLÉS y luego parsea con `%b` y órdenes
lubridate con nombre de mes — ambos dependientes del locale del
sistema. En Windows con locale español, "10-Apr-2025" no parsea
(`%b` espera "abr.") y el certificado completo muere con PARSE_ERROR.
Reproducido: 79 certificados fallan en la máquina del usuario; los
mismos archivos parsean en locale C.

Fix: normalizar TODO token de mes (inglés, español, portugués,
completo y abreviado) a su NÚMERO, y parsear únicamente formatos
numéricos. Eliminar `%b`/`%B` y las órdenes con nombre de mes de
todas las ramas. El resultado no depende del locale por construcción.

## Defecto 2 — sub-variante de cabecera Tipo A

Certificados del mismo laboratorio con: espacio antes de los dos
puntos en las claves (`LabjobNo :`), filas adicionales de cabecera
(`CLIENT :`, `PROJECT :`, `CERTIFICATE COMMENTS :`) y fechas
numéricas `dd/mm/YYYY`. El matcher de cabecera del formato A los
rechaza ("Unexpected INDEX header"). 3 certificados afectados en
toda plataforma.

Fix: normalizar la clave (recortar espacios antes de `:`) y aceptar
las filas de cabecera adicionales conocidas como metadatos opcionales
(se conservan en el índice si el esquema los contempla; jamás se
descartan en silencio).

## Validación (regla de primera aparición)

1. Fixture sintético nuevo por defecto: un certificado A con meses en
   inglés y test que fuerza `LC_TIME` a un locale español disponible
   (si el sistema no lo ofrece, el test se salta con nota) y exige el
   ISO correcto.
2. Fixture sintético de la sub-variante (espacio-dos-puntos + filas
   extra + fechas numéricas) con su golden.
3. Suite completa + goldens existentes byte-idénticos (los
   certificados que hoy parsean no cambian su producto).
4. Re-corrida sobre el proyecto privado del reporte: PARSE_ERROR
   79→0 (Windows) y 3→0 (toda plataforma) esperado; WRONG_JOBID queda
   como hallazgo de datos (no es objetivo de este plan).

## No incluido (deliberado)

- WRONG_JOBID con prefijo de solicitud: hallazgo de DATOS del
  proyecto, vuelve a los usuarios con la pregunta de mapeo — no se
  toca el motor por eso.

## Rulings pedidos

1. ¿Se aprueban ambos fixes con esa validación?
2. Tras verificar: ¿reinstalación inmediata o se acumula con el
   próximo cierre?
