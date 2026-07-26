# PRD — Lemonade Launcher

**Versión:** 2.0 · **Fecha:** 25/07/2026
**Cambio respecto a la v1:** el PRD original asumía una base en Kotlin + Jetpack Compose for TV. Tras analizar el código real de Arc Launcher se comprobó que la base es **Flutter/Dart**. Este documento reescribe el stack, elimina lo que ya está implementado en la base y añade lo que la base aporta y no estaba previsto.

---

## 1. Contexto del proyecto

Launcher personalizado para Android TV, optimizado para **Xiaomi TV Box S de 3.ª generación (Google TV)**. Objetivo: diseño ultra minimalista, premium y fluido, inspirado en la estética de macOS e iOS.

Base de código: fork del proyecto open source **Arc Launcher** (que desciende de LTvLauncher y de FLauncher). El launcher nativo de Google TV se deshabilita por ADB, por lo que Lemonade Launcher es el entorno absoluto del sistema.

## 2. Stack técnico

| Aspecto | Realidad del proyecto |
| --- | --- |
| Lenguaje | **Dart** (71 ficheros en `lib/`) |
| Framework UI | **Flutter** (Material 3, `useMaterial3: true`) — *no* Jetpack Compose |
| Código nativo | **Java**, en `android/app/src/main/java/com/leanbitlab/ltvL/` |
| Navegación D-Pad | `Focus` / `FocusNode` + política propia en `lib/custom_traversal_policy.dart` |
| Persistencia | `shared_preferences` (ajustes) + **Drift/SQLite** (apps y categorías) |
| Estado | `provider` (`ChangeNotifier` + `Selector`) |
| Idioma | **Español de España por defecto**; respeta el idioma del sistema si está admitido |
| Rendimiento | Objetivo 60 fps y bajo consumo de RAM. Impeller desactivado a propósito en el manifest (el backend GLES rinde peor en GPU de gama baja) |

> Equivalencias respecto a la v1 del PRD: donde decía `MainScreen` → `lib/flauncher.dart`; donde decía `Modifier.onFocusChanged` → `Focus(onFocusChange:)`; donde decía `androidx.tv.material3` → widgets de Flutter Material 3.

## 3. Arquitectura de la interfaz

### A. Barra superior — `lib/widgets/focus_aware_app_bar.dart`

**Decisión:** se mantiene la disposición actual de la base (no se reordena al orden literal de la v1) y se encapsulan los componentes en tarjetas con efecto cristal.

| Posición | Elemento | Estado |
| --- | --- | --- |
| Izquierda | Ajustes del launcher | ✅ implementado |
| Izquierda | Indicador de red (Wi-Fi/Ethernet), atajo a ajustes de red | ✅ implementado |
| Izquierda | Consumo diario de datos | ✅ implementado |
| Derecha | **Clima** — temperatura actual + icono | ⬜ **pendiente** |
| Derecha | Fecha y hora (formato configurable) | ✅ implementado |

Requisitos del bloque de clima:
1. Proveedor: **Open-Meteo** (ver sección 6).
2. Interruptor en Ajustes para mostrar u ocultar el clima. Por defecto **desactivado**.
3. Selección de ubicación por búsqueda de ciudad; sin geolocalización por GPS ni por IP.
4. Fallo silencioso: si no hay red o la petición falla, el widget desaparece sin mostrar error ni bloquear la barra.
5. Estética: tarjeta con cristal esmerilado, coherente con el dock.

**Eliminado de la v1:** el widget de RAM/almacenamiento. Un porcentaje de RAM actualizándose contradice el objetivo de minimalismo, y obligaría a añadir un `MethodChannel` nativo nuevo para un valor sobre el que el usuario no va a actuar.

### B. Lienzo central (fondo de pantalla)

✅ **Ya implementado.** `lib/providers/wallpaper_service.dart` + `lib/flauncher.dart`. Soporta imagen local, vídeo, degradados, negro puro para OLED y conmutación día/noche. El centro de la pantalla queda libre mediante un sliver espaciador en `lib/flauncher.dart`.

