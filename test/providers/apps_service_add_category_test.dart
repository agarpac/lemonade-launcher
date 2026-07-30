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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();

  late Directory temporaryDirectory;
  late File databaseFile;
  late FLauncherDatabase database;
  late MockFLauncherChannel channel;

  setUp(() async {
    // Its own directory: test files run in parallel.
    temporaryDirectory = await Directory.systemTemp.createTemp("apps_service_add_category_test");
    databaseFile = File("${temporaryDirectory.path}/db.sqlite");
    database = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

    channel = MockFLauncherChannel();
    when(channel.getApplications()).thenAnswer((_) => Future.value([]));
    when(channel.applicationExists(any)).thenAnswer((_) => Future.value(false));
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<AppsService> buildAppsService() async {
    final appsService = AppsService(channel, database);
    await untilCalled(channel.addAppsChangedListener(any));
    return appsService;
  }

  Future<int> storedCategoryType(int categoryId) async {
    final row = await database.customSelect(
      'SELECT "type" FROM categories WHERE id = ?',
      variables: [Variable.withInt(categoryId)],
    ).getSingle();
    return row.read<int>('type');
  }

  // Regression test for the bug where `AppsService.addCategory` built its
  // in-memory `Category` from the `type` (and `sort`/`columnsCount`/`rowHeight`)
  // it was given, but inserted the database row with only `name` and `order`,
  // leaving every other column to whatever the SQL column default happened to
  // be. On a fresh install that default coincides with `Category.Type` (grid),
  // so the bug was invisible; on a database that migrated through the v4 step
  // (which mistakenly wrote the "type" column's SQL-level default as 0/row
  // instead of 1/grid) a category explicitly created as a grid would silently
  // come back as a row after the next restart, because the stored row never
  // held the caller's actual choice in the first place.
  test("addCategory persists the type it was given, not the column default", () async {
    final appsService = await buildAppsService();

    // The column's default is grid (see Categories.type in lib/database.dart),
    // so asking for the opposite is what exposes an insert that silently
    // fell back to the default instead of writing what was requested.
    final categoryId = await appsService.addCategory("Test Category", type: CategoryType.row);

    expect(await storedCategoryType(categoryId), CategoryType.row.index);
  });

  test("addCategory persists sort, columnsCount and rowHeight it was given, not the column defaults", () async {
    final appsService = await buildAppsService();

    final categoryId = await appsService.addCategory(
      "Test Category",
      sort: CategorySort.alphabetical,
      columnsCount: 3,
      rowHeight: 200,
    );

    final row = await database.customSelect(
      'SELECT "sort", "columns_count", "row_height" FROM categories WHERE id = ?',
      variables: [Variable.withInt(categoryId)],
    ).getSingle();
    expect(row.read<int>('sort'), CategorySort.alphabetical.index);
    expect(row.read<int>('columns_count'), 3);
    expect(row.read<int>('row_height'), 200);
  });
}
