# EVIDENCE — Paridad de instaladores mac/windows (2026-08-21)

Base: `/Users/averrik/github/tools/dbAudit`, rama `dev`, HEAD `7fe0d0d`.
Alcance: `install/install.sh` vs `install/install.ps1`, componente por
componente, más el eje de instalación de `docs/` (`install.md`, `macos.md`,
`windows.md`, `troubleshooting.md`; `installers.md` borrado). Constructor:
instalación y paridad, bajo `PLAN-documentacion.md` Paso 1 y la auditoría
`AUDITORIA-docs-2026-08-21.md`.

## 1. Tabla de paridad

Números de línea contra el estado PREVIO a las correcciones de este pase
(HEAD `7fe0d0d`).

| Componente | install.sh | install.ps1 | Veredicto |
|---|---|---|---|
| Validación del árbol fuente (pre-copia) | `DBAudit` + `R/setup.R` + `bin/dbaudit` (l.50) | los mismos tres archivos (l.116-122) | IGUAL |
| Guardia de plataforma | rechaza MINGW/MSYS/CYGWIN y redirige a `install.ps1` (l.54-61) | `#Requires -Version 5.1`; sin guardia inversa | DIVERGENCIA-PLATAFORMA |
| Destino de instalación | system-wide: `/usr/local/bin` + `/usr/local/libexec/dbAudit` (requiere sudo) | per-user: `%LOCALAPPDATA%\Programs\_runtime\dbAudit` + launchers en `%LOCALAPPDATA%\Programs` (sin admin) | DIVERGENCIA-PLATAFORMA |
| Detección de instalación previa | `libexec` o binario (l.74) | `LibexecDir` o cualquiera de los dos launchers (l.137) | IGUAL (equivalente) |
| Lectura del manifiesto para remover instalación previa (rutas custom) | claves `bin_path`, `libexec_dir` (l.79-90) | claves `bin_dir`, `libexec_dir` (l.145-151) | DIVERGENCIA-PLATAFORMA (claves distintas, consistentes con lo que cada uno escribe) |
| Prompt de reinstalación | `read -r -p "Existing dbaudit will be removed. Continue? [y/N]"`, sin flag para omitirlo (l.98) | mismo texto vía `Read-Host`, omisible con `-Force` (l.162-165) | DIVERGENCIA-FUNCIONAL — documentada, sin corrección en este pase (ver §3) |
| Chequeo de R presente | `command -v Rscript`, error con URLs CRAN mac/linux (l.122-132) | `Get-Command Rscript`/`Rscript.exe`, error con URL CRAN windows (l.244-263) | IGUAL (equivalente; textos por plataforma) |
| Versión mínima de R | exigía `>= 3.5` (l.21, 125, 134-145) | exigía `>= 3.5` (l.14, 253, 265-276) | DIVERGENCIA-BUG contra `DESCRIPTION` (`R (>= 4.1.0)`) — **corregido en ambos** |
| Orden de operaciones | prompt/remoción → chequeo R → copia → manifiesto → paquetes → symlink | prompt/remoción → copia → manifiesto → chequeo R → paquetes → launchers | DIVERGENCIA-MENOR — sin corrección: solo difiere el estado parcial ante fallo (ps1 copia runtime antes de verificar R); poscondición de éxito idéntica; reordenar excede "bug objetivo" |
| Qué se copia | `DBAudit`, `R/.`, `inst/.`, `bin/dbaudit` (l.165-170) | los mismos cuatro componentes (l.184-195) | IGUAL |
| Validación del layout instalado | tres archivos: `DBAudit`, `R/setup.R`, `bin/dbaudit` (l.193) | solo `R\setup.R` (l.197-201) | DIVERGENCIA-BUG (validación más débil) — **corregido: ps1 valida los mismos tres** |
| Manifiesto `.version` | `commit, branch, tag, install_date, bin_path, libexec_dir` (l.183-190) | núcleo común `commit, branch, tag, install_date, libexec_dir` + `bin_dir, cmd_path, shim_path` y `path_added` anexado (l.218-227, 399-405) | DIVERGENCIA-PLATAFORMA (núcleo común idéntico; claves de ruta propias de cada layout; `dbaudit --version` solo lee el núcleo común) |
| Git ausente al generar manifiesto | `commit=unknown` etc., o `warn` si falla el bloque (l.176-191) | `commit=unknown` etc., try/catch con `Warn` (l.203-238) | IGUAL (equivalente) |
| Lista de paquetes R (instalación real) | los 5: `data.table, stringr, lubridate, readxl, jsonlite` (l.209, 220) | los 5 (l.292) | IGUAL |
| Mensajes de paquetes | reporta los 5 (l.213) | el banner decía 3 (l.287) y el hint de instalación manual decía 3 (l.311) | DIVERGENCIA-BUG (mensajes desactualizados) — **corregido: ambos mensajes listan los 5** |
| Pre-chequeo de paquetes faltantes | calcula `MISSING_PKGS` y evita lanzar R si no falta nada (l.210-213) | siempre lanza el script R, que internamente detecta "nada que instalar" (l.290-322) | IGUAL (equivalente; solo difiere quién corta) |
| Identidad R bajo sudo | corre R como `$SUDO_USER` para no resolver la librería de root (l.199-207) | N/A (instalador per-user) | DIVERGENCIA-PLATAFORMA |
| Tipo de instalación de paquetes | default de CRAN (fuente o binario) | `type = "binary"` forzado + nota Rtools (l.297-314) | DIVERGENCIA-PLATAFORMA |
| `--skip-packages` / `-SkipPackages` | presente, "auto-installed on first run" (l.42-47, 252-255) | presente, mismo texto (l.38, 333-336) | IGUAL |
| Launcher | symlink `/usr/local/bin/dbaudit → libexec/bin/dbaudit` (wrapper bash del repo) (l.257-264) | genera `dbaudit.cmd` (CRLF/ASCII) + shim Git Bash (LF) + `chmod +x` vía Git Bash + alta en User PATH (l.340-396) | DIVERGENCIA-PLATAFORMA |
| Manifiesto extra de instalación | no escribe | `dbaudit.INSTALL_MANIFEST` en `%LOCALAPPDATA%\Programs` (l.407-421) | DIVERGENCIA-PLATAFORMA (soporte de desinstalación per-user) |
| Mensajes finales | `--check`, `--help`, URL de docs (l.266-277) | `--check`, `--help`, sin URL de docs (l.424-429) | DIVERGENCIA-BUG (menor) — **corregido: ps1 imprime la misma URL** |

