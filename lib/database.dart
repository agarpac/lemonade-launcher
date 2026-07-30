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

/// One deep link. A *shortcut section* is the group of rows sharing
/// [sectionId]; it owns no row of its own.
///
/// Deliberately **not** `@UseRowClass(ContentShortcut)`, unlike its three
/// neighbours: [sectionOrder] is a property of the section, not of the
/// shortcut, and `ContentShortcut.available` is a runtime flag with no column
/// at all. A row class would have to be a bad fit in both directions, which is
/// exactly the mismatch that made drift's generated mapper silently drop
/// `Apps.lastLaunchedAt` (see the comment above `BackupService._exportRows`).
/// The mapping to the model happens once, in `AppsService`.
///
/// No foreign key to `apps`: that is the whole point of the table. The app
/// reconciliation in `AppsService._refreshState` deletes every `Apps` row whose
/// package the system no longer reports, and a shortcut whose target is gone
/// must survive as unavailable instead (see the PRD, section 12.3, point 5).
@DataClassName("ContentShortcutRow")
class ContentShortcuts extends Table
{
  IntColumn get id => integer().autoIncrement()();

  /// Groups shortcuts into one launcher section.
  IntColumn get sectionId => integer()();

  /// The order that places the whole section among the launcher's sections.
  /// Held by every row of the section and always written for the whole group at
  /// once, by `FLauncherDatabase.updateContentShortcutSectionOrder`.
  IntColumn get sectionOrder => integer()();

  /// Position of this shortcut inside its section.
  IntColumn get order => integer()();

  TextColumn get label => text()();

  TextColumn get uri => text()();

  TextColumn get targetPackage => text()();
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

@DriftDatabase(tables: [Apps, Categories, AppsCategories, LauncherSpacers, ContentShortcuts])
class FLauncherDatabase extends _$FLauncherDatabase
{
  late final bool wasCreated;

  FLauncherDatabase(DatabaseConnection super.databaseConnection);

  FLauncherDatabase.inMemory() : super(LazyDatabase(() => NativeDatabase.memory()));

