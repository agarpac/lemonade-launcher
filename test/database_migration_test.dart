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
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test("upgrade from v1 to v5", () async {
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
    await verifier.migrateAndValidate(db, 5);
    await db.close();

    final migratedDb = v5.DatabaseAtV5(schema.newConnection().executor);
    final v5.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v5.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v5.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(app.sideloaded, false);
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

  test("upgrade from v2 to v5", () async {
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
    await verifier.migrateAndValidate(db, 5);
    await db.close();

    final migratedDb = v5.DatabaseAtV5(schema.newConnection().executor);
    final v5.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v5.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v5.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(app.sideloaded, false);
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

  test("upgrade from v3 to v5", () async {
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
    await verifier.migrateAndValidate(db, 5);
    await db.close();

    final migratedDb = v5.DatabaseAtV5(schema.newConnection().executor);
    final v5.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v5.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v5.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(app.sideloaded, false);
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

  test("upgrade from v4 to v5", () async {
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
    await verifier.migrateAndValidate(db, 5);
    await db.close();

    final migratedDb = v5.DatabaseAtV5(schema.newConnection().executor);
    final v5.AppsData app = await migratedDb.select(migratedDb.apps).getSingle();
    final v5.CategoriesData category = await migratedDb.select(migratedDb.categories).getSingle();
    final v5.AppsCategoriesData appsCategory = await migratedDb.select(migratedDb.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(app.sideloaded, false);
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

  // The v6..v10 steps have no generated schema snapshot (see the PRD, section
  // 13.2: the snapshots stop at v5 and those of v6..v9 can no longer be produced
  // honestly), so `SchemaVerifier` cannot cover the v11 step either. These tests
  // build a v10 database from literal SQL instead, run the real migration over
  // it, and check both halves of the contract: the new table appears with
  // exactly the shape a fresh install has, and not one existing row moves.
  group("upgrade from v10 to v11", () {
    late Directory temporaryDirectory;
    late File databaseFile;

    setUp(() async {
      // Its own directory: test files run in parallel and a shared path would
      // have them fighting over the same file.
      temporaryDirectory = await Directory.systemTemp.createTemp("database_migration_v10_to_v11_test");
      databaseFile = File("${temporaryDirectory.path}/db.sqlite");
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    /// Creates [databaseFile] holding the schema as it stood at v10, stamped
    /// with `user_version = 10` so that opening [FLauncherDatabase] over it runs
    /// `onUpgrade(10, 11)` and nothing else.
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
          11);
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

    test("is purely additive: not one existing row is moved", () async {
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
      // And the new table is there, empty: a v10 database had no shortcuts.
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
