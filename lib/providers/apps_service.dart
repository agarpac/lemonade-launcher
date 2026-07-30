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

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:collection/collection.dart' as collection;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart' hide Category;

import '../models/app.dart';
import '../models/category.dart';

class AppsService extends ChangeNotifier
{
  final FLauncherChannel _fLauncherChannel;
  final FLauncherDatabase _database;

  bool _initialized = false;
  int _layoutVersion = 0;

  List<LauncherSection> _launcherSections = List.empty(growable: true);
  Map<String, App> _applications = Map();
  Map<String, Uint8List> _iconCache = Map();
  Map<String, Uint8List> _bannerCache = Map();

  Map<int, Category> _categoriesById = Map();

  // Cached SharedPreferences instance to avoid repeated disk I/O
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _prefsAsync async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool get initialized => _initialized;
  int get layoutVersion => _layoutVersion;

  @override
  void notifyListeners() {
    _layoutVersion++;
    super.notifyListeners();
  }

  String? _pendingReorderFocusPackage;
  int? _pendingReorderFocusCategoryId;
  String? get pendingReorderFocusPackage => _pendingReorderFocusPackage;
  int? get pendingReorderFocusCategoryId => _pendingReorderFocusCategoryId;
  void clearPendingReorderFocusPackage() {
    _pendingReorderFocusPackage = null;
    _pendingReorderFocusCategoryId = null;
  }
  void setPendingReorderFocus(String packageName, int categoryId) {
    _pendingReorderFocusPackage = packageName;
    _pendingReorderFocusCategoryId = categoryId;
  }

  final Set<String> _dirtyImagePackages = {};
  bool consumeDirtyImage(String packageName) => _dirtyImagePackages.remove(packageName);

  List<App> get applications => UnmodifiableListView(_applications.values.sortedBy((application) => application.name));

  List<LauncherSection> get launcherSections => List.unmodifiable(_launcherSections);
  List<Category> get categories => _categoriesById.values
      .map((category) => category.unmodifiable())
      .toList(growable: false);

  List<ContentShortcutSection> get contentShortcutSections => _launcherSections
      .whereType<ContentShortcutSection>()
      .map((section) => section.unmodifiable())
      .toList(growable: false);

  AppsService(this._fLauncherChannel, this._database) {
    _init();
  }

  Future<void> _init() async {
    await _refreshState(shouldNotifyListeners: false);
    if (_database.wasCreated) {
      await _initDefaultCategories();
    }

    _fLauncherChannel.addAppsChangedListener((event) async {
      String? changedPackageName;
      if (event.containsKey('packageName')) {
        changedPackageName = event['packageName'];
      } else if (event.containsKey('activityInfo')) {
         changedPackageName = event['activityInfo']['packageName'];
      }

      if (changedPackageName != null) {
        _iconCache.remove(changedPackageName);
        _bannerCache.remove(changedPackageName);
        _dirtyImagePackages.add(changedPackageName);
      }

      switch (event["action"]) {
        case "PACKAGE_ADDED":
        case "PACKAGE_CHANGED":
          Map<dynamic, dynamic> applicationInfo = event['activityInfo'];
          await _database.persistApps([_buildAppCompanion(applicationInfo)]);

          App newApp = App.fromSystem(applicationInfo);
          App? existingApp = _applications[newApp.packageName];

          if (existingApp != null) {
            newApp.hidden = existingApp.hidden;
            newApp.categoryOrders = Map.from(existingApp.categoryOrders);
            // The platform channel has no concept of "last launched", so carry
            // it over from the in-memory app or it would silently reset to
            // null (and "Last Used" sorting would break) until the next full
            // restart reloads it from the database.
            newApp.lastLaunchedAt = existingApp.lastLaunchedAt;
            for (int categoryId in newApp.categoryOrders.keys) {
              if (_categoriesById.containsKey(categoryId)) {
                Category category = _categoriesById[categoryId]!;
                int index = category.applications.indexOf(existingApp);
                if (index != -1) {
                  category.applications[index] = newApp;
                } else {
                  category.applications.add(newApp);
                }
              }
            }
            _applications[newApp.packageName] = newApp;
          } else {
            _applications[newApp.packageName] = newApp;
            final targetCategory = _findTargetCategoryForNewApp();
            if (targetCategory != null) {
              await addToCategory(newApp, targetCategory, shouldNotifyListeners: false);
            }
          }
          break;
        case "PACKAGES_AVAILABLE":
          List<dynamic> applicationsInfo = event["activitiesInfo"];
          await _database.persistApps((applicationsInfo).map(_buildAppCompanion));

          for (Map<dynamic, dynamic> applicationInfo in applicationsInfo) {
            App newApp = App.fromSystem(applicationInfo);
            App? existingApp = _applications[newApp.packageName];

            if (existingApp != null) {
              newApp.hidden = existingApp.hidden;
              newApp.categoryOrders = Map.from(existingApp.categoryOrders);
              // Same reasoning as the PACKAGE_ADDED/PACKAGE_CHANGED branch above:
              // preserve the in-memory last-launched timestamp across a bulk
              // package scan, since the platform channel cannot supply it.
              newApp.lastLaunchedAt = existingApp.lastLaunchedAt;
              for (int categoryId in newApp.categoryOrders.keys) {
                if (_categoriesById.containsKey(categoryId)) {
                  Category category = _categoriesById[categoryId]!;
                  int index = category.applications.indexOf(existingApp);
                  if (index != -1) {
                    category.applications[index] = newApp;
                  } else {
                    category.applications.add(newApp);
                  }
                }
              }
              _applications[newApp.packageName] = newApp;
            } else {
              _applications[newApp.packageName] = newApp;
            }
            _iconCache.remove(newApp.packageName);
            _bannerCache.remove(newApp.packageName);
          }
          break;
        case "PACKAGE_REMOVED":
          String packageName = event['packageName'];
          await _database.deleteApps([packageName]);

          // Clear icon cache for removed app
          _iconCache.remove(packageName);
          _bannerCache.remove(packageName);

          App? application = _applications.remove(packageName);

          if (application != null) {
            for (int categoryId in application.categoryOrders.keys) {
              if (_categoriesById.containsKey(categoryId)) {
                Category category = _categoriesById[categoryId]!;
                category.applications.remove(application);
              }
            }
          }
          break;
      }

      notifyListeners();
    });

    _initialized = true;
    notifyListeners();
    
    // Pre-cache icons for visible apps
    _preCacheIcons();
  }