### C. Dock inferior

✅ **Ya implementado.** Método `_dock()` en `lib/flauncher.dart`: fila única alimentada por la categoría `Favorites`, con cristal esmerilado (`CachedBlurBackdrop`), borde de 1,5 dp blanco al 15 %, radio 24 y sombra opcional. Los nombres de las apps están ocultos por defecto (`showAppNamesBelowIcons`).

⬜ **Pendiente:** forma **squircle** (superelipse iOS) para los iconos. Hoy son `BorderRadius.circular(12)` en `lib/widgets/app_card.dart`. Requiere un `CustomClipper` propio.

## 4. Experiencia de usuario y foco (D-Pad)

| Requisito | Estado |
| --- | --- |
| Borde fino translúcido con resplandor sobre el elemento enfocado | ✅ doble borde, ajustable con `showFocusBorders` |
| Arriba desde el dock va a la barra superior | ✅ `MoveFocusToSettingsIntent` |
| Abajo desde la barra vuelve a la última app enfocada | ✅ `custom_traversal_policy.dart` |
| Realimentación sonora al navegar | ✅ `SoundFeedbackDirectionalFocusAction` |
| Escalado 1,08× al enfocar, con físicas de muelle | ⬜ **pendiente de revisar** — existe `appHighlightAnimationEnabled`; hay que comprobar la curva y el factor reales |

**Prohibido:** transiciones lineales. Usar muelle o `Curves.fastOutSlowIn`.

## 5. Panel de ajustes interno

Ya existen 23 páginas en `lib/widgets/settings/`, incluidas selección de fondo, gestión de categorías y aplicaciones, colores de acento y formatos de fecha/hora.

⬜ **Pendiente:** página de clima — interruptor de visibilidad y buscador de ciudad.
❌ **Eliminado de la v1:** el campo para la API key de OpenWeatherMap. Open-Meteo no necesita clave, así que este requisito desaparece por completo.

## 6. Proveedor de clima: Open-Meteo

Se descarta OpenWeatherMap. Motivo: obliga a registrarse, a gestionar una clave y a exponer un campo de texto en un launcher de TV donde escribir es incómodo; además su plan gratuito ha ido moviéndose hacia el registro de tarjeta.

**Open-Meteo** no requiere clave ni registro. Verificado contra la API real:

```
GET https://api.open-meteo.com/v1/forecast
      ?latitude=40.4168&longitude=-3.7038
      &current=temperature_2m,weather_code&timezone=auto
→ {"current":{"temperature_2m":27.9,"weather_code":3}, "timezone":"Europe/Madrid"}
```

Geocodificación para el buscador de ciudad, también sin clave y con resultados en español:

```
GET https://geocoding-api.open-meteo.com/v1/search?name=Sevilla&count=5&language=es
→ {"results":[{"name":"Sevilla","latitude":37.38283,"longitude":-5.97317,"country":"España",...}]}
```

Notas de implementación:
- El `weather_code` sigue el estándar **WMO**; hay que mapearlo a iconos propios.
- Gratuito para uso no comercial hasta ~10.000 peticiones diarias. Con un refresco cada 15–30 minutos sobra de largo.
- La dependencia `http` ya está en `pubspec.yaml`; no hace falta añadir paquetes.
- Cachear la última lectura en `shared_preferences` para no mostrar el hueco vacío al arrancar.

## 7. Aportaciones de la base no previstas en la v1

- **Sección «Continuar viendo»** — Fila superior con el contenido a medias de las apps de streaming. Se alimenta del proveedor `TvContract.WatchNextPrograms` de Android TV, no de una API externa: cada aplicación (Netflix, Prime Video, Disney+…) publica ahí sus programas empezados, y el launcher los lee con el permiso `READ_TV_LISTINGS`. Implementado en `lib/providers/watch_next_service.dart` + `MainActivity.java`. Desactivado por defecto (`showWatchNextSection`).
- **Salvapantallas OLED** — Reloj minimalista que se desplaza cada 30 s. Servicio nativo `ClockScreensaverService`.
- **Programador de brillo** — Experimental; requiere `WRITE_SETTINGS` por ADB.
- **Widget de consumo de datos** — Consumo diario de Internet en la barra superior.
- **Colores de acento** — Preajustes que alimentan el `ColorScheme` completo.

