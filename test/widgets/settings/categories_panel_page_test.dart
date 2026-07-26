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
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

// The old CategoriesPanelPage + CategoryPanelPage + AddCategoryDialog trio was replaced by a
// single LauncherSectionsPanelPage (the list of sections, reading AppsService.launcherSections)
// plus LauncherSectionPanelPage (used both to create a new section and to edit an existing one,
// pushed with an integer section index as its route argument, or no argument when creating).
// Reordering also changed: it's no longer a single "move" key press; a section must first be put
// into "moving" mode (arrowLeft/arrowRight or long-press), then moved with arrowUp/arrowDown
// (AppsService.moveSectionInMemory), then confirmed with select/enter (AppsService.persistSectionsOrder).
void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Sections are displayed", (tester) async {
    final appsService = MockAppsService();
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites"),
      fakeCategory(name: "Applications"),
    ]);

    await _pumpWidgetWithProviders(tester, appsService);

    expect(find.text("Favorites"), findsOneWidget);
    expect(find.text("Applications"), findsOneWidget);
  });

  testWidgets("Long-press then 'Down' then 'Enter' reorders a section", (tester) async {
    final appsService = MockAppsService();
    // moveSectionInMemory must actually reorder the backing list: after it moves an item, the
    // widget re-reads AppsService.launcherSections while still considering that same section
    // "the one being moved" (by its new list position), so the mock has to reflect the move for
    // the subsequent 'Enter' key press to still target it.
    final sections = [
      fakeCategory(name: "Favorites"),
      fakeCategory(name: "Applications"),
    ];
    when(appsService.launcherSections).thenAnswer((_) => List<LauncherSection>.from(sections));
    when(appsService.moveSectionInMemory(any, any)).thenAnswer((invocation) {
      final oldIndex = invocation.positionalArguments[0] as int;
      final newIndex = invocation.positionalArguments[1] as int;
      final section = sections.removeAt(oldIndex);
      sections.insert(newIndex, section);
    });
    await _pumpWidgetWithProviders(tester, appsService);

    await tester.longPress(find.text("Favorites"));
    await tester.pumpAndSettle();
    // The section row only reacts to arrow/select key events while it holds keyboard focus;
    // long-pressing puts it into "moving" mode but does not itself grant focus, so request it
    // explicitly (mirroring what a real remote-control focus traversal would have done).
    Focus.of(tester.element(find.text("Favorites"))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    verify(appsService.moveSectionInMemory(0, 1));
    verify(appsService.persistSectionsOrder());
  });

  testWidgets("Tapping a section opens LauncherSectionPanelPage", (tester) async {
    final appsService = MockAppsService();
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites"),
      fakeCategory(name: "Applications"),
    ]);
    await _pumpWidgetWithProviders(tester, appsService);

    await tester.tap(find.text("Applications"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("LauncherSectionPanelPage")), findsOneWidget);
  });

  testWidgets("'Add section' opens LauncherSectionPanelPage to create a new section", (tester) async {
    final appsService = MockAppsService();
    when(appsService.launcherSections).thenReturn([
      fakeCategory(name: "Favorites"),
      fakeCategory(name: "Applications"),
    ]);
    await _pumpWidgetWithProviders(tester, appsService);

    await tester.tap(find.text("Add section"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("LauncherSectionPanelPage")), findsOneWidget);
  });
}

Future<void> _pumpWidgetWithProviders(WidgetTester tester, AppsService appsService) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          LauncherSectionPanelPage.routeName: (_) => Container(key: Key("LauncherSectionPanelPage")),
        },
        home: Scaffold(body: LauncherSectionsPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
