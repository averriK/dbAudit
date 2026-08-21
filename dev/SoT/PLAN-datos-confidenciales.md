# PLAN — Clasificación de datos y saneamiento del repositorio público

Fecha: 2026-08-21. Estado: PROPUESTA para ruling del dueño. Este
documento no repite ninguna identidad sensible: señala archivo y línea.

## Los hechos (verificados hoy contra los remotos)

| Repositorio | Visibilidad | Contenido de datos |
|---|---|---|
| este repositorio | **PÚBLICO** (con Pages) | motor + fixtures SINTÉTICOS (Vega 81 archivos + truth; synthetic-A/B, los dos modelos de certificado) + `dev/` completo (18 archivos publicados) |
| repo privado del proyecto geoquimico (org corporativa) | PRIVADO | datos geoquímicos reales (14.206 archivos bajo `project/`) |
| repo privado del proyecto de monitoreo | PRIVADO | datos de monitoreo reales (LFS) |
| repo privado del dashboard (cuenta de un tercero) | PRIVADO (de un tercero) | snapshot de datos reales en la rama `dev` |

Lo sano: `project/` del repo público está gitignoreado (0 versionados),
los fixtures son sintéticos por diseño, ningún certificado ni planilla
real viaja en el repo público, y los mensajes de commit están limpios.

## Las filtraciones (en el repo PÚBLICO, HEAD e historia)

1. **`dev/handoffs/HANDOFF-dbaudit-consolidacion.md:64`** — cita un
   nombre de archivo del cliente que contiene el NOMBRE DEL CLIENTE.
   Publicado desde 2026-08-19 (`4b1c208`). La filtración seria.
2. **`dev/SoT/PLAN-event-taxonomy.md:229-303`** — nombres de sitios
   reales, IDs de instrumento y fechas/filas de campañas del
   engagement de monitoreo. Publicado desde 2026-08-16, con versiones
   previas en la historia (`47591b7`).
3. **`dev/handoffs/PLAN-mensaje-presentacion.md:188`** — un ID de pozo
   real (menor).
4. **`examples/scripts/geochem/runGeochem.PE-DBAudit.json` + README** —
   rutas y nombre del proyecto privado (menor: identifica engagement,
   no datos).
5. **`PE-DBAudit.Rproj`** en la raíz del repositorio del motor —
   legado que vincula el motor público con el proyecto privado.

## La regla de clasificación propuesta (permanente)

- **Repo público del motor**: código + fixtures sintéticos + docs.
  PROHIBIDO en cualquier archivo versionado, `dev/` incluido: nombres
  de cliente, nombres de sitios reales, IDs de instrumento reales,
  fechas/filas/valores de datos reales, nombres de archivo del
  cliente. Las historias del engagement (hallazgos, casos, rulings
  sobre datos reales) viven en el `dev/` del PROYECTO privado; el SoT
  público conserva solo la regla y los casos Vega.
- **Datos reales**: siempre en el repo privado del proyecto
  (`PE-DBAudit`, `AR-S2L1X`), jamás en el motor ni en ejemplos.
- **Guardia mecánica** (cierra la causa raíz, como verifyDocs para
  docs): un check versionado con la lista de patrones prohibidos que
  corre en la suite — si un patrón aparece en un archivo a commitear,
  la suite falla. La lista de patrones vive FUERA del repo público
  (archivo local no versionado que el check lee si existe), para no
  publicar los nombres en la propia guardia.

## Remediación propuesta, en orden

1. **HEAD** (una sesión, cambios chicos): neutralizar 1-3 (frases
   neutras: "el registro de equipos del cliente", "el pozo del
   ejemplo"; el detalle real del PLAN-event-taxonomy se MUDA a
   `AR-S2L1X/dev/` y acá queda el resumen con casos Vega), quitar el
   `.Rproj` legado, y generalizar el ejemplo `PE-DBAudit.json` a un
   ejemplo con rutas genéricas.
2. **Historia**: los tres archivos viven en la historia clonable de un
   repo público desde el 16-19/08. La remediación completa es
   reescritura (`git filter-repo` sobre los paths afectados) + push
   forzado + rotación de clones — DESTRUCTIVO y Tier 2: solo con tu
   autoridad explícita y coordinando con toda sesión viva que tenga
   checkout. Alternativa consciente: limpiar HEAD y aceptar el riesgo
   residual de la historia (exposición corta, repo de nicho).
3. **Guardia**: implementar el check de patrones y sumarlo a la suite.
4. **Dash**: la visibilidad del repo del tercero no está bajo tu
   control de organización; decisión aparte (fork a una org propia o
   aceptación consciente).

## Rulings pedidos

1. ¿Se aprueba la regla de clasificación permanente?
2. HEAD: ¿ejecuto la neutralización 1-3 + mudanza del detalle a
   AR-S2L1X?
3. Historia: ¿filter-repo (Tier 2, con tu go explícito y coordinación
   de clones) o aceptación del residual?
4. ¿Guardia mecánica en la suite?
5. ¿Dash: fork a organización propia o queda como está?