## 2. Correcciones aplicadas (solo bug objetivo)

1. **Versión mínima de R 3.5 → 4.1.0 en ambos instaladores.** Autoridad:
   `DESCRIPTION` (`Depends: R (>= 4.1.0)`). `install.sh`: comentario de
   requisitos, texto de error de R ausente, comentario y condición del
   chequeo (`-lt 4 || (== 4 && minor < 1)`), texto de error de versión.
   `install.ps1`: los cuatro puntos equivalentes.
2. **install.sh: línea de error muerta eliminada.** En la remoción de la
   instalación previa había dos `error` consecutivos (l.113-114); `error()`
   hace `exit 1`, el segundo era código muerto duplicado de una edición
   vieja.
3. **install.ps1: banner y hint de paquetes con los 5 paquetes** (antes 3).
4. **install.ps1: validación del layout instalado extendida** a
   `DBAudit` + `R\setup.R` + `bin\dbaudit`, mismo criterio y mensaje que
   install.sh ("missing expected runtime files under …"). Solo agrega
   detección de fallo; no cambia ningún camino de éxito.
5. **install.ps1: URL de documentación en la salida final**, igual que
   install.sh (`https://averrik.github.io/dbAudit/docs/`).

No se tocó ningún comportamiento sano: sin reordenar operaciones, sin
flags nuevos, sin cambios de rutas ni de textos de prompt.

## 3. Divergencias documentadas, no corregidas