## 8. Identidad y limpieza del fork

- ✅ Nombre visible: **Lemonade Launcher**, vía `res/values/strings.xml` y `res/values-es/strings.xml`, referenciado desde el manifest como `@string/app_name`.
- ✅ Título de la app Flutter y locale por defecto es-ES.
- ✅ README en español de España.
- ⬜ **Pendiente:** el `name: flauncher` de `pubspec.yaml` **no se cambia**: es el identificador del paquete Dart y romper eso obligaría a reescribir los 71 imports `package:flauncher/...` sin ganar nada.
- ⬜ **Pendiente:** cadenas «Arc Launcher» en `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` y `lib/widgets/settings/flauncher_about_dialog.dart`.
- ✅ **Autoactualizador propio.** El repositorio de origen ya no está incrustado en el código: se pasa en tiempo de compilación con `--dart-define=UPDATE_REPO_OWNER` y `--dart-define=UPDATE_REPO_NAME` (ver `lib/build_flags.dart`). Sin ambos valores, `kSelfUpdaterAvailable` es `false` y la opción no aparece en los ajustes. Requisitos de publicación documentados en el README.
- ⬜ **Pendiente:** cuando exista el repositorio propio en GitHub, publicar la primera *release* con etiqueta semántica y un APK universal adjunto, y compilar con el flavor `github` (el único que declara `REQUEST_INSTALL_PACKAGES`).
- ⬜ **Pendiente:** el `applicationId` sigue siendo `com.omeda.arc` (`android/app/build.gradle`, `namespace` incluido), y las clases nativas viven en el paquete Java `com.leanbitlab.ltvL`, con restos de `me.efesser.flauncher` en `android/app/src/main/java/`. Cambiar el `applicationId` implica que el sistema lo trate como una app distinta: hay que desinstalar antes de instalar, y se pierden los ajustes y la base de datos.

## 9. Tesis de producto: en qué se diferencia este fork

Sin una tesis, un fork solo acumula deuda de mantenimiento. La ventaja real de este proyecto es que el launcher nativo está deshabilitado: es el dueño absoluto de la pantalla de inicio, sin contenido promocionado.

### 9.1 Escenas preconfiguradas — **aprobado**

El launcher cambia de comportamiento según el momento, no solo de fondo de pantalla. Cada escena es un preajuste seleccionable que agrupa:

- Subconjunto de aplicaciones visibles en el dock
- Nivel de brillo del sistema
- Fondo de pantalla asociado
- Opcionalmente, bloqueo con PIN para salir de la escena

Escenas de partida: **Cine** (streaming, brillo alto), **Noche** (brillo mínimo, música y pódcast), **Niños** (dock filtrado, salida con PIN), **Normal**.

**Activación exclusivamente manual.** La escena solo cambia cuando el usuario la selecciona, y persiste hasta que la vuelva a cambiar. Queda explícitamente fuera de alcance:

- Activación por horario, por rutina o por cualquier heurística.
- Sugerencias o avisos que propongan cambiar de escena.
- Reversión automática a una escena por defecto tras un tiempo o al reiniciar.

El motivo es de producto, no técnico: en la pantalla del salón, un entorno que se reconfigura por su cuenta produce desconfianza. El usuario debe poder predecir con total certeza qué se va a encontrar al encender la televisión. Nótese que esto convive con el fondo de pantalla por horario que ya existe, que es un ajuste independiente y sigue siendo opcional.

Reaprovecha lo que ya existe: categorías en Drift, `lib/providers/brightness_service.dart` y la gestión de fondos. Falta la capa que las orquesta y la persistencia de la escena activa.

### 9.2 Candidatas evaluadas

