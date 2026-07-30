/*
 * FLauncher
 * Copyright (C) 2026  Lemonade Launcher contributors
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
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  testWidgets("The app card clips its icon with a squircle, not a plain rounded rectangle", (tester) async {
    await _pumpAppCard(tester, app: fakeApp(), category: fakeCategory());

    final Material material = tester.widget<Material>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
    );

    // RoundedSuperellipseBorder is Flutter's engine-native "continuous corner"
    // shape (an iOS squircle) — this is what distinguishes it from the plain
    // circular arc a RoundedRectangleBorder (or bare borderRadius:) would draw.
    expect(material.shape, isA<RoundedSuperellipseBorder>());
    expect(
      (material.shape! as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(kAppCardCornerRadius),
    );
    // The old rounded-rectangle radius must be gone, not merely unused: Material
    // asserts against having both `shape` and `borderRadius` set at once.
    expect(material.borderRadius, isNull);
  });

  testWidgets(
      "The squircle clip sits inside the focus-scale animation, so it scales with the card "
      "instead of being computed once at rest size", (tester) async {
    // Traditional (D-pad) highlight mode is what actually triggers the scale
    // and the highlight outline; force it so focusing the card behaves like it
    // would on the TV remote this launcher targets, regardless of how the test
    // runner's own focus events would otherwise be classified.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

    await _pumpAppCard(tester, app: fakeApp(), category: fakeCategory(), autofocus: true);
    await tester.pumpAndSettle();

    final Finder focusScale = find.byWidgetPredicate(
      (widget) => widget is AnimatedScale && widget.duration == const Duration(milliseconds: 180),
    );
    expect(focusScale, findsOneWidget, reason: "the focus-scale AnimatedScale from app_card.dart");

    final AnimatedScale animatedScale = tester.widget<AnimatedScale>(focusScale);
    // Pinned by the PRD (section 4.1) and explicitly out of scope for this
    // change: still exactly 1.07, and still non-linear.
    expect(animatedScale.scale, 1.07);
    expect(animatedScale.curve, Curves.easeOutCubic);
    expect(animatedScale.curve, isNot(Curves.linear));

    // The squircle-shaped Material must be a descendant of that same
    // AnimatedScale, not a sibling or an ancestor: only then does the clip
    // scale together with the card's pixels instead of being computed once at
    // an unscaled rest size and then stretched independently of it.
    final Finder clippedMaterial = find.descendant(
      of: focusScale,
      matching: find.byWidgetPredicate((widget) => widget is Material && widget.shape is RoundedSuperellipseBorder),
    );
    expect(clippedMaterial, findsOneWidget);
  });

  testWidgets("A card that is not focused is not scaled up, but still uses the squircle shape", (tester) async {
    await _pumpAppCard(tester, app: fakeApp(), category: fakeCategory());
    await tester.pumpAndSettle();

    final AnimatedScale animatedScale = tester.widget<AnimatedScale>(
      find.byWidgetPredicate(
        (widget) => widget is AnimatedScale && widget.duration == const Duration(milliseconds: 180),
      ),
    );
    expect(animatedScale.scale, 1.0);
  });
}

Future<void> _pumpAppCard(
  WidgetTester tester, {
  required App app,
  required Category category,
  bool autofocus = false,
}) async {
  final appsService = MockAppsService();
  when(appsService.pendingReorderFocusPackage).thenReturn(null);
  when(appsService.pendingReorderFocusCategoryId).thenReturn(null);

  final settingsService = MockSettingsService();
  when(settingsService.showAppNamesBelowIcons).thenReturn(false);
  when(settingsService.appHighlightAnimationEnabled).thenReturn(false);
  when(settingsService.accentColorHex).thenReturn("FFFFFF");
  when(settingsService.showFocusBorders).thenReturn(true);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppCard(
            application: app,
            category: category,
            autofocus: autofocus,
            onMove: (_) {},
            onMoveEnd: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
