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

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();

  late Directory temporaryRoot;
  late Directory externalDirectory;
  late Directory documentsDirectory;
  late FLauncherDatabase database;
  late SharedPreferences sharedPreferences;
  late MockFLauncherChannel channel;
  late BackupService backupService;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp("backup_service_test");
    externalDirectory = await Directory("${temporaryRoot.path}/external").create();
    documentsDirectory = await Directory("${temporaryRoot.path}/documents").create();
    PathProviderPlatform.instance = _FakePathProviderPlatform(documentsDirectory.path, externalDirectory.path);

    database = FLauncherDatabase.inMemory();
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.clear();
    channel = MockFLauncherChannel();
    // Every app seeded by [seedDatabase] is installed unless a test says
    // otherwise: an import validates each packageName against this list.
    when(channel.getApplications()).thenAnswer((_) => Future.value([
          {"packageName": "com.example.one", "name": "One", "version": "1.0.0", "sideloaded": false},
          {"packageName": "com.example.two", "name": "Two", "version": "2.0.0", "sideloaded": false},
        ]));

    backupService = BackupService(database, sharedPreferences, channel);
  });

  tearDown(() async {
    await database.close();
    await temporaryRoot.delete(recursive: true);
  });

  /// Seeds the four tables with a configuration that exercises every column
  /// the backup carries, including `last_launched_at` (which the `App` row
  /// class silently drops, see BackupService._exportRows).
  Future<void> seedDatabase() async {
    await database.into(database.apps).insert(AppsCompanion.insert(
          packageName: "com.example.one",
          name: "One",
          version: "1.0.0",
          hidden: const Value(false),
          lastLaunchedAt: Value(DateTime.fromMillisecondsSinceEpoch(1700000000000)),
        ));
    await database.into(database.apps).insert(AppsCompanion.insert(
          packageName: "com.example.two",
          name: "Two",
          version: "2.0.0",
          hidden: const Value(true),
        ));
    await database.into(database.categories).insert(CategoriesCompanion.insert(
          id: const Value(1),
          name: "Favorites",
          order: 0,
          sort: const Value(CategorySort.manual),
          type: const Value(CategoryType.row),
          rowHeight: const Value(120),
          columnsCount: const Value(5),
        ));
    await database.into(database.categories).insert(CategoriesCompanion.insert(
          id: const Value(2),
          name: "All Apps",
          order: 1,
          sort: const Value(CategorySort.alphabetical),
          type: const Value(CategoryType.grid),
        ));
    await database.into(database.launcherSpacers).insert(
          LauncherSpacersCompanion.insert(id: const Value(1), height: 42, order: 2),
        );
    await database.into(database.appsCategories).insert(
          AppsCategoriesCompanion.insert(categoryId: 1, appPackageName: "com.example.one", order: 0),
        );
    await database.into(database.appsCategories).insert(
          AppsCategoriesCompanion.insert(categoryId: 2, appPackageName: "com.example.two", order: 0),
        );
  }

  /// Seeds preferences covering every supported value type, plus the two keys
  /// the scenes feature persists.
  Future<void> seedPreferences() async {
    await sharedPreferences.setBool("auto_hide_app_bar", true);
    await sharedPreferences.setString("accent_color", "00BFA5");
    await sharedPreferences.setInt("brightness_night", 12);
    await sharedPreferences.setDouble("some_double", 1.5);
    await sharedPreferences.setStringList("some_list", ["a", "b"]);
    await sharedPreferences.setString("scenes", '{"version":2,"scenes":[{"key":"normal","name":"Normal"}]}');
    await sharedPreferences.setString("active_scene_key", "normal");
  }

  /// The raw contents of the four tables, in a form two snapshots can be
  /// compared with: used to prove a refused or rolled back import changed
  /// nothing at all.
  Future<Map<String, List<Map<String, Object?>>>> databaseSnapshot() async {
    Future<List<Map<String, Object?>>> dump(String sql) async =>
        (await database.customSelect(sql).get()).map((row) => row.data).toList();
    return {
      "apps": await dump("SELECT * FROM apps ORDER BY package_name"),
      "categories": await dump('SELECT * FROM categories ORDER BY id'),
      "apps_categories": await dump('SELECT * FROM apps_categories ORDER BY category_id, app_package_name'),
      "launcher_spacers": await dump('SELECT * FROM launcher_spacers ORDER BY id'),
    };
  }

  Map<String, Object?> preferencesSnapshot() =>
      {for (final key in sharedPreferences.getKeys()) key: sharedPreferences.get(key)};

  File writeBackupFile(Object? payload) {
    final file = File("${temporaryRoot.path}/backup.json");
    file.writeAsStringSync(payload is String ? payload : jsonEncode(payload));
    return file;
  }

  /// A minimal, valid backup, so each test can alter exactly the one thing it
  /// is about.
  Map<String, Object?> validPayload({
    int schemaVersion = backupSchemaVersion,
    Map<String, Object?>? settings,
    List<Object?>? apps,
    List<Object?>? categories,
    List<Object?>? appsCategories,
    List<Object?>? spacers,
    List<Object?>? wallpapers,
    int? databaseSchemaVersion,
  }) =>
      {
        "schemaVersion": schemaVersion,
        "createdAt": "2026-07-25T10:00:00.000",
        "databaseSchemaVersion": databaseSchemaVersion ?? database.schemaVersion,
        "settings": settings ?? {"accent_color": "7C4DFF"},
        "wallpapers": wallpapers ?? const <Object?>[],
        "database": {
          "apps": apps ??
              [
                {"package_name": "com.example.one", "name": "One", "version": "1.0.0", "hidden": false}
              ],
          "categories": categories ??
              [
                {
                  "id": 1,
                  "name": "Favorites",
                  "sort": 0,
                  "type": 0,
                  "row_height": 110,
                  "columns_count": 6,
                  "order": 0
                }
              ],
          "apps_categories": appsCategories ??
              [
                {"category_id": 1, "app_package_name": "com.example.one", "order": 0}
              ],
          "launcher_spacers": spacers ?? const <Object?>[],
        },
      };

  group("export", () {
    test("writes a JSON file into the app's own external storage directory", () async {
      await seedDatabase();
      await seedPreferences();
      backupService.debugNow = () => DateTime(2026, 7, 25, 14, 5, 9);

      final result = await backupService.exportBackup();

      expect(result.status, BackupExportStatus.succeeded);
      expect(result.filePath, "${externalDirectory.path}/lemonade-launcher-backup-20260725-140509.json");
      expect(File(result.filePath!).existsSync(), isTrue);
    });

    test("records the format version, the settings, the scenes payload and every table row", () async {
      await seedDatabase();
      await seedPreferences();

      final result = await backupService.exportBackup();
      final payload = jsonDecode(await File(result.filePath!).readAsString()) as Map<String, dynamic>;

      expect(payload["schemaVersion"], backupSchemaVersion);
      expect(payload["databaseSchemaVersion"], database.schemaVersion);
      final settings = payload["settings"] as Map<String, dynamic>;
      expect(settings["auto_hide_app_bar"], true);
      expect(settings["accent_color"], "00BFA5");
      expect(settings["brightness_night"], 12);
      expect(settings["some_double"], 1.5);
      expect(settings["some_list"], ["a", "b"]);
      expect(settings["scenes"], '{"version":2,"scenes":[{"key":"normal","name":"Normal"}]}');
      expect(settings["active_scene_key"], "normal");

      final tables = payload["database"] as Map<String, dynamic>;
      expect((tables["apps"] as List).length, 2);
      expect((tables["categories"] as List).length, 2);
      expect((tables["apps_categories"] as List).length, 2);
      expect((tables["launcher_spacers"] as List).length, 1);
      expect((tables["apps"] as List).first["last_launched_at"], isNotNull);
      expect(result.appsCount, 2);
      expect(result.categoriesCount, 2);
      expect(result.settingsCount, settings.length);
    });

    test("leaves per-app custom banner paths out: they point at files the backup does not carry", () async {
      await sharedPreferences.setString("custom_banner_com.example.one", "/data/user/0/pictures/banner.png");
      await sharedPreferences.setString("accent_color", "00BFA5");

      final result = await backupService.exportBackup();
      final payload = jsonDecode(await File(result.filePath!).readAsString()) as Map<String, dynamic>;

      expect((payload["settings"] as Map<String, dynamic>).containsKey("custom_banner_com.example.one"), isFalse);
      expect((payload["settings"] as Map<String, dynamic>)["accent_color"], "00BFA5");
    });

    test("records the wallpaper names but never their bytes", () async {
      // 200 KB, the order of magnitude of a still image; a video wallpaper is
      // tens of megabytes, which is why no binary is ever included.
      await File("${documentsDirectory.path}/wallpaper").writeAsBytes(List.filled(200 * 1024, 0x42));
      await File("${documentsDirectory.path}/scene_wallpaper_cinema").writeAsBytes(List.filled(1024, 0x43));

      final result = await backupService.exportBackup();
      final exported = File(result.filePath!);
      final payload = jsonDecode(await exported.readAsString()) as Map<String, dynamic>;

      expect(payload["wallpapers"], containsAll(["wallpaper", "scene_wallpaper_cinema"]));
      expect(result.wallpapersNotIncluded, containsAll(["wallpaper", "scene_wallpaper_cinema"]));
      expect(await exported.length(), lessThan(4096));
    });
  });

  group("import", () {
    test("round trip: importing an exported file reproduces the settings and the table rows", () async {
      await seedDatabase();
      await seedPreferences();
      final exported = await backupService.exportBackup();
      final expectedDatabase = await databaseSnapshot();
      final expectedPreferences = preferencesSnapshot();

      // Wipe everything the backup owns, the way a reinstall would.
      await database.customStatement("DELETE FROM apps_categories");
      await database.customStatement("DELETE FROM launcher_spacers");
      await database.customStatement("DELETE FROM categories");
      await database.customStatement("DELETE FROM apps");
      await sharedPreferences.clear();

      final result = await backupService.importBackup(File(exported.filePath!));

      expect(result.status, BackupImportStatus.succeeded);
      expect(result.skippedPackageNames, isEmpty);
      expect(await databaseSnapshot(), expectedDatabase);
      expect(preferencesSnapshot(), expectedPreferences);
    });

    test("replaces instead of merging: rows and settings absent from the file are gone afterwards", () async {
      await seedDatabase();
      await sharedPreferences.setBool("show_focus_borders", false);

      final result = await backupService.importBackup(File(writeBackupFile(validPayload()).path));

      expect(result.status, BackupImportStatus.succeeded);
      final snapshot = await databaseSnapshot();
      expect(snapshot["apps"]!.map((row) => row["package_name"]), ["com.example.one"]);
      expect(snapshot["categories"]!.map((row) => row["name"]), ["Favorites"]);
      expect(snapshot["launcher_spacers"], isEmpty);
      expect(sharedPreferences.containsKey("show_focus_borders"), isFalse);
      expect(sharedPreferences.getString("accent_color"), "7C4DFF");
    });

    test("refuses a file whose format version is newer than this build understands", () async {
      await seedDatabase();
      final before = await databaseSnapshot();
      final file = writeBackupFile(validPayload(schemaVersion: backupSchemaVersion + 1));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.unsupportedVersion);
      expect(await databaseSnapshot(), before);
    });

    test("refuses a file whose database schema version is newer than this build's", () async {
      await seedDatabase();
      final before = await databaseSnapshot();
      final file = writeBackupFile(validPayload(databaseSchemaVersion: database.schemaVersion + 1));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.unsupportedVersion);
      expect(await databaseSnapshot(), before);
    });

    test("refuses a file with no schemaVersion at all", () async {
      final payload = validPayload()..remove("schemaVersion");

      final result = await backupService.importBackup(writeBackupFile(payload));

      expect(result.status, BackupImportStatus.invalidFile);
    });

    test("refuses a corrupt file and leaves the database and the settings untouched", () async {
      await seedDatabase();
      await seedPreferences();
      final expectedDatabase = await databaseSnapshot();
      final expectedPreferences = preferencesSnapshot();
      // A truncated JSON file: what a copy interrupted halfway leaves behind.
      final file = writeBackupFile('{"schemaVersion": 1, "database": {"apps": [{"package_');

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.invalidFile);
      expect(await databaseSnapshot(), expectedDatabase);
      expect(preferencesSnapshot(), expectedPreferences);
    });

    test("refuses a file that is not JSON at all and changes nothing", () async {
      await seedDatabase();
      final expectedDatabase = await databaseSnapshot();

      final result = await backupService.importBackup(writeBackupFile("this is not a backup"));

      expect(result.status, BackupImportStatus.invalidFile);
      expect(await databaseSnapshot(), expectedDatabase);
    });

    test("refuses a file with a wrongly typed row field and changes nothing", () async {
      await seedDatabase();
      final expectedDatabase = await databaseSnapshot();
      final file = writeBackupFile(validPayload(categories: [
        {"id": "one", "name": "Favorites", "order": 0}
      ]));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.invalidFile);
      expect(result.message, contains("categories.id"));
      expect(await databaseSnapshot(), expectedDatabase);
    });

    test("reports a missing file", () async {
      final result = await backupService.importBackup(File("${temporaryRoot.path}/does-not-exist.json"));

      expect(result.status, BackupImportStatus.fileNotFound);
    });

    test("skips apps that are no longer installed, and their category memberships, and reports them", () async {
      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {"packageName": "com.example.one", "name": "One", "version": "1.0.0", "sideloaded": false},
          ]));
      final file = writeBackupFile(validPayload(
        apps: [
          {"package_name": "com.example.one", "name": "One", "version": "1.0.0", "hidden": false},
          {"package_name": "com.example.gone", "name": "Gone", "version": "1.0.0", "hidden": false},
        ],
        appsCategories: [
          {"category_id": 1, "app_package_name": "com.example.one", "order": 0},
          {"category_id": 1, "app_package_name": "com.example.gone", "order": 1},
        ],
      ));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.succeeded);
      expect(result.skippedPackageNames, ["com.example.gone"]);
      final snapshot = await databaseSnapshot();
      expect(snapshot["apps"]!.map((row) => row["package_name"]), ["com.example.one"]);
      expect(snapshot["apps_categories"]!.map((row) => row["app_package_name"]), ["com.example.one"]);
    });

    test("refuses to restore when the installed applications cannot be listed", () async {
      when(channel.getApplications()).thenAnswer((_) => Future.error(Exception("channel unavailable")));
      await seedDatabase();
      final expectedDatabase = await databaseSnapshot();

      final result = await backupService.importBackup(writeBackupFile(validPayload()));

      expect(result.status, BackupImportStatus.installedAppsUnavailable);
      expect(await databaseSnapshot(), expectedDatabase);
    });

    test("refuses to restore when the platform reports no installed application at all", () async {
      when(channel.getApplications()).thenAnswer((_) => Future.value([]));
      await seedDatabase();
      final expectedDatabase = await databaseSnapshot();

      final result = await backupService.importBackup(writeBackupFile(validPayload()));

      expect(result.status, BackupImportStatus.installedAppsUnavailable);
      expect(await databaseSnapshot(), expectedDatabase);
    });

    test("is atomic: a row that fails partway rolls the whole restore back, settings included", () async {
      await seedDatabase();
      await seedPreferences();
      final expectedDatabase = await databaseSnapshot();
      final expectedPreferences = preferencesSnapshot();
      // Two categories with the same primary key: the shape is valid, so this
      // gets past validation and fails on the second insert, halfway through
      // the transaction.
      final file = writeBackupFile(validPayload(categories: [
        {"id": 7, "name": "Favorites", "sort": 0, "type": 0, "row_height": 110, "columns_count": 6, "order": 0},
        {"id": 7, "name": "All Apps", "sort": 0, "type": 1, "row_height": 110, "columns_count": 6, "order": 1},
      ], appsCategories: const <Object?>[]));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.restoreFailed);
      expect(await databaseSnapshot(), expectedDatabase);
      // Proof that the settings are written only after the transaction commits.
      expect(preferencesSnapshot(), expectedPreferences);
    });

    test("degrades an unknown category sort or type to the default instead of failing the restore", () async {
      final file = writeBackupFile(validPayload(categories: [
        {"id": 1, "name": "Favorites", "sort": 99, "type": 99, "row_height": 110, "columns_count": 6, "order": 0}
      ]));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.succeeded);
      final category = (await databaseSnapshot())["categories"]!.single;
      expect(category["sort"], Category.Sort.index);
      expect(category["type"], Category.Type.index);
    });

    test("reports the wallpapers the file recorded that this device no longer has", () async {
      await File("${documentsDirectory.path}/wallpaper").writeAsBytes([0x01]);
      final file = writeBackupFile(validPayload(wallpapers: ["wallpaper", "wallpaper_night_video"]));

      final result = await backupService.importBackup(file);

      expect(result.status, BackupImportStatus.succeeded);
      expect(result.wallpapersToReselect, ["wallpaper_night_video"]);
    });
  });

  group("previewImport", () {
    test("reports what a restore would skip without writing anything", () async {
      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {"packageName": "com.example.one", "name": "One", "version": "1.0.0", "sideloaded": false},
          ]));
      await seedDatabase();
      await seedPreferences();
      final expectedDatabase = await databaseSnapshot();
      final expectedPreferences = preferencesSnapshot();
      final file = writeBackupFile(validPayload(
        apps: [
          {"package_name": "com.example.one", "name": "One", "version": "1.0.0", "hidden": false},
          {"package_name": "com.example.gone", "name": "Gone", "version": "1.0.0", "hidden": false},
        ],
        wallpapers: ["wallpaper_video"],
      ));

      final result = await backupService.previewImport(file);

      expect(result.status, BackupImportStatus.succeeded);
      expect(result.skippedPackageNames, ["com.example.gone"]);
      expect(result.wallpapersToReselect, ["wallpaper_video"]);
      expect(result.restoredApps, 1);
      expect(await databaseSnapshot(), expectedDatabase);
      expect(preferencesSnapshot(), expectedPreferences);
    });

    test("reports the same refusal an import would, without writing anything", () async {
      await seedDatabase();
      final expectedDatabase = await databaseSnapshot();
      final file = writeBackupFile(validPayload(schemaVersion: backupSchemaVersion + 1));

      final result = await backupService.previewImport(file);

      expect(result.status, BackupImportStatus.unsupportedVersion);
      expect(await databaseSnapshot(), expectedDatabase);
    });
  });
}

/// Points `path_provider` at throwaway directories: the documents directory
/// where the wallpapers live, and the app's own external storage directory
/// where a backup is written.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;
  final String externalPath;

  _FakePathProviderPlatform(this.documentsPath, this.externalPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getExternalStoragePath() async => externalPath;
}
