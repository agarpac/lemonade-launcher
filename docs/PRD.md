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
| Escalado al enfocar con animación no lineal | ✅ **cumplido** — ver 4.1 |

**Prohibido:** transiciones lineales.

### 4.1 Valores reales de la animación de foco

La v1 de este PRD pedía «escalado 1,08× con físicas de muelle». Ese número se escribió antes de conocer el código y **sin haberlo probado en un televisor**. Los valores implementados son distintos, están mejor fundamentados, y se conservan:

| Elemento | Valor | Ubicación |
| --- | --- | --- |
| Factor de escala del icono | **1,07** | `lib/widgets/app_card.dart:106` |
| Duración | **180 ms** | `lib/widgets/app_card.dart:107` |
| Curva | **`Curves.easeOutCubic`** | `lib/widgets/app_card.dart:215` |
| Tipo de animación | `AnimatedScale` implícita, envuelta en `RepaintBoundary` | — |
| Borde de foco | Contorno de 1 dp con alfa pulsante `0.4 + v*0.6`, `AnimationController` de 1200 ms independiente de la escala | `_HighlightOutline` |
| Tarjetas de «Continuar viendo» | 1,06 + elevación de −4 px | `lib/widgets/watch_next_row.dart:364` |

Estos valores provienen de la rama `feature/animations-refine` del proyecto de origen, que iteró **1,2 → 1,06 → 1,07** y **`easeInOut` → `easeOutCubic`**. Es decir: hay ajuste empírico detrás. Nunca probaron 1,08.

Decisiones registradas para que nadie las «arregle» sin contexto:

1. **No se cambia 1,07 por 1,08.** En un icono de unos 100 px la diferencia es de un píxel. Alinear el código con una cifra inventada del documento no aporta nada perceptible.
2. **Se mantiene `easeOutCubic` en lugar de `Curves.fastOutSlowIn`.** `easeOutCubic` arranca rápido y desacelera; `fastOutSlowIn` acelera al principio. En navegación con mando lo que se percibe como calidad no es la suavidad sino la **latencia**: el icono debe responder de inmediato al pulsar la cruceta. La curva actual es la mejor de las dos para este caso.
3. **Se descartan las físicas de muelle reales** (`SpringSimulation`/`SpringDescription`, hoy ausentes del proyecto). Exigirían sustituir la `AnimatedScale` implícita por un `AnimationController`, añadiendo **un ticker por tarjeta enfocada** en una GPU de gama baja donde Impeller ya está desactivado para sostener los 60 fps. El riesgo de tirones supera la ganancia estética.
4. **El 1,06 de «Continuar viendo» no es una incoherencia.** Sus tarjetas son pósteres 16:9 mucho mayores, y un mismo factor sobre un elemento más grande desplaza más píxeles; un factor algo menor mantiene el efecto visual equivalente.

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

El launcher cambia de presentación según el momento. Cada escena es un preajuste seleccionable manualmente.

> **Restricción firme: una escena NUNCA altera el contenido del dock.**
>
> Las aplicaciones que el usuario ha añadido al dock están **siempre disponibles, en todas las escenas**, en su orden. Ni se filtran, ni se ocultan, ni se reordenan.
>
> El motivo es el mismo por el que se descartó el dock adaptativo (sección 9.2): con un mando a distancia se navega por posición, sin mirar. Un dock cuyo contenido depende del modo activo obliga a releer la pantalla en cada uso y destruye la memoria muscular. El dock es territorio del usuario y es estable.

Una escena agrupa por tanto **ajustes de presentación**, no de contenido:

- Nivel de brillo del sistema
- Fondo de pantalla asociado

### 9.1.3 Qué agrupa una escena

Una escena es **un paquete de ajustes de presentación que se cambian de golpe**. Todos ellos ya existen hoy en `lib/providers/settings_service.dart`, pero son globales y están repartidos por el panel de Ajustes: poner la televisión en «modo cine» obliga a entrar, cambiar cinco cosas y luego revertirlas una a una.