| Candidata | Estado | Motivo |
| --- | --- | --- |
| Dock adaptativo por uso real | **Descartada** | Reordenar iconos automáticamente destruye la memoria muscular: con mando a distancia se navega por posición sin mirar la pantalla. La única variante defendible era sugerir la escena, y eso choca con la activación manual exclusiva de la sección 9.1. Sin propósito restante, no se implementa `UsageStatsManager` |
| Copia de seguridad de la configuración | Recomendada | No existe nada: cero referencias a exportación en `lib/providers/`. Sin ella, reinstalar el launcher o cambiar el `applicationId` borra categorías y ajustes |
| Accesos directos a contenido (*deep links*) | **Recomendada** | Un icono del dock que no abre una aplicación, sino un contenido concreto dentro de ella. Viable y verificado con las aplicaciones no oficiales: ver sección 12 |
| Filtro rápido de aplicaciones | **Descartada** | El usuario no lo necesita: con un dock curado de favoritos, buscar escribiendo no aporta |
| Cámara del timbre en pantalla | Aplazada | El caso de uso más atractivo, pero exige RTSP local del dispositivo y trabajo nativo con Media3: `video_player` no cubre RTSP. Depende de que la cámara lo exponga |
| Integración con Home Assistant | **Descartada** | Los dispositivos disponibles (Ring, EZVIZ, Pro Breeze, Kaysun/NetHome Plus) son cuatro fabricantes con cuatro apps propias, sin ecosistema común. Montar y mantener un servidor de Home Assistant solo para esto no se sostiene |

## 10. Trabajo pendiente, por orden

**Bloqueante:** reparar la suite de tests. `flutter test` da 23 pruebas correctas y **14 ficheros que no compilan**, porque el fork de origen refactorizó `lib/` sin actualizar `test/`. Los ficheros afectados cubren precisamente las zonas donde vamos a trabajar: categorías, aplicaciones, panel de ajustes y la pantalla principal. Construir escenas encima de esto sería trabajar a ciegas sobre el entorno absoluto del sistema.

Después:

1. Escenas preconfiguradas (sección 9.1).
2. Copia de seguridad y restauración de la configuración (sección 11).
3. Widget de clima con Open-Meteo, interruptor y buscador de ciudad en Ajustes.
4. Encapsular los elementos de la barra superior en tarjetas de cristal.
5. Squircle para los iconos de aplicación.
6. Revisar el escalado al enfocar (factor 1,08× y físicas de muelle).
7. Limpiar las cadenas y referencias restantes a Arc Launcher.
8. Decidir si se renombra el `applicationId` `com.omeda.arc` — **antes** de la primera publicación, nunca después.

## 11. Copia de seguridad y restauración

El estado del launcher vive hoy en tres sitios distintos, y esto condiciona el diseño:

| Origen | Contenido | Cómo se exporta |
| --- | --- | --- |
| `shared_preferences` | 23 ajustes: formatos de fecha y hora, color de acento, interruptores del dock y de la barra | Volcado directo a pares clave-valor |
| SQLite vía Drift | Tablas `Apps`, `Categories`, `AppsCategories`, `LauncherSpacers`: qué apps hay, en qué categoría y en qué orden | Consulta de cada tabla y serialización de las filas |
| Ficheros en el directorio de soporte | `wallpaper`, `wallpaper_day`, `wallpaper_night` y sus variantes de vídeo (`lib/providers/wallpaper_service.dart:82-87`) | Referencia por nombre; los binarios no se incluyen |

Diseño acordado:

