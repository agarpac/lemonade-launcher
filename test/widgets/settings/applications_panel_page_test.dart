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
import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/add_to_category_dialog.dart';
import 'package:flauncher/widgets/settings/app_details_page.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  // ApplicationsPanelPage's tabs changed from TV/Non-TV/Hidden (split by App.sideloaded) to
  // All Apps/Favorite Apps/Hidden Apps (see lib/widgets/settings/applications_panel_page.dart).
  testWidgets("All Apps tab shows every non-hidden application", (tester) async {
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn([
      fakeApp(
        packageName: "me.efesser.flauncher",
        name: "FLauncher",
        hidden: false,
      )
    ]);
    when(appsService.categories).thenReturn([]);

    await _pumpWidgetWithProviders(tester, appsService);

    expect(find.text("All Apps"), findsOneWidget);
    expect(find.text("FLauncher"), findsOneWidget);
  });

  testWidgets("Favorite Apps tab shows the Favorites category's applications", (tester) async {
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      hidden: false,
    );
    when(appsService.applications).thenReturn([application]);
    final favoritesCategory = fakeCategory(name: "Favorites");
    favoritesCategory.applications.add(application);
    when(appsService.categories).thenReturn([favoritesCategory]);

    await _pumpWidgetWithProviders(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text("Favorite Apps"), findsOneWidget);
    expect(find.text("FLauncher"), findsOneWidget);
  });

  testWidgets("Hidden Apps tab shows hidden applications", (tester) async {
    final appsService = MockAppsService();
    when(appsService.applications).thenReturn([
      fakeApp(
        packageName: "me.efesser.flauncher",
        name: "FLauncher",
        hidden: true,
      )
    ]);
    when(appsService.categories).thenReturn([]);

    await _pumpWidgetWithProviders(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text("Hidden Apps"), findsOneWidget);
    expect(find.text("FLauncher"), findsOneWidget);
  });

  // Tapping an app in ApplicationsPanelPage now navigates to AppDetailsPage (instead of
  // directly opening a context menu), which is where "Add to Category" and "Application info"
  // now live (see lib/widgets/settings/app_details_page.dart).
  testWidgets("'Add to Category' on AppDetailsPage opens AddToCategoryDialog", (tester) async {
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    );
    when(appsService.applications).thenReturn([application]);
    when(appsService.categories).thenReturn([]);
    when(appsService.isAppInFavorites(application)).thenReturn(false);
    when(appsService.getAppIcon(application.packageName)).thenAnswer((_) => Future.error(Exception("no icon")));

    await _pumpWidgetWithProviders(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AppDetailsPage), findsOneWidget);

    await tester.tap(find.text("Add to Category"));
    await tester.pumpAndSettle();

    expect(find.byType(AddToCategoryDialog), findsOneWidget);
  });

  testWidgets("'Application info' on AppDetailsPage calls AppsService.openAppInfo", (tester) async {
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    );
    when(appsService.applications).thenReturn([application]);
    when(appsService.categories).thenReturn([]);
    when(appsService.isAppInFavorites(application)).thenReturn(false);
    when(appsService.getAppIcon(application.packageName)).thenAnswer((_) => Future.error(Exception("no icon")));

    await _pumpWidgetWithProviders(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AppDetailsPage), findsOneWidget);

    await tester.tap(find.text("Application info"));
    await tester.pumpAndSettle();

    verify(appsService.openAppInfo(application));
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
        home: Scaffold(body: ApplicationsPanelPage()),
        onGenerateRoute: (settings) {
          if (settings.name == AppDetailsPage.routeName) {
            return MaterialPageRoute(
              builder: (_) => Scaffold(body: AppDetailsPage(application: settings.arguments as App)),
            );
          }
          return MaterialPageRoute(builder: (_) => Container());
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
