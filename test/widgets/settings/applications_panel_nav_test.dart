import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  testWidgets("Left/Right arrow keys switch tabs in ApplicationsPanelPage", (tester) async {
    final appsService = MockAppsService();
    final allApp = fakeApp(packageName: "pkg.all", name: "All App", hidden: false);
    final favoriteApp = fakeApp(packageName: "pkg.fav", name: "Fav App", hidden: false);
    final hiddenApp = fakeApp(packageName: "pkg.hidden", name: "Hidden App", hidden: true);
    // ApplicationsPanelPage now exposes 3 tabs: "All Apps" (every non-hidden app), "Favorite
    // Apps" (the "Favorites" category's non-hidden apps) and "Hidden Apps" (hidden apps),
    // replacing the removed TV/Non-TV/Hidden split.
    when(appsService.applications).thenReturn([allApp, favoriteApp, hiddenApp]);
    final favoritesCategory = fakeCategory(name: "Favorites");
    favoritesCategory.applications.add(favoriteApp);
    when(appsService.categories).thenReturn([favoritesCategory]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppsService>.value(value: appsService),
        ],
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ApplicationsPanelPage()),
          onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => Container()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state: All Apps (index 0)
    expect(find.text("All Apps"), findsOneWidget, reason: "Should start on All Apps tab");
    expect(find.text("All App"), findsOneWidget);

    // Simulate Right Arrow
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Should now be on Favorite Apps (index 1)
    expect(find.text("Favorite Apps"), findsOneWidget, reason: "Should switch to Favorite Apps after Right Arrow");
    expect(find.text("Fav App"), findsOneWidget);

    // Simulate Right Arrow again
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Should now be on Hidden Apps (index 2)
    expect(find.text("Hidden Apps"), findsOneWidget, reason: "Should switch to Hidden Apps after Right Arrow");
    expect(find.text("Hidden App"), findsOneWidget);

    // Simulate Left Arrow
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    // Should be back on Favorite Apps (index 1)
    expect(find.text("Favorite Apps"), findsOneWidget, reason: "Should switch back to Favorite Apps after Left Arrow");

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    // Should be back on All Apps (index 0)
    expect(find.text("All Apps"), findsOneWidget, reason: "Should switch back to All Apps after Left Arrow");
    expect(find.text("All App"), findsOneWidget);

    // Check boundary (Left on first tab)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text("All Apps"), findsOneWidget, reason: "Should stay on All Apps when pressing Left on first tab");
  });
}
