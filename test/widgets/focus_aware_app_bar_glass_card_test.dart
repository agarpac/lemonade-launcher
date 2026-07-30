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

// PRD section 10, pending item 1: every remaining element of the status bar
// (the settings and scene buttons, the network indicator, the Wi-Fi usage
// widget, and the date/time) is now wrapped in `StatusBarGlassCard`, the same
// reusable surface as the dock and the weather card. These tests cover what a
// pure visual refactor must not touch: which widgets are focusable, in what
// order, and whether the settings button stays reachable while the bar is
// auto-hidden.

import 'package:flauncher/gradients.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/daily_wifi_usage_widget.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/network_widget.dart';
import 'package:flauncher/widgets/status_bar_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  MockSettingsService mkSettingsService({bool autoHide = false}) {
    final settingsService = MockSettingsService();
    when(settingsService.autoHideAppBarEnabled).thenReturn(autoHide);
    when(settingsService.showNetworkIndicatorInStatusBar).thenReturn(true);
    when(settingsService.showWifiWidgetInStatusBar).thenReturn(true);
    when(settingsService.showDateInStatusBar).thenReturn(true);
    when(settingsService.showTimeInStatusBar).thenReturn(true);
    when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
    when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
    when(settingsService.showWeather).thenReturn(false);
    // Not what these tests are about: keep the live blur off so none of them
    // need to depend on the blur snapshot's async build.
    when(settingsService.dockBackdropFilterDisabled).thenReturn(true);
    return settingsService;
  }

  MockNetworkService mkNetworkService() {
    final networkService = MockNetworkService();
    when(networkService.networkType).thenReturn(NetworkType.Wifi);
    when(networkService.cellularNetworkType).thenReturn(CellularNetworkType.Unknown);
    when(networkService.wirelessNetworkSignalLevel).thenReturn(3);
    // No permission: the Wi-Fi usage widget renders its "grant permission"
    // button, sidestepping the FutureBuilder branch and the dart:io-backed
    // usage query, which does not advance inside a fake-async test zone.
    when(networkService.hasUsageStatsPermission).thenReturn(false);
    return networkService;
  }

  MockWallpaperService mkWallpaperService() {
    final wallpaperService = MockWallpaperService();
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.wallpaperVideoFile).thenReturn(null);
    when(wallpaperService.wallpaperRevision).thenReturn(0);
    when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
    return wallpaperService;
  }

  Future<FocusAwareAppBarState> pumpBar(WidgetTester tester, {bool autoHide = false}) async {
    final scenesService = MockScenesService();
    when(scenesService.activeSceneKey).thenReturn(SceneKeys.normal);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: mkSettingsService(autoHide: autoHide)),
          ChangeNotifierProvider<ScenesService>.value(value: scenesService),
          ChangeNotifierProvider<NetworkService>.value(value: mkNetworkService()),
          ChangeNotifierProvider<WallpaperService>.value(value: mkWallpaperService()),
          ChangeNotifierProvider(create: (_) => LauncherState()),
        ],
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(appBar: FocusAwareAppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<FocusAwareAppBarState>(find.byType(FocusAwareAppBar));
  }

  /// Whether the currently focused widget overlaps [finder]'s render box.
  /// Same rationale as `isFocused` in `flauncher_test.dart`: geometry survives
  /// incidental nesting details that `Focus.of()` would get wrong.
  bool isFocusedAt(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final focusRect = FocusManager.instance.primaryFocus?.rect;
    return focusRect != null && rect.overlaps(focusRect);
  }

  group("every remaining bar element sits inside its own glass card", () {
    testWidgets("the settings button", (tester) async {
      await pumpBar(tester);

      expect(
        find.ancestor(of: find.byIcon(Icons.settings_outlined), matching: find.byType(StatusBarGlassCard)),
        findsOneWidget,
      );
    });

    testWidgets("the scene picker button", (tester) async {
      await pumpBar(tester);

      expect(
        find.ancestor(of: find.byIcon(Icons.home_outlined), matching: find.byType(StatusBarGlassCard)),
        findsOneWidget,
      );
    });

    testWidgets("the network indicator", (tester) async {
      await pumpBar(tester);

      expect(
        find.ancestor(of: find.byType(NetworkWidget), matching: find.byType(StatusBarGlassCard)),
        findsOneWidget,
      );
    });

    testWidgets("the Wi-Fi usage widget", (tester) async {
      await pumpBar(tester);

      expect(
        find.ancestor(of: find.byType(DailyWifiUsageWidget), matching: find.byType(StatusBarGlassCard)),
        findsOneWidget,
      );
    });

    testWidgets("the date and time, sharing one card", (tester) async {
      await pumpBar(tester);

      final dateCard = find.ancestor(of: find.byKey(const Key("statusbar_date")), matching: find.byType(StatusBarGlassCard));
      final clockCard = find.ancestor(of: find.byKey(const Key("statusbar_clock")), matching: find.byType(StatusBarGlassCard));
      expect(dateCard, findsOneWidget);
      expect(clockCard, findsOneWidget);
      // Same card, not one per widget: they read as a single "what time is it,
      // on what day" element.
      expect(tester.widget(dateCard), same(tester.widget(clockCard)));
    });
  });

  testWidgets(
      "the settings button, scene button, network indicator and Wi-Fi widget stay focusable, "
      "in the same left-to-right order, once wrapped in glass cards", (tester) async {
    final appBarState = await pumpBar(tester);

    appBarState.focusSettings();
    await tester.pumpAndSettle();
    expect(isFocusedAt(tester, find.byIcon(Icons.settings_outlined)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(isFocusedAt(tester, find.byIcon(Icons.home_outlined)), isTrue,
        reason: "focus should move to the scene picker button next");

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(isFocusedAt(tester, find.byType(NetworkWidget)), isTrue,
        reason: "focus should move to the network indicator next");

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(isFocusedAt(tester, find.descendant(of: find.byType(DailyWifiUsageWidget), matching: find.byType(TextButton))), isTrue,
        reason: "focus should move to the Wi-Fi usage widget's permission button last");
  });

  testWidgets("the settings button is still reachable through the glass cards while the bar is auto-hidden and collapsed",
      (tester) async {
    final appBarState = await pumpBar(tester, autoHide: true);

    // Collapsed: nothing has focused it yet.
    expect(tester.getSize(find.byType(AppBar)).height, 0);

    // Reached the same way the real settings shortcut does: a programmatic
    // `requestFocus()`, never directional traversal, so it must work at zero
    // height regardless of how many glass cards now sit inside the bar.
    appBarState.focusSettings();
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(isFocusedAt(tester, find.byIcon(Icons.settings_outlined)), isTrue);
    // The bar grew back to accommodate the now-focused button.
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });
}
