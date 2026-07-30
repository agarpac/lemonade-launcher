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
import 'package:drift_dev/api/migrations.dart';
import 'package:flauncher/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v12.dart' as v12;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test("upgrade from v1 to v12", () async {
    final schema = await verifier.schemaAt(1);

    final oldDb = v1.DatabaseAtV1(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v1.AppsCompanion.insert(
            packageName: "me.efesser.flauncher",
            name: "FLauncher",
            className: ".MainActivity",
            version: "0.0.1",
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v1.CategoriesCompanion.insert(name: "Applications", order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v1.AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 0),
        );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 12);
    await db.close();

    final migratedDb = v12.DatabaseAtV12(schema.newConnection().executor);
    final v12.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v12.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v12.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, 0);
    expect(category.type, 1);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await migratedDb.close();
  });

  test("upgrade from v2 to v12", () async {
    final schema = await verifier.schemaAt(2);

    final oldDb = v2.DatabaseAtV2(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v2.AppsCompanion.insert(
            packageName: "me.efesser.flauncher",
            name: "FLauncher",
            version: "0.0.1",
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v2.CategoriesCompanion.insert(name: "Applications", order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v2.AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 0),
        );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 12);
    await db.close();

    final migratedDb = v12.DatabaseAtV12(schema.newConnection().executor);
    final v12.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v12.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v12.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, 0);
    expect(category.type, 1);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await migratedDb.close();
  });

  test("upgrade from v3 to v12", () async {
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v3.AppsCompanion.insert(
            packageName: "me.efesser.flauncher",
            name: "FLauncher",
            version: "0.0.1",
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v3.CategoriesCompanion.insert(name: "Applications", order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v3.AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 0),
        );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 12);
    await db.close();

    final migratedDb = v12.DatabaseAtV12(schema.newConnection().executor);
    final v12.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v12.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v12.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, 0);
    expect(category.type, 1);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await migratedDb.close();
  });

  test("upgrade from v4 to v12", () async {
    final schema = await verifier.schemaAt(4);

    final oldDb = v4.DatabaseAtV4(schema.newConnection().executor);
    await oldDb.into(oldDb.apps).insert(
          v4.AppsCompanion.insert(
            packageName: "me.efesser.flauncher",
            name: "FLauncher",
            version: "0.0.1",
          ),
        );
    final categoryId = await oldDb.into(oldDb.categories).insert(
          v4.CategoriesCompanion.insert(name: "Applications", type: Value(1), order: 0),
        );
    await oldDb.into(oldDb.appsCategories).insert(
          v4.AppsCategoriesCompanion.insert(categoryId: categoryId, appPackageName: "me.efesser.flauncher", order: 0),
        );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 12);
    await db.close();

    final migratedDb = v12.DatabaseAtV12(schema.newConnection().executor);
    final v12.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v12.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v12.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, 0);
    expect(category.type, 1);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await migratedDb.close();
  });

  // Coverage: the four tests above build a database at v1, v2, v3 or v4 and
  // migrate it all the way to v12 (the current `FLauncherDatabase.schemaVersion`),
  // using `SchemaVerifier` snapshots regenerated from the JSON exports in
  // `drift_schemas/` (v1..v5, including the `banner`/`icon` columns v5 was
  // previously missing) plus v11 and v12 snapshots dumped straight from the live
  // `lib/database.dart`. That means every migration step from 2 through 12 is
  // now schema-verified as an intermediate stage of those four runs, including
  // the six steps (v6..v11) that used to run completely unchecked.
  //
  // "v4 to v12" is the one that pins the v12 rebuild: from a v4 snapshot the
  // `categories.type` column already exists — v4 is where it was introduced —
  // so the `from < 4` guard never runs and the corrected `DEFAULT 1` in that
  // step cannot help. Only the v12 rebuild can bring such a database in line
  // with a fresh install, and `SchemaVerifier` compares the stored DDL, so this
  // test fails if the rebuild is dropped.
  //
  // v6..v9 remain uncoverable as *starting* points: no JSON export for those
  // versions survives (see the PRD, section 13.2), so there is no honest way to
  // spin up a database starting exactly at v6, v7, v8 or v9 for a dedicated
  // `SchemaVerifier` test. Their transformations are still exercised in transit
  // by the four tests above, just not individually as a starting point.
  //
  // v10 and v11 are in the same boat (no JSON export for v10, and a v11 export
  // that cannot express the wrong column default a *migrated* v11 database
  // carries), but both get dedicated coverage below because `SchemaVerifier`
  // only checks schema shape, not data: these tests build the older database
  // from literal SQL instead, run the real migration over it, and check the half
  // of the contract the schema tests above cannot — that not one row is lost.
  group("upgrade from v10 to v12", () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      // Its own directory: test files run in parallel and a shared path would
      // have them fighting over the same file.
      temporaryDirectory = await Directory.systemTemp.createTemp("database_migration_v10_to_v12_test");
      databaseFile = File("${temporaryDirectory.path}/db.sqlite");
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    /// Creates [databaseFile] holding the schema as it stood at v10, stamped
    /// with `user_version = 10` so that opening [FLauncherDatabase] over it runs
    /// `onUpgrade(10, 12)` and nothing else.
    Future<void> createV10Database() async {
      final executor = NativeDatabase(databaseFile);
      await executor.ensureOpen(_SchemaOnlyUser(10));
      await executor.runCustom('CREATE TABLE "apps" ('
          '"package_name" TEXT NOT NULL, "name" TEXT NOT NULL, "version" TEXT NOT NULL, '
          '"hidden" INTEGER NOT NULL DEFAULT 0 CHECK ("hidden" IN (0, 1)), '
          '"last_launched_at" INTEGER NULL, PRIMARY KEY ("package_name"))');
      await executor.runCustom('CREATE TABLE "categories" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, '
          '"sort" INTEGER NOT NULL DEFAULT 0, "type" INTEGER NOT NULL DEFAULT 1, '
          '"row_height" INTEGER NOT NULL DEFAULT 110, "columns_count" INTEGER NOT NULL DEFAULT 6, '
          '"order" INTEGER NOT NULL)');
      await executor.runCustom('CREATE TABLE "apps_categories" ('
          '"category_id" INTEGER REFERENCES categories(id) ON DELETE CASCADE, '
          '"app_package_name" TEXT REFERENCES apps(package_name) ON DELETE CASCADE, '
          '"order" INTEGER NOT NULL, PRIMARY KEY ("category_id", "app_package_name"))');
      await executor.runCustom('CREATE TABLE "launcher_spacers" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "height" INTEGER NOT NULL, '
          '"order" INTEGER NOT NULL)');
      await executor.close();
    }

    /// Writes the configuration whose survival the migration must guarantee.
    Future<void> seedV10Data() async {
      final executor = NativeDatabase(databaseFile);
      await executor.ensureOpen(_SchemaOnlyUser(10));
      await executor.runCustom("INSERT INTO apps(package_name, name, version, hidden, last_launched_at)"
          " VALUES('com.teamsmart.videomanager.tv', 'SmartTube', '1.0.0', 0, 1700000000000)");
      await executor.runCustom("INSERT INTO categories(id, name, sort, type, row_height, columns_count, \"order\")"
          " VALUES(1, 'Favorites', 0, 0, 120, 5, 0)");
      await executor.runCustom("INSERT INTO apps_categories(category_id, app_package_name, \"order\")"
          " VALUES(1, 'com.teamsmart.videomanager.tv', 0)");
      await executor.runCustom("INSERT INTO launcher_spacers(id, height, \"order\") VALUES(1, 42, 1)");
      await executor.close();
    }

    Future<List<Map<String, Object?>>> dump(FLauncherDatabase database, String sql) async =>
        (await database.customSelect(sql).get()).map((row) => row.data).toList();

    test("creates content_shortcuts with exactly the shape a fresh install has", () async {
      await createV10Database();
      await seedV10Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
      final migratedSql = (await migrated.customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'content_shortcuts'",
      ).getSingle())
          .read<String>("sql");
      expect(await migrated.customSelect("PRAGMA user_version").getSingle().then((row) => row.read<int>("user_version")),
          12);
      await migrated.close();

      final fresh = FLauncherDatabase.inMemory();
      final freshSql = (await fresh.customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'content_shortcuts'",
      ).getSingle())
          .read<String>("sql");
      await fresh.close();

      // Character for character: a migrated database that merely *resembles* a
      // fresh one is how the two inherited migration bugs hid for so long.
      expect(migratedSql, freshSql);
    });

    // The v10 -> v11 step is purely additive and the v11 -> v12 step only
    // rewrites `categories`' DDL, so between them not a single stored value may
    // change — including this category's `type` of 0, which is *not* the column
    // default and must survive the rebuild verbatim.
    test("not one existing row is moved", () async {
      await createV10Database();
      await seedV10Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

      expect(await dump(migrated, "SELECT * FROM apps"), [
        {
          "package_name": "com.teamsmart.videomanager.tv",
          "name": "SmartTube",
          "version": "1.0.0",
          "hidden": 0,
          "last_launched_at": 1700000000000,
        }
      ]);
      expect(await dump(migrated, "SELECT * FROM categories"), [
        {
          "id": 1,
          "name": "Favorites",
          "sort": 0,
          "type": 0,
          "row_height": 120,
          "columns_count": 5,
          "order": 0,
        }
      ]);
      expect(await dump(migrated, 'SELECT * FROM apps_categories'), [
        {"category_id": 1, "app_package_name": "com.teamsmart.videomanager.tv", "order": 0}
      ]);
      expect(await dump(migrated, 'SELECT * FROM launcher_spacers'), [
        {"id": 1, "height": 42, "order": 1}
      ]);
      // And the table v11 added is there, empty: a v10 database had no shortcuts.
      expect(await dump(migrated, 'SELECT * FROM content_shortcuts'), isEmpty);

      await migrated.close();
    });

    test("a v10 database with no rows at all still opens", () async {
      await createV10Database();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
      expect(await dump(migrated, 'SELECT * FROM content_shortcuts'), isEmpty);
      await migrated.close();
    });
  });

  // The v12 step recreates "categories" to repair the `type` column default the
  // v4 step wrote as 0 where a fresh install has 1. Rebuilding a table means
  // dropping one, and `apps_categories.category_id` is declared
  // `REFERENCES categories(id) ON DELETE CASCADE`: get the ordering wrong and
  // the drop cascades away every app-to-category membership there is — the
  // user's whole dock and the contents of every category. `SchemaVerifier`
  // would not notice, because the schema would come out exactly right and only
  // the data would be gone. Hence a database built from literal SQL, seeded,
  // migrated for real, and read back row by row.
  group("upgrade from v11 to v12", () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      // Its own directory: test files run in parallel and a shared path would
      // have them fighting over the same file.
      temporaryDirectory = await Directory.systemTemp.createTemp("database_migration_v11_to_v12_test");
      databaseFile = File("${temporaryDirectory.path}/db.sqlite");
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    /// Creates [databaseFile] holding v11 as a *migrated* database really had
    /// it, stamped with `user_version = 11` so that opening [FLauncherDatabase]
    /// over it runs `onUpgrade(11, 12)` and nothing else.
    ///
    /// Two things here are deliberately not what a fresh v11 install looked
    /// like, because they are what every upgraded database actually holds and
    /// what the v12 step has to cope with:
    ///
    ///  * `"type" INTEGER NOT NULL DEFAULT 0` — the bug being repaired.
    ///  * `categories` column order `id, name, "order", sort, type, row_height,
    ///    columns_count`, because v1..v3 declared `id, name, "order"` and v4
    ///    appended the other four with `ALTER TABLE ADD COLUMN`. The rebuild
    ///    copies by column name, so it must survive this ordering and normalise
    ///    it to a fresh install's.
    Future<void> createV11Database() async {
      final executor = NativeDatabase(databaseFile);
      await executor.ensureOpen(_SchemaOnlyUser(11));
      await executor.runCustom('CREATE TABLE "apps" ('
          '"package_name" TEXT NOT NULL, "name" TEXT NOT NULL, "version" TEXT NOT NULL, '
          '"hidden" INTEGER NOT NULL DEFAULT 0 CHECK ("hidden" IN (0, 1)), '
          '"last_launched_at" INTEGER NULL, PRIMARY KEY ("package_name"))');
      await executor.runCustom('CREATE TABLE "categories" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, '
          '"order" INTEGER NOT NULL, '
          '"sort" INTEGER NOT NULL DEFAULT 0, "type" INTEGER NOT NULL DEFAULT 0, '
          '"row_height" INTEGER NOT NULL DEFAULT 110, "columns_count" INTEGER NOT NULL DEFAULT 6)');
      await executor.runCustom('CREATE TABLE "apps_categories" ('
          '"category_id" INTEGER REFERENCES categories(id) ON DELETE CASCADE, '
          '"app_package_name" TEXT REFERENCES apps(package_name) ON DELETE CASCADE, '
          '"order" INTEGER NOT NULL, PRIMARY KEY ("category_id", "app_package_name"))');
      await executor.runCustom('CREATE TABLE "launcher_spacers" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "height" INTEGER NOT NULL, '
          '"order" INTEGER NOT NULL)');
      await executor.runCustom('CREATE TABLE "content_shortcuts" ('
          '"id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
          '"section_id" INTEGER NOT NULL, "section_order" INTEGER NOT NULL, '
          '"order" INTEGER NOT NULL, "label" TEXT NOT NULL, "uri" TEXT NOT NULL, '
          '"target_package" TEXT NOT NULL)');
      await executor.close();
    }

    /// Writes the configuration whose survival the rebuild must guarantee: the
    /// two categories whose names the launcher matches by string equality, one
    /// user-made category on top, and a membership row for every one of them.
    Future<void> seedV11Data() async {
      final executor = NativeDatabase(databaseFile);
      await executor.ensureOpen(_SchemaOnlyUser(11));
      await executor.runCustom("INSERT INTO apps(package_name, name, version, hidden, last_launched_at)"
          " VALUES('com.teamsmart.videomanager.tv', 'SmartTube', '1.0.0', 0, 1700000000000)");
      await executor.runCustom("INSERT INTO apps(package_name, name, version, hidden, last_launched_at)"
          " VALUES('org.videolan.vlc', 'VLC', '3.5.0', 1, NULL)");
      await executor.runCustom('INSERT INTO categories(id, name, "order", sort, type, row_height, columns_count)'
          " VALUES(1, 'Favorites', 0, 0, 0, 120, 5)");
      await executor.runCustom('INSERT INTO categories(id, name, "order", sort, type, row_height, columns_count)'
          " VALUES(2, 'All Apps', 1, 1, 1, 110, 6)");
      await executor.runCustom('INSERT INTO categories(id, name, "order", sort, type, row_height, columns_count)'
          " VALUES(7, 'Películas', 2, 2, 0, 200, 3)");
      await executor.runCustom('INSERT INTO apps_categories(category_id, app_package_name, "order")'
          " VALUES(1, 'com.teamsmart.videomanager.tv', 0)");
      await executor.runCustom('INSERT INTO apps_categories(category_id, app_package_name, "order")'
          " VALUES(2, 'org.videolan.vlc', 0)");
      await executor.runCustom('INSERT INTO apps_categories(category_id, app_package_name, "order")'
          " VALUES(7, 'com.teamsmart.videomanager.tv', 3)");
      await executor.runCustom('INSERT INTO launcher_spacers(id, height, "order") VALUES(1, 42, 1)');
      await executor.close();
    }

    Future<List<Map<String, Object?>>> dump(FLauncherDatabase database, String sql) async =>
        (await database.customSelect(sql).get()).map((row) => row.data).toList();

    Future<String> categoriesDdl(FLauncherDatabase database) async =>
        (await database.customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'categories'")
                .getSingle())
            .read<String>("sql");

    test("rebuilds categories with exactly the DDL a fresh install has", () async {
      await createV11Database();
      await seedV11Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
      final migratedSql = await categoriesDdl(migrated);
      expect(await migrated.customSelect("PRAGMA user_version").getSingle().then((row) => row.read<int>("user_version")),
          12);
      await migrated.close();

      final fresh = FLauncherDatabase.inMemory();
      final freshSql = await categoriesDdl(fresh);
      await fresh.close();

      // Character for character, temporary table name and all: this whole step
      // exists because "resembles a fresh install" is what let the wrong
      // `DEFAULT 0` hide for years.
      expect(migratedSql, freshSql);
      expect(migratedSql, contains('"type" INTEGER NOT NULL DEFAULT 1'));
      expect(migratedSql, isNot(contains("categories_v12")));
    });

    test("every categories row survives with identical values", () async {
      await createV11Database();
      await seedV11Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

      // Read back by name and ordered by id, because the rebuild also
      // normalises the physical column order.
      expect(await dump(migrated, 'SELECT id, name, "order", sort, type, row_height, columns_count'
          ' FROM categories ORDER BY id'), [
        {"id": 1, "name": "Favorites", "order": 0, "sort": 0, "type": 0, "row_height": 120, "columns_count": 5},
        {"id": 2, "name": "All Apps", "order": 1, "sort": 1, "type": 1, "row_height": 110, "columns_count": 6},
        {"id": 7, "name": "Películas", "order": 2, "sort": 2, "type": 0, "row_height": 200, "columns_count": 3},
      ]);
      // 'Favorites' and 'All Apps' are matched by string equality all over the
      // launcher — the dock literally looks its row up by name — and id 7 must
      // stay 7, not be renumbered to 3, or every membership row below dangles.
      await migrated.close();
    });

    test("every apps_categories row survives the dropped parent table", () async {
      await createV11Database();
      await seedV11Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

      expect(await dump(migrated, 'SELECT * FROM apps_categories ORDER BY category_id, app_package_name'), [
        {"category_id": 1, "app_package_name": "com.teamsmart.videomanager.tv", "order": 0},
        {"category_id": 2, "app_package_name": "org.videolan.vlc", "order": 0},
        {"category_id": 7, "app_package_name": "com.teamsmart.videomanager.tv", "order": 3},
      ]);
      // Nothing else may be collateral damage either.
      expect(await dump(migrated, "SELECT * FROM apps ORDER BY package_name"), [
        {
          "package_name": "com.teamsmart.videomanager.tv",
          "name": "SmartTube",
          "version": "1.0.0",
          "hidden": 0,
          "last_launched_at": 1700000000000,
        },
        {
          "package_name": "org.videolan.vlc",
          "name": "VLC",
          "version": "3.5.0",
          "hidden": 1,
          "last_launched_at": null,
        },
      ]);
      expect(await dump(migrated, 'SELECT * FROM launcher_spacers'), [
        {"id": 1, "height": 42, "order": 1}
      ]);
      expect(await dump(migrated, 'SELECT * FROM content_shortcuts'), isEmpty);

      // And the foreign key is enforced again once the migration is over, so
      // the step left the connection as it found it.
      expect(
          await migrated.customSelect("PRAGMA foreign_keys").getSingle().then((row) => row.read<int>("foreign_keys")), 1);
      await migrated.close();
    });

    test("an insert that omits type now lands on 1, not 0", () async {
      await createV11Database();
      await seedV11Data();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
      await migrated.customStatement('INSERT INTO categories(name, "order") VALUES(\'Relying on the default\', 3)');

      // The user-visible symptom of the wrong default: a category created on a
      // migrated database came back as a row after a restart, whatever the user
      // had picked. 1 is CategoryType.grid.
      expect(
          await migrated
              .customSelect("SELECT type FROM categories WHERE name = 'Relying on the default'")
              .getSingle()
              .then((row) => row.read<int>("type")),
          1);
      await migrated.close();
    });

    test("a v11 database with no rows at all still opens", () async {
      await createV11Database();

      final migrated = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
      expect(await dump(migrated, "SELECT * FROM categories"), isEmpty);
      expect(await categoriesDdl(migrated), contains('"type" INTEGER NOT NULL DEFAULT 1'));
      await migrated.close();
    });
  });
}

/// Opens a database at a fixed schema version without running any migration:
/// just enough of a [QueryExecutorUser] to stamp `user_version` and hand back a
/// usable executor, so a test can lay down historical SQL by hand.
class _SchemaOnlyUser implements QueryExecutorUser {
  @override
  final int schemaVersion;

  _SchemaOnlyUser(this.schemaVersion);

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
