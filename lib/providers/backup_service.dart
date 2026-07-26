/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/category.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Version of the backup file format, written at the root of every exported
/// file as `schemaVersion` and mandatory on import.
///
/// Bump it only on a shape change, and keep every older shape importable in
/// [BackupService._parse]. An import refuses anything greater than this
/// constant instead of guessing: a file written by a newer build may carry
/// fields whose meaning this build does not know, and quietly dropping them
/// would restore a configuration the user never had.
///
/// * 1 — initial shape: `settings`, `wallpapers`, `database`.
const int backupSchemaVersion = 1;

/// Prefix of the exported file name. The rest is a local timestamp, so two
/// exports never overwrite each other and `adb pull` picks the newest by name.
///
/// Public because the restore UI lists the backups in the export directory and
/// must filter on exactly this prefix; a second copy of the literal over there
/// would be free to drift away from the one used to write the files.
const String backupFileNamePrefix = "lemonade-launcher-backup-";

/// Basenames of the six fixed user wallpaper files, in the documents
/// directory, as `WallpaperService` builds them in its `_init`.
///
/// Deliberately duplicated rather than exposed by `WallpaperService`: this
/// service only needs the names to record "a wallpaper existed here", and
/// `WallpaperService` owns no public accessor for them. If a seventh fixed
/// file is ever added there, add it here too — a missing name means an export
/// silently forgets to tell the user that wallpaper has to be picked again.
const List<String> _fixedWallpaperFileNames = [
  "wallpaper",
  "wallpaper_day",
  "wallpaper_night",
  "wallpaper_video",
  "wallpaper_day_video",
  "wallpaper_night_video",
];

/// Prefix of the per-scene wallpaper files (`scene_wallpaper_<sceneKey>`),
/// matching `WallpaperService._sceneWallpaperFile`.
const String _sceneWallpaperFileNamePrefix = "scene_wallpaper_";

/// Preference keys starting with any of these are never exported nor removed
/// on restore.
///
/// `custom_banner_<packageName>` (see `AppsService.setCustomAppBanner`) holds
/// an absolute path to an image file that is *not* part of the backup, exactly
/// like the wallpapers. Restoring the path on another device — or after a
/// reinstall that relocated the app's directories — would point the banner at
/// nothing, so the current device's own value is left alone instead.
const List<String> _nonExportableSettingKeyPrefixes = ["custom_banner_"];

/// Outcome of an export request.
enum BackupExportStatus {
  /// The file was written. [BackupExportResult.filePath] says where.
  succeeded,

  /// The platform reports no app-specific external storage directory, so
  /// there is nowhere reachable by `adb pull` to write to. Nothing was
  /// written.
  storageUnavailable,

  /// Gathering the state or writing the file failed. Nothing usable was
  /// written.
  failed,
}

/// Outcome of an import request.
///
/// Every value except [succeeded] and [settingsRestoreIncomplete] guarantees
/// the database and the preferences are exactly as they were before the call:
/// the file is fully validated before the first row is written.
enum BackupImportStatus {
  /// The configuration was replaced with the file's contents.
  succeeded,

  /// No file at the given path. Nothing changed.
  fileNotFound,

  /// The file is not readable JSON, is not a backup, or one of its values has
  /// the wrong type. Nothing changed.
  invalidFile,

  /// The file was written by a build with a newer format (or a newer database
  /// schema) than this one understands. Nothing changed — refusing beats
  /// restoring a configuration the user never had.
  unsupportedVersion,

  /// The set of installed packages could not be determined, so the file's
  /// `packageName`s could not be validated. Nothing changed: restoring without
  /// that check would either fill the dock with entries pointing at nothing or
  /// — if the empty list were believed — throw the whole dock away.
  installedAppsUnavailable,

  /// A write failed partway through the database transaction, which was rolled
  /// back. Nothing changed.
  restoreFailed,

  /// The database was restored, but one or more preferences could not be
  /// written. Unlike the database, `shared_preferences` offers no transaction,
  /// so this state is reachable and is reported rather than hidden: the
  /// settings are a mix of restored and default values, and importing the same
  /// file again is safe.
  settingsRestoreIncomplete,
}

