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
}