1. **Un único fichero JSON** con los ajustes y las tablas. Los fondos de pantalla **no** se incluyen: un vídeo puede pesar decenas de megas y convierte una copia de seguridad en un archivo inmanejable. Se guarda solo la referencia, y al restaurar se avisa de qué fondos hay que volver a seleccionar.
2. **Campo `schemaVersion`** en la raíz del JSON. Sin él, un fichero antiguo restaurado sobre una versión nueva corrompe la base de datos en silencio. Con él, se puede migrar o rechazar con un mensaje claro.
3. **Validación al importar:** por cada `packageName` del fichero, comprobar que la aplicación sigue instalada. Las que no lo estén se omiten y se informa de ello, en lugar de dejar entradas fantasma en el dock.
4. **Ubicación del fichero:** almacenamiento externo, para que sea accesible por ADB o por un USB. Para elegir el fichero al importar se reutiliza `lib/widgets/tv_media_picker.dart`, que ya resuelve la selección de ficheros con mando a distancia.
5. **La restauración reemplaza, no fusiona.** Fusionar exigiría resolver conflictos de orden y de pertenencia a categorías: mucha complejidad para un caso de uso que es «devuélveme mi configuración».

## 12. Accesos directos a contenido (*deep links*)

Un icono del dock que no abre la aplicación, sino un contenido concreto dentro de ella: una lista de reproducción, un canal, la bandeja de suscripciones.

### 12.1 Por qué funciona mejor con aplicaciones no oficiales

Un *deep link* solo funciona si la aplicación de destino declara un `intent-filter` público en su manifest. Con las aplicaciones oficiales de streaming eso es ingeniería inversa: contratos no documentados que se rompen en cada actualización.

Con las aplicaciones no oficiales instaladas por *sideload* ocurre lo contrario: son de código abierto, así que **el contrato es público, legible y estable**.

### 12.2 Verificado: SmartTube

Consultado su `AndroidManifest.xml` público (`yuliskov/SmartTube`, `smarttubetv/src/main/AndroidManifest.xml`), la actividad principal declara:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <action android:name="android.media.action.MEDIA_PLAY_FROM_SEARCH"/>
    <data android:scheme="http"/>
    <data android:scheme="https"/>
    <data android:host="youtube.com"/>
    <data android:host="www.youtube.com"/>
    <data android:host="m.youtube.com"/>
    <data android:host="youtu.be"/>
    <data android:pathPattern=".*"/>
    <data android:host="search" android:scheme="youtube"/>
    <data android:host="play"   android:scheme="youtube"/>
</intent-filter>
<intent-filter>
    <data android:scheme="vnd.youtube"/>
    <data android:scheme="vnd.youtube.launch"/>
</intent-filter>
```

Consecuencias prácticas:

| Se puede lanzar | Cómo |
| --- | --- |
| Cualquier URL de YouTube: vídeo, lista, canal, suscripciones | `pathPattern=".*"` acepta cualquier ruta de `youtube.com` o `youtu.be` |
| Una búsqueda directa | `MEDIA_PLAY_FROM_SEARCH`, o el esquema `youtube://search` |
| Reproducción inmediata | Esquema `youtube://play` o `vnd.youtube:` |

Ejemplos de icono de dock que dejan de ser «abrir SmartTube»: la bandeja de suscripciones (`youtube.com/feed/subscriptions`), una lista de música de fondo, o un canal concreto.

### 12.3 Diseño

1. **Un acceso directo es una entrada del dock más**, con su propio icono, etiqueta y URI de destino. Conceptualmente convive con las aplicaciones, no es una pantalla aparte.
2. **Paquete de destino explícito.** El intent fija el `packageName` (por ejemplo `com.teamsmart.videomanager.tv`) en lugar de dejar que Android muestre un selector. Sin esto, en una televisión aparecería un diálogo de «elige aplicación» que hay que resolver con el mando cada vez.
3. **Validación al crear y al restaurar.** Si el paquete de destino no está instalado, el acceso directo se marca como no disponible en lugar de fallar al pulsarlo.
4. **Descubrimiento en el dispositivo.** Para averiguar qué acepta cualquier aplicación instalada, sin adivinar: `adb shell dumpsys package <packageName>` lista sus `intent-filter` reales. Documentar los contratos confirmados aquí a medida que se verifiquen.
5. **Sin ingeniería inversa de aplicaciones oficiales.** Solo se soportan contratos declarados públicamente. Un acceso directo que se rompe en silencio tras una actualización es peor que no tenerlo.
