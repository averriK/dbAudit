# HANDOFF — Toma de control de dbAudit

Fecha: 2026-08-21. Escrito por la sesión maestra que trabajó el motor
todo el día. Autocontenido: leelo entero antes de tocar nada. Aplicá el
router `~/github/agents/AGENTS.md`; para tocar código R, `STYLE.md`,
`PRACTICE.md` y `R.md`.

Repositorio: `~/github/tools/dbAudit`. Ramas: `dev` (trabajo) y `main`
(publicada; GitHub Pages sirve `main /docs`). El dueño instala y prueba
desde `main`.

## Regla número uno de este repositorio

**El dueño opera por CLI en Windows; vos verificás en macOS.** Casi todo
lo que falló hoy era invisible en macOS y fatal en Windows. Antes de
declarar algo corregido, preguntate si tu verificación toca la
diferencia (separadores, mayúsculas, caracteres reservados, paquete R
ausente, archivos de solo lectura). Si no la toca, no está verificado.

## Estado al momento de la transferencia

- `dev` = `d862435`; `main` = `b4f1926` (la auditoría de arquitectura
  está en dev y aún no publicada: mergeala cuando el dueño lo pida).
- Suite completa en verde. Guard de documentación en verde.
- Versión publicada: **0.1.0**.
- El CLI tiene tres subcomandos: `geochemistry`, `piezometer`,
  `inclinometer`. La invocación sin subcomando conserva el contrato
  geoquímico histórico.

## Lo que se hizo hoy (para no re-derivar)

Corregidos y publicados, todos de la misma familia —código que trata
una ruta como texto con separador `/`, invisible en POSIX:

1. La raíz usada como expresión regular: el sitio terminaba siendo la
   ruta completa (`PLAN-site-from-path.md`).
2. `SourcePath` guardado absoluto en vez de relativo.
3. La rama de escape que devolvía la ruta absoluta — reintroducida por
   mi propio arreglo y detectada por la caza.
4. El identificador de pozo sin sanear para Windows (se vuelve nombre
   de directorio).
5. El censo restando un prefijo normalizado.
6. Manifiesto y catálogo pedidos al paquete R que el instalador nunca
   instala; ahora un único `.dbauditResource`.
7. Log de solo lectura: mataba la auditoría; ahora degrada y avisa
   (`PLAN-log-reintentos.md`).
8. Detector de formato fuera de todo handler: un certificado ilegible
   abortaba la campaña entera.
9. Instalador de paquetes sin biblioteca fijada.
10. Instalador de Windows: manifiesto con BOM, gate de versión de R que
    mataba la instalación en R 4.1.x, launcher ASCII con rutas
    acentuadas, identidad de build sin git
    (`EVIDENCE-instaladores-paridad.md`).
11. Parser: fechas independientes del locale y sub-variante de cabecera
    tipo A (`PLAN-parse-locale-tipoA.md`).

## LO PRIMERO QUE TENÉS QUE LEER

`dev/handoffs/AUDITORIA-arquitectura-2026-08-21.md`. El dueño auditó el
código y tiene razón: **hay parches**. Ese documento los enumera, los
míos incluidos, con archivo y línea. Sus cinco rulings gobiernan el
trabajo que sigue. No empieces a refactorizar sin ellos.

Resumen del diagnóstico: tres formas distintas de declarar dónde está
la entrada (y yo agregué una cuarta, sondeo por convención);
inclinómetros no existe como dominio propio —usa los defaults y el
manifiesto de piezómetros—; los IDs están cableados en ocho lugares;
los dos parsers de piezómetro son código paralelo divergente; `raw/`
significa entrada en un dominio y producto en el otro. La salida
propuesta es un **registro de dominios** del que todo se derive.

## Planes abiertos, por prioridad

| Plan (`dev/SoT/`) | Estado |
|---|---|
| `AUDITORIA-arquitectura-…` (handoffs) | 5 rulings pendientes — bloquea el refactor |
| `PLAN-log-unificado.md` | 3 rulings — un log por dominio, formato común |
| `PLAN-deteccion-r.md` | 4 rulings — detectar R sin duplicar instalaciones |
| `PLAN-ejemplos-instalados.md` | 3 rulings — `dbaudit example` |
| `PLAN-datos-confidenciales.md` | historia del repo público: filter-repo o residual |
| `PLAN-documentacion.md` (handoffs) | ejecutado en su mayor parte; quedan pasos 7-8 |
| `HANDOFF-sesion-dbaudit.md` | el objetivo del taller pkgdown, sin empezar |

## Menores confirmados y sin corregir

- `piezometerParse.R:221` — `sort(list.files())` ordena por locale y ese
  orden llega al orden de filas de los productos.
- `piezometerAudit.R:95-138` — los lectores de rechazos no verifican
  frescura del sumidero.
- `auditPiezometer.R:72-74`, `auditInclinometer.R:63`,
  `piezometerBuild.R:349-351` — retornos de `unlink`/`file.remove`
  descartados: un borrado fallido pasa inadvertido.

## Cómo verificar cualquier cosa que toques

    Rscript -e 'testthat::test_local()'        # suite, con Vega
    Rscript inst/scripts/verifyDocs.R          # guard de docs y anti-fuga

Vega (`inst/fixtures/Vega`) es la suite de aceptación con verdad
conocida: ningún evento nuevo emite en producción sin nacer ahí. Para
probar los tres dominios sobre una raíz:

    mkdir -p /tmp/t/data/GEO/lab /tmp/t/data/GEO/assay
    cp tests/testthat/fixtures/synthetic-A/raw/* /tmp/t/data/GEO/lab/
    cp tests/testthat/fixtures/synthetic-A/assay/* /tmp/t/data/GEO/assay/
    for d in PCG PCV INC; do cp -R inst/fixtures/Vega/source/$d /tmp/t/data/$d; done
    for s in geochemistry piezometer inclinometer; do Rscript DBAudit $s --project /tmp/t; done

## Reglas de la casa que costaron caras

1. **Cambio de motor = plan en `dev/SoT` con ruling del dueño ANTES.**
   Implementar sin plan fue rechazado y revertido una vez hoy.
2. **Nunca inferir sin datos.** Diagnosticar la causa de una falla del
   usuario sin ver su salida fue rechazado explícitamente.
3. **Comando no corrido = comando no documentado.**
4. **Confidencialidad**: el repositorio es PÚBLICO. Cero nombres de
   cliente, sitios reales, IDs reales o repos privados. El guard
   anti-fuga corre en la suite con una lista local no versionada.
5. **Nunca pushear con la suite en rojo.** Pasó una vez hoy; el dueño no
   lo vio, lo detecté y lo corregí, pero no debe repetirse.
6. Sin atribución de IA en los commits.

## Datos de prueba

- `inst/fixtures/Vega` — sitio virtual de monitoreo con `truth.csv`.
- `tests/testthat/fixtures/synthetic-A|B` — los dos modelos de
  certificado.
- Datos reales del dueño: repo PRIVADO `PE-DBAudit`, proyectos
  `BV`, `QV`, `Yumpag` (geoquímica) y `Catalina`, `Vega` (monitoreo),
  cada uno con raíz `project/<Nombre>/data`. Correr ahí requiere
  autorización explícita del dueño en tu sesión.
