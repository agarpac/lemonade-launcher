// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutFlauncher => 'About Lemonade Launcher';

  @override
  String get addCategory => 'Add category';

  @override
  String get addSection => 'Add section';

  @override
  String get alphabetical => 'Alphabetical';

  @override
  String get appCardHighlightAnimation => 'App card highlight animation';

  @override
  String get showFocusBorders => 'Show focus borders';

  @override
  String get showContentShortcutHandle =>
      'Show the channel handle instead of the shortcut name';

  @override
  String get appInfo => 'Application info';

  @override
  String get appKeyClick => 'Click sound on key press';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get backgroundBlur => 'Background blur';

  @override
  String get dockBlur => 'Dock blur';

  @override
  String get dockDarkBackground => 'Dark dock background';

  @override
  String get dockShadow => 'Dock shadow';

  @override
  String get applications => 'Applications';

  @override
  String get autoHideAppBar => 'Automatically hide status bar';

  @override
  String get backButtonAction => 'Back button action';

  @override
  String get category => 'Category';

  @override
  String get categories => 'Categories';

  @override
  String get columnCount => 'Column count';

  @override
  String get date => 'Date';

  @override
  String get dateAndTimeFormat => 'Date and time format';

  @override
  String get delete => 'Delete';

  @override
  String get dialogOptionBackButtonActionDoNothing => 'Do nothing';

  @override
  String get dialogOptionBackButtonActionShowScreensaver => 'Show screensaver';

  @override
  String get dialogOptionBackButtonActionShowClock => 'Show clock';

  @override
  String get dialogTextNoFileExplorer =>
      'Please install a file explorer in order to pick a picture.';

  @override
  String get dialogTitleBackButtonAction => 'Choose the back button action';

  @override
  String disambiguateCategoryTitle(String title) {
    return '$title (Category)';
  }

  @override
  String formattedDate(String dateString) {
    return 'Formatted date: $dateString';
  }

  @override
  String formattedTime(String timeString) {
    return 'Formatted time: $timeString';
  }

  @override
  String get gradient => 'Gradient';

  @override
  String get favoriteApps => 'Favorite Apps';

  @override
  String get grid => 'Grid';

  @override
  String get height => 'Height';

  @override
  String get hide => 'Hide';

  @override
  String get hiddenApplications => 'Hidden Apps';

  @override
  String get launcherSections => 'Sections';

  @override
  String get layout => 'Layout';

  @override
  String get loading => 'Loading';

  @override
  String get manual => 'Manual';

  @override
  String get modifySection => 'Modify section';

  @override
  String get mustNotBeEmpty => 'Must not be empty';

  @override
  String get name => 'Name';

  @override
  String get newSection => 'New section';

  @override
  String get noDateFormatSpecified => 'No date format specified';

  @override
  String get noTimeFormatSpecified => 'No time format specified';

  @override
  String get allApplications => 'All Apps';

  @override
  String get favorites => 'Favorites';

  @override
  String get nonTvApplications => 'Non-TV Apps';

  @override
  String get open => 'Open';

  @override
  String get orSelectFormatSpecifiers => 'Or select format specifiers';

  @override
  String get picture => 'Picture';

  @override
  String removeFrom(String name) {
    return 'Remove from $name';
  }

  @override
  String get renameCategory => 'Rename category';

  @override
  String get reorder => 'Reorder';

  @override
  String get row => 'Row';

  @override
  String get rowHeight => 'Row height';

  @override
  String get save => 'Save';

  @override
  String get scenes => 'Scenes';

  @override
  String get scenesEnable => 'Enable scenes';

  @override
  String get sceneNormal => 'Normal';

  @override
  String get sceneCinema => 'Cinema';

  @override
  String get sceneNight => 'Night';

  @override
  String get sceneActiveSemanticLabel => 'Active scene';

  @override
  String get sceneActivationFailed => 'Could not switch scenes.';

  @override
  String get scenePinProtected =>
      'This scene requires a PIN, which isn\'t supported yet.';

  @override
  String get sceneEditorNormalExplanation =>
      'Normal is your own settings, left untouched. There is nothing to configure here.';

  @override
  String get sceneOverrideShowAppNames => 'Show app names below icons';

  @override
  String get sceneOverrideDisableBackgroundBlur => 'Disable background blur';

  @override
  String get sceneOverrideInheritOn => 'Inherit (on)';

  @override
  String get sceneOverrideInheritOff => 'Inherit (off)';

  @override
  String get sceneOverrideOn => 'On';

  @override
  String get sceneOverrideOff => 'Off';

  @override
  String sceneOverrideInheritGradient(String gradientName) {
    return 'Inherit ($gradientName)';
  }

  @override
  String get sceneOverrideAccentColor => 'Accent color';

  @override
  String sceneOverrideInheritAccentColor(String colorName) {
    return 'Inherit ($colorName)';
  }

  @override
  String get sceneOverrideUpdateFailed => 'Could not save this change.';

  @override
  String get sceneOverrideImage => 'Image';

  @override
  String get sceneOverrideImageSet => 'Image set';

  @override
  String get sceneOverrideImageNotSet => 'No image';

  @override
  String get sceneOverrideChooseImage => 'Choose image';

  @override
  String get sceneOverrideClearImage => 'Clear image';

  @override
  String get spacer => 'Spacer';

  @override
  String get spacerMaxHeightRequirement =>
      'Must be greater than 0 and less than or equal to 500';

  @override
  String get statusBar => 'Status bar';

  @override
  String get settings => 'Settings';

  @override
  String get show => 'Show';

  @override
  String get showCategoryTitles => 'Show category titles';

  @override
  String get sort => 'Sort';

  @override
  String get systemSettings => 'System settings';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateNoUpdateTitle => 'No updates available';

  @override
  String updateNoUpdateBody(String currentVersion) {
    return 'You are already on the latest version ($currentVersion).';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String latestVersion, String currentVersion) {
    return 'Version $latestVersion is available (current: $currentVersion).';
  }

  @override
  String get updateDownloadButton => 'Download';

  @override
  String get updateReadyToInstallTitle => 'Ready to install';

  @override
  String updateReadyToInstallBody(String latestVersion) {
    return 'The APK for version $latestVersion is downloaded. Start installation now?';
  }

  @override
  String get updateInstallButton => 'Install';

  @override
  String get updateInstallPermissionTitle => 'Installer permission required';

  @override
  String get updateInstallPermissionBody =>
      'Allow Lemonade Launcher to install unknown apps, then retry the update.';

  @override
  String get updateOpenPermissionSettingsButton => 'Open permission settings';

  @override
  String get updateErrorGeneric => 'Update check failed. Please try again.';

  @override
  String textAboutDialog(String repoUrl) {
    return 'Lemonade Launcher by Alberto Garrido — https://github.com/agarpac\n\nIt is a fork of Arc Launcher by Meddouri Badis, which is itself based on FLauncher by Étienne Fesser.\n\nArc Launcher (upstream project) source code: $repoUrl';
  }

  @override
  String get textEmptyCategory => 'This category is empty.';

  @override
  String get time => 'Time';

  @override
  String get titleStatusBarSettingsPage =>
      'Choose what to display in the status bar';

  @override
  String get tvApplications => 'TV Apps';

  @override
  String get type => 'Type';

  @override
  String get typeInTheDateFormat => 'Type in the date format';

  @override
  String get typeInTheHourFormat => 'Type in the hour format';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get wallpaper => 'Wallpaper';

  @override
  String get withEllipsisAddTo => 'Add to...';

  @override
  String get timeBasedWallpaper => 'Time based wallpaper';

  @override
  String get pickDayWallpaper => 'Pick day wallpaper';

  @override
  String get pickNightWallpaper => 'Pick night wallpaper';

  @override
  String get video => 'Video';

  @override
  String get pickDayVideoWallpaper => 'Pick day video';

  @override
  String get pickNightVideoWallpaper => 'Pick night video';

  @override
  String get watchNextSectionTitle => 'Watch Next';

  @override
  String get showWatchNextSection => 'Show Watch Next Section';

  @override
  String get watchNextPermissionTitle => 'Watch Next permission required';

  @override
  String get watchNextPermissionBody =>
      'Allow access to TV listings to show your continue watching items.';

  @override
  String get watchNextGrantPermission => 'Grant permission';

  @override
  String get watchNextCheckPermission => 'Check again';

  @override
  String get interface => 'Interface';

  @override
  String get system => 'System';

  @override
  String get contentSettings => 'Content';

  @override
  String get settingsSectionDock => 'Dock';

  @override
  String get settingsSectionEffects => 'Effects';

  @override
  String get settingsSectionColor => 'Color';

  @override
  String get settingsSectionBrightness => 'Brightness';

  @override
  String get settingsSectionScreensaver => 'Screensaver';

  @override
  String get settingsSectionDateTime => 'Date & time';

  @override
  String get settingsSectionBehavior => 'Behavior';

  @override
  String get settingsSectionNetwork => 'Network';

  @override
  String get settingsSectionData => 'Data';

  @override
  String get brightnessScheduler => 'Brightness Scheduler';

  @override
  String get screensaverSettings => 'Screensaver Settings';

  @override
  String get screensaverClockStyle => 'Screensaver Clock Style';

  @override
  String get wifiUsagePeriodTitle => 'WiFi Usage Period';

  @override
  String get wifiPeriodDaily => 'Daily';

  @override
  String get wifiPeriodWeekly => 'Weekly';

  @override
  String get wifiPeriodMonthly => 'Monthly';

  @override
  String get wifiUsageToggle => 'WiFi Usage';

  @override
  String get networkIndicator => 'Network Indicator';

  @override
  String get wifiUsageGrantPermission => 'Grant Usage Permission';

  @override
  String get selectAName => 'Select a name';

  @override
  String get customName => 'Custom Name';

  @override
  String get lastUsed => 'Last Used';

  @override
  String get addToCategory => 'Add to Category';

  @override
  String get removeFromFavorites => 'Remove from Fav';

  @override
  String get addToFavorites => 'Add to Fav';

  @override
  String get setCustomBanner => 'Set Custom Banner';

  @override
  String get clearCustomBanner => 'Clear Custom Banner';

  @override
  String setBannerFailed(String error) {
    return 'Failed to set banner: $error';
  }

  @override
  String clearBannerFailed(String error) {
    return 'Failed to clear banner: $error';
  }

  @override
  String get selectImage => 'Select Image';

  @override
  String get selectVideo => 'Select Video';

  @override
  String mediaItemsCount(String count) {
    return '$count items';
  }

  @override
  String get noImagesFoundOnDevice => 'No images found on device';

  @override
  String get noVideosFoundOnDevice => 'No videos found on device';

  @override
  String get mediaPickerHintNoItems => 'D-pad: navigate  •  Back: cancel';

  @override
  String get mediaPickerHintWithItems =>
      'D-pad: navigate  •  Select: set wallpaper  •  Back: cancel';

  @override
  String get mediaAccessPermissionRequired =>
      'Media access permission is required';

  @override
  String get mediaAccessPermissionExplanation =>
      'Grant permission to browse photos and videos';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get brightnessAdbInstructions =>
      'To control brightness on this device, you must grant permission via ADB:';

  @override
  String get checkStatus => 'Check Status';

  @override
  String get enableScheduler => 'Enable Scheduler';

  @override
  String currentTimeSlotLabel(String label) {
    return 'Current: $label';
  }

  @override
  String get brightnessExperimentalNotice =>
      'EXPERIMENTAL: This feature is untested and may be removed in future versions based on user feedback.';

  @override
  String get brightnessDeviceSupportNote =>
      'Note: Some Android TV devices may not support app-level brightness control.';

  @override
  String get noApplicationsFound => 'No applications found';

  @override
  String get invalidFormat => 'Invalid format';

  @override
  String get selectFormatsBelow => 'Select formats below';

  @override
  String get aboutLegalese =>
      'Lemonade Launcher © Alberto Garrido\nFork of Arc Launcher © Meddouri Badis\nBased on FLauncher © Étienne Fesser';

  @override
  String get preview => 'Preview';

  @override
  String get clockStyleMinimalTitle => 'Minimal';

  @override
  String get clockStyleMinimalSubtitle => 'Thin, elegant font (Default)';

  @override
  String get clockStyleBoldTitle => 'Bold';

  @override
  String get clockStyleBoldSubtitle => 'Thick, highly visible font';

  @override
  String get clockStyleRetroTitle => 'Retro';

  @override
  String get clockStyleRetroSubtitle => 'Monospaced, retro terminal style';

  @override
  String get clockStyleElegantTitle => 'Elegant';

  @override
  String get clockStyleElegantSubtitle => 'Classic serif typeface';

  @override
  String get clockStyleNeonTitle => 'Neon';

  @override
  String get clockStyleNeonSubtitle => 'Ultra-thin, glowing style';

  @override
  String get clockStylePixelTitle => 'Pixel';

  @override
  String get clockStylePixelSubtitle => 'Bold monospaced, arcade feel';

  @override
  String get clockStyleDigitalTitle => 'Digital';

  @override
  String get clockStyleDigitalSubtitle => 'Clean monospaced display';

  @override
  String get backupAndRestore => 'Backup and restore';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupRestore => 'Restore backup';

  @override
  String get backupChooseFile => 'Choose a backup';

  @override
  String get backupCreatedTitle => 'Backup created';

  @override
  String get backupNotCreatedTitle => 'Backup not created';

  @override
  String get backupExportSucceeded =>
      'The whole configuration was saved to a file.';

  @override
  String get backupExportStorageUnavailable =>
      'This device exposes no storage where the backup could be written.';

  @override
  String get backupExportFailed =>
      'The backup file could not be written. Nothing was saved.';

  @override
  String backupExportFilePath(String path) {
    return 'File: $path';
  }

  @override
  String get backupExportWallpapersNotIncluded =>
      'Wallpaper images are not part of the backup. You will have to choose these again after restoring:';

  @override
  String get backupListEmpty =>
      'No backup found on this device. Create one first.';

  @override
  String get backupListStorageUnavailable =>
      'This device exposes no storage where backups could be looked for.';

  @override
  String get backupRestoreConfirmTitle => 'Restore this backup?';

  @override
  String get backupRestoreConfirmBody =>
      'The current configuration is replaced by the contents of this file, not merged with it: applications, categories, sections and settings all go back to what they were when the backup was created.';

  @override
  String get backupRestoreConfirmButton => 'Restore';

  @override
  String get backupRestoreSkippedApps =>
      'These applications are in the backup but are not installed, so they will be left out:';

  @override
  String get backupRestoreWallpapersToReselect =>
      'These wallpapers are not on this device, so you will have to choose them again:';

  @override
  String get backupRestoredTitle => 'Configuration restored';

  @override
  String get backupNotRestoredTitle => 'Configuration not restored';

  @override
  String get backupImportSucceeded => 'The configuration was restored.';

  @override
  String get backupImportSettingsRestoreIncomplete =>
      'The configuration was restored, but some settings could not be written and went back to their default value. Restoring the same backup again is safe.';

  @override
  String get backupImportFileNotFound =>
      'This backup file no longer exists. Nothing was changed.';

  @override
  String get backupImportInvalidFile =>
      'This file is not a backup, or it is damaged. Nothing was changed.';

  @override
  String get backupImportUnsupportedVersion =>
      'This backup was created by a newer version of the launcher and cannot be read. Nothing was changed.';

  @override
  String get backupImportInstalledAppsUnavailable =>
      'The list of installed applications could not be read, so the backup could not be checked. Nothing was changed.';

  @override
  String get backupImportRestoreFailed =>
      'The configuration could not be restored. Nothing was changed.';

  @override
  String get weather => 'Weather';

  @override
  String get weatherShowInStatusBar => 'Show in the status bar';

  @override
  String get weatherNoCity => 'No city chosen';

  @override
  String get weatherClearCity => 'Clear city';

  @override
  String get weatherSearchCity => 'Search a city';

  @override
  String get weatherSearchPrompt => 'Type a city name, then confirm to search.';

  @override
  String get weatherSearching => 'Searching…';

  @override
  String get weatherSearchNoResults => 'No city matches that name.';

  @override
  String get weatherSearchFailed =>
      'The search could not be completed. Check the connection and try again.';

  @override
  String weatherTemperature(String degrees) {
    return '$degrees°';
  }

  @override
  String get contentShortcuts => 'Shortcuts';

  @override
  String get contentShortcutAdd => 'Add shortcut';

  @override
  String get contentShortcutNew => 'New shortcut';

  @override
  String get contentShortcutModify => 'Modify shortcut';

  @override
  String contentShortcutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shortcuts',
      one: '1 shortcut',
      zero: 'No shortcuts',
    );
    return '$_temp0';
  }

  @override
  String get contentShortcutSectionEmpty => 'This section has no shortcuts.';

  @override
  String get contentShortcutAddress => 'Channel or address';

  @override
  String get contentShortcutNameOptional => 'Name (optional)';

  @override
  String get contentShortcutAddressPrompt =>
      'Type @handle, a channel id or a full address, then confirm to look for the apps that can open it.';

  @override
  String get contentShortcutAddressInvalid =>
      'This is not a channel or an address that can be opened. Try @handle, a channel id, or a full address.';

  @override
  String get contentShortcutResolving =>
      'Looking for the apps that can open it…';

  @override
  String get contentShortcutTargetsEmpty =>
      'No installed app reported that it can open this address. The address may well be right: this also happens when the app is installed but this version of Android does not let the launcher see it.';

  @override
  String get contentShortcutChooseTarget => 'Choose the app that will open it:';

  @override
  String contentShortcutTarget(String appName) {
    return 'Opens in $appName';
  }

  @override
  String get contentShortcutNoTarget => 'No app chosen yet';

  @override
  String get contentShortcutUnavailable => 'Unavailable';
}
