# PLAN — Detección robusta de R e instalación asistida (prototipo)

Fecha: 2026-08-21. Estado: PROPUESTA para ruling del dueño.
Alcance de esta etapa: un PROTOTIPO DE DETECCIÓN, sin efectos, que se
corre en máquinas reales y se acepta con sus reportes ANTES de que
cualquier instalador adquiera la capacidad de instalar R.

## El problema

Hoy ambos instaladores detectan R por una sola vía: `Rscript` en el
PATH (`install.sh:121`, `install.ps1:290-291`). Si no está, abortan con
instrucciones. Si el instalador pasara a instalar R con ese detector,
un falso negativo produce una SEGUNDA instalación de R en la máquina.

La consecuencia no es cosmética: dos instalaciones de R tienen árboles
de biblioteca distintos. Los cinco paquetes se instalan en una, el
lanzador resuelve la otra, y el usuario entra en un ciclo de "falta el
paquete" que reinstalar no arregla.

## Por qué el falso negativo es probable, no teórico

- **Windows**: el instalador de CRAN NO agrega R al PATH por defecto.
  Una máquina con R perfectamente instalado da negativo hoy. Es el
  caso más común de la población objetivo.
- **macOS**: evidencia de la máquina de referencia — tres versiones en
  `/Library/Frameworks/R.framework/Versions/` (4.4-arm64, 4.5-arm64,
  4.6), `rig` presente, y el `Rscript` del PATH es un enlace a
  `Resources/bin` de la versión Current. Un PATH roto o un shell no
  interactivo bastan para el falso negativo, con tres instalaciones
  legítimas ya presentes.
- **Homebrew vs CRAN**: `brew install r` junto a la R de CRAN es el
  duplicado clásico de macOS, con dos árboles de biblioteca.
- **Linux**: paquete de distribución (`/usr/lib/R`) frente a build
  local (`/usr/local/lib/R`).

## El prototipo (lo único que esta etapa construye)

`dev/prototype/detectR.sh` y `dev/prototype/detectR.ps1`: SOLO
observan y reportan. No instalan, no modifican PATH, no escriben fuera
de su archivo de reporte. Cada uno enumera TODAS las fuentes y emite
un reporte legible y en JSON.

Fuentes a enumerar (todas, aunque una ya haya dado positivo — el valor
del prototipo es ver la máquina entera):

macOS/Linux
1. `Rscript` y `R` en PATH, con su ruta resuelta (`readlink -f`).
2. `/Library/Frameworks/R.framework/Versions/*/Resources/bin/Rscript`
   y a qué apunta `Current`.
3. Homebrew: `brew --prefix r` y `<prefix>/bin/Rscript`.
4. `rig list` si `rig` existe.
5. Rutas de distribución: `/usr/lib/R/bin/Rscript`,
   `/usr/local/lib/R/bin/Rscript`, `/opt/R/*/bin/Rscript`.
6. `R_HOME` del entorno, si está definida.

Windows
1. `Rscript` / `Rscript.exe` en PATH.
2. Registro: `HKLM\SOFTWARE\R-core\R\InstallPath` y sus subclaves por
   versión; ídem `HKCU`; ídem la vista de 32 bits.
3. Rutas convencionales: `C:\Program Files\R\R-*\bin\Rscript.exe` y
   `%LOCALAPPDATA%\Programs\R\R-*\bin\Rscript.exe`.
4. `rig list` si existe.
5. `R_HOME` del entorno.

Por cada candidato hallado, el prototipo registra: ruta, versión real
(ejecutando `--version` y parseándola, no infiriéndola del nombre de
carpeta), arquitectura, si está en PATH, y su `.libPaths()`. Dos
candidatos que resuelven al MISMO `R.home()` son la misma instalación
y se declaran como tal: el detector cuenta instalaciones, no rutas.

## La regla de decisión que el prototipo valida

Se prueba contra los reportes, no se asume:

1. Si alguna fuente encuentra R **>= 4.1.0**: NO se instala nada.
2. Si esa R no está en el PATH: el problema es de resolución, no de
   ausencia — el instalador fija la ruta resuelta (ver §"efecto en el
   lanzador"), y opcionalmente informa cómo agregarla al PATH. Jamás
   instala una segunda copia.
3. Si sólo hay R **< 4.1.0**: se informa la versión encontrada y su
   ruta, y se ofrece instalar una nueva DECLARANDO que convivirá con
   la existente. Nunca se reemplaza ni se desinstala nada.
4. Si NINGUNA fuente encuentra R: recién ahí se ofrece instalar.
5. Ante cualquier ambigüedad no resuelta por las reglas anteriores, el
   instalador se detiene y reporta lo que vio. Un detector que duda no
   instala.

## Efecto en el lanzador (hallazgo de diseño)

El lanzador resuelve `Rscript` por PATH en tiempo de ejecución
(`bin/dbaudit:32`, y el `.cmd` generado con `where Rscript`). Si una R
válida existe fuera del PATH, detectar bien no alcanza: el lanzador
falla igual. El prototipo debe informar esta decisión — registrar la
ruta resuelta de Rscript en el manifiesto y que el lanzador la use,
con el PATH como respaldo.

## Aceptación del prototipo

Se corre en, como mínimo: (a) la Mac de referencia (tres versiones +
rig + enlace en PATH); (b) el Windows del dueño; (c) al menos una
máquina de usuario con R instalado y FUERA del PATH — el caso que
motiva el plan. Para cada corrida, el reporte debe clasificar
correctamente cuántas instalaciones distintas hay, cuál usaría el
lanzador, y qué diría la regla de decisión. Los reportes se archivan
como evidencia. Sin los tres reportes correctos, la etapa de
instalación no empieza.

## Etapa siguiente (fuera de este plan, se planifica después)

Instalar R es un cambio a nivel de sistema y requiere elevación
(administrador en Windows, `sudo` en macOS): es autoridad propia,
distinta de instalar dbaudit, y el instalador debe pedirla de forma
explícita. La elección de mecanismo por plataforma (instalador de CRAN,
`rig`, gestor de paquetes de la distribución) se decide con los
reportes del prototipo a la vista, no antes.

## Rulings pedidos

1. ¿Se aprueba construir el prototipo de detección con ese alcance
   (observar y reportar, sin efectos)?
2. ¿La regla de decisión propuesta es la correcta, en particular
   "encontrada pero fuera del PATH nunca instala"?
3. ¿Se acepta el cambio de diseño del lanzador (fijar la ruta de
   Rscript resuelta en el manifiesto, con PATH como respaldo)?
4. ¿Qué máquinas de usuario están disponibles para correr el prototipo
   y quién las corre?
