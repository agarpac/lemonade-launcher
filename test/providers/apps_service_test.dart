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

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

/// Stubs [MockFLauncherChannel] icon/banner lookups for any package name. AppsService
/// pre-caches icons and banners for every non-hidden app right after initialisation
/// (see AppsService._preCacheIcons), so any test that ends up with non-hidden apps in
/// memory must provide these stubs or the fire-and-forget calls throw MissingStubError.
void _stubIconAndBannerLookups(MockFLauncherChannel channel) {
  when(channel.getApplicationIcon(any)).thenAnswer((_) => Future.value(Uint8List(0)));
  when(channel.getApplicationBanner(any)).thenAnswer((_) => Future.value(Uint8List(0)));
}

/// Adds [apps] to [category].applications, also recording their order in
/// App.categoryOrders. AppsService.sortCategory relies on categoryOrders being set
/// for the default (manual) CategorySort, so any test pre-populating a category's
/// applications directly (bypassing AppsService.addToCategory) must set this up too.
void _addAppsToCategory(Category category, List<App> apps) {
  for (var i = 0; i < apps.length; i++) {
    apps[i].categoryOrders[category.id] = i;
  }
  category.applications.addAll(apps);
}

void main() {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();

  group("AppsService initialised correctly", () {
    // The upstream default-category bootstrap ("TV Applications"/"Non-TV Applications" split by
    // `sideloaded`) was replaced by AppsService._initDefaultCategories with an "All Apps" category
    // (every non-hidden app) plus a "Favorites" category seeded from a hard-coded list of default
    // launcher package names, with those apps moved out of "All Apps". These tests were rewritten
    // to match that behaviour instead of the removed TV/Non-TV split.
    test("creates 'All Apps' and 'Favorites' categories on first run", () async {
      final channel = MockFLauncherChannel();
      final database = MockFLauncherDatabase();
      _stubIconAndBannerLookups(channel);
      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {
              'packageName': 'me.efesser.flauncher',
              'name': 'FLauncher',
              'version': null,
              'sideloaded': false,
            },
            {
              'packageName': 'com.omeda.arc',
              'name': 'Arc Launcher',
              'version': '2.0.0',
              'sideloaded': false,
            },
          ]));

      final persistedApps = [
        fakeApp(packageName: "me.efesser.flauncher", name: "FLauncher", version: ""),
        fakeApp(packageName: "com.omeda.arc", name: "Arc Launcher", version: "2.0.0"),
      ];
      int getApplicationsCallCount = 0;
      when(database.getApplications()).thenAnswer((_) {
        getApplicationsCallCount++;
        return Future.value(getApplicationsCallCount == 1 ? <App>[] : persistedApps);
      });
      when(database.getCategories()).thenAnswer((_) => Future.value(<Category>[]));
      when(database.getAppsCategories()).thenAnswer((_) => Future.value(<AppCategory>[]));
      when(database.getLauncherSpacers()).thenAnswer((_) => Future.value(<LauncherSpacer>[]));
      when(database.transaction(any)).thenAnswer((realInvocation) => realInvocation.positionalArguments[0]());
      when(database.wasCreated).thenReturn(true);
      int nextCategoryId = 100;
      when(database.insertCategory(any)).thenAnswer((_) => Future.value(nextCategoryId++));
      when(database.nextAppCategoryOrder(any)).thenAnswer((_) => Future.value(null));

      final appsService = AppsService(channel, database);
      await untilCalled(channel.addAppsChangedListener(any));

      verifyInOrder([
        database.getApplications(),
        database.persistApps([
          AppsCompanion.insert(packageName: "me.efesser.flauncher", name: "FLauncher", version: ""),
          AppsCompanion.insert(packageName: "com.omeda.arc", name: "Arc Launcher", version: "2.0.0"),
        ]),
        database.deleteApps([]),
        database.insertCategory(CategoriesCompanion.insert(name: "All Apps", order: 0)),
        database.insertCategory(CategoriesCompanion.insert(name: "Favorites", order: 0)),
      ]);

      // The most recently created category is inserted at order 0 and pushes older ones down,
      // so "Favorites" (created second) ends up before "All Apps".
      final categories = List.of(appsService.categories)..sort((a, b) => a.order.compareTo(b.order));
      expect(categories.length, 2);
      expect(categories[0].name, "Favorites");
      expect(categories[0].applications.map((a) => a.packageName), ["com.omeda.arc"]);
      expect(categories[1].name, "All Apps");
      expect(categories[1].applications.map((a) => a.packageName), ["me.efesser.flauncher"]);
    });

    test("with newly installed, uninstalled and existing apps", () async {
      final channel = MockFLauncherChannel();
      final database = MockFLauncherDatabase();
      _stubIconAndBannerLookups(channel);
      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {
              'packageName': 'me.efesser.flauncher',
              'name': 'FLauncher',
              'version': '2.0.0',
              'sideloaded': false,
            },
            {
              'packageName': 'me.efesser.flauncher.2',
              'name': 'FLauncher 2',
              'version': '1.0.0',
              'sideloaded': false,
            }
          ]));
      when(channel.applicationExists("uninstalled.app")).thenAnswer((_) => Future.value(false));
      when(channel.applicationExists("not.uninstalled.app")).thenAnswer((_) => Future.value(true));
      when(database.getApplications()).thenAnswer((_) => Future.value([
            fakeApp(packageName: "me.efesser.flauncher", name: "FLauncher", version: "1.0.0"),
            fakeApp(packageName: "uninstalled.app", name: "Uninstalled Application", version: "1.0.0"),
            fakeApp(packageName: "not.uninstalled.app", name: "Not Uninstalled Application", version: "1.0.0")
          ]));
      when(database.getCategories()).thenAnswer((_) => Future.value(<Category>[]));
      when(database.getAppsCategories()).thenAnswer((_) => Future.value(<AppCategory>[]));
      when(database.getLauncherSpacers()).thenAnswer((_) => Future.value(<LauncherSpacer>[]));
      when(database.transaction(any)).thenAnswer((realInvocation) => realInvocation.positionalArguments[0]());
      when(database.wasCreated).thenReturn(false);
      AppsService(channel, database);
      await untilCalled(channel.addAppsChangedListener(any));

      verifyInOrder([
        database.getApplications(),
        database.persistApps([
          AppsCompanion.insert(
            packageName: "me.efesser.flauncher",
            name: "FLauncher",
            version: "2.0.0",
          ),
          AppsCompanion.insert(
            packageName: "me.efesser.flauncher.2",
            name: "FLauncher 2",
            version: "1.0.0",
          )
        ]),
        database.deleteApps(["uninstalled.app"]),
        database.getApplications(),
      ]);
    });
  });

  /// The platform channel has no concept of "last launched" — App.fromSystem always builds
  /// a fresh App with lastLaunchedAt == null. AppsService._init merges that fresh app with the
  /// existing in-memory one (carrying over `hidden` and `categoryOrders`); lastLaunchedAt must
  /// be carried over too, or "Last Used" sorting silently breaks every time an app is
  /// installed/updated or a bulk package scan runs, until the launcher fully restarts and
  /// reloads from the database.
  group("platform-channel merge preserves lastLaunchedAt", () {
    test("PACKAGE_CHANGED event preserves in-memory lastLaunchedAt", () async {
      final channel = MockFLauncherChannel();
      final database = MockFLauncherDatabase();
      _stubIconAndBannerLookups(channel);
      final lastLaunchedAt = DateTime.fromMillisecondsSinceEpoch(12345);

      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {
              'packageName': 'me.efesser.flauncher',
              'name': 'FLauncher',
              'version': '1.0.0',
              'sideloaded': false,
            },
          ]));
      when(database.getApplications()).thenAnswer((_) => Future.value([
            fakeApp(
              packageName: "me.efesser.flauncher",
              name: "FLauncher",
              version: "1.0.0",
              lastLaunchedAt: lastLaunchedAt,
            ),
          ]));
      when(database.getCategories()).thenAnswer((_) => Future.value(<Category>[]));
      when(database.getAppsCategories()).thenAnswer((_) => Future.value(<AppCategory>[]));
      when(database.getLauncherSpacers()).thenAnswer((_) => Future.value(<LauncherSpacer>[]));
      when(database.transaction(any)).thenAnswer((realInvocation) => realInvocation.positionalArguments[0]());
      when(database.wasCreated).thenReturn(false);
      when(database.persistApps(any)).thenAnswer((_) => Future.value());

      final appsService = AppsService(channel, database);
      await untilCalled(channel.addAppsChangedListener(any));
      final dynamic listener = verify(channel.addAppsChangedListener(captureAny)).captured.single;

      final result = listener({
        "action": "PACKAGE_CHANGED",
        "activityInfo": {
          "packageName": "me.efesser.flauncher",
          "name": "FLauncher",
          "version": "2.0.0",
          "sideloaded": false,
        },
      });
      if (result is Future) {
        await result;
      }

      final updatedApp = appsService.applications.firstWhere((app) => app.packageName == "me.efesser.flauncher");
      // Sanity check: the merge did rebuild the app from the fresh system data.
      expect(updatedApp.version, "2.0.0");
      // The bug under test: without carrying it over, this is null after the merge.
      expect(updatedApp.lastLaunchedAt, lastLaunchedAt);

      // The database write for this event never touches last_launched_at (the companion
      // built from platform-channel data has no such field), so the merge bug above is an
      // in-memory/display bug only — it cannot clobber the stored value.
      // (persistApps is also called once during the initial _refreshState, so take the
      // most recent invocation — the one triggered by this PACKAGE_CHANGED event.)
      final persistedCalls = verify(database.persistApps(captureAny)).captured;
      final persisted = persistedCalls.last as Iterable<AppsCompanion>;
      expect(persisted.single.lastLaunchedAt, const Value<DateTime?>.absent());
    });

    test("PACKAGES_AVAILABLE event preserves in-memory lastLaunchedAt", () async {
      final channel = MockFLauncherChannel();
      final database = MockFLauncherDatabase();
      _stubIconAndBannerLookups(channel);
      final lastLaunchedAt = DateTime.fromMillisecondsSinceEpoch(67890);

      when(channel.getApplications()).thenAnswer((_) => Future.value([
            {
              'packageName': 'me.efesser.flauncher',
              'name': 'FLauncher',
              'version': '1.0.0',
              'sideloaded': false,
            },
          ]));
      when(database.getApplications()).thenAnswer((_) => Future.value([
            fakeApp(
              packageName: "me.efesser.flauncher",
              name: "FLauncher",
              version: "1.0.0",
              lastLaunchedAt: lastLaunchedAt,
            ),
          ]));
      when(database.getCategories()).thenAnswer((_) => Future.value(<Category>[]));
      when(database.getAppsCategories()).thenAnswer((_) => Future.value(<AppCategory>[]));
      when(database.getLauncherSpacers()).thenAnswer((_) => Future.value(<LauncherSpacer>[]));
      when(database.transaction(any)).thenAnswer((realInvocation) => realInvocation.positionalArguments[0]());
      when(database.wasCreated).thenReturn(false);
      when(database.persistApps(any)).thenAnswer((_) => Future.value());

      final appsService = AppsService(channel, database);
      await untilCalled(channel.addAppsChangedListener(any));
      final dynamic listener = verify(channel.addAppsChangedListener(captureAny)).captured.single;

      final result = listener({
        "action": "PACKAGES_AVAILABLE",
        "activitiesInfo": [
          {
            "packageName": "me.efesser.flauncher",
            "name": "FLauncher",
            "version": "2.0.0",
            "sideloaded": false,
          },
        ],
      });
      if (result is Future) {
        await result;
      }

      final updatedApp = appsService.applications.firstWhere((app) => app.packageName == "me.efesser.flauncher");
      expect(updatedApp.version, "2.0.0");
      expect(updatedApp.lastLaunchedAt, lastLaunchedAt);
    });
  });

  test("launchApp calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);
    final app = fakeApp();

    await appsService.launchApp(app);
  });

  test("openAppInfo calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);
    final app = fakeApp();

    await appsService.openAppInfo(app);

    verify(channel.openAppInfo(app.packageName));
  });

  test("uninstallApp calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);
    final app = fakeApp();

    await appsService.uninstallApp(app);

    verify(channel.uninstallApp(app.packageName));
  });

  test("openSettings calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);

    await appsService.openSettings();

    verify(channel.openSettings());
  });

  test("isDefaultLauncher calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    when(channel.isDefaultLauncher()).thenAnswer((_) => Future.value(true));
    final appsService = await _buildInitialisedAppsService(channel, database, []);

    final isDefaultLauncher = await appsService.isDefaultLauncher();

    verify(channel.isDefaultLauncher());
    expect(isDefaultLauncher, isTrue);
  });

  test("startAmbientMode calls channel", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);

    await appsService.startAmbientMode();

    verify(channel.startAmbientMode());
  });

  test("addToCategory adds app to category", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);
    final category = fakeCategory(name: "Category");
    when(database.nextAppCategoryOrder(category.id)).thenAnswer((_) => Future.value(1));

    await appsService.addToCategory(fakeApp(packageName: "app.to.be.added"), category);

    verify(database.insertAppsCategories(
        [AppsCategoriesCompanion.insert(categoryId: category.id, appPackageName: "app.to.be.added", order: 1)]));
  });

  test("removeFromCategory removes app from category", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final appsService = await _buildInitialisedAppsService(channel, database, []);
    final app = fakeApp(packageName: "app.to.be.added");
    final category = fakeCategory(name: "Category");

    await appsService.removeFromCategory(app, category);

    verify(database.deleteAppCategory(category.id, app.packageName));
  });

  test("saveOrderInCategory persists apps order from memory to database", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(name: "Category");
    _addAppsToCategory(category, [fakeApp(packageName: "app.1"), fakeApp(packageName: "app.2")]);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    await appsService.saveApplicationOrderInCategory(category);

    verify(database.replaceAppsCategories([
      AppsCategoriesCompanion.insert(categoryId: category.id, appPackageName: "app.1", order: 0),
      AppsCategoriesCompanion.insert(categoryId: category.id, appPackageName: "app.2", order: 1)
    ]));
  });

  test("reorderApplication changes application order in-memory", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(name: "Category");
    _addAppsToCategory(category, [fakeApp(packageName: "app.1"), fakeApp(packageName: "app.2")]);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    appsService.reorderApplication(category, 1, 0);

    expect(appsService.categories[0].applications[0].packageName, "app.2");
    expect(appsService.categories[0].applications[1].packageName, "app.1");
  });

  test("addCategory adds category at index 0 and moves others", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final existingCategory = fakeCategory(name: "Existing Category", order: 0);
    final appsService = await _buildInitialisedAppsService(
      channel,
      database,
      [existingCategory],
    );
    when(database.insertCategory(any)).thenAnswer((_) => Future.value(500));

    await appsService.addCategory("New Category");

    verify(database.insertCategory(CategoriesCompanion.insert(name: "New Category", order: 0)));
    verify(database.updateCategories([CategoriesCompanion(id: Value(existingCategory.id), order: Value(1))]));
  });

  test("renameCategory renames category", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(name: "Old name", order: 0);
    final appsService = await _buildInitialisedAppsService(
      channel,
      database,
      [category],
    );

    await appsService.renameCategory(category, "New name");

    verify(database.updateCategory(category.id, CategoriesCompanion(name: Value("New name"))));
    expect(appsService.categories.first.name, "New name");
  });

  test("deleteSection deletes category", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final defaultCategory = fakeCategory(name: "Applications", order: 0);
    final categoryToDelete = fakeCategory(name: "Delete Me", order: 1);
    // NOTE: the previous implementation moved a deleted category's apps into the default
    // category before removing it. The current AppsService.deleteSection(int index) no longer
    // does this: it only deletes the category row (apps_categories rows cascade-delete in the
    // database) and removes the section, without reassigning apps elsewhere. See final report.
    final appsService = await _buildInitialisedAppsService(
      channel,
      database,
      [defaultCategory, categoryToDelete],
    );
    final indexToDelete = appsService.launcherSections.indexOf(categoryToDelete);

    await appsService.deleteSection(indexToDelete);

    verify(database.deleteCategory(categoryToDelete.id));
    expect(appsService.categories.map((c) => c.name), ["Applications"]);
  });

  test("moveSection changes sections order", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final applicationsCategory = fakeCategory(name: "Applications", order: 0);
    final favoritesCategory = fakeCategory(name: "Favorites", order: 1);
    final appsService = await _buildInitialisedAppsService(
      channel,
      database,
      [applicationsCategory, favoritesCategory],
    );

    await appsService.moveSection(1, 0);

    verify(database.updateCategories(
      [
        CategoriesCompanion(id: Value(favoritesCategory.id), order: Value(0)),
        CategoriesCompanion(id: Value(applicationsCategory.id), order: Value(1))
      ],
    ));
    expect(appsService.launcherSections.map((s) => (s as Category).name), ["Favorites", "Applications"]);
  });

  test("hideApplication hides application", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final application = fakeApp();
    final appsService =
        await _buildInitialisedAppsService(channel, database, [], initialApplications: [application]);

    await appsService.hideApplication(application);

    verify(database.updateApp(application.packageName, AppsCompanion(hidden: Value(true))));
    expect(application.hidden, isTrue);
    expect(appsService.applications, [application]);
  });

  test("showApplication un-hides application", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final application = fakeApp(hidden: true);
    final appsService =
        await _buildInitialisedAppsService(channel, database, [], initialApplications: [application]);

    await appsService.showApplication(application);

    verify(database.updateApp(application.packageName, AppsCompanion(hidden: Value(false))));
    expect(application.hidden, isFalse);
  });

  test("setCategoryType persists change in database", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(type: CategoryType.row);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    await appsService.setCategoryType(category, CategoryType.grid);

    verify(database.updateCategory(category.id, CategoriesCompanion(type: Value(CategoryType.grid))));
    expect(category.type, CategoryType.grid);
  });

  test("setCategorySort persists change in database", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(sort: CategorySort.manual);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    await appsService.setCategorySort(category, CategorySort.alphabetical);

    verify(database.updateCategory(category.id, CategoriesCompanion(sort: Value(CategorySort.alphabetical))));
    expect(category.sort, CategorySort.alphabetical);
  });

  test("setCategoryColumnsCount persists change in database", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(columnsCount: 6);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    await appsService.setCategoryColumnsCount(category, 8);

    verify(database.updateCategory(category.id, CategoriesCompanion(columnsCount: Value(8))));
    expect(category.columnsCount, 8);
  });

  test("setCategoryRowHeight persists change in database", () async {
    final channel = MockFLauncherChannel();
    final database = MockFLauncherDatabase();
    final category = fakeCategory(rowHeight: 110);
    final appsService = await _buildInitialisedAppsService(channel, database, [category]);

    await appsService.setCategoryRowHeight(category, 120);

    verify(database.updateCategory(category.id, CategoriesCompanion(rowHeight: Value(120))));
    expect(category.rowHeight, 120);
  });
}

