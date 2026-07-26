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

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';

part 'database.drift.dart';

@UseRowClass(App)
class Apps extends Table
{
  TextColumn get packageName => text()();

  TextColumn get name => text()();

  TextColumn get version => text()();

  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  DateTimeColumn get lastLaunchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {packageName};
}

@UseRowClass(Category)
class Categories extends Table
{
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get sort => intEnum<CategorySort>().withDefault(Constant(Category.Sort.index))();

  IntColumn get type => intEnum<CategoryType>().withDefault(Constant(Category.Type.index))();

  IntColumn get rowHeight => integer().withDefault(const Constant(Category.RowHeight))();

  IntColumn get columnsCount => integer().withDefault(const Constant(Category.ColumnsCount))();

  IntColumn get order => integer()();
}

@UseRowClass(LauncherSpacer)
class LauncherSpacers extends Table
{
  IntColumn get id => integer().autoIncrement()();

  IntColumn get height => integer()();

  IntColumn get order => integer()();
}

@DataClassName("AppCategory")
class AppsCategories extends Table
{
  IntColumn get categoryId => integer().customConstraint("REFERENCES categories(id) ON DELETE CASCADE")();

  TextColumn get appPackageName => text().customConstraint("REFERENCES apps(package_name) ON DELETE CASCADE")();

  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {categoryId, appPackageName};
}

@DriftDatabase(tables: [Apps, Categories, AppsCategories, LauncherSpacers])
class FLauncherDatabase extends _$FLauncherDatabase
{
  late final bool wasCreated;

  FLauncherDatabase(DatabaseConnection super.databaseConnection);