/// What an export did, and what the user must know about it.
class BackupExportResult {
  final BackupExportStatus status;

  /// Absolute path of the written file, or `null` when nothing was written.
  final String? filePath;

  /// Names of the wallpaper files that existed at export time and whose
  /// **binaries were deliberately left out** of the file (see the PRD, section
  /// 11): a video wallpaper alone can be tens of megabytes. The user has to
  /// pick these again after restoring.
  final List<String> wallpapersNotIncluded;

  final int settingsCount;
  final int appsCount;
  final int categoriesCount;
  final int appsCategoriesCount;
  final int spacersCount;

  /// English, non-localized detail for logs and bug reports. The UI shows a
  /// localized message chosen from [status], never this string.
  final String? message;

  const BackupExportResult({
    required this.status,
    this.filePath,
    this.wallpapersNotIncluded = const [],
    this.settingsCount = 0,
    this.appsCount = 0,
    this.categoriesCount = 0,
    this.appsCategoriesCount = 0,
    this.spacersCount = 0,
    this.message,
  });

  bool get succeeded => status == BackupExportStatus.succeeded;
}

/// What an import did — or, for [BackupService.previewImport], what it would
/// do — and what the user must know about it.
class BackupImportResult {
  final BackupImportStatus status;

  /// `packageName`s present in the file whose app is no longer installed.
  /// Their rows and their category memberships were skipped, rather than
  /// leaving dock entries pointing at nothing.
  final List<String> skippedPackageNames;

  /// Wallpapers the file recorded that are not on this device, so the user has
  /// to pick them again. Their binaries were never in the file.
  final List<String> wallpapersToReselect;

  final int restoredSettings;
  final int restoredApps;
  final int restoredCategories;
  final int restoredAppsCategories;
  final int restoredSpacers;

  /// English, non-localized detail for logs and bug reports. The UI shows a
  /// localized message chosen from [status], never this string.
  final String? message;

  const BackupImportResult({
    required this.status,
    this.skippedPackageNames = const [],
    this.wallpapersToReselect = const [],
    this.restoredSettings = 0,
    this.restoredApps = 0,
    this.restoredCategories = 0,
    this.restoredAppsCategories = 0,
    this.restoredSpacers = 0,
    this.message,
  });

  bool get succeeded =>
      status == BackupImportStatus.succeeded || status == BackupImportStatus.settingsRestoreIncomplete;
}

/// Exports and restores the launcher configuration: the `shared_preferences`
/// values (which include the scenes payload and the active scene key) and the
/// four Drift tables.
///
/// Wallpaper binaries are never included; only the fact that a wallpaper
/// existed is recorded, and a restore reports which ones have to be picked
/// again. See the PRD, section 11.
///
/// Not a [ChangeNotifier], unlike its neighbours: it owns no in-memory state
/// anyone could listen to. Every call returns a result the caller inspects.
///
/// **Contract after a successful [importBackup]:** every other service holds
/// in-memory state loaded at construction time, and none of them is told that
/// the store underneath changed. The caller must therefore rebuild them (or
/// restart the launcher) before the UI can be trusted:
///
///  * `AppsService` caches sections, categories and applications — it must be
///    re-created, or its refresh path re-run.
///  * `ScenesService` reads the scenes payload once, in its constructor — it
///    must be re-created, otherwise it keeps serving the pre-restore scenes
///    and will overwrite the restored payload on the next scene edit.
///  * `SettingsService` and `BrightnessService` read through to
///    `SharedPreferences` on every getter, so their values are already
///    correct, but nothing has notified their listeners: both need a
///    `notifyListeners` (in practice, re-creation together with the others).
///  * `WallpaperService` resolves files on demand but caches the resolved
///    layer; the restored `gradient_uuid` and the restored scenes only reach
///    the screen after it re-resolves.
///
/// Restarting the launcher process is the simplest way to satisfy all of the
/// above at once, and is what the import UI is expected to do.
class BackupService {
  final FLauncherDatabase _database;
  final SharedPreferences _sharedPreferences;
  final FLauncherChannel _fLauncherChannel;