- **`-Force` sin equivalente `--force` en install.sh.** La reinstalación en
  mac/linux es siempre interactiva (`read -r -p`); bajo sudo no interactivo
  el prompt no puede responderse y la corrida se bloquea o aborta. El plan
  aprobado lo trata como hecho a documentar (así quedó en `docs/install.md`
  y `docs/troubleshooting.md`); agregar el flag es decisión del dueño, no
  bug objetivo. Queda como candidato de paridad para un pase futuro.
- **Orden de operaciones** (ps1 copia el runtime antes de verificar R): la
  poscondición de éxito es idéntica; solo difiere el estado parcial si R
  falta. Reordenar es cambio estructural fuera del alcance autorizado.

## 4. Cambios en docs/

- `docs/install.md` — reescrito: R >= 4.1.0, los 5 paquetes,
  `--skip-packages`/`-SkipPackages`, `-Force` (y su ausencia en sh), aviso
  del prompt interactivo de reinstalación (cuelgue bajo sudo no
  interactivo), `--check` y `--version` con salida real, manifiesto
  `.version` (claves comunes y por plataforma), sección de binario
  desactualizado (`--version` vs `git rev-parse --short HEAD`), y sección
  CLI vs paquete R (el instalador nunca corre `R CMD INSTALL`; los runners
  de proyecto usan el paquete, 4 exports en `NAMESPACE`). Front matter y
  permalink `/docs/install/` intactos.
- `docs/macos.md` — quirúrgico: lista de paquetes 3 → 5, layout con
  `inst/` y `.version`, R >= 4.1.0, sección Verify con `--check`, opción
  `--skip-packages`, nota del prompt de reinstalación. Permalink
  `/docs/macos/` intacto.
- `docs/windows.md` — conservado (coincide con install.ps1); agregados:
  requisito R >= 4.1.0, opciones `-SkipPackages`/`-Force`, y `--check` en
  Verify (antes solo `--help`, que prueba el launcher pero no R).
  Permalink `/docs/windows/` intacto.
- `docs/troubleshooting.md` — reescrito: `--check` como primer
  diagnóstico; rutas Windows CORRECTAS y coincidentes con `windows.md`
  (`%LOCALAPPDATA%\Programs\dbaudit.cmd`, shim `…\Programs\dbaudit`,
  runtime `…\Programs\_runtime\dbAudit`); sección nueva de prompt de
  reinstalación; sección nueva de binario desactualizado con salida real
  de `--version`; lista de 5 paquetes con el porqué de `readxl`/`jsonlite`;
  se conservan literales las tres secciones válidas (command not found
  mac, permisos/sudo, verificación de Rscript). Permalink
  `/docs/troubleshooting/` intacto.
- `docs/installers.md` — **borrado** (9 líneas que declaraban fuente de
  verdad a un documento externo inaccesible, desincronizado desde
  2026-01-17). Nota: `docs/_config.yml:22` lo lista en `exclude:`; esa
  línea queda apuntando a un archivo inexistente (inofensivo para Jekyll)
  y su limpieza corresponde al constructor del hub (Paso 6), dueño de
  `_config.yml`.

## 5. Comandos corridos (verificación)

Regla aplicada: todo comando documentado se corrió antes; los comandos del
CLI se verificaron con `Rscript /Users/averrik/github/tools/dbAudit/DBAudit`
(comportamiento post-instalación; el binario instalado en esta máquina es
viejo: `892a246`).

