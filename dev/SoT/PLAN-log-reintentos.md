# PLAN — Escritura de log resistente en sistemas de archivos compartidos

Fecha: 2026-08-21. Estado: APROBADO ("1 implementa") e IMPLEMENTADO.
Ruling 1 resuelto: reintento con degradación declarada, en ambos
loggers. Validación ejecutada: suite completa en verde con goldens
byte-idénticos; tests nuevos en tests/testthat/test-log-resilience.R
(el escritor cuenta y sigue; un certificado ingresa aunque su línea de
log no pueda escribirse; el logger de monitoreo sobrevive igual).
Ruling 2 (documentar la recomendación de disco local): abierto.

## Hecho observado (dos corridas, evidencia en disco)

`.log()` (`R/helpers.R`) abre el archivo de log para APPEND en CADA
evento: una corrida geoquímica de 340 certificados hace ~700 aperturas.
Sobre un directorio compartido (Parallels, y por el mismo mecanismo
cualquier unidad de red o carpeta sincronizada), la apertura falla de
forma intermitente y ABORTA la corrida completa:

- corrida 10:29 — 94 eventos escritos, luego "Permission denied ...
  Failed to open existing file for writing";
- corrida 10:38 — 327 eventos escritos (164 FILE_START, 163 PARSE_OK),
  mismo corte.

No es un problema de permisos: cientos de escrituras previas tienen
éxito con el mismo usuario sobre el mismo archivo. Es una violación de
compartición transitoria del sistema de archivos remoto.

## Defecto

Un fallo transitorio de infraestructura de registro destruye trabajo de
parseo ya realizado. El log es instrumentación: su indisponibilidad
momentánea no debe terminar una auditoría.

## Fix propuesto

`.log()` reintenta la escritura con espera breve (p. ej. 5 intentos,
50-100 ms) y, si agota los reintentos, emite un aviso por consola y
CONTINÚA la corrida en vez de abortar — con una marca al cierre que
declare cuántos eventos no pudieron registrarse (un log incompleto se
declara, nunca se finge completo). Mismo tratamiento en el logger de
monitoreo (`.logEvent`), que tiene el mismo patrón de apertura.

Alternativa considerada y descartada: mantener el archivo abierto toda
la corrida — cambia la semántica de crash-safety (hoy cada evento está
en disco al emitirse) y complica la reinicialización por corrida.

## Validación

Test con un directorio de solo lectura simulando el fallo de apertura:
la corrida completa igual, el producto es correcto, y el cierre declara
los eventos perdidos. Suite completa + goldens byte-idénticos.

## Rulings pedidos

1. ¿Se aprueba el reintento con degradación declarada?
2. ¿Se documenta además la recomendación de correr sobre disco local
   cuando la raíz de datos vive en una unidad compartida?
