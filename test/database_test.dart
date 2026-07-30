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

import 'package:flauncher/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;

void main() {
  late FLauncherDatabase database;
  setUp(() {
    database = FLauncherDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test("getApplications", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");

    final apps = await database.getApplications();

    expect(apps.length, 1);
    expect(apps[0].packageName, "me.efesser.flauncher");
    expect(apps[0].name, "FLauncher");
    expect(apps[0].version, "1.0.0");
  });

  test("persistApps", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    await database.persistApps(
        [AppsCompanion.insert(packageName: "me.efesser.flauncher", name: "FLauncher 2", version: "1.1.0")]);

    final app = await database.customSelect("SELECT * FROM apps;").getSingle();
    expect(app.read<String>("package_name"), "me.efesser.flauncher");
    expect(app.read<String>("name"), "FLauncher 2");
    expect(app.read<String>("version"), "1.1.0");
  });

  test("updateApp", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version, hidden)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0', false);");
    await database.updateApp("me.efesser.flauncher", AppsCompanion(hidden: Value(true)));

    final app = await database.customSelect("SELECT * FROM apps;").getSingle();
    expect(app.read<String>("package_name"), "me.efesser.flauncher");
    expect(app.read<String>("name"), "FLauncher");
    expect(app.read<String>("version"), "1.0.0");
    expect(app.read<bool>("hidden"), true);
  });

  test("getApplications round-trips lastLaunchedAt for \"Last Used\" sorting", () async {
    final older = DateTime.fromMillisecondsSinceEpoch(1000);
    final newer = DateTime.fromMillisecondsSinceEpoch(2000);

    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.older', 'Older', '1.0.0');");
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.newer', 'Newer', '1.0.0');");

    await database.updateApp("me.efesser.older", AppsCompanion(lastLaunchedAt: Value(older)));
    await database.updateApp("me.efesser.newer", AppsCompanion(lastLaunchedAt: Value(newer)));

    final apps = await database.getApplications();
    final olderApp = apps.firstWhere((app) => app.packageName == "me.efesser.older");
    final newerApp = apps.firstWhere((app) => app.packageName == "me.efesser.newer");

    // The column is written correctly (proven independently); the bug is that
    // App's constructor didn't accept it, so drift's generated mapper never
    // read it back, and lastLaunchedAt was always null after a DB round trip.
    expect(olderApp.lastLaunchedAt, older);
    expect(newerApp.lastLaunchedAt, newer);

    // This is exactly what AppsService.sortCategory does for CategorySort.lastUsed:
    // without the fix both fall back to epoch zero and tie, so the sort is a no-op.
    final sorted = [olderApp, newerApp]..sort((a, b) {
      final aTime = a.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    expect(sorted.map((app) => app.packageName).toList(), ["me.efesser.newer", "me.efesser.older"]);
  });

  test("deleteApps", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher.2', 'FLauncher 2', '1.0.0');");

    await database.deleteApps(["me.efesser.flauncher"]);

    final app = await database.customSelect("SELECT * FROM apps;").getSingle();
    expect(app.read<String>("package_name"), "me.efesser.flauncher.2");
  });

  test("insertCategory", () async {
    await database.insertCategory(CategoriesCompanion.insert(name: "Test", order: 2));

    final category = await database.customSelect("SELECT * FROM categories WHERE name = 'Test';").getSingle();
    expect(category.read<String>("name"), "Test");
    expect(category.read<int>("order"), 2);
  });

  test("deleteCategory", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher', 0);");

    await database.deleteCategory(categoryId);

    final app = await database.customSelect("SELECT * FROM apps;").getSingle();
    expect(app.read<String>("package_name"), "me.efesser.flauncher");
    final appsCategories = await database.customSelect("SELECT * FROM apps_categories;").get();
    expect(appsCategories, isEmpty);
    final categories = await database.customSelect("SELECT * FROM categories c ORDER BY c.'order' ASC;").get();
    expect(categories, isEmpty);
  });

  test("updateCategories", () async {
    final test1Id = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test 1', 2);");
    final test2Id = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test 2', 3);");

    await database.updateCategories([
      CategoriesCompanion(id: Value(test2Id), order: Value(2)),
      CategoriesCompanion(id: Value(test1Id), order: Value(3)),
    ]);

    final categories = await database.customSelect("SELECT * FROM categories c ORDER BY c.'order' ASC;").get();
    expect(categories.length, 2);
    expect(categories[0].read<String>("name"), "Test 2");
    expect(categories[1].read<String>("name"), "Test 1");
  });

  test("updateCategory", () async {
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");

    await database.updateCategory(categoryId, CategoriesCompanion(order: Value(5)));

    final categories = await database.customSelect("SELECT * FROM categories c ORDER BY c.'order' ASC;").get();
    expect(categories.length, 1);
    expect(categories[0].read<String>("name"), "Test");
    expect(categories[0].read<int>("order"), 5);
  });

  test("deleteAppCategory", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher', 0);");

    await database.deleteAppCategory(categoryId, "me.efesser.flauncher");

    final app = await database.customSelect("SELECT * FROM apps;").getSingle();
    expect(app.read<String>("package_name"), "me.efesser.flauncher");
    final appsCategories = await database.customSelect("SELECT * FROM apps_categories;").get();
    expect(appsCategories, isEmpty);
    final categories = await database.customSelect("SELECT * FROM categories c ORDER BY c.'order' ASC;").get();
    expect(categories.length, 1);
    expect(categories[0].read<String>("name"), "Test");
  });

  test("insertAppsCategories", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order')"
        " VALUES('Test', 2);");
    await database.insertAppsCategories([
      AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 0),
    ]);

    final appCategory = await database.customSelect("SELECT * FROM apps_categories;").getSingle();
    expect(appCategory.read<int>("category_id"), categoryId);
    expect(appCategory.read<String>("app_package_name"), "me.efesser.flauncher");
    expect(appCategory.read<int>("order"), 0);
  });

  test("replaceAppsCategories", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher', 0);");

    await database.replaceAppsCategories(
        [AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 1)]);

    final appCategory = await database.customSelect("SELECT * FROM apps_categories;").getSingle();
    expect(appCategory.read<int>("category_id"), categoryId);
    expect(appCategory.read<String>("app_package_name"), "me.efesser.flauncher");
    expect(appCategory.read<int>("order"), 1);
  });

  test("getAppsCategories", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher.2', 'FLauncher 2', '1.0.0');");
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher.3', 'FLauncher 3', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher', 1);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher.2', 0);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher.3', 2);");

    final appsCategories = await database.getAppsCategories();

    expect(appsCategories.length, 3);
    expect(appsCategories.every((appCategory) => appCategory.categoryId == categoryId), isTrue);
    // Ordered by app_package_name ascending, per FLauncherDatabase.getAppsCategories.
    expect(appsCategories[0].appPackageName, "me.efesser.flauncher");
    expect(appsCategories[0].order, 1);
    expect(appsCategories[1].appPackageName, "me.efesser.flauncher.2");
    expect(appsCategories[1].order, 0);
    expect(appsCategories[2].appPackageName, "me.efesser.flauncher.3");
    expect(appsCategories[2].order, 2);
  });

  test("getCategories orders by category order ascending", () async {
    await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Second', 2);");
    await database.customInsert("INSERT INTO categories(name, 'order') VALUES('First', 1);");

    final categories = await database.getCategories();

    expect(categories.length, 2);
    expect(categories[0].name, "First");
    expect(categories[1].name, "Second");
  });

  group("content shortcuts", () {
    Future<int> insertShortcut({
      required int sectionId,
      required int sectionOrder,
      required int order,
      String label = "Subscriptions",
      String uri = "https://www.youtube.com/feed/subscriptions",
      String targetPackage = "com.teamsmart.videomanager.tv",
    }) =>
        database.insertContentShortcut(ContentShortcutsCompanion.insert(
          sectionId: sectionId,
          sectionOrder: sectionOrder,
          order: order,
          label: label,
          uri: uri,
          targetPackage: targetPackage,
        ));

    test("insertContentShortcut stores every column", () async {
      final id = await insertShortcut(sectionId: 3, sectionOrder: 2, order: 1, label: "Channel");

      final row = await database.customSelect("SELECT * FROM content_shortcuts;").getSingle();
      expect(row.read<int>("id"), id);
      expect(row.read<int>("section_id"), 3);
      expect(row.read<int>("section_order"), 2);
      expect(row.read<int>("order"), 1);
      expect(row.read<String>("label"), "Channel");
      expect(row.read<String>("uri"), "https://www.youtube.com/feed/subscriptions");
      expect(row.read<String>("target_package"), "com.teamsmart.videomanager.tv");
    });

    test("getContentShortcuts orders by section order, then section, then position", () async {
      await insertShortcut(sectionId: 1, sectionOrder: 5, order: 1, label: "Second of late section");
      await insertShortcut(sectionId: 1, sectionOrder: 5, order: 0, label: "First of late section");
      await insertShortcut(sectionId: 2, sectionOrder: 0, order: 0, label: "Only of early section");

      final shortcuts = await database.getContentShortcuts();

      expect(shortcuts.map((shortcut) => shortcut.label),
          ["Only of early section", "First of late section", "Second of late section"]);
    });

    test("updateContentShortcut rewrites one row only", () async {
      final id = await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 1, label: "Untouched");

      await database.updateContentShortcut(
          id, ContentShortcutsCompanion(label: const Value("Renamed"), uri: const Value("youtube://play")));

      final shortcuts = await database.getContentShortcuts();
      expect(shortcuts.firstWhere((shortcut) => shortcut.id == id).label, "Renamed");
      expect(shortcuts.firstWhere((shortcut) => shortcut.id == id).uri, "youtube://play");
      expect(shortcuts.where((shortcut) => shortcut.label == "Untouched").length, 1);
    });

    test("deleteContentShortcut removes one row, deleteContentShortcutSection removes the group", () async {
      final firstOfSectionOne = await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 1);
      await insertShortcut(sectionId: 2, sectionOrder: 1, order: 0, label: "Other section");

      await database.deleteContentShortcut(firstOfSectionOne);
      expect((await database.getContentShortcuts()).length, 2);

      await database.deleteContentShortcutSection(1);
      final remaining = await database.getContentShortcuts();
      expect(remaining.map((shortcut) => shortcut.label), ["Other section"]);
    });

    test("updateContentShortcutSectionOrder moves every row of the section at once", () async {
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 1);
      await insertShortcut(sectionId: 2, sectionOrder: 1, order: 0);

      await database.updateContentShortcutSectionOrder(1, 7);

      final shortcuts = await database.getContentShortcuts();
      expect(shortcuts.where((shortcut) => shortcut.sectionId == 1).map((shortcut) => shortcut.sectionOrder), [7, 7]);
      expect(shortcuts.where((shortcut) => shortcut.sectionId == 2).single.sectionOrder, 1);
    });

    test("updateContentShortcuts writes a batch of positions", () async {
      final first = await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      final second = await insertShortcut(sectionId: 1, sectionOrder: 0, order: 1);

      await database.updateContentShortcuts([
        ContentShortcutsCompanion(id: Value(first), order: const Value(1)),
        ContentShortcutsCompanion(id: Value(second), order: const Value(0)),
      ]);

      final shortcuts = await database.getContentShortcuts();
      expect(shortcuts.map((shortcut) => shortcut.id), [second, first]);
    });

    test("nextContentShortcutSectionId starts at 1 and then follows the highest section", () async {
      expect(await database.nextContentShortcutSectionId(), 1);

      await insertShortcut(sectionId: 4, sectionOrder: 0, order: 0);

      expect(await database.nextContentShortcutSectionId(), 5);
    });

    test("nextContentShortcutOrder counts only the given section", () async {
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 1);
      await insertShortcut(sectionId: 2, sectionOrder: 1, order: 5);

      expect(await database.nextContentShortcutOrder(1), 2);
      expect(await database.nextContentShortcutOrder(2), 6);
      expect(await database.nextContentShortcutOrder(3), 0);
    });

    test("deleting an app never touches a shortcut pinned to that same package", () async {
      // The whole reason shortcuts have a table of their own: no foreign key
      // ties them to `apps`, so the app reconciliation cannot reach them.
      await database.customInsert("INSERT INTO apps(package_name, name, version)"
          " VALUES('com.teamsmart.videomanager.tv', 'SmartTube', '1.0.0');");
      await insertShortcut(sectionId: 1, sectionOrder: 0, order: 0);

      await database.deleteApps(["com.teamsmart.videomanager.tv"]);

      final shortcuts = await database.getContentShortcuts();
      expect(shortcuts.single.targetPackage, "com.teamsmart.videomanager.tv");
    });
  });

  test("nextAppCategoryOrder", () async {
    await database.customInsert("INSERT INTO apps(package_name, name, version)"
        " VALUES('me.efesser.flauncher', 'FLauncher', '1.0.0');");
    final categoryId = await database.customInsert("INSERT INTO categories(name, 'order') VALUES('Test', 2);");
    await database.customInsert("INSERT INTO apps_categories(category_id, app_package_name, 'order')"
        " VALUES($categoryId, 'me.efesser.flauncher', 1);");

    final index = await database.nextAppCategoryOrder(categoryId);

    expect(index, 2);
  });
}
