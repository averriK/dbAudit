# HANDOFF (Fable) — Presentación de features de dbAudit para audiencia experta

Fecha: 2026-08-18. Repo de trabajo: `~/github/tools/dbAudit`.
Recursos en `~/Cloud/github/projects/el proyecto de monitoreo downstream` y
`~/github/libraries/reports` (NGR). Aplica el router
`~/github/agents/AGENTS.md` (QRT.md para renderizar — jamás quarto
crudo; TECHNICAL-WRITING para la prosa). Dirección, no autoridad.

## Objetivo

Un deck revealjs de PRESENTACIÓN EN VIVO de las capacidades de
dbAudit, para audiencia de EXPERTOS (ingenieros geotécnicos,
hidrogeólogos, QA de laboratorio). No es el deck de auditoría mensual
de un proyecto: es la demo del producto dbAudit.

## Contenido requerido

1. **Certificados de laboratorio (geoquímica)**: cómo dbAudit procesa
   certificados — el pipeline auditGeochem (R/parseLab.R,
   parseAssay.R, audit.R): formatos A/B de certificado, PARSE_OK,
   DUPLICATE_VID, SAMPLEID_NOT_UNIQUE, CLIENT_MISSING_COLUMNS, la
   exclusión de jobs por ERROR. CON EJEMPLOS ANIMADOS POR TYPEWRITER:
   el ruling vigente permite la animación NGR (showTypewriter /
   rotateTypewriter, en ~/github/libraries/reports — estudiar su API
   real; rotateTypewriter acepta texts=; terminalWidth solo 40/60/80)
   EXCLUSIVAMENTE para presentación en vivo — este es ese caso. Los
   ejemplos de certificado: usar fixtures/goldens propios del repo,
   JAMÁS datos reales de un cliente.
2. **Piezómetros**: el gate de ingreso (COMMA reparado con valor
   correcto, UNREADABLE rechazado con hueco visible), duplicados por
   identidad de la planilla, seco como condición (flag D), el censo
   de archivos (MISSING), hojas malformadas.
3. **Inclinómetros**: MISLABELED con normalización de variantes,
   REDATED por firma de contenido (con la explicación de mecanismo
   neutral), consolidación de duplicados, MISCOUNTED, INCOMPLETE.
4. **El catálogo de eventos**: la leyenda GENERADA de
   inst/events.csv (evento, nivel INFO/WARNING/ERROR, significado,
   impacto) — el modelo de tres niveles y el filtro por ERROR.
5. **Vega, el sitio de validación**: la joya de la demo — un sitio
   sintético con 15 corrupciones inyectadas y verdad conocida
   (inst/fixtures/Vega + truth.csv): mostrar el log que produce y
   cómo cada línea se traza a su planilla. Permite demo completa SIN
   exponer datos de ningún cliente.

## Reglas de la casa que la presentación debe respetar

- Todo lo mostrado COMPUTADO de fixtures/productos — cero capturas
  trucadas, cero logs tipeados a mano.
- Ventanas terminal (ámbar/negro) para logs; typewriter SOLO como
  animación de presentación en vivo; la versión estática debe existir
  como fallback (el trigger de showTypewriter solo tipea con slide
  'present').
- Prosa profesional; títulos frase nominal; dominio declarado; sin
  lenguaje wiki; leyenda generada, jamás tipeada (rulings en
  <proyecto>/dev/SoT/PLAN-logging.md — leer sus rulings v4/v5/v7 para
  no repetir los rechazos del dueño).
- Dónde vive: propuesta `dev/deck/` o `docs/` de este repo con render
  qrt — proponer al dueño y esperar su ok antes de fijar ubicación.

## Aceptación

El dueño revisa el render (lámina por lámina, celda por celda — su
estándar). Entregar el HTML con el comando de regeneración. La
animación typewriter debe verse funcionando EN VIVO en al menos las
láminas de certificados.