  Future<void> _preCacheIcons() async {
    // Only cache apps that are not hidden
    final visibleApps = _applications.values.where((app) => !app.hidden).toList();
    for (var app in visibleApps) {
      // Don't await, let it run in background
      getAppIcon(app.packageName);
      // Also cache banner if it's likely to be needed soon
      getAppBanner(app.packageName);
    }
  }

  AppsCompanion _buildAppCompanion(dynamic data) {
    String? version = data["version"];
    if (version == null) {
      version = "";
    }

    return AppsCompanion(
        packageName: Value(data["packageName"]),
        name: Value(data["name"]),
        version: Value(version),
        hidden: const Value.absent()
      );
  }

  Future<void> _initDefaultCategories() {
    final allApps = _applications.values.where((application) => !application.hidden);
    final defaultFavoriteLauncherPackageNames = [
      'com.omeda.arc',
      'com.omeda.arc.debug',
    ];

    return _database.transaction(() async {
      if (allApps.isNotEmpty) {
        int categoryId = await addCategory("All Apps",
            type: CategoryType.grid, shouldNotifyListeners: false
        );

        Category allAppsCategory = _categoriesById[categoryId]!;
        for (final app in allApps) {
          await addToCategory(app, allAppsCategory, shouldNotifyListeners: false);
        }
      }

      final int favoritesId = await addCategory("Favorites", shouldNotifyListeners: false);
      final Category favoritesCategory = _categoriesById[favoritesId]!;
      final Category? allAppsCategory = _getAppsCategory();
      for (final packageName in defaultFavoriteLauncherPackageNames) {
        final app = _applications[packageName];
        if (app != null && !app.hidden) {
          await addToCategory(app, favoritesCategory, shouldNotifyListeners: false);
          if (allAppsCategory != null) {
            await removeFromCategory(app, allAppsCategory);
          }
        }
      }
    });
  }

