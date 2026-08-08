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

// `StatusBarGlassCard` is the single reusable definition of the status bar's
// frosted-glass surface (PRD section 10): every element of the bar builds on
// this widget instead of each copying the dock's decoration by hand. These
// tests exercise the card in isolation, decoupled from any particular bar
// element.

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flauncher/widgets/status_bar_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  MockWallpaperService mkWallpaperService() {
    final wallpaperService = MockWallpaperService();
    // No image and no video: the blurred content is the static gradient,
    // which needs no asset loading inside the test's fake-async zone.
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.wallpaperVideoFile).thenReturn(null);
    when(wallpaperService.wallpaperRevision).thenReturn(0);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    return wallpaperService;
  }

  Future<void> pumpCard(WidgetTester tester, {required bool backdropDisabled}) async {
    final settingsService = MockSettingsService();
    when(settingsService.dockBackdropFilterDisabled).thenReturn(backdropDisabled);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ChangeNotifierProvider<WallpaperService>.value(value: mkWallpaperService()),
        ],
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: StatusBarGlassCard(
              child: Text("content", key: const Key("card_content")),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("renders its child inside the frosted container", (tester) async {
    await pumpCard(tester, backdropDisabled: true);

    expect(find.byKey(const Key("card_content")), findsOneWidget);
  });

  testWidgets("uses the live blur backdrop when the dock's escape hatch is off", (tester) async {
    await pumpCard(tester, backdropDisabled: false);

    expect(find.byType(CachedBlurBackdrop), findsOneWidget);
    expect(find.byKey(const Key("card_content")), findsOneWidget);
  });

  testWidgets("skips the blur backdrop entirely when dockBackdropFilterDisabled is on", (tester) async {
    await pumpCard(tester, backdropDisabled: true);

    // Not just "not built this frame": the widget must never exist in this
    // tree, exactly like the dock's own escape hatch — a status-bar surface
    // that quietly kept a live BackdropFilter around would defeat the point
    // of the setting on a low-end GPU.
    expect(find.byType(CachedBlurBackdrop), findsNothing);
    expect(find.byKey(const Key("card_content")), findsOneWidget);
  });

  testWidgets("creates no Focus node of its own", (tester) async {
    await pumpCard(tester, backdropDisabled: true);

    // Structural, not behavioural: wrapping a widget in this card must never
    // insert a focus node, whether or not the child it wraps is focusable.
    expect(
      find.descendant(
        of: find.byType(StatusBarGlassCard),
        matching: find.byWidgetPredicate((widget) => widget is Focus || widget is FocusScope),
      ),
      findsNothing,
    );
  });

  /// Regression test for the defect where the focus outline drew *inside*
  /// the frosted card: a `Border.all` inside the `ClipRRect` gets clipped
  /// against this card's own radius and reads as an inner stroke rather than
  /// an outline hugging the card. `focused: true` must draw an outline layer
  /// that sits *outside* the clip; `focused: false` (the default, used by
  /// every non-focusable caller like the weather card) must paint no border
  /// and no shadow at all — the overlay slot itself always exists (see the
  /// comment above the `Stack` in the widget for why: swapping the slot's
  /// widget *type* between focused states is what remounted a caller's
  /// `Focus` node and broke directional traversal), but it is visually a
  /// no-op when unfocused.
  group("focus outline overlay", () {
    Future<void> pumpFocusableCard(WidgetTester tester, {required bool focused}) async {
      final settingsService = MockSettingsService();
      when(settingsService.dockBackdropFilterDisabled).thenReturn(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(value: settingsService),
            ChangeNotifierProvider<WallpaperService>.value(value: mkWallpaperService()),
          ],
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: StatusBarGlassCard(
                focused: focused,
                child: Text("content", key: const Key("card_content")),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("focused renders an outline layer outside the clipped card", (tester) async {
      await pumpFocusableCard(tester, focused: true);

      // The clipped surface (blur/translucency) must still be there...
      expect(find.descendant(of: find.byType(StatusBarGlassCard), matching: find.byType(ClipRRect)), findsOneWidget);

      // ...and the outline must be a sibling of that `ClipRRect`, not a
      // descendant of it: that is what keeps it from being clipped away.
      final outlineFinder = find.byKey(const Key("status_bar_glass_card_focus_outline"));
      expect(outlineFinder, findsOneWidget);
      expect((tester.widget(outlineFinder) as DecoratedBox).decoration, isA<BoxDecoration>());
      final outlineDecoration = (tester.widget(outlineFinder) as DecoratedBox).decoration as BoxDecoration;
      expect(outlineDecoration.border, isNotNull);
      expect(
        find.descendant(of: find.byType(ClipRRect), matching: outlineFinder),
        findsNothing,
        reason: "the outline must not be clipped by the card's own ClipRRect",
      );

      // Never intercepts input, and never on the focused child's own render
      // pass: same shape as the home grid's `_HighlightOutline`.
      expect(find.descendant(of: find.byType(StatusBarGlassCard), matching: find.byType(IgnorePointer)), findsOneWidget);
    });

    testWidgets("unfocused (the default) paints no border and no shadow", (tester) async {
      await pumpFocusableCard(tester, focused: false);

      final outlineFinder = find.byKey(const Key("status_bar_glass_card_focus_outline"));
      expect(outlineFinder, findsOneWidget);
      final outlineDecoration = (tester.widget(outlineFinder) as DecoratedBox).decoration as BoxDecoration;
      expect(outlineDecoration.border, isNull);
      expect(outlineDecoration.boxShadow, isNull);
      expect(find.byKey(const Key("card_content")), findsOneWidget);
    });
  });
}
