# Seguimiento del upstream (Arc Launcher)

Lemonade Launcher es un fork de [Arc Launcher](https://github.com/meddouribadis/arclauncher). Este documento explica cómo está fijado el punto de partida, cómo vigilar novedades del proyecto original y cómo decidir, de forma trazable, qué se adopta y qué no.

## Baseline fijado

- **Tag upstream**: `1.0.6`
- **Commit**: `5b2176b9cc8d06c548e66ef72c2ca3221c9b1703`
- **Objeto del tag** (es un tag anotado, tiene su propio SHA distinto del commit): `d2a5774aec40e70c901205321a67043a8baa2ddd`
- **Fecha**: 2026-07-19
- **Remote**: `upstream` → `https://github.com/meddouribadis/arclauncher.git`

Este es el estado exacto de upstream del que partió el fork (`pubspec.yaml` local marca `version: 1.0.6+4115`, idéntico al de esta etiqueta). Para cualquier futura duda de "¿cuándo bifurcamos?", la referencia es siempre el **commit** `5b2176b9cc8d06c548e66ef72c2ca3221c9b1703`, no el objeto del tag (que es una referencia distinta a nivel de Git aunque apunte a ese commit).

## Cómo comprobar novedades en upstream

Antes de nada, traer las referencias del remote (esto es de solo lectura respecto al árbol de trabajo, no toca ningún fichero):

```bash
git fetch upstream --tags
```

### 1. Tags de release nuevos

```bash
git tag -l --sort=-creatordate | head -20
```

Muestra las etiquetas de versión existentes, ordenadas de más reciente a más antigua. Si aparece algo por encima de `1.0.6`, hay una release nueva que evaluar.

### 2. Commits desde el baseline

```bash
git log 1.0.6..upstream/main --oneline
git rev-list --count 1.0.6..upstream/main
```

El primer comando lista los commits que existen en `upstream/main` y no en nuestro baseline. El segundo da solo el recuento, útil para un vistazo rápido.

### 3. Diff de un fichero o directorio concreto

```bash
git diff 1.0.6..upstream/main -- ruta/al/fichero_o_directorio
```

Limita el diff a una parte del árbol en lugar de ver todos los cambios de golpe. Es el primer paso para decidir si algo interesa.

### 4. Inspeccionar un fichero de upstream sin tocar el árbol de trabajo

```bash
git show 1.0.6:ruta/al/fichero
git show upstream/main:ruta/al/fichero
```

Imprime el contenido de ese fichero tal como existe en ese commit/tag, sin hacer checkout ni modificar nada local. Sirve para leer un fichero que no existe en el fork (por ejemplo, uno de los "ficheros perdidos" de la tabla siguiente) sin necesidad de fusionar ni cambiar de rama.

El script `scripts/check-upstream.sh` automatiza los puntos 1-3 en una sola ejecución.

## Cómo adoptar un cambio puntual de upstream

Hay dos formas de traer **una sola** mejora sin arrastrar todo lo demás:

**Opción A — cherry-pick de un commit concreto**

```bash
git log 1.0.6..upstream/main -- ruta/afectada   # localizar el commit
git show <sha>                                   # revisar qué contiene
git cherry-pick <sha>                            # aplicarlo sobre nuestra rama
```

**Opción B — extraer el diff de un fichero y aplicarlo a mano**

```bash
git diff 1.0.6..upstream/main -- ruta/al/fichero > /tmp/cambio.patch
git apply --3way /tmp/cambio.patch
```

Útil cuando el commit upstream mezcla el cambio deseado con otros no deseados, o cuando el fichero ya ha divergido y el cherry-pick directo no aplica limpio.

**Compensación (trade-off)**

- **Cherry-pick / patch selectivo**: mantiene el historial limpio, solo entra lo que se ha evaluado y aprobado explícitamente. Requiere revisar y aplicar cada cambio a mano.
- **Merge completo de una rama upstream**: trae todo de una vez (rápido), pero también arrastra funcionalidades que este fork ha rechazado deliberadamente (ver sección siguiente). Un merge completo puede reintroducir código que ya se descartó y crear una regresión funcional silenciosa. No se recomienda salvo que se audite el conjunto entero de cambios antes de fusionar.

## Ficheros perdidos en la copia inicial

Estos ficheros existen en el tag `1.0.6` de upstream pero no llegaron a la copia local (verificado con diff contra el baseline):

| Fichero | Qué hace | Recomendación |
|---|---|---|
| `.fvmrc` | Fija la versión de Flutter (`3.41.9`) para quien use FVM como gestor de versiones. | **Descartar.** Este fork usa `mise` (ver `mise.toml`, que ya fija la misma versión `3.41.9`). Restaurarlo generaría dos fuentes de verdad contradictorias. Documentar la divergencia (mise vs FVM) en vez de restaurar el fichero. |
| `.metadata` | Metadatos internos de la herramienta Flutter (canal, revisión del SDK, plataformas del proyecto). Lo genera y mantiene el propio tooling de Flutter. | **Evaluar caso a caso.** No es crítico a mano; normalmente se regenera solo. Restaurar si algún comando de Flutter empieza a quejarse de su ausencia. |
| `.vscode/settings.json` | Configuración de VS Code del proyecto upstream (probablemente ajustes de formateo/análisis Dart). | **Pendiente.** Bajo riesgo, útil solo si se usa VS Code como editor. Revisar contenido antes de decidir. |
| `.github/FUNDING.yml` | Declara los enlaces de patrocinio/sponsorship de GitHub para el repositorio upstream. | **Descartar.** Apunta a las cuentas del autor original; no aplica a este fork. |
| `.github/workflows/release.yml` | Pipeline de CI que publica APKs firmadas en GitHub Releases al pushear un tag (252 líneas). | **Alto valor — estudiar en detalle.** Es directamente relevante porque este fork quiere un self-updater propio alimentado por GitHub Releases. Este workflow es la plantilla más cercana a ese objetivo: define el flavor `github`, el flag `--dart-define=ENABLE_SELF_UPDATER=true`, la firma del APK y el cálculo del build number desde `pubspec.yaml`. No copiar tal cual sin revisar los secretos/firma que asume. |
| `.github/workflows/virustotal_scan.yml` | Escanea el APK publicado con VirusTotal como parte del pipeline de release. | **Evaluar junto con `release.yml`.** Solo tiene sentido si se adopta el pipeline de release; si se hace, es una buena práctica de confianza para un self-updater que descarga binarios de terceros. |
| `.gitlab-ci.yml` | Pipeline de CI para GitLab. | **Descartar.** El proyecto vive en GitHub; este fichero es peso muerto sin GitLab de por medio. |

## Registro de evaluación

Aquí se anota cada verdicto sobre una funcionalidad o commit de upstream, para no volver a analizarlo dos veces.

| Versión/commit upstream | Funcionalidad | Fecha de evaluación | Decisión | Motivo |
|---|---|---|---|---|
| `dd1dd1f` (post-`1.0.6`) | Merge del tag `1.0.6` a `develop` | 2026-07-25 | Descartar | Solo housekeeping de ramas internas de upstream; no aporta código. |
| `aaafb3a` (post-`1.0.6`) | CI: fix del parseo de versionCode desde `pubspec.yaml` + workflow | 2026-07-25 | Descartar | Cambio de CI, no funcional para la app. Superado por el siguiente commit. |
| `b590cf7` (post-`1.0.6`) | CI: fix del parseo de versionCode desde `pubspec.yaml` + workflow (versión definitiva) | 2026-07-25 | Descartar | Ajuste de `.github/workflows/release.yml` (usa `steps.meta.outputs.build_number` en vez de `github.run_number`). Relevante solo si se adopta el pipeline de release completo; de momento no se ha restaurado ese workflow, así que no aplica. Revisar de nuevo si se decide adoptar `release.yml`. |
| _(pendiente)_ | | | Pendiente | |

## Decisiones ya tomadas

Estas funcionalidades de upstream han sido rechazadas deliberadamente en este fork. Si una futura release upstream toca alguna de estas áreas, se descarta directamente sin necesidad de nuevo análisis (y se anota igualmente en el registro de evaluación como "Descartar" con referencia a esta sección):

- **Integración con Home Assistant.**
- **Búsqueda/filtro de aplicaciones.**
- **Dock adaptativo basado en uso** (reordenación automática por frecuencia de uso).
- **Campo de API key de OpenWeatherMap.**
- **Widget de RAM/almacenamiento.**
- **Cambio automático de escenas.** Las escenas en este fork son de activación manual únicamente; cualquier comportamiento de upstream que active o cambie escenas automáticamente (por horario, sensor, etc.) queda fuera de alcance.