  @override
  int get schemaVersion => 12;

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
            // DEFAULT 1, not 0: the live table declares
            // `withDefault(Constant(Category.Type.index))`, and `Category.Type`
            // is `CategoryType.grid`, whose index is 1. Written as 0 this step
            // left every migrated database with a column default that a fresh
            // install never had — invisible for years because the only insert
            // that relied on it also omitted the column, so a category created
            // on a migrated database came back as a row after a restart.
            await customStatement('ALTER TABLE categories ADD COLUMN "type" INTEGER NOT NULL DEFAULT 1;');
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
          if (from < 11 && to >= 11) {
            // v11 introduced content shortcuts (deep links) in a table of their
            // own. Purely additive: not a single existing row is read or
            // written by this step.
            //
            // Literal SQL, matching what `migrator.createTable(contentShortcuts)`
            // emits today, per rule 1 above: the v7 `createTable` call is the
            // only exception in this chain and it is not one worth extending.
            // Written character for character as drift's own `createAll` writes
            // it, so that a migrated database and a freshly created one hold
            // exactly the same DDL — `database_migration_test.dart` asserts that.
            await customStatement('CREATE TABLE "content_shortcuts" ('
                '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
                '"section_id" INTEGER NOT NULL, '
                '"section_order" INTEGER NOT NULL, '
                '"order" INTEGER NOT NULL, '
                '"label" TEXT NOT NULL, '
                '"uri" TEXT NOT NULL, '
                '"target_package" TEXT NOT NULL)');
          }
          if (from < 12 && to >= 12) {
            await _rebuildCategoriesWithCorrectTypeDefault();
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

  /// Migration (v12): recreates "categories" so that its `type` column carries
  /// the same default a fresh install has.
  ///
  /// The v4 step that introduced the column wrote `DEFAULT 0` where a fresh
  /// install has `DEFAULT 1` (`CategoryType.grid`). Fixing the v4 step is not
  /// enough: a database that has already been at v4 or later owns the column
  /// with the wrong default, `from < 4` never runs for it again, and SQLite
  /// cannot alter a column default in place. The only way out is to rebuild the
  /// table, which is why this step exists at all — it changes no column, no
  /// name and no value, only the stored DDL.
  ///
  /// ## Why this ordering is safe
  ///
  /// `apps_categories.category_id` is declared
  /// `REFERENCES categories(id) ON DELETE CASCADE`, and `apps_categories` holds
  /// every app-to-category membership there is: the whole dock and every
  /// category's contents. With foreign keys enforced, `DROP TABLE categories`
  /// counts as deleting every parent row and fires that cascade, so the naive
  /// create/copy/drop/rename would empty the launcher on the way past.
  ///
  /// Hence, in order:
  ///
  ///  1. `PRAGMA foreign_keys = OFF`, issued **outside** any transaction. The
  ///     pragma is a silent no-op while a transaction is open, and drift does
  ///     not wrap `onUpgrade` in one (`DelegatedDatabase._runMigrations` calls
  ///     `beforeOpen` — and therefore `onUpgrade` — directly), so this is the
  ///     one place it can take effect. The previous value is read first and put
  ///     back afterwards, so this step cannot change the state a later step
  ///     runs under. In the app the value here is SQLite's default of *off*
  ///     anyway: `beforeOpen` turns foreign keys on only after every migration
  ///     step has finished. Setting it explicitly means the step does not
  ///     depend on that.
  ///  2. Everything else inside a single transaction. A rebuild that failed
  ///     halfway would leave a database the launcher cannot open, and this
  ///     launcher is the device's only home screen; rolling back to an intact
  ///     v11 and retrying on the next open is the only acceptable failure mode.
  ///  3. The replacement is created under a temporary name and renamed **last**.
  ///     `apps_categories` is never written to, dropped or recreated, so its
  ///     `REFERENCES categories(id)` clause survives untouched: nothing
  ///     references the temporary name, and with foreign keys off SQLite does
  ///     not rewrite `REFERENCES` clauses on rename either way. Its rows are
  ///     briefly orphaned between the `DROP` and the `RENAME`, which is
  ///     harmless precisely because enforcement is off and both statements are
  ///     in the same transaction.
  ///
  /// Rows are copied column by column, by name, so `'All Apps'` and
  /// `'Favorites'` come across byte for byte — both names are matched by string
  /// equality elsewhere, including by the dock, and altering either empties the
  /// launcher in silence.
  ///
  /// The only thing not carried over is the AUTOINCREMENT high-water mark in
  /// `sqlite_sequence`: it is re-derived from the copied ids, so after this step
  /// a new category may take an id previously used by a deleted one. Nothing
  /// keeps a reference to a deleted category (memberships cascade), so this is
  /// a non-issue.
  ///
  /// Literal SQL, per the rules above `onUpgrade`, written character for
  /// character as drift's own `createAll` writes it: a migrated database and a
  /// fresh one must hold exactly the same DDL, which is the whole point of the
  /// step and which `database_migration_test.dart` asserts.
  Future<void> _rebuildCategoriesWithCorrectTypeDefault() async {
    final foreignKeysRow = await customSelect('PRAGMA foreign_keys').getSingleOrNull();
    final foreignKeysWereOn = (foreignKeysRow?.read<int>('foreign_keys') ?? 0) != 0;

    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await transaction(() async {
        await customStatement('CREATE TABLE "categories_v12" ('
            '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            '"name" TEXT NOT NULL, '
            '"sort" INTEGER NOT NULL DEFAULT 0, '
            '"type" INTEGER NOT NULL DEFAULT 1, '
            '"row_height" INTEGER NOT NULL DEFAULT 110, '
            '"columns_count" INTEGER NOT NULL DEFAULT 6, '
            '"order" INTEGER NOT NULL)');
        await customStatement('INSERT INTO "categories_v12" '
            '("id", "name", "sort", "type", "row_height", "columns_count", "order") '
            'SELECT "id", "name", "sort", "type", "row_height", "columns_count", "order" FROM "categories";');
        await customStatement('DROP TABLE "categories";');
        await customStatement('ALTER TABLE "categories_v12" RENAME TO "categories";');
      });
    } finally {
      if (foreignKeysWereOn) {
        await customStatement('PRAGMA foreign_keys = ON;');
      }
    }
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

  /// Every shortcut row, ordered so that grouping them by `section_id` yields
  /// the sections in the order they must appear, each with its shortcuts in
  /// their own order.
  Future<List<ContentShortcutRow>> getContentShortcuts()
  {
    final query = select(contentShortcuts);
    query.orderBy([
      (s) => OrderingTerm.asc(s.sectionOrder),
      (s) => OrderingTerm.asc(s.sectionId),
      (s) => OrderingTerm.asc(s.order),
      (s) => OrderingTerm.asc(s.id),
    ]);

    return query.get();
  }

  Future<int> insertContentShortcut(Insertable<ContentShortcutRow> shortcut) =>
      into(contentShortcuts).insert(shortcut);

  Future<int> updateContentShortcut(int shortcutId, Insertable<ContentShortcutRow> insertable) =>
      (update(contentShortcuts)..where((shortcut) => shortcut.id.equals(shortcutId))).write(insertable);

  Future<int> deleteContentShortcut(int shortcutId) =>
      (delete(contentShortcuts)..where((shortcut) => shortcut.id.equals(shortcutId))).go();

  /// Deletes a whole shortcut section: every row sharing [sectionId].
  Future<int> deleteContentShortcutSection(int sectionId) =>
      (delete(contentShortcuts)..where((shortcut) => shortcut.sectionId.equals(sectionId))).go();

  /// Moves a whole section at once, so that its rows can never disagree about
  /// where the section sits.
  Future<int> updateContentShortcutSectionOrder(int sectionId, int order) =>
      (update(contentShortcuts)..where((shortcut) => shortcut.sectionId.equals(sectionId)))
          .write(ContentShortcutsCompanion(sectionOrder: Value(order)));

  Future<void> updateContentShortcuts(Iterable<ContentShortcutsCompanion> values) => batch(
        (batch) {
          for (final value in values) {
            batch.update<$ContentShortcutsTable, ContentShortcutRow>(
              contentShortcuts,
              value,
              where: (table) => (table.id.equals(value.id.value)),
            );
          }
        }
      );

  /// The next free `section_id`. Shortcut sections have no table of their own,
  /// so nothing allocates this for us.
  Future<int> nextContentShortcutSectionId() async {
    final query = selectOnly(contentShortcuts);
    final maxExpression = coalesce([contentShortcuts.sectionId.max(), const Constant(0)]) + const Constant(1);
    query.addColumns([maxExpression]);
    final result = await query.getSingle();
    return result.read(maxExpression) ?? 1;
  }

  Future<int> nextContentShortcutOrder(int sectionId) async {
    final query = selectOnly(contentShortcuts);
    final maxExpression = coalesce([contentShortcuts.order.max(), const Constant(-1)]) + const Constant(1);
    query.addColumns([maxExpression]);
    query.where(contentShortcuts.sectionId.equals(sectionId));
    final result = await query.getSingle();
    return result.read(maxExpression) ?? 0;
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