| Ajuste | Clave existente |
| --- | --- |
| Fondo de pantalla (fichero o gradiente) | `WallpaperService` / `gradientUuid` |
| Ocultar la barra superior | `autoHideAppBarEnabled` |
| Mostrar «Continuar viendo» | `showWatchNextSection` |
| Nombres bajo los iconos | `showAppNamesBelowIcons` |
| Desenfoque del fondo | `backgroundBlurDisabled` |
| Títulos de categoría | `showCategoryTitles` |
| Color de acento | `accentColorHex` |

Cada uno es una sobrescritura **opcional**: `null` significa «no cambiar, respeta el ajuste global del usuario».

Escenas de partida:

- **Normal** — no sobrescribe nada; los ajustes del usuario tal cual.
- **Cine** — barra superior oculta, sin «Continuar viendo», sin nombres bajo los iconos, fondo oscuro. Pantalla limpia.
- **Noche** — fondo negro OLED, sin desenfoque.

❌ **«Niños» se elimina.** Su único propósito era filtrar el dock, y eso ya no ocurre. Con el PIN aparcado (9.1.2), sería una etiqueta que no hace nada.

❌ **El brillo se elimina de las escenas.** La variante no destructiva solo afecta a la ventana del launcher: deja de aplicarse en cuanto cualquier aplicación pasa a primer plano, que es justo cuando una escena «Cine» debería servir para algo. Y la propia interfaz de ajustes ya advierte de que muchos televisores no admiten el control de brillo a nivel de aplicación. La variante que sí funciona escribe un ajuste global del sistema y es irreversible: ver la sección 13. Con el fondo y los seis ajustes de presentación restantes, una escena ya cambia la cara del launcher de forma clara y sin efectos colaterales fuera de la aplicación.

**Consecuencia arquitectónica, y es la parte difícil:** todos estos ajustes son preferencias **globales** persistidas. Si activar una escena las escribe, destruye la configuración del usuario sin vuelta atrás. La solución está en 9.1.4.

### 9.1.4 Arquitectura: superposición por derivación

**Decisión: la sobrescritura de una escena nunca se escribe en ninguna parte.** Es una función pura de la escena activa, evaluada en el momento de leer el valor:

```
valor efectivo = sobrescritura de la escena activa ?? ajuste del usuario
```

El ajuste del usuario **no se modifica jamás**. La escena ya está persistida, así que el valor efectivo se recalcula desde cero en cada arranque.

**Por qué no «guardar y restaurar».** Esa alternativa tiene un fallo con nombre propio: *baseline envenenado*. El mecanismo concreto aquí sería: el usuario tiene el gradiente A; al activar «Noche» se guarda A como original y se escribe B; **el sistema mata el launcher** —cosa que ocurre con normalidad mientras Netflix está en primer plano—; al reabrir, la marca «estoy en una escena» se ha perdido, y la siguiente activación guarda B como si fuera el original. **El gradiente A del usuario es irrecuperable.** Un indicador persistido no lo arregla: son dos escrituras sin transacción entre ellas. Y aún queda la otra mitad: si el usuario cambia su fondo *mientras* hay una escena activa, salir de la escena revierte su cambio en silencio.

Con superposición, esos tres escenarios desaparecen porque no existe ningún «original» que guardar.

**El punto de composición es el servicio, no el árbol de widgets.** `lib/widgets/cached_blur_backdrop.dart` lee el fondo por su cuenta, además de `_wallpaper()` en `lib/flauncher.dart`. Si la superposición se compone en los widgets, hay que hacerlo en dos sitios, y el día que discrepen se ve **el desenfoque del fondo del usuario detrás del fondo de la escena**. Un único punto de composición, dos consumidores.

**Precedencia del fondo,** de mayor a menor: fondo de la escena → vídeo del usuario (resuelto día/noche) → imagen del usuario (día/noche) → gradiente del usuario. La escena **suprime el vídeo**: `_wallpaper()` comprueba el vídeo primero y sale antes de tiempo, así que si no se suprimiera, la escena sería invisible para cualquier usuario con fondo de vídeo. El cambio día/noche sigue funcionando por debajo, para que al volver a «Normal» el fondo correcto esté ya resuelto sin esperar al siguiente ciclo.