  BackupService(this._database, this._sharedPreferences, this._fLauncherChannel);

  /// Test-only seam for the clock used to name the exported file, matching the
  /// `debugNow` seam in `WallpaperService`.
  @visibleForTesting
  DateTime Function() debugNow = DateTime.now;

  // ---------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------

  /// Gathers the whole configuration into a single JSON file in the app's own
  /// external storage directory and reports where it went.
  ///
  /// That directory (`getExternalStorageDirectory`) is reachable with
  /// `adb pull` and by a file manager and needs **no runtime permission**. A
  /// public folder such as `Download` would need permissions this app does not
  /// hold — its manifest only declares media *read* permissions.
  Future<BackupExportResult> exportBackup() async {
    final Directory? directory;
    try {
      directory = await getExternalStorageDirectory();
    } catch (e) {
      return BackupExportResult(
        status: BackupExportStatus.storageUnavailable,
        message: "Could not resolve the external storage directory: $e",
      );
    }
    if (directory == null) {
      return const BackupExportResult(
        status: BackupExportStatus.storageUnavailable,
        message: "This platform exposes no app-specific external storage directory",
      );
    }

    try {
      final settings = _exportableSettings();
      final wallpapers = await _recordedWallpaperNames();
      final apps = await _exportRows('SELECT * FROM apps ORDER BY package_name', _appRowToJson);
      final categories = await _exportRows('SELECT * FROM categories ORDER BY "order"', _categoryRowToJson);
      final appsCategories =
          await _exportRows('SELECT * FROM apps_categories ORDER BY category_id, "order"', _appCategoryRowToJson);
      final spacers = await _exportRows('SELECT * FROM launcher_spacers ORDER BY "order"', _spacerRowToJson);

      final payload = <String, Object?>{
        "schemaVersion": backupSchemaVersion,
        "createdAt": debugNow().toIso8601String(),
        "databaseSchemaVersion": _database.schemaVersion,
        "settings": settings,
        "wallpapers": wallpapers,
        "database": <String, Object?>{
          "apps": apps,
          "categories": categories,
          "apps_categories": appsCategories,
          "launcher_spacers": spacers,
        },
      };

      final file = File("${directory.path}/$backupFileNamePrefix${_fileNameTimestamp(debugNow())}.json");
      await directory.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent("  ").convert(payload), flush: true);

      return BackupExportResult(
        status: BackupExportStatus.succeeded,
        filePath: file.path,
        wallpapersNotIncluded: wallpapers,
        settingsCount: settings.length,
        appsCount: apps.length,
        categoriesCount: categories.length,
        appsCategoriesCount: appsCategories.length,
        spacersCount: spacers.length,
      );
    } catch (e) {
      return BackupExportResult(status: BackupExportStatus.failed, message: "Could not write the backup file: $e");
    }
  }

  /// Every preference this service owns, with its value.
  ///
  /// Read generically from [SharedPreferences.getKeys] rather than from a
  /// hardcoded list of keys: the keys live as private constants inside
  /// `SettingsService`, `ScenesService` and `BrightnessService`, and a copy
  /// here would silently stop covering a setting the day one is added. The
  /// price is that anything else stored in the same box is exported too, which
  /// is why [_nonExportableSettingKeyPrefixes] exists.
  Map<String, Object> _exportableSettings() {
    final settings = <String, Object>{};
    for (final key in _sharedPreferences.getKeys()) {
      if (!_isExportableSettingKey(key)) {
        continue;
      }
      final Object? value;
      try {
        value = _sharedPreferences.get(key);
      } catch (e) {
        debugPrint("BackupService: skipping preference '$key', it could not be read ($e)");
        continue;
      }
      if (value == null) {
        continue;
      }
      if (value is List) {
        settings[key] = value.whereType<String>().toList(growable: false);
      } else if (value is bool || value is int || value is double || value is String) {
        settings[key] = value;
      } else {
        debugPrint("BackupService: skipping preference '$key', unsupported value type ${value.runtimeType}");
      }
    }
    return settings;
  }

  static bool _isExportableSettingKey(String key) =>
      !_nonExportableSettingKeyPrefixes.any((prefix) => key.startsWith(prefix));

  /// Names of the wallpaper files present in the documents directory: the six
  /// fixed user ones and one `scene_wallpaper_<sceneKey>` per scene that has
  /// an imported image.
  ///
  /// Only names — never bytes. A missing documents directory yields an empty
  /// list rather than failing the export: not knowing about a wallpaper is a
  /// worse report, not a broken backup.
  Future<List<String>> _recordedWallpaperNames() async {
    final Directory documents;
    try {
      documents = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint("BackupService: could not list the wallpaper files ($e)");
      return const [];
    }

    final names = <String>[];
    for (final name in _fixedWallpaperFileNames) {
      if (await File("${documents.path}/$name").exists()) {
        names.add(name);
      }
    }
    try {
      await for (final entity in documents.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final name = entity.uri.pathSegments.last;
        if (name.startsWith(_sceneWallpaperFileNamePrefix)) {
          names.add(name);
        }
      }
    } catch (e) {
      debugPrint("BackupService: could not list the scene wallpaper files ($e)");
    }
    return names;
  }

  /// Runs [sql] and maps every row with [toJson].
  ///
  /// Reads the raw columns instead of the typed row classes on purpose: the
  /// `Apps` table uses `@UseRowClass(App)`, and `App`'s constructor takes no
  /// `lastLaunchedAt`, so drift's generated mapper never fills that field.
  /// Exporting through `FLauncherDatabase.getApplications()` would therefore
  /// lose the timestamp that drives the "Last used" category sort.
  Future<List<Map<String, Object?>>> _exportRows(
    String sql,
    Map<String, Object?> Function(QueryRow row) toJson,
  ) async {
    final rows = await _database.customSelect(sql).get();
    return rows.map(toJson).toList(growable: false);
  }

  static Map<String, Object?> _appRowToJson(QueryRow row) => {
        "package_name": row.read<String>("package_name"),
        "name": row.read<String>("name"),
        "version": row.read<String>("version"),
        "hidden": row.read<bool>("hidden"),
        "last_launched_at": row.readNullable<DateTime>("last_launched_at")?.toIso8601String(),
      };

  static Map<String, Object?> _categoryRowToJson(QueryRow row) => {
        "id": row.read<int>("id"),
        "name": row.read<String>("name"),
        "sort": row.read<int>("sort"),
        "type": row.read<int>("type"),
        "row_height": row.read<int>("row_height"),
        "columns_count": row.read<int>("columns_count"),
        "order": row.read<int>("order"),
      };

  static Map<String, Object?> _appCategoryRowToJson(QueryRow row) => {
        "category_id": row.read<int>("category_id"),
        "app_package_name": row.read<String>("app_package_name"),
        "order": row.read<int>("order"),
      };

  static Map<String, Object?> _spacerRowToJson(QueryRow row) => {
        "id": row.read<int>("id"),
        "height": row.read<int>("height"),
        "order": row.read<int>("order"),
      };

  static String _fileNameTimestamp(DateTime now) {
    String two(int value) => value.toString().padLeft(2, "0");
    return "${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}";
  }

  // ---------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------

  /// Validates [file] and reports what an import would do, **without writing
  /// anything**. Intended for a confirmation screen: a restore replaces the
  /// configuration, it does not merge, so the user should see beforehand which
  /// apps will be skipped and which wallpapers they will have to pick again.
  Future<BackupImportResult> previewImport(File file) async {
    try {
      final backup = await _parse(file);
      final plan = _plan(backup, await _installedPackageNames(), await _recordedWallpaperNames());
      return _resultFor(BackupImportStatus.succeeded, plan);
    } on _BackupRejected catch (rejection) {
      return BackupImportResult(status: rejection.status, message: rejection.message);
    }
  }

  /// Replaces the whole configuration with the contents of [file].
  ///
  /// Fully validated first: an unreadable, truncated, non-JSON or wrongly
  /// typed file is refused before the first row is written, so a bad file
  /// cannot leave a half-restored launcher behind. The database part then runs
  /// inside a single Drift transaction, and the preferences are written only
  /// once that transaction has committed — a rolled-back database must not be
  /// left paired with restored settings.
  ///
  /// Replaces, never merges: resolving conflicts of ordering and category
  /// membership is enormous complexity for what is really "give me my
  /// configuration back" (see the PRD, section 11).
  ///
  /// See the class documentation for what the caller must do afterwards: this
  /// service does not, and cannot, refresh the other services' in-memory
  /// state.
  Future<BackupImportResult> importBackup(File file) async {
    final _Backup backup;
    final _RestorePlan plan;
    try {
      backup = await _parse(file);
      plan = _plan(backup, await _installedPackageNames(), await _recordedWallpaperNames());
    } on _BackupRejected catch (rejection) {
      return BackupImportResult(status: rejection.status, message: rejection.message);
    }

    try {
      await _restoreDatabase(plan);
    } catch (e) {
      // The transaction rolled back, so the database still holds exactly what
      // it held before this call, and no preference has been touched yet.
      return BackupImportResult(
        status: BackupImportStatus.restoreFailed,
        message: "The database transaction was rolled back: $e",
        skippedPackageNames: plan.skippedPackageNames,
        wallpapersToReselect: plan.wallpapersToReselect,
      );
    }

    final settingsRestored = await _restoreSettings(backup.settings);
    return _resultFor(
      settingsRestored ? BackupImportStatus.succeeded : BackupImportStatus.settingsRestoreIncomplete,
      plan,
      message: settingsRestored ? null : "The database was restored but some preferences could not be written",
    );
  }

  BackupImportResult _resultFor(BackupImportStatus status, _RestorePlan plan, {String? message}) => BackupImportResult(
        status: status,
        skippedPackageNames: plan.skippedPackageNames,
        wallpapersToReselect: plan.wallpapersToReselect,
        restoredSettings: plan.settingsCount,
        restoredApps: plan.apps.length,
        restoredCategories: plan.categories.length,
        restoredAppsCategories: plan.appsCategories.length,
        restoredSpacers: plan.spacers.length,
        message: message,
      );

  /// Reads and fully validates [file]. Throws [_BackupRejected] — never a raw
  /// exception — for anything the caller has to be told about.
  Future<_Backup> _parse(File file) async {
    if (!await file.exists()) {
      throw _BackupRejected(BackupImportStatus.fileNotFound, "No file at ${file.path}");
    }

    final String contents;
    try {
      contents = await file.readAsString();
    } catch (e) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The file could not be read: $e");
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } catch (e) {
      // Covers a truncated file, a binary file, and anything that is not JSON.
      throw _BackupRejected(BackupImportStatus.invalidFile, "The file is not valid JSON: $e");
    }
    if (decoded is! Map<String, dynamic>) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The file's root is not a JSON object");
    }

    final schemaVersion = decoded["schemaVersion"];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw _BackupRejected(
        BackupImportStatus.invalidFile,
        "Missing or malformed mandatory 'schemaVersion' field: $schemaVersion",
      );
    }
    if (schemaVersion > backupSchemaVersion) {
      throw _BackupRejected(
        BackupImportStatus.unsupportedVersion,
        "The file's format version is $schemaVersion; this build understands up to $backupSchemaVersion",
      );
    }
    // Second guard, on the database side: a file from a build with a newer SQL
    // schema may describe rows whose meaning has changed, which the format
    // version alone would not catch.
    final databaseSchemaVersion = decoded["databaseSchemaVersion"];
    if (databaseSchemaVersion is int && databaseSchemaVersion > _database.schemaVersion) {
      throw _BackupRejected(
        BackupImportStatus.unsupportedVersion,
        "The file's database schema version is $databaseSchemaVersion;"
        " this build uses ${_database.schemaVersion}",
      );
    }

    final settings = _parseSettings(decoded["settings"]);
    final wallpapers = _parseWallpapers(decoded["wallpapers"]);

    final database = decoded["database"];
    if (database is! Map<String, dynamic>) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The 'database' field is missing or is not an object");
    }

    return _Backup(
      settings: settings,
      wallpapers: wallpapers,
      apps: _parseTable(database, "apps", _appFromJson),
      categories: _parseTable(database, "categories", _categoryFromJson),
      appsCategories: _parseTable(database, "apps_categories", _appCategoryFromJson),
      spacers: _parseTable(database, "launcher_spacers", _spacerFromJson),
    );
  }

  static Map<String, Object> _parseSettings(Object? raw) {
    if (raw == null) {
      return const {};
    }
    if (raw is! Map<String, dynamic>) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The 'settings' field is not an object");
    }
    final settings = <String, Object>{};
    raw.forEach((key, value) {
      if (!_isExportableSettingKey(key)) {
        // A hand-edited file must not be able to point a banner at an
        // arbitrary path on this device.
        return;
      }
      if (value is bool || value is int || value is double || value is String) {
        settings[key] = value as Object;
      } else if (value is List) {
        if (!value.every((element) => element is String)) {
          throw _BackupRejected(
            BackupImportStatus.invalidFile,
            "Setting '$key' is a list with non-string elements",
          );
        }
        settings[key] = List<String>.from(value);
      } else {
        throw _BackupRejected(
          BackupImportStatus.invalidFile,
          "Setting '$key' has an unsupported value type: ${value.runtimeType}",
        );
      }
    });
    return settings;
  }

  static List<String> _parseWallpapers(Object? raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List || !raw.every((element) => element is String)) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The 'wallpapers' field is not a list of strings");
    }
    return List<String>.from(raw);
  }

  static List<T> _parseTable<T>(
    Map<String, dynamic> database,
    String table,
    T Function(Map<String, dynamic> row, String table) fromJson,
  ) {
    final raw = database[table];
    if (raw == null) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The '$table' table is missing");
    }
    if (raw is! List) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "The '$table' table is not a list");
    }
    return raw.map((row) {
      if (row is! Map<String, dynamic>) {
        throw _BackupRejected(BackupImportStatus.invalidFile, "A row of '$table' is not an object");
      }
      return fromJson(row, table);
    }).toList(growable: false);
  }

  static AppsCompanion _appFromJson(Map<String, dynamic> row, String table) => AppsCompanion.insert(
        packageName: _requiredString(row, "package_name", table),
        name: _requiredString(row, "name", table),
        version: _requiredString(row, "version", table),
        hidden: Value(_optionalBool(row, "hidden", table) ?? false),
        lastLaunchedAt: Value(_optionalDateTime(row, "last_launched_at", table)),
      );

  static CategoriesCompanion _categoryFromJson(Map<String, dynamic> row, String table) => CategoriesCompanion.insert(
        id: Value(_requiredInt(row, "id", table)),
        name: _requiredString(row, "name", table),
        order: _requiredInt(row, "order", table),
        sort: Value(_enumValue(CategorySort.values, _optionalInt(row, "sort", table), Category.Sort)),
        type: Value(_enumValue(CategoryType.values, _optionalInt(row, "type", table), Category.Type)),
        rowHeight: Value(_optionalInt(row, "row_height", table) ?? Category.RowHeight),
        columnsCount: Value(_optionalInt(row, "columns_count", table) ?? Category.ColumnsCount),
      );

  static AppsCategoriesCompanion _appCategoryFromJson(Map<String, dynamic> row, String table) =>
      AppsCategoriesCompanion.insert(
        categoryId: _requiredInt(row, "category_id", table),
        appPackageName: _requiredString(row, "app_package_name", table),
        order: _requiredInt(row, "order", table),
      );

  static LauncherSpacersCompanion _spacerFromJson(Map<String, dynamic> row, String table) =>
      LauncherSpacersCompanion.insert(
        id: Value(_requiredInt(row, "id", table)),
        height: _requiredInt(row, "height", table),
        order: _requiredInt(row, "order", table),
      );

  /// Resolves a persisted enum index, degrading to [fallback] when it names no
  /// known value — the same rule `WallpaperService` applies to an unknown
  /// gradient uuid. A category whose sort mode this build does not know must
  /// still come back, with the default sort, rather than sink the whole
  /// restore.
  static T _enumValue<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) {
      return fallback;
    }
    return values[index];
  }

  static String _requiredString(Map<String, dynamic> row, String field, String table) {
    final value = row[field];
    if (value is! String) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is missing or is not a string");
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> row, String field, String table) {
    final value = row[field];
    if (value is! int) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is missing or is not an integer");
    }
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> row, String field, String table) {
    final value = row[field];
    if (value == null) {
      return null;
    }
    if (value is! int) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is not an integer");
    }
    return value;
  }

  static bool? _optionalBool(Map<String, dynamic> row, String field, String table) {
    final value = row[field];
    if (value == null) {
      return null;
    }
    if (value is! bool) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is not a boolean");
    }
    return value;
  }

  static DateTime? _optionalDateTime(Map<String, dynamic> row, String field, String table) {
    final value = row[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is not an ISO-8601 string");
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw _BackupRejected(BackupImportStatus.invalidFile, "'$table.$field' is not an ISO-8601 date: $value");
    }
    return parsed;
  }

  /// The packages currently installed on the device.
  ///
  /// An empty answer is treated as a failure, never as "nothing is installed":
  /// this launcher is itself an installed package, so an empty list means the
  /// platform channel did not answer. Believing it would skip every app in the
  /// file and restore an empty dock.
  Future<Set<String>> _installedPackageNames() async {
    final List<Map<dynamic, dynamic>> applications;
    try {
      applications = await _fLauncherChannel.getApplications();
    } catch (e) {
      throw _BackupRejected(
        BackupImportStatus.installedAppsUnavailable,
        "The list of installed applications could not be read: $e",
      );
    }
    final packageNames = <String>{};
    for (final application in applications) {
      final packageName = application["packageName"];
      if (packageName is String) {
        packageNames.add(packageName);
      }
    }
    if (packageNames.isEmpty) {
      throw _BackupRejected(
        BackupImportStatus.installedAppsUnavailable,
        "The platform reported no installed application at all",
      );
    }
    return packageNames;
  }

  /// Decides what will actually be written: apps whose package is gone are
  /// dropped, and so are the category memberships that referred to them, so no
  /// dock entry is left pointing at nothing.
  ///
  /// [presentWallpaperNames] are the wallpaper files this device already has;
  /// a wallpaper the file recorded but this device does not have is one the
  /// user will have to pick again, since no binary ever travels in a backup.
  _RestorePlan _plan(
    _Backup backup,
    Set<String> installedPackageNames,
    List<String> presentWallpaperNames,
  ) {
    final keptApps = <AppsCompanion>[];
    final skipped = <String>[];
    final keptPackageNames = <String>{};
    for (final app in backup.apps) {
      final packageName = app.packageName.value;
      if (installedPackageNames.contains(packageName)) {
        keptApps.add(app);
        keptPackageNames.add(packageName);
      } else if (!skipped.contains(packageName)) {
        skipped.add(packageName);
      }
    }

    final categoryIds = backup.categories.map((category) => category.id.value).toSet();
    final keptAppsCategories = backup.appsCategories
        .where((entry) =>
            keptPackageNames.contains(entry.appPackageName.value) && categoryIds.contains(entry.categoryId.value))
        .toList(growable: false);

    return _RestorePlan(
      apps: keptApps,
      categories: backup.categories,
      appsCategories: keptAppsCategories,
      spacers: backup.spacers,
      settingsCount: backup.settings.length,
      skippedPackageNames: skipped,
      wallpapersToReselect:
          backup.wallpapers.where((name) => !presentWallpaperNames.contains(name)).toList(growable: false),
    );
  }

  /// Replaces the contents of the four tables in **one** transaction: either
  /// every row of the plan lands, or the database is left exactly as it was.
  /// Drift rolls the transaction back when the body throws, and rethrows.
  ///
  /// Order matters: the child rows go first on the way out and last on the way
  /// in, because `apps_categories` references both `apps` and `categories` and
  /// `PRAGMA foreign_keys` is ON (see `FLauncherDatabase.migration`).
  Future<void> _restoreDatabase(_RestorePlan plan) => _database.transaction(() async {
        await _database.delete(_database.appsCategories).go();
        await _database.delete(_database.launcherSpacers).go();
        await _database.delete(_database.categories).go();
        await _database.delete(_database.apps).go();

        for (final app in plan.apps) {
          await _database.into(_database.apps).insert(app);
        }
        for (final category in plan.categories) {
          await _database.into(_database.categories).insert(category);
        }
        for (final spacer in plan.spacers) {
          await _database.into(_database.launcherSpacers).insert(spacer);
        }
        for (final entry in plan.appsCategories) {
          await _database.into(_database.appsCategories).insert(entry);
        }
      });

  /// Replaces every exportable preference with the file's values.
  ///
  /// Removes the current ones first, so a key absent from the file falls back
  /// to its default: a restore replaces, it does not merge. Returns `false`
  /// when at least one write failed, which the caller reports as
  /// [BackupImportStatus.settingsRestoreIncomplete] — `shared_preferences` has
  /// no transaction, so this cannot be made atomic and is surfaced instead.
  Future<bool> _restoreSettings(Map<String, Object> settings) async {
    var complete = true;
    for (final key in _sharedPreferences.getKeys().where(_isExportableSettingKey).toList(growable: false)) {
      try {
        await _sharedPreferences.remove(key);
      } catch (e) {
        debugPrint("BackupService: could not remove preference '$key' ($e)");
        complete = false;
      }
    }
    for (final entry in settings.entries) {
      try {
        if (!await _writeSetting(entry.key, entry.value)) {
          complete = false;
        }
      } catch (e) {
        debugPrint("BackupService: could not write preference '${entry.key}' ($e)");
        complete = false;
      }
    }
    return complete;
  }

  Future<bool> _writeSetting(String key, Object value) async {
    if (value is bool) {
      return _sharedPreferences.setBool(key, value);
    }
    if (value is int) {
      return _sharedPreferences.setInt(key, value);
    }
    if (value is double) {
      return _sharedPreferences.setDouble(key, value);
    }
    if (value is String) {
      return _sharedPreferences.setString(key, value);
    }
    if (value is List<String>) {
      return _sharedPreferences.setStringList(key, value);
    }
    // Unreachable: _parseSettings rejects every other type.
    debugPrint("BackupService: ignoring preference '$key' of unsupported type ${value.runtimeType}");
    return false;
  }
}