  Future<void> _refreshState({bool shouldNotifyListeners = true}) async {
    Future<List<App>> appsFromDatabaseFuture = _database.getApplications();
    Future<List<AppCategory>> appsCategoriesFuture = _database.getAppsCategories();
    Future<List<Category>> categoriesFuture = _database.getCategories();
    Future<List<LauncherSpacer>> spacersFuture = _database.getLauncherSpacers();
    Future<List<ContentShortcutRow>> shortcutsFuture = _database.getContentShortcuts();
    List<Map<dynamic, dynamic>> appsFromSystem = await _fLauncherChannel.getApplications();
    Iterable<MapEntry<String, (Map, AppsCompanion)>> appEntries = appsFromSystem.map(
            (appFromSystem) => new MapEntry(appFromSystem['packageName'], (appFromSystem, _buildAppCompanion(appFromSystem))));
    Map<String, (Map, AppsCompanion)> appsFromSystemByPackageName = Map.fromEntries(appEntries);

    List<App> appsFromDatabase = await appsFromDatabaseFuture;
    final Iterable<App> appsRemovedFromSystem = appsFromDatabase
        .where((app) => !appsFromSystemByPackageName.containsKey(app.packageName));

    final List<String> uninstalledApplications = [];
    for (App app in appsRemovedFromSystem) {
      String packageName = app.packageName;

      // TODO: Is this really necessary? Can't we get this information from the getApplications method?
      bool appExists = await _fLauncherChannel.applicationExists(packageName);
      if (!appExists) {
        uninstalledApplications.add(packageName);
      }
    }

    await _database.transaction(() async {
      await _database.persistApps(appsFromSystemByPackageName.values.map((record) => record.$2));
      await _database.deleteApps(uninstalledApplications);
    });

    appsFromDatabaseFuture = _database.getApplications();

    await Future.wait([appsFromDatabaseFuture, appsCategoriesFuture, categoriesFuture, spacersFuture, shortcutsFuture]);

    appsFromDatabase = await appsFromDatabaseFuture;
    List<AppCategory> appsCategories = await appsCategoriesFuture;
    List<Category> categories = await categoriesFuture;
    List<LauncherSpacer> spacers = await spacersFuture;
    List<ContentShortcutRow> shortcutRows = await shortcutsFuture;

    _categoriesById = Map.fromEntries(categories.map((category) => MapEntry(category.id, category)));
    _applications = Map.fromEntries(appsFromDatabase.map((application) => MapEntry(application.packageName, application)));

    // Note that nothing above this line has touched the shortcut rows: the
    // reconciliation that deletes uninstalled apps runs over `Apps` rows only,
    // which is exactly why shortcuts live in a table of their own.
    List<ContentShortcutSection> shortcutSections =
        await _buildContentShortcutSections(shortcutRows, appsFromSystemByPackageName.keys.toSet());

    _launcherSections.clear();
    _launcherSections.addAll(categories);
    _launcherSections.addAll(spacers);
    _launcherSections.addAll(shortcutSections);
    _launcherSections.sort((ls0, ls1) => ls0.order.compareTo(ls1.order));

    for (App application in _applications.values) {
      Map? applicationFromSystem = appsFromSystemByPackageName[application.packageName]?.$1;

      if (applicationFromSystem != null) {
        if (applicationFromSystem.containsKey('action')) {
          application.action = applicationFromSystem['action'];
        }
        if (applicationFromSystem.containsKey('sideloaded')) {
          application.sideloaded = applicationFromSystem['sideloaded'];
        }
      }

      if (appsCategories.isNotEmpty && !application.hidden) {
        Iterable<AppCategory> currentApplicationCategories = appsCategories
            .where((appCategory) => appCategory.appPackageName == application.packageName);

        for (AppCategory appCategory in currentApplicationCategories) {
          if (_categoriesById.containsKey(appCategory.categoryId)) {
            Category category = _categoriesById[appCategory.categoryId]!;
            application.categoryOrders[category.id] = appCategory.order;
            category.applications.add(application);
          }
        }
      }
    }

    for (Category category in _categoriesById.values) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  /// Groups [rows] into sections by their `section_id`.
  ///
  /// Tolerates every shape a hand-edited backup file can produce: rows of one
  /// section disagreeing about where the section sits, orders with gaps,
  /// duplicates or negative values, and an empty URI or target package. None of
  /// them throws, and none of them loses a row.
  Future<List<ContentShortcutSection>> _buildContentShortcutSections(
    List<ContentShortcutRow> rows,
    Set<String> installedPackageNames,
  ) async {
    final Map<int, ContentShortcutSection> sectionsById = {};
    final Map<String, bool> installedByPackageName = {};

    for (final ContentShortcutRow row in rows) {
      final ContentShortcutSection section = sectionsById.putIfAbsent(
        row.sectionId,
        () => ContentShortcutSection(id: row.sectionId, order: row.sectionOrder),
      );
      // Every row of a section carries the section's order, so they can only
      // disagree if the database was hand-edited or restored from a tampered
      // file. The smallest value wins, so the outcome is at least deterministic.
      if (row.sectionOrder < section.order) {
        section.order = row.sectionOrder;
      }

      final ContentShortcut shortcut = ContentShortcut(
        id: row.id,
        sectionId: row.sectionId,
        order: row.order,
        label: row.label,
        uri: row.uri,
        targetPackage: row.targetPackage,
        available: false,
      );
      shortcut.available = shortcut.launchable &&
          await _isTargetInstalled(row.targetPackage,
              installedPackageNames: installedPackageNames, cache: installedByPackageName);
      section.shortcuts.add(shortcut);
    }

    final List<ContentShortcutSection> sections = sectionsById.values.toList(growable: false);
    for (final ContentShortcutSection section in sections) {
      section.shortcuts.sort((s0, s1) => s0.order.compareTo(s1.order));
    }
    return sections;
  }

  /// Whether the package a shortcut pins is installed.
  ///
  /// A shortcut target does not have to be a launchable application, so the list
  /// the launcher already holds is only the fast path; anything missing from it
  /// is asked about explicitly. A check that cannot be answered counts as
  /// installed: nothing is ever destroyed on the strength of it, and a shortcut
  /// wrongly greyed out is a worse lie than one that fails when pressed.
  Future<bool> _isTargetInstalled(
    String packageName, {
    Set<String>? installedPackageNames,
    Map<String, bool>? cache,
  }) async {
    if (packageName.isEmpty) {
      return false;
    }
    if (installedPackageNames?.contains(packageName) ?? _applications.containsKey(packageName)) {
      return true;
    }
    final bool? cached = cache?[packageName];
    if (cached != null) {
      return cached;
    }
    bool exists;
    try {
      exists = await _fLauncherChannel.applicationExists(packageName);
    } catch (_) {
      exists = true;
    }
    cache?[packageName] = exists;
    return exists;
  }

  ContentShortcutSection? _contentShortcutSection(int sectionId) => _launcherSections
      .whereType<ContentShortcutSection>()
      .firstWhereOrNull((section) => section.id == sectionId);

  /// The live shortcut behind [shortcut], which may be a copy handed out by
  /// [contentShortcutSections]. Mutating anything else would update an object
  /// nothing renders.
  ContentShortcut? _liveContentShortcut(ContentShortcut shortcut) {
    for (final ContentShortcutSection section in _launcherSections.whereType<ContentShortcutSection>()) {
      final ContentShortcut? found = section.shortcuts.firstWhereOrNull((s) => s.id == shortcut.id);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  /// The installed applications that publicly declare an intent filter for [uri],
  /// so the user picks the target instead of the launcher guessing a package.
  Future<List<Map<String, dynamic>>> resolveContentShortcutTargets(String uri) =>
      _fLauncherChannel.resolveUriTargets(uri);

  /// Creates a shortcut, either in the section [sectionId] or — when that is
  /// null, or names a section that is gone — in a new section appended after
  /// every existing one.
  ///
  /// Returns the new shortcut's id.
  Future<int> addContentShortcut({
    required String label,
    required String uri,
    required String targetPackage,
    int? sectionId,
    bool shouldNotifyListeners = true,
  }) async {
    ContentShortcutSection? section = sectionId == null ? null : _contentShortcutSection(sectionId);

    final int resolvedSectionId;
    final int sectionOrder;
    if (section != null) {
      resolvedSectionId = section.id;
      sectionOrder = section.order;
    } else {
      resolvedSectionId = await _database.nextContentShortcutSectionId();
      sectionOrder = _launcherSections.length;
    }

    final int order = await _database.nextContentShortcutOrder(resolvedSectionId);
    final int shortcutId = await _database.insertContentShortcut(ContentShortcutsCompanion.insert(
      sectionId: resolvedSectionId,
      sectionOrder: sectionOrder,
      order: order,
      label: label,
      uri: uri,
      targetPackage: targetPackage,
    ));

    final ContentShortcut shortcut = ContentShortcut(
      id: shortcutId,
      sectionId: resolvedSectionId,
      order: order,
      label: label,
      uri: uri,
      targetPackage: targetPackage,
      available: false,
    );
    shortcut.available = shortcut.launchable && await _isTargetInstalled(targetPackage);

    if (section == null) {
      section = ContentShortcutSection(id: resolvedSectionId, order: sectionOrder);
      _launcherSections.add(section);
    }
    section.shortcuts.add(shortcut);

    if (shouldNotifyListeners) {
      notifyListeners();
    }

    return shortcutId;
  }

  /// Edits a shortcut. Every argument left null keeps its current value.
  Future<void> updateContentShortcut(
    ContentShortcut shortcut, {
    String? label,
    String? uri,
    String? targetPackage,
  }) async {
    final ContentShortcut? live = _liveContentShortcut(shortcut);
    final String newLabel = label ?? shortcut.label;
    final String newUri = uri ?? shortcut.uri;
    final String newTargetPackage = targetPackage ?? shortcut.targetPackage;

    await _database.updateContentShortcut(
      shortcut.id,
      ContentShortcutsCompanion(
        label: Value(newLabel),
        uri: Value(newUri),
        targetPackage: Value(newTargetPackage),
      ),
    );

    if (live != null) {
      live.label = newLabel;
      live.uri = newUri;
      live.targetPackage = newTargetPackage;
      live.available = live.launchable && await _isTargetInstalled(newTargetPackage);
    }

    notifyListeners();
  }

  /// Deletes a shortcut, and with it its section when it was the last one left:
  /// a shortcut section owns no row of its own, it *is* its shortcuts.
  Future<void> deleteContentShortcut(ContentShortcut shortcut) async {
    await _database.deleteContentShortcut(shortcut.id);

    final ContentShortcutSection? section = _contentShortcutSection(shortcut.sectionId);
    if (section != null) {
      section.shortcuts.removeWhere((s) => s.id == shortcut.id);
      if (section.shortcuts.isEmpty) {
        _launcherSections.remove(section);
      } else {
        await _persistContentShortcutOrder(section);
      }
    }

    notifyListeners();
  }

  /// Moves a shortcut inside its section, in memory only, mirroring
  /// [reorderApplication]. Call [saveContentShortcutOrder] to persist it.
  void reorderContentShortcut(ContentShortcutSection section, int oldIndex, int newIndex) {
    final ContentShortcutSection? found = _contentShortcutSection(section.id);
    if (found == null) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= found.shortcuts.length || newIndex < 0 || newIndex >= found.shortcuts.length) {
      return;
    }

    final ContentShortcut shortcut = found.shortcuts.removeAt(oldIndex);
    found.shortcuts.insert(newIndex, shortcut);

    notifyListeners();
  }

  Future<void> saveContentShortcutOrder(ContentShortcutSection section) async {
    final ContentShortcutSection? found = _contentShortcutSection(section.id);
    if (found == null) {
      return;
    }

    await _persistContentShortcutOrder(found);
    notifyListeners();
  }

  Future<void> _persistContentShortcutOrder(ContentShortcutSection section) async {
    final List<ContentShortcutsCompanion> values = [];
    for (int i = 0; i < section.shortcuts.length; ++i) {
      section.shortcuts[i].order = i;
      values.add(ContentShortcutsCompanion(id: Value(section.shortcuts[i].id), order: Value(i)));
    }
    await _database.updateContentShortcuts(values);
  }

  /// Opens a shortcut, with its stored target package pinned so that Android
  /// cannot answer with an app chooser — a dialog the user would have to resolve
  /// with the remote every single time.
  ///
  /// Returns whether the target actually took the intent. A refusal re-checks
  /// the target and leaves the shortcut marked unavailable; it never deletes it.
  Future<bool> launchContentShortcut(ContentShortcut shortcut) async {
    if (!shortcut.launchable) {
      return false;
    }

    final bool launched = await _fLauncherChannel.launchUri(shortcut.uri, shortcut.targetPackage);

    final ContentShortcut? live = _liveContentShortcut(shortcut);
    if (!launched && live != null) {
      live.available = await _isTargetInstalled(live.targetPackage);
      notifyListeners();
    }

    return launched;
  }

  void sortCategory(Category category) {
    if (category.sort == CategorySort.alphabetical) {
      category.applications.sortBy(
              (application) => application.name);
    }
    else if (category.sort == CategorySort.lastUsed) {
      category.applications.sort((a, b) {
        final aTime = a.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastLaunchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // Descending (newest first)
      });
    }
    else {
      category.applications.sortBy<num>(
              (application) => application.categoryOrders[category.id]!);
    }
  }

  /// Finds the appropriate category for a newly installed app.
  /// Returns "All Apps" category, or falls back to first non-Favorites category.
  Category? _findTargetCategoryForNewApp() {
    return _categoriesById.values.firstWhere(
      (c) => c.name.toLowerCase() == "all apps",
      orElse: () {
        return _categoriesById.values.firstWhere(
          (c) => c.name.toLowerCase() != 'favorites',
          orElse: () => _categoriesById.values.first,
        );
      },
    );
  }

  Future<Uint8List> getAppBanner(String packageName) async {
    if (_bannerCache.containsKey(packageName)) {
      return _bannerCache[packageName]!;
    }

    try {
      final prefs = await _prefsAsync;
      final customBannerPath = prefs.getString('custom_banner_$packageName');
      if (customBannerPath != null) {
        final file = File(customBannerPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _bannerCache[packageName] = bytes;
          return bytes;
        }
      }
    } on FileSystemException {
      // File was deleted between check and read - clear stale reference
      final prefs = await _prefsAsync;
      await prefs.remove('custom_banner_$packageName');
    } catch (_) {
      // Ignore other errors reading custom banner
    }

    final bytes = await _fLauncherChannel.getApplicationBanner(packageName);
    if (bytes.isNotEmpty) {
      _bannerCache[packageName] = bytes;
    }
    return bytes;
  }

  Future<void> setCustomAppBanner(String packageName, String imagePath) async {
    final prefs = await _prefsAsync;
    await prefs.setString('custom_banner_$packageName', imagePath);
    _bannerCache.remove(packageName);
    _dirtyImagePackages.add(packageName);
    notifyListeners();
  }

  Future<void> removeCustomAppBanner(String packageName) async {
    final prefs = await _prefsAsync;
    final customBannerPath = prefs.getString('custom_banner_$packageName');
    if (customBannerPath != null) {
      try {
        await File(customBannerPath).delete();
      } catch (_) {
        // Ignore file deletion errors
      }
    }
    await prefs.remove('custom_banner_$packageName');
    _bannerCache.remove(packageName);
    _dirtyImagePackages.add(packageName);
    notifyListeners();
  }

  Future<bool> hasCustomBanner(String packageName) async {
    final prefs = await _prefsAsync;
    return prefs.containsKey('custom_banner_$packageName');
  }

  Future<Uint8List> getAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName]!;
    }
    final bytes = await _fLauncherChannel.getApplicationIcon(packageName);
    if (bytes.isNotEmpty) {
      _iconCache[packageName] = bytes;
    }
    return bytes;
  }

  Future<void> launchApp(App app) async {
    app.lastLaunchedAt = DateTime.now();
    await _database.updateApp(app.packageName, AppsCompanion(lastLaunchedAt: Value(app.lastLaunchedAt)));
    notifyListeners();

    Future<void> future;
    if (app.action == null) {
      future = _fLauncherChannel.launchApp(app.packageName);
    }
    else {
      future = _fLauncherChannel.launchActivityFromAction(app.action!);
    }

    return future;
  }

  Future<void> openAppInfo(App app) => _fLauncherChannel.openAppInfo(app.packageName);

  Future<void> uninstallApp(App app) => _fLauncherChannel.uninstallApp(app.packageName);

  Future<void> openSettings() => _fLauncherChannel.openSettings();

  Future<bool> isDefaultLauncher() => _fLauncherChannel.isDefaultLauncher();

  Future<void> startAmbientMode() => _fLauncherChannel.startAmbientMode();

  Future<void> addToCategory(App app, Category category, {bool shouldNotifyListeners = true}) async {
    int index = await _database.nextAppCategoryOrder(category.id) ?? 0;
    await _database.insertAppsCategories([
      AppsCategoriesCompanion.insert(
        categoryId: category.id,
        appPackageName: app.packageName,
        order: index,
      )
    ]);

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      app.categoryOrders[categoryFound.id] = index;
      categoryFound.applications.add(app);

      if (shouldNotifyListeners) {
        sortCategory(categoryFound);
        notifyListeners();
      }
    }
  }

  Future<void> removeFromCategory(App application, Category category) async {
    await _database.deleteAppCategory(category.id, application.packageName);
    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      application.categoryOrders.remove(categoryFound.id);
      categoryFound.applications.remove(application);

      notifyListeners();
    }
  }

  /// Auto-populates a category based on its special name.
  /// For "All Apps": adds all non-hidden apps regardless of sideloaded status.
  Future<void> autoPopulateCategory(Category category) async {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    Category actualCategory = _categoriesById[category.id]!;
    
    Iterable<App> appsToAdd;
    
    switch (actualCategory.name) {
      case 'All Apps':
        appsToAdd = _applications.values.where((app) => !app.hidden);
        break;
      default:
        return;
    }
    
    for (final app in appsToAdd) {
      await addToCategory(app, actualCategory, shouldNotifyListeners: false);
    }
    
    notifyListeners();
  }

  Category? _getAppsCategory() {
    return _categoriesById.values.firstWhereOrNull(
          (category) => category.name == 'All Apps',
    );
  }

  /// Gets the Favorites category, creating it if it doesn't exist
  Future<Category> getOrCreateFavoritesCategory() async {
    Category? favorites = _categoriesById.values.firstWhereOrNull(
      (category) => category.name == 'Favorites'
    );
    
    if (favorites != null) {
      return favorites;
    }
    
    int categoryId = await addCategory('Favorites', shouldNotifyListeners: false);
    return _categoriesById[categoryId]!;
  }
  
  /// Checks if an app is in the Favorites category
  bool isAppInFavorites(App app) {
    Category? favorites = _categoriesById.values.firstWhereOrNull(
      (category) => category.name == 'Favorites'
    );
    
    if (favorites == null) {
      return false;
    }
    
    return favorites.applications.any((a) => a.packageName == app.packageName);
  }
  
  /// Adds an app to Favorites and removes it from the Apps category
  Future<void> addToFavorites(App app) async {
    Category favorites = await getOrCreateFavoritesCategory();
    
    if (!favorites.applications.any((a) => a.packageName == app.packageName)) {
      await addToCategory(app, favorites, shouldNotifyListeners: false);
    }

    final appsCategory = _getAppsCategory();
    if (appsCategory != null &&
        appsCategory.applications.any((a) => a.packageName == app.packageName)) {
      await removeFromCategory(app, appsCategory);
    } else {
      notifyListeners();
    }
  }
  
  /// Removes an app from Favorites and puts it back in the Apps category
  Future<void> removeFromFavorites(App app) async {
    Category? favorites = _categoriesById.values.firstWhereOrNull(
      (category) => category.name == 'Favorites'
    );
    
    if (favorites != null) {
      await removeFromCategory(app, favorites);
    }

    final appsCategory = _getAppsCategory();
    if (appsCategory != null &&
        !appsCategory.applications.any((a) => a.packageName == app.packageName)) {
      await addToCategory(app, appsCategory);
    }
  }
  
  /// Toggles an app in/out of Favorites
  Future<void> toggleFavorite(App app) async {
    if (isAppInFavorites(app)) {
      await removeFromFavorites(app);
    } else {
      await addToFavorites(app);
    }
  }

  Future<void> saveApplicationOrderInCategory(Category category) async {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    
    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    List<AppsCategoriesCompanion> orderedAppCategories = [];

    for (int i = 0; i < applications.length; ++i) {
      orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(categoryFound.id),
        appPackageName: Value(applications[i].packageName),
        order: Value(i),
      ));
    }
    await _database.replaceAppsCategories(orderedAppCategories);
    notifyListeners();
  }

  Future<void> moveAppToAdjacentCategory(App app, Category currentCategory, AxisDirection direction) async {
    int currentSectionIndex = _launcherSections.indexOf(currentCategory);
    if (currentSectionIndex == -1) {
       return;
    }

    int targetSectionIndex = -1;
    Category? targetCategory;

    // Find next valid category (skip spacers)
    if (direction == AxisDirection.down) {
      for (int i = currentSectionIndex + 1; i < _launcherSections.length; i++) {
        if (_launcherSections[i] is Category) {
          targetSectionIndex = i;
          targetCategory = _launcherSections[i] as Category;
          break;
        }
      }
    } else if (direction == AxisDirection.up) {
      for (int i = currentSectionIndex - 1; i >= 0; i--) {
        if (_launcherSections[i] is Category) {
          targetSectionIndex = i;
          targetCategory = _launcherSections[i] as Category;
          break;
        }
      }
    }

    if (targetCategory == null) {
      return;
    }

    // Remove from current
    await removeFromCategory(app, currentCategory);
    
    // Set pending focus package so AppCard can reclaim focus and reorder mode
    _pendingReorderFocusPackage = app.packageName;
    
    // Add to target
    int newIndex = 0;
    if (direction == AxisDirection.up) {
      // If moving UP (to previous section), append to BOTTOM
       newIndex = await _database.nextAppCategoryOrder(targetCategory.id) ?? 0;
    } else {
      // If moving DOWN (to next section), insert at TOP (index 0)
      newIndex = 0;
    }

    // DB Insert Logic
    // 1. Get current items in target
    List<App> targetApps = targetCategory.applications;
    
    // 2. Adjust local list
    if (direction == AxisDirection.down) {
       targetApps.insert(0, app); // Insert at top
    } else {
       targetApps.add(app); // Insert at bottom
    }
    
    // 3. Update orders for all items in target category
    List<AppsCategoriesCompanion> orderedAppCategories = [];
    for (int i = 0; i < targetApps.length; ++i) {
       App a = targetApps[i];
       a.categoryOrders[targetCategory.id] = i; // Update local map
       orderedAppCategories.add(AppsCategoriesCompanion(
        categoryId: Value(targetCategory.id),
        appPackageName: Value(a.packageName),
        order: Value(i),
      ));
    }
    
    // 4. Batch DB update
    await _database.replaceAppsCategories(orderedAppCategories);
    
    notifyListeners();
  }

  void reorderApplication(Category category, int oldIndex, int newIndex) {
    if (!_categoriesById.containsKey(category.id)) {
      return;
    }
    Category categoryFound = _categoriesById[category.id]!;
    List<App> applications = categoryFound.applications;
    App application = applications.removeAt(oldIndex);
    applications.insert(newIndex, application);

    notifyListeners();
  }

  Future<int> addCategory(String categoryName, {
    CategorySort sort = Category.Sort,
    CategoryType type = Category.Type,
    int columnsCount = Category.ColumnsCount,
    int rowHeight = Category.RowHeight,
    bool shouldNotifyListeners = true
  }) async {
    List<CategoriesCompanion> orderedCategories = [];
    int categoryOrder = 1, newCategoryId = -1;
    for (Category category in _categoriesById.values) {
      orderedCategories.add(CategoriesCompanion(id: Value(category.id), order: Value(categoryOrder++)));
    }

    try {
      newCategoryId = await _database.transaction(() async {
        int newCategoryId = await _database.insertCategory(CategoriesCompanion.insert(name: categoryName, order: 0));
        await _database.updateCategories(orderedCategories);

        return newCategoryId;
      });

      Map<int, Category> newCategories = Map();
      Category newCategory = Category(
          id: newCategoryId,
          name: categoryName,
          sort: sort,
          type: type,
          columnsCount: columnsCount,
          rowHeight: rowHeight,
          order: 0
      );
      newCategories[newCategoryId] = newCategory;

      categoryOrder = 1;
      for (Category category in _categoriesById.values) {
        newCategories[category.id] = category;
        category.order = categoryOrder++;
      }

      _categoriesById = newCategories;
      _launcherSections.add(newCategory);

      if (shouldNotifyListeners) {
        notifyListeners();
      }

    }
    catch (ex) { }

    return newCategoryId;
  }

  Future<void> updateCategory(
    int categoryId,
    String name,
    CategorySort sort,
    CategoryType type,
    int columnsCount,
    int rowHeight, {
    bool shouldNotifyListeners = true
    }) async
  {
    Category? category = _categoriesById[categoryId];
    assert(category != null);

    await _database.updateCategory(categoryId, CategoriesCompanion(
      name: Value(name),
      sort: Value(sort),
      type: Value(type),
      columnsCount: Value(columnsCount),
      rowHeight: Value(rowHeight)
    ));

    CategorySort oldSort = category!.sort;

    category.name = name;
    category.sort = sort;
    category.type = type;
    category.columnsCount = columnsCount;
    category.rowHeight = rowHeight;

    if (oldSort != sort) {
      sortCategory(category);
    }

    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  Future<void> addSpacer(int height) async
  {
    int order = launcherSections.length;
    int spacerId = await _database.insertSpacer(
        LauncherSpacersCompanion.insert(height: height, order: order)
    );

    _launcherSections.add(LauncherSpacer(
      id: spacerId,
      height: height,
      order: order
    ));

    notifyListeners();
  }

  Future<void> updateSpacerHeight(LauncherSpacer spacer, int height) async
  {
    await _database.updateSpacer(spacer.id, LauncherSpacersCompanion(
      height: Value(height)
    ));

    spacer.height = height;
    notifyListeners();
  }

  Future<void> renameCategory(Category category, String categoryName) async {
    await _database.updateCategory(category.id, CategoriesCompanion(name: Value(categoryName)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.name = categoryName;
      notifyListeners();
    }
  }

  Future<void> deleteSection(int index) async
  {
    assert(index < _launcherSections.length);

    // One explicit branch per section type, never a catch-all `else`: a section
    // type with no branch here used to delete the *spacer* whose id happened to
    // match. An unknown type now leaves the store alone instead.
    LauncherSection section = _launcherSections[index];
    if (section is Category) {
      await _database.deleteCategory(section.id);
      _categoriesById.remove(section.id);
    }
    else if (section is LauncherSpacer) {
      await _database.deleteSpacer(section.id);
    }
    else if (section is ContentShortcutSection) {
      await _database.deleteContentShortcutSection(section.id);
    }

    _launcherSections.removeAt(index);

    notifyListeners();
  }

  void moveSectionInMemory(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _launcherSections.length ||
        newIndex < 0 || newIndex >= _launcherSections.length) return;
        
    final section = _launcherSections.removeAt(oldIndex);
    _launcherSections.insert(newIndex, section);
    notifyListeners();
  }

  Future<void> persistSectionsOrder() async {
    List<CategoriesCompanion> orderedCategories = [];
    List<LauncherSpacersCompanion> orderedSpacers = [];
    List<MapEntry<int, int>> orderedShortcutSections = [];

    for (int i = 0; i < _launcherSections.length; ++i) {
      LauncherSection section = _launcherSections[i];
      // `order` lives on LauncherSection, so one assignment covers every type,
      // present and future.
      section.order = i;

      if (section is Category) {
        orderedCategories.add(CategoriesCompanion(id: Value(section.id), order: Value(i)));
      }
      else if (section is LauncherSpacer) {
        orderedSpacers.add(LauncherSpacersCompanion(id: Value(section.id), order: Value(i)));
      }
      else if (section is ContentShortcutSection) {
        // Written for the whole group at once, so the section's rows can never
        // disagree about where the section sits.
        orderedShortcutSections.add(MapEntry(section.id, i));
      }
    }

    final List<Future<void>> writes = [
      _database.updateCategories(orderedCategories),
      _database.updateSpacers(orderedSpacers),
    ];
    for (final MapEntry<int, int> entry in orderedShortcutSections) {
      writes.add(_database.updateContentShortcutSectionOrder(entry.key, entry.value));
    }

    await Future.wait(writes);
  }

  Future<void> moveSection(int oldIndex, int newIndex) async {
    moveSectionInMemory(oldIndex, newIndex);
    await persistSectionsOrder();
  }

  Future<void> hideApplication(App application) async {
    await _database.updateApp(application.packageName, const AppsCompanion(hidden: Value(true)));

    if (_applications.containsKey(application.packageName)) {
      App applicationFound = _applications[application.packageName]!;
      applicationFound.hidden = true;

      for (int categoryId in applicationFound.categoryOrders.keys) {
        if (_categoriesById.containsKey(categoryId)) {
          Category category = _categoriesById[categoryId]!;
          category.applications.removeWhere((application0) => application0.packageName == application.packageName);
        }
      }

      notifyListeners();
    }
  }

  Future<void> showApplication(App application) async {
    await _database.updateApp(application.packageName, const AppsCompanion(hidden: Value(false)));

    if (_applications.containsKey(application.packageName)) {
      App applicationFound = _applications[application.packageName]!;
      applicationFound.hidden = false;

      for (int categoryId in application.categoryOrders.keys) {
        if (_categoriesById.containsKey(categoryId)) {
          Category category = _categoriesById[categoryId]!;
          category.applications.add(application);
          sortCategory(category);
        }
      }

      notifyListeners();
    }
  }

  Future<void> setCategoryType(Category category, CategoryType type, {bool shouldNotifyListeners = true}) async {
    await _database.updateCategory(category.id, CategoriesCompanion(type: Value(type)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.type = type;

      if (shouldNotifyListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> setCategorySort(Category category, CategorySort sort) async {
    await _database.updateCategory(category.id, CategoriesCompanion(sort: Value(sort)));
    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.sort = sort;
      sortCategory(categoryFound);

      notifyListeners();
    }

  }

  Future<void> setCategoryColumnsCount(Category category, int columnsCount) async {
    await _database.updateCategory(category.id, CategoriesCompanion(columnsCount: Value(columnsCount)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.columnsCount = columnsCount;

      notifyListeners();
    }
  }

  Future<void> setCategoryRowHeight(Category category, int rowHeight) async {
    await _database.updateCategory(category.id, CategoriesCompanion(rowHeight: Value(rowHeight)));

    if (_categoriesById.containsKey(category.id)) {
      Category categoryFound = _categoriesById[category.id]!;
      categoryFound.rowHeight = rowHeight;
      notifyListeners();
    }
  }
}