**Sin migración y sin subir la versión del formato.** No hace falta ninguna clave nueva ni ningún campo nuevo: `wallpaperPath` y `gradientUuid` ya existen. Importa no subir la versión sin necesidad, porque `_decodeScenes` rechaza un payload de versión superior y cae a los valores por defecto: instalar un APK antiguo sobre uno nuevo **borraría en silencio toda la configuración de escenas**.

Un identificador de gradiente desconocido se resuelve como «sin sobrescritura», no como un gradiente arbitrario: una escena restaurada desde otra versión degrada al fondo del usuario.

**Activación exclusivamente manual.** La escena solo cambia cuando el usuario la selecciona, y persiste hasta que la vuelva a cambiar. Queda explícitamente fuera de alcance:

- Activación por horario, por rutina o por cualquier heurística.
- Sugerencias o avisos que propongan cambiar de escena.
- Reversión automática a una escena por defecto tras un tiempo o al reiniciar.

El motivo es de producto, no técnico: en la pantalla del salón, un entorno que se reconfigura por su cuenta produce desconfianza. El usuario debe poder predecir con total certeza qué se va a encontrar al encender la televisión. Nótese que esto convive con el fondo de pantalla por horario que ya existe, que es un ajuste independiente y sigue siendo opcional.

Reaprovecha lo que ya existe: categorías en Drift, `lib/providers/brightness_service.dart` y la gestión de fondos.

### 9.1.1 Estado: núcleo implementado

`lib/models/scene.dart` y `lib/providers/scenes_service.dart`, con 93 pruebas propias. Persistencia en `shared_preferences` como JSON con campo `version`; el esquema SQL **no** se toca. Cada escena tiene una clave estable (`normal`, `cinema`, `night`, `kids`) independiente de su etiqueta visible.

Sobrescrituras opcionales por escena: aplicaciones visibles del dock (por `packageName`, no por identificador de base de datos, para que sobrevivan a reinstalaciones), brillo, y fondo — este último por fichero **o** por gradiente, mutuamente excluyentes y validado en el constructor. `null` significa siempre «no cambiar nada».

El PIN se guarda como SHA-256 con sal aleatoria por escritura, se compara en tiempo constante, y se verifica **en el servicio**, no en la interfaz: quitar el PIN, cambiarlo o restaurar los valores por defecto exigen conocerlo. `saveScene` transfiere siempre el estado de PIN almacenado, de modo que no existe forma de expresar «guarda esta escena sin su bloqueo».

### 9.1.2 El PIN queda aplazado

El bloqueo por PIN **no forma parte del alcance actual**. La capacidad está implementada y probada en el servicio, pero es opcional: sin PIN configurado no interviene en nada, y ninguna escena se siembra con uno.

Queda por tanto fuera de esta fase: el diálogo de introducción de PIN, y exigirlo para entrar en Ajustes.

Si algún día se retoma, esa segunda parte es imprescindible y no es negociable: sin ella el bloqueo es decorativo, porque el candado impide *salir* de la escena pero cualquiera que abra Ajustes puede añadir aplicaciones al dock de «Niños» o desactivar el launcher. La defensa correcta es **una sola puerta** —la entrada a Ajustes— y no proteger uno por uno los ajustes individuales, que obligaría a reintroducir el PIN en cada cambio sin cerrar el agujero real.

Consecuencia práctica: la escena «Niños» es hoy un dock filtrado sin candado. Sigue siendo útil —limita lo que se ve— pero no impide salir de ella.

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

✅ **Completado — reparación de la suite de tests.** Se partía de 23 pruebas correctas y **14 ficheros que no compilaban**, porque el proyecto de origen refactorizó `lib/` sin actualizar `test/`. Estado actual: **102 pruebas correctas, 1 omitida, 0 fallos**, y 0 errores de `flutter analyze`. Incluyó además la corrección de un fallo real heredado en la cadena de migraciones de `lib/database.dart`, que dejaba la base de datos inabrible al actualizar desde los esquemas v1 a v4.