  FLauncherDatabase.inMemory() : super(LazyDatabase(() => NativeDatabase.memory()));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
        },
        // Stepped migration: every block upgrades the database by exactly one
        // schema version.
        //
        // Two rules keep the chain internally consistent, and both must be
        // respected when adding a new step:
        //
        //  1. A historical step is expressed with literal SQL describing the
        //     schema as it existed at *that* version. Historical steps must never
        //     be written in terms of the current Dart tables: those keep
        //     evolving, so a step referring to them would silently start
        //     migrating old databases to the wrong shape (or fail outright, as
        //     soon as a column it copies no longer exists).
        //     The one exception is the v7 `createTable(launcherSpacers)` below:
        //     that table has not changed since it was introduced. If it ever
        //     does, replace the call with the literal v7 CREATE TABLE.
        //  2. Every step is bounded by `to` as well as `from`, so that a
        //     migration to an intermediate version stops there instead of
        //     applying later steps. In the app `to` is always [schemaVersion],
        //     so this only matters for migration tests.
        onUpgrade: (migrator, from, to) async {
          if (from < 2 && to >= 2) {
            // v2 removed the unused "class_name" column from "apps".
            await customStatement('ALTER TABLE apps DROP COLUMN "class_name";');
          }
          if (from < 3 && to >= 3) {
            // v3 added "hidden" to "apps".
            await customStatement(
                'ALTER TABLE apps ADD COLUMN "hidden" INTEGER NOT NULL DEFAULT 0 CHECK ("hidden" IN (0, 1));');
          }
          if (from < 4 && to >= 4) {
            // v4 added the per-category display settings.
            await customStatement('ALTER TABLE categories ADD COLUMN "sort" INTEGER NOT NULL DEFAULT 0;');
            await customStatement('ALTER TABLE categories ADD COLUMN "type" INTEGER NOT NULL DEFAULT 0;');
            await customStatement('ALTER TABLE categories ADD COLUMN "row_height" INTEGER NOT NULL DEFAULT 110;');
            await customStatement('ALTER TABLE categories ADD COLUMN "columns_count" INTEGER NOT NULL DEFAULT 6;');
            // "Applications" is the default category and is rendered as a grid.
            // 1 is CategoryType.grid at the time this step was introduced; it is
            // hardcoded so that reordering the enum cannot rewrite history.
            await customStatement("UPDATE categories SET \"type\" = 1 WHERE \"name\" = 'Applications';");
          }
          if (from < 5 && to >= 5) {
            // v5 added "sideloaded" to "apps"; v7 removed it again. The column no
            // longer exists in the Dart schema, so it is recreated literally: the
            // v7 step below can then drop it unconditionally.
            await customStatement(
                'ALTER TABLE apps ADD COLUMN "sideloaded" INTEGER NOT NULL DEFAULT 0 CHECK ("sideloaded" IN (0, 1));');
          }
          if (from < 6 && to >= 6) {
            // v6 moved app artwork out of the database.
            await customStatement('ALTER TABLE apps DROP COLUMN "banner";');
            await customStatement('ALTER TABLE apps DROP COLUMN "icon";');
          }
          if (from < 7 && to >= 7) {
            // v7 introduced launcher spacers and removed "sideloaded".
            await migrator.createTable(launcherSpacers);
            await customStatement('ALTER TABLE apps DROP COLUMN "sideloaded";');
          }
          if (from < 8 && to >= 8) {
            // v8 added "last_launched_at" to "apps".
            await customStatement('ALTER TABLE apps ADD COLUMN "last_launched_at" INTEGER NULL;');
          }
          if (from < 9 && to >= 9) {
            await _mergeTvAndNonTvCategories();
          }
          if (from < 10 && to >= 10) {
            await _stripFavoritesFromAllApps();
          }
        },
        beforeOpen: (openingDetails) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA journal_mode = WAL;');
          wasCreated = openingDetails.wasCreated;
        },
      );

  /// Migration: merge "TV Apps" and "Non-TV Apps" into a single "All Apps" category.
  Future<void> _mergeTvAndNonTvCategories() async {
    final tvRows = await customSelect(
      "SELECT id FROM categories WHERE name = 'TV Apps'",
    ).get();
    final nonTvRows = await customSelect(
      "SELECT id FROM categories WHERE name = 'Non-TV Apps'",
    ).get();

    final int? tvId = tvRows.isNotEmpty ? tvRows.first.read<int>('id') : null;
    final int? nonTvId = nonTvRows.isNotEmpty ? nonTvRows.first.read<int>('id') : null;

    if (tvId != null && nonTvId != null) {
      // Both exist: rename TV Apps -> All Apps, move Non-TV apps into it, delete Non-TV category
      await customStatement("UPDATE categories SET name = 'All Apps' WHERE id = ?", [tvId]);

      final maxOrderResult = await customSelect(
        "SELECT COALESCE(MAX(\"order\"), -1) + 1 AS next_order FROM apps_categories WHERE category_id = ?",
        variables: [Variable.withInt(tvId)],
      ).getSingle();
      int nextOrder = maxOrderResult.read<int>('next_order');

      final nonTvEntries = await customSelect(
        "SELECT app_package_name FROM apps_categories WHERE category_id = ? ORDER BY \"order\"",
        variables: [Variable.withInt(nonTvId)],
      ).get();

      for (final entry in nonTvEntries) {
        final packageName = entry.read<String>('app_package_name');
        await customStatement(
          "INSERT OR IGNORE INTO apps_categories (category_id, app_package_name, \"order\") VALUES (?, ?, ?)",
          [tvId, packageName, nextOrder],
        );
        nextOrder++;
      }

      await customStatement("DELETE FROM apps_categories WHERE category_id = ?", [nonTvId]);
      await customStatement("DELETE FROM categories WHERE id = ?", [nonTvId]);
    } else if (tvId != null) {
      await customStatement("UPDATE categories SET name = 'All Apps' WHERE id = ?", [tvId]);
    } else if (nonTvId != null) {
      await customStatement("UPDATE categories SET name = 'All Apps' WHERE id = ?", [nonTvId]);
    }
  }

  /// Migration: remove apps that are in "Favorites" from "All Apps",
  /// so the data model matches the UI (favorites live only in the dock).
  Future<void> _stripFavoritesFromAllApps() async {
    final allAppsRows = await customSelect(
      "SELECT id FROM categories WHERE name = 'All Apps'",
    ).get();
    final favRows = await customSelect(
      "SELECT id FROM categories WHERE name = 'Favorites'",
    ).get();

    if (allAppsRows.isEmpty || favRows.isEmpty) return;

    final allAppsId = allAppsRows.first.read<int>('id');
    final favId = favRows.first.read<int>('id');

    await customStatement(
      "DELETE FROM apps_categories "
      "WHERE category_id = ? AND app_package_name IN "
      "(SELECT app_package_name FROM apps_categories WHERE category_id = ?)",
      [allAppsId, favId],
    );
  }

  Future<void> persistApps(Iterable<AppsCompanion> applications) =>
      batch((batch) => batch.insertAllOnConflictUpdate(apps, applications));

  Future<void> updateApp(String packageName, AppsCompanion value) =>
      (update(apps)..where((tbl) => tbl.packageName.equals(packageName))).write(value);

  Future<void> deleteApps(List<String> packageNames) =>
      (delete(apps)..where((tbl) => tbl.packageName.isIn(packageNames))).go();

  Future<int> insertCategory(Insertable<Category> category) => into(categories).insert(category);

  Future<void> deleteCategory(int id) => (delete(categories)..where((tbl) => tbl.id.equals(id))).go();

  Future<void> updateCategories(List<CategoriesCompanion> values) => batch(
        (batch) {
          for (final value in values) {
            batch.update<$CategoriesTable, Category>(
              categories,
              value,
              where: (table) => (table.id.equals(value.id.value)),
            );
          }
        },
      );

  Future<void> updateCategory(int id, CategoriesCompanion value) =>
      (update(categories)..where((tbl) => tbl.id.equals(id))).write(value);

  Future<void> deleteAppCategory(int categoryId, String packageName) => (delete(appsCategories)
        ..where((tbl) => tbl.categoryId.equals(categoryId) & tbl.appPackageName.equals(packageName)))
      .go();

  Future<void> insertAppsCategories(List<AppsCategoriesCompanion> value) =>
      batch((batch) => batch.insertAll(appsCategories, value, mode: InsertMode.insertOrIgnore));

  Future<void> replaceAppsCategories(List<AppsCategoriesCompanion> value) =>
      batch((batch) => batch.replaceAll(appsCategories, value));

  Future<int> insertSpacer(Insertable<LauncherSpacer> spacer) => into(launcherSpacers).insert(spacer);

  Future<int> deleteSpacer(int spacerId) => (delete(launcherSpacers)..where(
          (spacer) => spacer.id.equals(spacerId))).go();

  Future<int> updateSpacer(int spacerId, Insertable<LauncherSpacer> insertable) => (update(launcherSpacers)..where(
          (spacer) => spacer.id.equals(spacerId))).write(insertable);

  Future<void> updateSpacers(Iterable<LauncherSpacersCompanion> values) => batch(
        (batch) {
          for (final value in values) {
            batch.update<$LauncherSpacersTable, LauncherSpacer>(
              launcherSpacers,
              value,
              where: (table) => (table.id.equals(value.id.value)),
            );
          }
        }
      );

  Future<List<Category>> getCategories()
  {
    final query = select(categories);
    query.orderBy([ (c) => OrderingTerm.asc(c.order) ]);

    return query.get();
  }

  Future<List<LauncherSpacer>> getLauncherSpacers()
  {
    final query = select(launcherSpacers);
    query.orderBy([ (s) => OrderingTerm.asc(s.order) ]);

    return query.get();
  }

  Future<List<AppCategory>> getAppsCategories() {
    final query = select(appsCategories);
    query.orderBy([ (c) => OrderingTerm.asc(c.appPackageName) ]);

    return query.get();
  }

  Future<List<App>> getApplications() {
    return select(apps).get();
  }

  Future<int?> nextAppCategoryOrder(int categoryId) async {
    final query = selectOnly(appsCategories);
    final maxExpression = coalesce([appsCategories.order.max(), const Constant(-1)]) + const Constant(1);
    query.addColumns([maxExpression]);
    query.where(appsCategories.categoryId.equals(categoryId));
    final result = await query.getSingle();
    return result.read(maxExpression);
  }
}

DatabaseConnection connect() => DatabaseConnection.delayed(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(path.join(dbFolder.path, 'db.sqlite'));
      return DatabaseConnection(NativeDatabase(file, logStatements: foundation.kDebugMode));
    }());