| Comando | Salida (línea representativa real) |
|---|---|
| `Rscript DBAudit --help` | `USAGE: dbaudit [geochemistry\|piezometer\|inclinometer] --project <DATA_ROOT> [OPTIONS]` … `--check (verify installation and dependencies)`, `--version` (EXIT=0) |
| `Rscript DBAudit --version` | `Build: unknown (version file not found)` (EXIT=0; el checkout no tiene `.version` — conducta documentada en troubleshooting) |
| `Rscript DBAudit --check` | `R version: 4.6.0` … los 5 paquetes `[✓] … (version …)` … `Status: ✓ All dependencies satisfied` (EXIT=0) |
| `/usr/local/bin/dbaudit --version` | `Build: 892a246 (dev)` / `Installed: 2026-08-19 16:48:12 UTC` (EXIT=0) |
| `/usr/local/bin/dbaudit --check` | `Installation: /usr/local/libexec/dbAudit` … `Status: ✓ All dependencies satisfied` (EXIT=0) — fuente del ejemplo de salida en docs |
| `git -C … rev-parse --short HEAD` | `7fe0d0d` — contraste real 892a246 ≠ 7fe0d0d: demostración viva de la sección "binario desactualizado" |
| `cat /usr/local/libexec/dbAudit/.version` | `commit=892a246`, `branch=dev`, `tag=`, `install_date=2026-08-19 16:48:12 UTC`, `bin_path=…`, `libexec_dir=…` — confirma las claves documentadas del manifiesto sh |
| `ls -l /usr/local/bin/dbaudit` | `… /usr/local/bin/dbaudit -> /usr/local/libexec/dbAudit/bin/dbaudit` — confirma el symlink documentado |
| `command -v Rscript` / `Rscript --version` | `/usr/local/bin/Rscript` / `Rscript (R) version 4.6.0 (2026-04-24)` |
| `bash -n install/install.sh` | sin salida, exit 0 — ANTES y DESPUÉS de las ediciones |
| `bash -n install/uninstall.sh` | sin salida, exit 0 |
| `R CMD INSTALL --help` | `Usage: R CMD INSTALL [options] pkgs` — confirma la superficie citada en "CLI vs R package" |
| `Rscript -e 'find.package("dbAudit")'` | `/Library/Frameworks/R.framework/Versions/4.6/Resources/library/dbAudit` — las dos superficies (CLI + paquete) coexisten en esta máquina |

**No ejecutados, y por qué** (comandos que docs/ documenta por necesidad):

- `sudo bash dbAudit/install/install.sh` y los dos uninstallers: mutarían
  `/usr/local` de esta máquina y reemplazarían el binario instalado
  (`892a246`), que es evidencia viva del caso "binario viejo"; reinstalar
  es decisión del dueño (Paso 0.5 del plan). Verificados con `bash -n` +
  lectura componente por componente (§1).
- `install.ps1`, `Get-Command …`: no ejecutables en macOS; no hay `pwsh`
  en esta máquina (`command -v pwsh` → vacío), así que ni siquiera hubo
  chequeo de parseo — la edición de ps1 se verificó por lectura. Los
  comandos PowerShell documentados son los ya vigentes en `windows.md`
  (auditoría: CONSERVAR, coincide con install.ps1).
- `R CMD INSTALL dbAudit` (mencionado en "CLI vs R package"): instalaría
  el paquete en la librería R del usuario, fuera de la lista de archivos
  autorizada; el mecanismo lo nombra la instrucción del maestro y la
  superficie del comando se verificó con `R CMD INSTALL --help`.

## 6. Confidencialidad

Sin nombres de cliente, sitios reales, IDs de instrumento reales, fechas o
valores de datos reales, ni repositorios privados: los únicos ejemplos son
rutas de instalación, salidas del CLI sobre esta máquina y el fixture
sintético implícito en `inst/` (Vega, solo nombrado como contenido del
runtime).

## ADENDA 2026-08-21 — BOM en el manifiesto de Windows

Hallazgo posterior a la auditoría: `install.ps1` escribía `.version`
con `[System.Text.Encoding]::UTF8` de .NET, que ANTEPONE BOM; la
primera línea quedaba `﻿commit=...` y el parser key=value de
`dbaudit --version` no encontraba `commit` → "Build: unknown" en toda
instalación Windows. Corregido en ambos lados: el ps1 escribe UTF-8
sin BOM (`UTF8Encoding($false)`) y suma `bin_path=` para paridad de
campos con install.sh; el lector de `DBAudit` descarta un BOM inicial
(defensa para instalaciones viejas). Verificado con manifiesto BOM
simulado: el lector resuelve `commit` correcto.
