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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

// The old CategoryPanelPage(categoryId: ...), driven by list-style "arrow down N times then
// enter" navigation and immediate per-field AppsService calls (setCategorySort/setCategoryType/
// setCategoryColumnsCount/setCategoryRowHeight), was replaced by
// LauncherSectionPanelPage(sectionIndex: ...): a dropdown-based form (name/sort/layout/
// columns-or-row-height) that stages edits locally and only persists them, all at once, via
// AppsService.updateCategory(id, name, sort, type, columnsCount, rowHeight) when "Save" is
// pressed. Deleting now calls AppsService.deleteSection(index) with the section's list index,
// not the Category object.
void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Category settings are pre-filled from the existing category", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.grid, columnsCount: 6);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    expect(find.text("Favorites"), findsOneWidget);
    expect(find.text("Alphabetical"), findsOneWidget);
    expect(find.text("Grid"), findsOneWidget);
    expect(find.text("6"), findsOneWidget);
  });

  testWidgets("Changing the name preset and saving calls AppsService.updateCategory", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.grid, columnsCount: 6);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    await _selectDropdownOption(tester, find.byType(DropdownButtonFormField<String>), "Games");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateCategory(
      favoritesCategory.id,
      "Games",
      CategorySort.alphabetical,
      CategoryType.grid,
      6,
      favoritesCategory.rowHeight,
    ));
  });

  testWidgets("Changing sort and saving calls AppsService.updateCategory", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.grid, columnsCount: 6);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    await _selectDropdownOption(tester, find.byType(DropdownButtonFormField<CategorySort>), "Manual");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateCategory(
      favoritesCategory.id,
      "Favorites",
      CategorySort.manual,
      CategoryType.grid,
      6,
      favoritesCategory.rowHeight,
    ));
  });

  testWidgets("Changing layout and saving calls AppsService.updateCategory", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.row, rowHeight: 110);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    await _selectDropdownOption(tester, find.byType(DropdownButtonFormField<CategoryType>), "Grid");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateCategory(
      favoritesCategory.id,
      "Favorites",
      CategorySort.alphabetical,
      CategoryType.grid,
      favoritesCategory.columnsCount,
      110,
    ));
  });

  testWidgets("Changing columns count and saving calls AppsService.updateCategory", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.grid, columnsCount: 6);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    await _selectDropdownOption(tester, find.byType(DropdownButtonFormField<int>), "7");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateCategory(
      favoritesCategory.id,
      "Favorites",
      CategorySort.alphabetical,
      CategoryType.grid,
      7,
      favoritesCategory.rowHeight,
    ));
  });

  testWidgets("Changing row height and saving calls AppsService.updateCategory", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.row, rowHeight: 110);
    when(appsService.launcherSections).thenReturn([favoritesCategory, fakeCategory(name: "Applications")]);

    await _pumpWidgetWithProviders(tester, appsService, 0);

    await _selectDropdownOption(tester, find.byType(DropdownButtonFormField<int>), "120");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateCategory(
      favoritesCategory.id,
      "Favorites",
      CategorySort.alphabetical,
      CategoryType.row,
      favoritesCategory.columnsCount,
      120,
    ));
  });

  testWidgets("'Delete' calls AppsService.deleteSection with the section index", (tester) async {
    final appsService = MockAppsService();
    final favoritesCategory =
        fakeCategory(name: "Favorites", sort: CategorySort.alphabetical, type: CategoryType.row, rowHeight: 110);
    when(appsService.launcherSections).thenReturn([fakeCategory(name: "Applications"), favoritesCategory]);
    when(appsService.deleteSection(any)).thenAnswer((_) => Future.value());

    await _pumpWidgetWithProviders(tester, appsService, 1);

    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();

    verify(appsService.deleteSection(1));
  });
}

Future<void> _selectDropdownOption(WidgetTester tester, Finder dropdownFinder, String optionText) async {
  await tester.ensureVisible(dropdownFinder);
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpWidgetWithProviders(WidgetTester tester, AppsService appsService, int sectionIndex) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LauncherSectionPanelPage(sectionIndex: sectionIndex)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