/// A validated backup file, still unfiltered: every row it holds is
/// well-formed, but nothing has been checked against what is installed.
class _Backup {
  final Map<String, Object> settings;
  final List<String> wallpapers;
  final List<AppsCompanion> apps;
  final List<CategoriesCompanion> categories;
  final List<AppsCategoriesCompanion> appsCategories;
  final List<LauncherSpacersCompanion> spacers;

  const _Backup({
    required this.settings,
    required this.wallpapers,
    required this.apps,
    required this.categories,
    required this.appsCategories,
    required this.spacers,
  });
}

/// Exactly what a restore will write, and what it will leave out.
class _RestorePlan {
  final List<AppsCompanion> apps;
  final List<CategoriesCompanion> categories;
  final List<AppsCategoriesCompanion> appsCategories;
  final List<LauncherSpacersCompanion> spacers;
  final int settingsCount;
  final List<String> skippedPackageNames;
  final List<String> wallpapersToReselect;

  const _RestorePlan({
    required this.apps,
    required this.categories,
    required this.appsCategories,
    required this.spacers,
    required this.settingsCount,
    required this.skippedPackageNames,
    required this.wallpapersToReselect,
  });
}

/// Internal signal carrying the refusal the caller must be told about. Never
/// escapes the service: both public import methods turn it into a
/// [BackupImportResult].
class _BackupRejected implements Exception {
  final BackupImportStatus status;
  final String message;

  _BackupRejected(this.status, this.message);

  @override
  String toString() => "BackupRejected($status): $message";
}
