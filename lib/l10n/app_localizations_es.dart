// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get aboutFlauncher => 'Acerca de Lemonade Launcher';

  @override
  String get addCategory => 'Añadir categoría';

  @override
  String get addSection => 'Añadir sección';

  @override
  String get alphabetical => 'Alfabético';

  @override
  String get appCardHighlightAnimation => 'Resaltar aplicaciones';

  @override
  String get showFocusBorders => 'Mostrar bordes de enfoque';

  @override
  String get appInfo => 'Datos de la aplicación';

  @override
  String get appKeyClick => 'Sonido al presionar una tecla';

  @override
  String get appearanceSettings => 'Apariencia';

  @override
  String get backgroundBlur => 'Desenfoque de fondo';

  @override
  String get dockBlur => 'Desenfoque del dock';

  @override
  String get dockDarkBackground => 'Fondo oscuro del dock';

  @override
  String get dockShadow => 'Sombra del dock';

  @override
  String get applications => 'Aplicaciones';

  @override
  String get autoHideAppBar => 'Ocultar barra de estado automáticamente';

  @override
  String get backButtonAction => 'Acción del botón \'Atrás\'';

  @override
  String get category => 'Categoría';

  @override
  String get categories => 'Categorías';

  @override
  String get columnCount => 'Cantidad de columnas';

  @override
  String get date => 'Fecha';

  @override
  String get dateAndTimeFormat => 'Formato de fecha y hora';

  @override
  String get delete => 'Eliminar';

  @override
  String get dialogOptionBackButtonActionDoNothing => 'Nada';

  @override
  String get dialogOptionBackButtonActionShowScreensaver =>
      'Mostrar salvapantallas';

  @override
  String get dialogOptionBackButtonActionShowClock => 'Mostrar reloj';

  @override
  String get dialogTextNoFileExplorer =>
      'Por favor, instale un gestor de archivos para seleccionar una imagen.';

  @override
  String get dialogTitleBackButtonAction =>
      'Elegir la acción del botón \'Atrás\'';

  @override
  String disambiguateCategoryTitle(String title) {
    return '$title (Categoría)';
  }

  @override
  String formattedDate(String dateString) {
    return 'Fecha con formato: $dateString';
  }

  @override
  String formattedTime(String timeString) {
    return 'Hora con formato: $timeString';
  }

  @override
  String get gradient => 'Gradiente';

  @override
  String get favoriteApps => 'Favoritas';

  @override
  String get grid => 'Cuadrícula';

  @override
  String get height => 'Altura';

  @override
  String get hide => 'Ocultar';

  @override
  String get hiddenApplications => 'Aplicaciones ocultas';

  @override
  String get launcherSections => 'Secciones';

  @override
  String get layout => 'Distribución';

  @override
  String get loading => 'Cargando';

  @override
  String get manual => 'Manual';

  @override
  String get modifySection => 'Modificar sección';

  @override
  String get mustNotBeEmpty => 'No debe estar vacío';

  @override
  String get name => 'Nombre';

  @override
  String get newSection => 'Nueva sección';

  @override
  String get noDateFormatSpecified => 'Sin formato de fecha';

  @override
  String get noTimeFormatSpecified => 'Sin formato de hora';

  @override
  String get allApplications => 'Todas las aplicaciones';

  @override
  String get nonTvApplications => 'Otras aplicaciones';

  @override
  String get open => 'Abrir';

  @override
  String get orSelectFormatSpecifiers =>
      'O seleccione especificadores de formato';

  @override
  String get picture => 'Imagen';

  @override
  String removeFrom(String name) {
    return 'Remover de $name';
  }

  @override
  String get renameCategory => 'Renombrar categoría';

  @override
  String get reorder => 'Reordenar';

  @override
  String get row => 'Row';

  @override
  String get rowHeight => 'Altura de fila';

  @override
  String get save => 'Guardar';

  @override
  String get scenes => 'Escenas';

  @override
  String get sceneNormal => 'Normal';

  @override
  String get sceneCinema => 'Cine';

  @override
  String get sceneNight => 'Noche';

  @override
  String get sceneActiveSemanticLabel => 'Escena activa';

  @override
  String get sceneActivationFailed => 'No se ha podido cambiar de escena.';

  @override
  String get scenePinProtected =>
      'Esta escena requiere un PIN, que todavía no está disponible.';

  @override
  String get sceneEditorNormalExplanation =>
      'Normal es tu propia configuración, sin cambios. No hay nada que configurar aquí.';

  @override
  String get sceneOverrideShowAppNames =>
      'Mostrar nombres de aplicaciones bajo los iconos';

  @override
  String get sceneOverrideDisableBackgroundBlur =>
      'Desactivar el desenfoque de fondo';

  @override
  String get sceneOverrideInheritOn => 'Heredar (activado)';

  @override
  String get sceneOverrideInheritOff => 'Heredar (desactivado)';

  @override
  String get sceneOverrideOn => 'Activado';

  @override
  String get sceneOverrideOff => 'Desactivado';

  @override
  String sceneOverrideInheritGradient(String gradientName) {
    return 'Heredar ($gradientName)';
  }

  @override
  String get sceneOverrideAccentColor => 'Color de acento';

  @override
  String sceneOverrideInheritAccentColor(String colorName) {
    return 'Heredar ($colorName)';
  }

  @override
  String get sceneOverrideUpdateFailed =>
      'No se ha podido guardar este cambio.';

  @override
  String get sceneOverrideImage => 'Imagen';

  @override
  String get sceneOverrideImageSet => 'Imagen establecida';

  @override
  String get sceneOverrideImageNotSet => 'Sin imagen';

  @override
  String get sceneOverrideChooseImage => 'Elegir imagen';

  @override
  String get sceneOverrideClearImage => 'Quitar imagen';

  @override
  String get spacer => 'Espaciador';

  @override
  String get spacerMaxHeightRequirement =>
      'Debe ser mayor a cero y menor o igual a 500';

  @override
  String get statusBar => 'Barra de estado';

  @override
  String get settings => 'Ajustes';

  @override
  String get show => 'Mostrar';

  @override
  String get showCategoryTitles => 'Mostrar títulos de categorías';

  @override
  String get sort => 'Orden';

  @override
  String get systemSettings => 'Ajustes del sistema';

  @override
  String get updateCheck => 'Buscar actualizaciones';

  @override
  String get updateNoUpdateTitle => 'No hay actualizaciones';

  @override
  String updateNoUpdateBody(String currentVersion) {
    return 'Ya tienes la última versión ($currentVersion).';
  }

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateAvailableBody(String latestVersion, String currentVersion) {
    return 'La versión $latestVersion está disponible (actual: $currentVersion).';
  }

  @override
  String get updateDownloadButton => 'Descargar';

  @override
  String get updateReadyToInstallTitle => 'Lista para instalar';

  @override
  String updateReadyToInstallBody(String latestVersion) {
    return 'El APK de la versión $latestVersion ya se descargó. ¿Instalar ahora?';
  }

  @override
  String get updateInstallButton => 'Instalar';

  @override
  String get updateInstallPermissionTitle =>
      'Se requiere permiso de instalación';

  @override
  String get updateInstallPermissionBody =>
      'Permite que Lemonade Launcher instale apps desconocidas y vuelve a intentar la actualización.';

  @override
  String get updateOpenPermissionSettingsButton => 'Abrir ajustes de permisos';

  @override
  String get updateErrorGeneric =>
      'La actualización falló. Inténtalo de nuevo.';

  @override
  String textAboutDialog(String repoUrl) {
    return 'Lemonade Launcher es un fork de Arc Launcher de Meddouri Badis, que a su vez está basado en FLauncher de Étienne Fesser.\n\nCódigo fuente de Arc Launcher (proyecto original): $repoUrl';
  }

  @override
  String get textEmptyCategory => 'Esta categoría está vacía.';

  @override
  String get time => 'Hora';

  @override
  String get titleStatusBarSettingsPage =>
      'Elija la información a mostrar en la barra de estado';

  @override
  String get tvApplications => 'Aplicaciones del televisor';

  @override
  String get type => 'Tipo';

  @override
  String get typeInTheDateFormat => 'Escriba el formato de fecha';

  @override
  String get typeInTheHourFormat => 'Escriba el formato de hora';

  @override
  String get uninstall => 'Desinstalar';

  @override
  String get wallpaper => 'Fondo de pantalla';

  @override
  String get withEllipsisAddTo => 'Añadir a...';

  @override
  String get timeBasedWallpaper => 'Fondo de pantalla según la hora';

  @override
  String get pickDayWallpaper => 'Elegir fondo de día';

  @override
  String get pickNightWallpaper => 'Elegir fondo de noche';

  @override
  String get video => 'Vídeo';

  @override
  String get pickDayVideoWallpaper => 'Elegir vídeo de día';

  @override
  String get pickNightVideoWallpaper => 'Elegir vídeo de noche';

  @override
  String get watchNextSectionTitle => 'Ver después';

  @override
  String get showWatchNextSection => 'Mostrar sección Ver después';

  @override
  String get watchNextPermissionTitle => 'Se requiere permiso para Ver después';

  @override
  String get watchNextPermissionBody =>
      'Permite el acceso a la guía de TV para mostrar lo que estabas viendo.';

  @override
  String get watchNextGrantPermission => 'Conceder permiso';

  @override
  String get watchNextCheckPermission => 'Comprobar de nuevo';

  @override
  String get miscellaneous => 'Varios';

  @override
  String get interface => 'Interfaz';

  @override
  String get system => 'Sistema';

  @override
  String get brightnessScheduler => 'Programador de brillo';

  @override
  String get screensaverSettings => 'Ajustes del salvapantallas';

  @override
  String get screensaverClockStyle => 'Estilo del reloj del salvapantallas';

  @override
  String get wifiUsagePeriodTitle => 'Periodo de uso de WiFi';

  @override
  String get wifiPeriodDaily => 'Diario';

  @override
  String get wifiPeriodWeekly => 'Semanal';

  @override
  String get wifiPeriodMonthly => 'Mensual';

  @override
  String get wifiUsageToggle => 'Uso de WiFi';

  @override
  String get networkIndicator => 'Indicador de red';

  @override
  String get wifiUsageGrantPermission => 'Conceder permiso de uso';

  @override
  String get selectAName => 'Selecciona un nombre';

  @override
  String get customName => 'Nombre personalizado';

  @override
  String get lastUsed => 'Uso reciente';

  @override
  String get addToCategory => 'Añadir a categoría';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get setCustomBanner => 'Establecer banner personalizado';

  @override
  String get clearCustomBanner => 'Quitar banner personalizado';

  @override
  String setBannerFailed(String error) {
    return 'No se pudo establecer el banner: $error';
  }

  @override
  String clearBannerFailed(String error) {
    return 'No se pudo quitar el banner: $error';
  }

  @override
  String get selectImage => 'Seleccionar imagen';

  @override
  String get selectVideo => 'Seleccionar vídeo';

  @override
  String mediaItemsCount(String count) {
    return '$count elementos';
  }

  @override
  String get noImagesFoundOnDevice =>
      'No se encontraron imágenes en el dispositivo';

  @override
  String get noVideosFoundOnDevice =>
      'No se encontraron vídeos en el dispositivo';

  @override
  String get mediaPickerHintNoItems => 'D-pad: navegar  •  Atrás: cancelar';

  @override
  String get mediaPickerHintWithItems =>
      'D-pad: navegar  •  Seleccionar: establecer fondo  •  Atrás: cancelar';

  @override
  String get mediaAccessPermissionRequired =>
      'Se requiere permiso de acceso a multimedia';

  @override
  String get mediaAccessPermissionExplanation =>
      'Concede el permiso para explorar fotos y vídeos';

  @override
  String get grantPermission => 'Conceder permiso';

  @override
  String get permissionRequired => 'Permiso necesario';

  @override
  String get brightnessAdbInstructions =>
      'Para controlar el brillo de este dispositivo, debes conceder permiso mediante ADB:';

  @override
  String get checkStatus => 'Comprobar estado';

  @override
  String get enableScheduler => 'Activar programador';

  @override
  String currentTimeSlotLabel(String label) {
    return 'Actual: $label';
  }

  @override
  String get brightnessExperimentalNotice =>
      'EXPERIMENTAL: esta función no está probada y podría eliminarse en futuras versiones según los comentarios de los usuarios.';

  @override
  String get brightnessDeviceSupportNote =>
      'Nota: algunos dispositivos Android TV podrían no admitir el control de brillo a nivel de aplicación.';

  @override
  String get noApplicationsFound => 'No se encontraron aplicaciones';

  @override
  String get invalidFormat => 'Formato no válido';

  @override
  String get selectFormatsBelow => 'Selecciona los formatos a continuación';

  @override
  String get aboutLegalese =>
      'Fork de Arc Launcher © Meddouri Badis\nBasado en FLauncher © Étienne Fesser';

  @override
  String get preview => 'Vista previa';

  @override
  String get clockStyleMinimalTitle => 'Minimalista';

  @override
  String get clockStyleMinimalSubtitle =>
      'Fuente fina y elegante (predeterminado)';

  @override
  String get clockStyleBoldTitle => 'Negrita';

  @override
  String get clockStyleBoldSubtitle => 'Fuente gruesa y muy visible';

  @override
  String get clockStyleRetroTitle => 'Retro';

  @override
  String get clockStyleRetroSubtitle =>
      'Estilo monoespaciado de terminal retro';

  @override
  String get clockStyleElegantTitle => 'Elegante';

  @override
  String get clockStyleElegantSubtitle => 'Tipografía serif clásica';

  @override
  String get clockStyleNeonTitle => 'Neón';

  @override
  String get clockStyleNeonSubtitle => 'Estilo ultrafino y luminoso';

  @override
  String get clockStylePixelTitle => 'Píxel';

  @override
  String get clockStylePixelSubtitle =>
      'Monoespaciado en negrita, estilo arcade';

  @override
  String get clockStyleDigitalTitle => 'Digital';

  @override
  String get clockStyleDigitalSubtitle => 'Pantalla monoespaciada nítida';

  @override
  String get backupAndRestore => 'Copia de seguridad y restauración';

  @override
  String get backupCreate => 'Crear copia de seguridad';

  @override
  String get backupRestore => 'Restaurar copia de seguridad';

  @override
  String get backupChooseFile => 'Elegir una copia de seguridad';

  @override
  String get backupCreatedTitle => 'Copia de seguridad creada';

  @override
  String get backupNotCreatedTitle => 'No se creó la copia de seguridad';

  @override
  String get backupExportSucceeded =>
      'Se guardó toda la configuración en un archivo.';

  @override
  String get backupExportStorageUnavailable =>
      'Este dispositivo no expone ningún almacenamiento donde escribir la copia de seguridad.';

  @override
  String get backupExportFailed =>
      'No se pudo escribir el archivo de copia de seguridad. No se guardó nada.';

  @override
  String backupExportFilePath(String path) {
    return 'Archivo: $path';
  }

  @override
  String get backupExportWallpapersNotIncluded =>
      'Las imágenes de fondo no forman parte de la copia de seguridad. Tendrás que volver a elegir estas después de restaurar:';

  @override
  String get backupListEmpty =>
      'No se encontró ninguna copia de seguridad en este dispositivo. Crea una primero.';

  @override
  String get backupListStorageUnavailable =>
      'Este dispositivo no expone ningún almacenamiento donde buscar copias de seguridad.';

  @override
  String get backupRestoreConfirmTitle => '¿Restaurar esta copia de seguridad?';

  @override
  String get backupRestoreConfirmBody =>
      'La configuración actual se reemplaza por el contenido de este archivo, no se combina con él: aplicaciones, categorías, secciones y ajustes vuelven a como estaban cuando se creó la copia de seguridad.';

  @override
  String get backupRestoreConfirmButton => 'Restaurar';

  @override
  String get backupRestoreSkippedApps =>
      'Estas aplicaciones están en la copia de seguridad pero no están instaladas, así que quedarán fuera:';

  @override
  String get backupRestoreWallpapersToReselect =>
      'Estos fondos no están en este dispositivo, así que tendrás que volver a elegirlos:';

  @override
  String get backupRestoredTitle => 'Configuración restaurada';

  @override
  String get backupNotRestoredTitle => 'No se restauró la configuración';

  @override
  String get backupImportSucceeded => 'Se restauró la configuración.';

  @override
  String get backupImportSettingsRestoreIncomplete =>
      'Se restauró la configuración, pero algunos ajustes no se pudieron escribir y volvieron a su valor predeterminado. Restaurar de nuevo la misma copia de seguridad es seguro.';

  @override
  String get backupImportFileNotFound =>
      'Este archivo de copia de seguridad ya no existe. No se cambió nada.';

  @override
  String get backupImportInvalidFile =>
      'Este archivo no es una copia de seguridad, o está dañado. No se cambió nada.';

  @override
  String get backupImportUnsupportedVersion =>
      'Esta copia de seguridad se creó con una versión más reciente del lanzador y no se puede leer. No se cambió nada.';

  @override
  String get backupImportInstalledAppsUnavailable =>
      'No se pudo leer la lista de aplicaciones instaladas, así que no se pudo comprobar la copia de seguridad. No se cambió nada.';

  @override
  String get backupImportRestoreFailed =>
      'No se pudo restaurar la configuración. No se cambió nada.';

  @override
  String get weather => 'Clima';

  @override
  String get weatherShowInStatusBar => 'Mostrar en la barra de estado';

  @override
  String get weatherNoCity => 'Sin ciudad elegida';

  @override
  String get weatherClearCity => 'Quitar la ciudad';

  @override
  String get weatherSearchCity => 'Buscar una ciudad';

  @override
  String get weatherSearchPrompt =>
      'Escribe el nombre de una ciudad y confirma para buscar.';

  @override
  String get weatherSearching => 'Buscando…';

  @override
  String get weatherSearchNoResults =>
      'Ninguna ciudad coincide con ese nombre.';

  @override
  String get weatherSearchFailed =>
      'No se pudo completar la búsqueda. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String weatherTemperature(String degrees) {
    return '$degrees°';
  }

  @override
  String get contentShortcuts => 'Accesos directos';

  @override
  String get contentShortcutAdd => 'Añadir acceso directo';

  @override
  String get contentShortcutNew => 'Nuevo acceso directo';

  @override
  String get contentShortcutModify => 'Modificar acceso directo';

  @override
  String contentShortcutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accesos directos',
      one: '1 acceso directo',
      zero: 'Sin accesos directos',
    );
    return '$_temp0';
  }

  @override
  String get contentShortcutSectionEmpty =>
      'Esta sección no tiene accesos directos.';

  @override
  String get contentShortcutAddress => 'Canal o dirección';

  @override
  String get contentShortcutAddressPrompt =>
      'Escribe @nombre, un id de canal o una dirección completa y confirma para buscar las aplicaciones que pueden abrirlo.';

  @override
  String get contentShortcutAddressInvalid =>
      'Esto no es un canal ni una dirección que se pueda abrir. Prueba con @nombre, un id de canal o una dirección completa.';

  @override
  String get contentShortcutResolving =>
      'Buscando las aplicaciones que pueden abrirlo…';

  @override
  String get contentShortcutTargetsEmpty =>
      'Ninguna aplicación instalada ha indicado que pueda abrir esta dirección. La dirección puede estar bien: esto también ocurre cuando la aplicación está instalada pero esta versión de Android no deja que el lanzador la vea.';

  @override
  String get contentShortcutChooseTarget =>
      'Elige la aplicación que lo abrirá:';

  @override
  String contentShortcutTarget(String appName) {
    return 'Se abre en $appName';
  }

  @override
  String get contentShortcutNoTarget =>
      'Todavía no hay ninguna aplicación elegida';

  @override
  String get contentShortcutUnavailable => 'No disponible';
}