✅ **Completado — animación de foco** (sección 4.1): el requisito estaba mal planteado en la v1; los valores reales son mejores y se conservan documentados.

Pendiente:

1. Escenas preconfiguradas (sección 9.1).
2. Copia de seguridad y restauración de la configuración (sección 11).
3. Accesos directos a contenido (sección 12).
4. Widget de clima con Open-Meteo, interruptor y buscador de ciudad en Ajustes.
5. Encapsular los elementos de la barra superior en tarjetas de cristal.
6. Squircle para los iconos de aplicación.
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

## 13. Deuda heredada conocida

Fallos reales del código heredado de Arc Launcher, detectados durante el desarrollo pero **fuera del alcance actual**. Se anotan aquí para que la decisión de no tocarlos sea consciente y no un olvido.

### 13.1 El programador de brillo destruye el brillo automático del dispositivo

`android/app/src/main/java/com/leanbitlab/ltvL/MainActivity.java:672`

El método nativo `setSystemBrightness` no se limita a escribir `Settings.System.SCREEN_BRIGHTNESS`: además cambia `SCREEN_BRIGHTNESS_MODE` a **manual**, y escribe a ciegas las claves de fabricante `backlight` y `backlight_level` (líneas 675-677). Nada en el proyecto lee ni restaura jamás el valor anterior de ese modo.

Consecuencia: quien active el programador de brillo pierde el brillo automático de su televisor **de forma permanente**. El cambio es un ajuste del sistema, así que sobrevive a cerrar la aplicación, a reiniciar el dispositivo e incluso a desinstalar el launcher. Solo se recupera desde los ajustes del propio televisor.

Agravantes en el mismo método:

- **`setSystemBrightness` devuelve `true` desde dentro de su propio `catch`** (líneas 680-682). Es decir, en `lib/providers/brightness_service.dart:206` la variable `success` significa «teníamos permiso», no «la escritura funcionó». Un fallo real se interpreta como éxito.
- **El permiso se consulta una sola vez, en el constructor** (`brightness_service.dart:84`), con `_hasPermission` inicializado a `true` (:80) y con fallback a `true` si el canal falla (:95-98). Como `WRITE_SETTINGS` se concede **fuera** de la aplicación —por ADB o por el diálogo del sistema—, tras concederlo el launcher sigue creyendo el valor obsoleto hasta que se reinicia el proceso. El arreglo natural es volver a comprobarlo en `AppLifecycleState.resumed`, donde `lib/flauncher.dart:79-84` ya atiende ese evento para otro servicio.

Por qué no se arregla ahora: la funcionalidad está marcada como experimental, viene desactivada por defecto y requiere un permiso que hay que conceder a mano por ADB, así que nadie la sufre sin haberla buscado. Arreglarlo bien exige capturar una línea base del valor **y del modo** antes de la primera escritura, con garantía de escritura única, y restaurarla — es decir, el mismo problema de línea base envenenada descrito en 9.1.4, pero sobre un ajuste del sistema que ni siquiera es nuestro.

Si algún día se retoma, el orden correcto es: primero arreglar el `catch` que miente, después la comprobación de permiso obsoleta, y solo entonces plantearse la restauración.

### 13.2 Las instantáneas de esquema de la base de datos son incompletas y contradictorias

`test/generated_migrations/schema_v1..v5.dart` no contienen las columnas `banner` ni `icon`, mientras que los JSON de `drift_schemas/` sí las incluyen. El test de migración valida por tanto contra esquemas que ningún dispositivo real tuvo. Fue precisamente el motivo de que no detectara los dos fallos corregidos en la cadena de migraciones.

Además solo existen instantáneas de la v1 a la v5, mientras el esquema vivo va por la **v10**: los pasos de la v6 en adelante no tienen ninguna verificación automática. Las instantáneas de v6 a v9 ya no se pueden generar honestamente, porque de esas versiones solo queda el esquema actual.

Arreglo posible: regenerar las instantáneas v1-v5 desde los JSON, que sí son correctos.
