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

import 'package:flauncher/gradients.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/status_bar_weather_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // Same 720p test surface every other widget test sets up, spelled with the
    // non-deprecated view API so this file adds no new analyzer noise.
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  group("the card itself", () {
    testWidgets("renders nothing at all when the weather is switched off", (tester) async {
      // `hasWeather` is false exactly when the feature is off, no city is set,
      // or nothing has been read yet — the widget cannot tell them apart, and
      // must not: all three are "draw nothing".
      final weatherService = mkWeatherService(hasWeather: false, reading: null);

      await _pumpCard(tester, weatherService);

      expect(find.byType(StatusBarWeatherWidget), findsOneWidget);
      expect(tester.getSize(find.byType(StatusBarWeatherWidget)), Size.zero);
      // No placeholder, no spinner, no error text: a gap is the right failure.
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets("renders nothing when the weather is on but there is no reading yet", (tester) async {
      // A city is set and the toggle is on, but the very first request has not
      // come back (or every one of them failed).
      final weatherService = mkWeatherService(hasWeather: false, reading: null);

      await _pumpCard(tester, weatherService);

      expect(tester.getSize(find.byType(StatusBarWeatherWidget)), Size.zero);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets("shows the rounded temperature and the condition icon once there is a reading", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        // 21.6 rounds up; WMO code 0 is a clear sky.
        reading: WeatherReading(temperatureCelsius: 21.6, wmoCode: 0, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpCard(tester, weatherService);

      expect(find.text("22°"), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(StatusBarWeatherWidget)).width, greaterThan(0));
    });

    testWidgets("rounds a negative temperature to whole degrees too", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        // WMO code 71 is snowfall.
        reading: WeatherReading(temperatureCelsius: -2.4, wmoCode: 71, observedAt: DateTime(2026, 1, 8, 7)),
      );

      await _pumpCard(tester, weatherService);

      expect(find.text("-2°"), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    });

    testWidgets("an unmapped WMO code still shows the temperature, with a fallback glyph", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        reading: WeatherReading(temperatureCelsius: 14.0, wmoCode: 4242, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpCard(tester, weatherService);

      expect(find.text("14°"), findsOneWidget);
      expect(find.byIcon(Icons.thermostat_outlined), findsOneWidget);
    });

    testWidgets("holds no focusable node, so the D-pad can never land on it", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        reading: WeatherReading(temperatureCelsius: 21.6, wmoCode: 0, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpCard(tester, weatherService);

      // Structural, not behavioural, on purpose: the guarantee wanted here is
      // that there is nothing inside the card that *could* take focus, which
      // no amount of arrow-key pressing can prove.
      expect(
        find.descendant(
          of: find.byType(StatusBarWeatherWidget),
          matching: find.byWidgetPredicate((widget) => widget is Focus || widget is FocusScope),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(StatusBarWeatherWidget), matching: find.byType(InkWell)),
        findsNothing,
      );
    });
  });

  group("inside the status bar", () {
    testWidgets("the bar shows the card to the left of the clock", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        reading: WeatherReading(temperatureCelsius: 18.2, wmoCode: 3, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpAppBar(tester, weatherService, showWeather: true);

      expect(find.text("18°"), findsOneWidget);
      final weatherRight = tester.getTopRight(find.byType(StatusBarWeatherWidget)).dx;
      final clockLeft = tester.getTopLeft(find.byKey(const Key("statusbar_clock"))).dx;
      expect(weatherRight, lessThanOrEqualTo(clockLeft));
    });

    testWidgets("the bar keeps its settings button reachable while the card is on screen", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        reading: WeatherReading(temperatureCelsius: 18.2, wmoCode: 3, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpAppBar(tester, weatherService, showWeather: true);

      final appBarState = tester.state<FocusAwareAppBarState>(find.byType(FocusAwareAppBar));
      appBarState.focusSettings();
      await tester.pumpAndSettle();

      // The programmatic route into Settings is the only way into the bar when
      // it is auto-hidden; the weather card must not have disturbed it.
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets("switching the weather off leaves the bar without a card", (tester) async {
      final weatherService = mkWeatherService(
        hasWeather: true,
        reading: WeatherReading(temperatureCelsius: 18.2, wmoCode: 3, observedAt: DateTime(2026, 7, 26, 12)),
      );

      await _pumpAppBar(tester, weatherService, showWeather: false);

      expect(find.byType(StatusBarWeatherWidget), findsNothing);
      expect(find.text("18°"), findsNothing);
    });
  });
}

MockWeatherService mkWeatherService({required bool hasWeather, required WeatherReading? reading}) {
  final weatherService = MockWeatherService();
  when(weatherService.hasWeather).thenReturn(hasWeather);
  when(weatherService.reading).thenReturn(reading);
  return weatherService;
}

MockSettingsService _mkSettingsService({bool showWeather = true}) {
  final settingsService = MockSettingsService();
  when(settingsService.showWeather).thenReturn(showWeather);
  // The dock's blur escape hatch, which the card honours too. Left on here so
  // the frosted path — `CachedBlurBackdrop` and its `WallpaperService` lookup —
  // is the one under test.
  when(settingsService.dockBackdropFilterDisabled).thenReturn(false);
  when(settingsService.autoHideAppBarEnabled).thenReturn(false);
  when(settingsService.showNetworkIndicatorInStatusBar).thenReturn(false);
  when(settingsService.showWifiWidgetInStatusBar).thenReturn(false);
  when(settingsService.showDateInStatusBar).thenReturn(false);
  when(settingsService.showTimeInStatusBar).thenReturn(true);
  when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
  when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
  // Not what these tests are about: off, matching the production default,
  // since none of them exercise the scenes icon itself.
  when(settingsService.scenesEnabled).thenReturn(false);
  return settingsService;
}

MockWallpaperService _mkWallpaperService() {
  final wallpaperService = MockWallpaperService();
  // No image and no video: `CachedBlurBackdrop` blurs the gradient instead,
  // which needs no asset loading inside the test's fake-async zone.
  when(wallpaperService.wallpaper).thenReturn(null);
  when(wallpaperService.wallpaperVideoFile).thenReturn(null);
  when(wallpaperService.wallpaperRevision).thenReturn(0);
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  return wallpaperService;
}

/// Pumps the card on its own, with the real frosted-glass backdrop behind it.
Future<void> _pumpCard(WidgetTester tester, MockWeatherService weatherService) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WeatherService>.value(value: weatherService),
        ChangeNotifierProvider<SettingsService>.value(value: _mkSettingsService()),
        ChangeNotifierProvider<WallpaperService>.value(value: _mkWallpaperService()),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Align(alignment: Alignment.topRight, child: StatusBarWeatherWidget()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the whole status bar, which is where the card's placement and its
/// absence from the focus path actually matter.
Future<void> _pumpAppBar(
  WidgetTester tester,
  MockWeatherService weatherService, {
  required bool showWeather,
}) async {
  final scenesService = MockScenesService();
  when(scenesService.activeSceneKey).thenReturn(SceneKeys.normal);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WeatherService>.value(value: weatherService),
        ChangeNotifierProvider<SettingsService>.value(value: _mkSettingsService(showWeather: showWeather)),
        ChangeNotifierProvider<WallpaperService>.value(value: _mkWallpaperService()),
        ChangeNotifierProvider<ScenesService>.value(value: scenesService),
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
}
