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

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.mocks.dart';

const String _smartTube = "com.teamsmart.videomanager.tv";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();

  late Directory temporaryDirectory;
  late File databaseFile;
  late FLauncherDatabase database;
  late MockFLauncherChannel channel;

  /// A file-backed database rather than an in-memory one so that it can be
  /// opened twice: the second open reports `wasCreated == false`, which is what
  /// keeps `AppsService._initDefaultCategories` from injecting a "Favorites"
  /// category into the very section ordering these tests assert on.
  setUp(() async {
    // Its own directory: test files run in parallel.
    temporaryDirectory = await Directory.systemTemp.createTemp("apps_service_content_shortcuts_test");
    databaseFile = File("${temporaryDirectory.path}/db.sqlite");

    final creator = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
    await creator.getContentShortcuts();
    await creator.close();

    database = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

    channel = MockFLauncherChannel();
    when(channel.getApplications()).thenAnswer((_) => Future.value([
          {"packageName": _smartTube, "name": "SmartTube", "version": "1.0.0", "sideloaded": true},
        ]));
    when(channel.applicationExists(any)).thenAnswer((_) => Future.value(false));
    when(channel.getApplicationIcon(any)).thenAnswer((_) => Future.value(Uint8List(0)));
    when(channel.getApplicationBanner(any)).thenAnswer((_) => Future.value(Uint8List(0)));
    when(channel.launchUri(any, any)).thenAnswer((_) => Future.value(true));
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<int> seedShortcut({
    required int sectionId,
    required int sectionOrder,
    required int order,
    String label = "Subscriptions",
    String uri = "https://www.youtube.com/feed/subscriptions",
    String targetPackage = _smartTube,
  }) =>
      database.insertContentShortcut(ContentShortcutsCompanion.insert(
        sectionId: sectionId,
        sectionOrder: sectionOrder,
        order: order,
        label: label,
        uri: uri,
        targetPackage: targetPackage,
      ));

  Future<AppsService> buildAppsService() async {
    final appsService = AppsService(channel, database);
    await untilCalled(channel.addAppsChangedListener(any));
    return appsService;
  }

  Future<List<Map<String, Object?>>> shortcutRows() async =>
      (await database.customSelect('SELECT * FROM content_shortcuts ORDER BY section_order, section_id, "order"').get())
          .map((row) => row.data)
          .toList();

  group("loading", () {
    test("groups rows sharing a section id into one ordered section", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 1, label: "Second");
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, label: "First");

      final appsService = await buildAppsService();

      final sections = appsService.launcherSections.whereType<ContentShortcutSection>().toList();
      expect(sections.length, 1);
      expect(sections.single.id, 1);
      expect(sections.single.shortcuts.map((shortcut) => shortcut.label), ["First", "Second"]);
    });

    test("places shortcut sections among categories and spacers by their order", () async {
      await database.insertCategory(CategoriesCompanion.insert(name: "All Apps", order: 0));
      await seedShortcut(sectionId: 1, sectionOrder: 1, order: 0);
      await database.insertSpacer(LauncherSpacersCompanion.insert(height: 40, order: 2));
      await database.insertCategory(CategoriesCompanion.insert(name: "Favorites", order: 3));
      await seedShortcut(sectionId: 2, sectionOrder: 4, order: 0, label: "Music");

      final appsService = await buildAppsService();

      expect(
        appsService.launcherSections.map((section) => section.runtimeType.toString()),
        ["Category", "ContentShortcutSection", "LauncherSpacer", "Category", "ContentShortcutSection"],
      );
      expect(appsService.launcherSections.map((section) => section.order), [0, 1, 2, 3, 4]);
    });

    test("marks a shortcut whose target is installed as available", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);

      final appsService = await buildAppsService();

      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isTrue);
    });

    test("an uninstalled target yields an unavailable shortcut, never a deleted one", () async {
      // The opposite of what happens to an `Apps` row, and the whole reason the
      // shortcuts live in a table of their own (PRD 12.3, point 5).
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "com.gone.app");

      final appsService = await buildAppsService();

      final shortcut = appsService.contentShortcutSections.single.shortcuts.single;
      expect(shortcut.available, isFalse);
      expect(shortcut.label, "Subscriptions");
      expect(shortcut.uri, "https://www.youtube.com/feed/subscriptions");
      expect(await shortcutRows(), hasLength(1));
    });

    test("asks the platform about a target the launcher list does not carry", () async {
      // A deep link target does not have to be a launchable application, so
      // absence from `getApplications()` is not proof it is gone.
      when(channel.applicationExists("com.headless.player")).thenAnswer((_) => Future.value(true));
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "com.headless.player");

      final appsService = await buildAppsService();

      verify(channel.applicationExists("com.headless.player"));
      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isTrue);
    });
  });

  group("the app reconciliation cannot reach a shortcut", () {
    test("deletes the uninstalled app row and leaves the shortcut pinned to that package", () async {
      // An app row for a package the system no longer reports: exactly what
      // AppsService._refreshState deletes.
      await database.persistApps([
        AppsCompanion.insert(packageName: "com.gone.app", name: "Gone", version: "1.0.0"),
      ]);
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "com.gone.app");

      final appsService = await buildAppsService();

      // The app row is gone...
      final apps = await database.customSelect("SELECT * FROM apps").get();
      expect(apps.map((row) => row.read<String>("package_name")), [_smartTube]);
      // ...and the shortcut is not, it is only unavailable.
      expect(await shortcutRows(), hasLength(1));
      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isFalse);
    });

    test("a PACKAGE_REMOVED event deletes the app row and leaves the shortcut alone", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);

      final appsService = await buildAppsService();
      final dynamic listener = verify(channel.addAppsChangedListener(captureAny)).captured.single;

      final result = listener({"action": "PACKAGE_REMOVED", "packageName": _smartTube});
      if (result is Future) {
        await result;
      }

      expect((await database.customSelect("SELECT * FROM apps").get()), isEmpty);
      expect(await shortcutRows(), hasLength(1));
      expect(appsService.launcherSections.whereType<ContentShortcutSection>(), hasLength(1));
    });
  });

  group("create", () {
    test("puts a first shortcut in a new section appended after every other one", () async {
      await database.insertCategory(CategoriesCompanion.insert(name: "All Apps", order: 0));
      final appsService = await buildAppsService();

      final id = await appsService.addContentShortcut(
        label: "Subscriptions",
        uri: "https://www.youtube.com/feed/subscriptions",
        targetPackage: _smartTube,
      );

      expect(await shortcutRows(), [
        {
          "id": id,
          "section_id": 1,
          "section_order": 1,
          "order": 0,
          "label": "Subscriptions",
          "uri": "https://www.youtube.com/feed/subscriptions",
          "target_package": _smartTube,
        }
      ]);
      expect(appsService.launcherSections.last, isA<ContentShortcutSection>());
      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isTrue);
    });

    test("appends to an existing section when given its id", () async {
      final appsService = await buildAppsService();
      await appsService.addContentShortcut(label: "First", uri: "https://youtu.be/a", targetPackage: _smartTube);
      final sectionId = appsService.contentShortcutSections.single.id;

      await appsService.addContentShortcut(
        label: "Second",
        uri: "https://youtu.be/b",
        targetPackage: _smartTube,
        sectionId: sectionId,
      );

      expect(appsService.contentShortcutSections.single.shortcuts.map((shortcut) => shortcut.label),
          ["First", "Second"]);
      expect((await shortcutRows()).map((row) => row["order"]), [0, 1]);
      expect(appsService.launcherSections.whereType<ContentShortcutSection>(), hasLength(1));
    });

    test("falls back to a new section when the given section id no longer exists", () async {
      final appsService = await buildAppsService();

      await appsService.addContentShortcut(
        label: "Orphan",
        uri: "https://youtu.be/a",
        targetPackage: _smartTube,
        sectionId: 999,
      );

      expect(appsService.contentShortcutSections, hasLength(1));
      expect(appsService.contentShortcutSections.single.id, isNot(999));
    });

    test("a shortcut whose target is not installed is created, and unavailable", () async {
      final appsService = await buildAppsService();

      await appsService.addContentShortcut(
        label: "Later",
        uri: "https://youtu.be/a",
        targetPackage: "com.not.installed",
      );

      expect(await shortcutRows(), hasLength(1));
      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isFalse);
    });
  });

  group("edit", () {
    test("persists the new label, URI and target and re-resolves availability", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "com.gone.app");
      final appsService = await buildAppsService();
      final shortcut = appsService.contentShortcutSections.single.shortcuts.single;

      await appsService.updateContentShortcut(
        shortcut,
        label: "Music",
        uri: "https://www.youtube.com/playlist?list=X",
        targetPackage: _smartTube,
      );

      final row = (await shortcutRows()).single;
      expect(row["label"], "Music");
      expect(row["uri"], "https://www.youtube.com/playlist?list=X");
      expect(row["target_package"], _smartTube);
      final updated = appsService.contentShortcutSections.single.shortcuts.single;
      expect(updated.label, "Music");
      expect(updated.available, isTrue);
    });

    test("keeps every field the caller left out", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      final appsService = await buildAppsService();

      await appsService.updateContentShortcut(
        appsService.contentShortcutSections.single.shortcuts.single,
        label: "Renamed",
      );

      final row = (await shortcutRows()).single;
      expect(row["label"], "Renamed");
      expect(row["uri"], "https://www.youtube.com/feed/subscriptions");
      expect(row["target_package"], _smartTube);
    });
  });

  group("delete", () {
    test("removes one shortcut and renumbers the rest of its section", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, label: "First");
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 1, label: "Second");
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 2, label: "Third");
      final appsService = await buildAppsService();

      await appsService.deleteContentShortcut(appsService.contentShortcutSections.single.shortcuts.first);

      expect((await shortcutRows()).map((row) => row["label"]), ["Second", "Third"]);
      expect((await shortcutRows()).map((row) => row["order"]), [0, 1]);
      expect(appsService.contentShortcutSections.single.shortcuts.map((shortcut) => shortcut.order), [0, 1]);
    });

    test("the last shortcut leaving takes its section with it", () async {
      // A shortcut section owns no row of its own; it *is* its shortcuts.
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      final appsService = await buildAppsService();

      await appsService.deleteContentShortcut(appsService.contentShortcutSections.single.shortcuts.single);

      expect(await shortcutRows(), isEmpty);
      expect(appsService.launcherSections.whereType<ContentShortcutSection>(), isEmpty);
    });

    test("deleteSection removes the whole group, and no spacer that happens to share its id", () async {
      await database.insertSpacer(LauncherSpacersCompanion.insert(height: 40, order: 0));
      await seedShortcut(sectionId: 1, sectionOrder: 1, order: 0, label: "First");
      await seedShortcut(sectionId: 1, sectionOrder: 1, order: 1, label: "Second");
      final appsService = await buildAppsService();
      final index = appsService.launcherSections.indexWhere((section) => section is ContentShortcutSection);

      await appsService.deleteSection(index);

      expect(await shortcutRows(), isEmpty);
      expect((await database.getLauncherSpacers()).map((spacer) => spacer.height), [40]);
      expect(appsService.launcherSections.map((section) => section.runtimeType.toString()), ["LauncherSpacer"]);
    });
  });

  group("reorder", () {
    test("reorders shortcuts inside a section and persists the new positions", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, label: "First");
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 1, label: "Second");
      final appsService = await buildAppsService();
      final section = appsService.launcherSections.whereType<ContentShortcutSection>().single;

      appsService.reorderContentShortcut(section, 1, 0);
      expect(section.shortcuts.map((shortcut) => shortcut.label), ["Second", "First"]);

      await appsService.saveContentShortcutOrder(section);

      expect((await shortcutRows()).map((row) => row["label"]), ["Second", "First"]);
    });

    test("ignores an out-of-range index instead of throwing", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      final appsService = await buildAppsService();
      final section = appsService.launcherSections.whereType<ContentShortcutSection>().single;

      appsService.reorderContentShortcut(section, 5, 0);

      expect(section.shortcuts, hasLength(1));
    });

    test("moveSection writes the new section order onto every row of the group", () async {
      await database.insertCategory(CategoriesCompanion.insert(name: "All Apps", order: 0));
      await seedShortcut(sectionId: 1, sectionOrder: 1, order: 0, label: "First");
      await seedShortcut(sectionId: 1, sectionOrder: 1, order: 1, label: "Second");
      final appsService = await buildAppsService();

      await appsService.moveSection(1, 0);

      expect((await shortcutRows()).map((row) => row["section_order"]), [0, 0]);
      expect((await database.getCategories()).single.order, 1);
      expect(appsService.launcherSections.first, isA<ContentShortcutSection>());
    });
  });

  group("launch", () {
    test("pins the stored target package", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);
      final appsService = await buildAppsService();

      final launched =
          await appsService.launchContentShortcut(appsService.contentShortcutSections.single.shortcuts.single);

      expect(launched, isTrue);
      verify(channel.launchUri("https://www.youtube.com/feed/subscriptions", _smartTube));
    });

    test("a refused launch marks the shortcut unavailable and never deletes it", () async {
      when(channel.launchUri(any, any)).thenAnswer((_) => Future.value(false));
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "com.gone.app");
      final appsService = await buildAppsService();

      final launched =
          await appsService.launchContentShortcut(appsService.contentShortcutSections.single.shortcuts.single);

      expect(launched, isFalse);
      expect(appsService.contentShortcutSections.single.shortcuts.single.available, isFalse);
      expect(await shortcutRows(), hasLength(1));
    });

    test("never hands an empty target package to the channel", () async {
      // Reachable from a hand-edited backup file: an empty package pins nothing,
      // so Android would answer with the app chooser this design exists to avoid.
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, targetPackage: "");
      final appsService = await buildAppsService();

      final launched =
          await appsService.launchContentShortcut(appsService.contentShortcutSections.single.shortcuts.single);

      expect(launched, isFalse);
      verifyNever(channel.launchUri(any, any));
    });

    test("never hands an empty URI to the channel", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, uri: "");
      final appsService = await buildAppsService();

      final launched =
          await appsService.launchContentShortcut(appsService.contentShortcutSections.single.shortcuts.single);

      expect(launched, isFalse);
      verifyNever(channel.launchUri(any, any));
    });
  });

  test("resolveContentShortcutTargets asks the platform which apps declare a filter for the URI", () async {
    when(channel.resolveUriTargets("https://youtu.be/a")).thenAnswer((_) => Future.value([
          {"packageName": _smartTube, "name": "SmartTube"},
        ]));
    final appsService = await buildAppsService();

    final targets = await appsService.resolveContentShortcutTargets("https://youtu.be/a");

    expect(targets.map((target) => target["packageName"]), [_smartTube]);
  });

  group("hostile stored values", () {
    test("rows disagreeing about the section order settle on the smallest, without throwing", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 5, order: 0, label: "First");
      await seedShortcut(sectionId: 1, sectionOrder: 2, order: 1, label: "Second");

      final appsService = await buildAppsService();

      final section = appsService.launcherSections.whereType<ContentShortcutSection>().single;
      expect(section.order, 2);
      expect(section.shortcuts.map((shortcut) => shortcut.label), ["First", "Second"]);
    });

    test("negative, duplicated and gapped positions load without throwing and lose no row", () async {
      await seedShortcut(sectionId: 1, sectionOrder: -3, order: -1, label: "Negative");
      await seedShortcut(sectionId: 1, sectionOrder: -3, order: 7, label: "Gapped");
      await seedShortcut(sectionId: 1, sectionOrder: -3, order: 7, label: "Duplicate");

      final appsService = await buildAppsService();

      final section = appsService.launcherSections.whereType<ContentShortcutSection>().single;
      expect(section.order, -3);
      expect(section.shortcuts.map((shortcut) => shortcut.label).first, "Negative");
      expect(section.shortcuts, hasLength(3));
    });

    test("a row with an empty label, URI and target package loads as unavailable", () async {
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0, label: "", uri: "", targetPackage: "");

      final appsService = await buildAppsService();

      final shortcut = appsService.contentShortcutSections.single.shortcuts.single;
      expect(shortcut.available, isFalse);
      expect(shortcut.launchable, isFalse);
    });

    test("a shortcut section is never reachable through the categories getter", () async {
      // AppsService.categories drives the dock lookup (`name == 'Favorites'`);
      // a shortcut section leaking into it would be cast to Category.
      await seedShortcut(sectionId: 1, sectionOrder: 0, order: 0);

      final appsService = await buildAppsService();

      expect(appsService.categories, isEmpty);
      expect(appsService.launcherSections, hasLength(1));
    });
  });
}