/// Builds an [AppsService] whose initial state is fully controlled by the test: [categories] are
/// returned verbatim by `getCategories()` (their `applications` lists, if pre-populated by the
/// caller, are left untouched since `getAppsCategories()` is empty) and [initialApplications] are
/// returned by the first `getApplications()` call so that `AppsService`'s internal `_applications`
/// map contains them (this is required for methods such as hideApplication/showApplication that
/// only mutate apps already tracked in memory).
Future<AppsService> _buildInitialisedAppsService(
  MockFLauncherChannel channel,
  MockFLauncherDatabase database,
  List<Category> categories, {
  List<App> initialApplications = const [],
}) async {
  _stubIconAndBannerLookups(channel);
  when(channel.getApplications()).thenAnswer((_) => Future.value([]));
  when(database.getApplications()).thenAnswer((_) => Future.value(initialApplications));
  when(database.getCategories()).thenAnswer((_) => Future.value(categories));
  when(database.getAppsCategories()).thenAnswer((_) => Future.value(<AppCategory>[]));
  when(database.getLauncherSpacers()).thenAnswer((_) => Future.value(<LauncherSpacer>[]));
  when(database.transaction(any)).thenAnswer((realInvocation) => realInvocation.positionalArguments[0]());
  when(database.wasCreated).thenReturn(false);
  // initialApplications are absent from channel.getApplications() (stubbed to []) above, so
  // AppsService._refreshState treats them as candidates for uninstallation and checks
  // channel.applicationExists for each; report them as still installed.
  when(channel.applicationExists(any)).thenAnswer((_) => Future.value(true));
  final appsService = AppsService(channel, database);
  await untilCalled(channel.addAppsChangedListener(any));
  clearInteractions(channel);
  clearInteractions(database);
  return appsService;
}
