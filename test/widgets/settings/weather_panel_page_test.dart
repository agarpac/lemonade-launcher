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
import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/weather_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../flauncher_test.dart' show isFocused;
import '../../mocks.mocks.dart';

const _sevilla = WeatherCity(
  name: "Sevilla",
  latitude: 37.38283,
  longitude: -5.97317,
  country: "España",
  admin1: "Andalucía",
);

const _seville = WeatherCity(name: "Seville", latitude: 28.01474, longitude: -82.08312, country: "United States");

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

  testWidgets("Starts with the switch off, no city, and the search prompt", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService();

    await _pumpPage(tester, settingsService, weatherService);

    expect(find.text("Show in the status bar"), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text("No city chosen"), findsOneWidget);
    // No city, so nothing to clear.
    expect(find.text("Clear city"), findsNothing);
    // Never a blank space where the results will be.
    expect(find.text("Type a city name, then confirm to search."), findsOneWidget);
  });

  testWidgets("The visibility switch writes the setting", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService();

    await _pumpPage(tester, settingsService, weatherService);

    await tester.tap(find.text("Show in the status bar"));
    await tester.pumpAndSettle();

    verify(settingsService.setShowWeather(true)).called(1);
  });

  testWidgets("The switch reflects the stored value and can be turned back off", (tester) async {
    final settingsService = _mkSettingsService(showWeather: true);
    final weatherService = _mkWeatherService();

    await _pumpPage(tester, settingsService, weatherService);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.text("Show in the status bar"));
    await tester.pumpAndSettle();

    verify(settingsService.setShowWeather(false)).called(1);
  });

  testWidgets("Typing fires no search; only submitting does, exactly once", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService(results: [_sevilla]);

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.pumpAndSettle();

    // Seven characters typed one D-pad press at a time must not be seven
    // requests to the geocoding endpoint.
    verifyNever(weatherService.searchCities(any, language: anyNamed("language"), count: anyNamed("count")));

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(weatherService.searchCities("Sevilla", language: "en", count: anyNamed("count"))).called(1);
  });

  testWidgets("The search is made in the active locale's language", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService(results: [_sevilla]);

    await _pumpPage(tester, settingsService, weatherService, locale: const Locale("es"));

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(weatherService.searchCities("Sevilla", language: "es", count: anyNamed("count"))).called(1);
  });

  testWidgets("Submitting an empty field searches nothing and says what to do", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService();

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "   ");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verifyNever(weatherService.searchCities(any, language: anyNamed("language"), count: anyNamed("count")));
    expect(find.text("Type a city name, then confirm to search."), findsOneWidget);
  });

  testWidgets("A search the provider answered with nothing says 'no match', not 'it failed'", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkSearchingWeatherService(const WeatherCitySearchResult.completed([]));

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Xyzzy");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text("No city matches that name."), findsOneWidget);
    expect(find.text("The search could not be completed. Check the connection and try again."), findsNothing);
  });

  testWidgets("A search that never got through says so, instead of denying the city exists", (tester) async {
    // The whole point of the distinction: with the Wi-Fi down, a user must not
    // be told that Sevilla is not a place. They would retype it until they
    // gave up, never learning that the network is the problem.
    final settingsService = _mkSettingsService();
    final weatherService = _mkSearchingWeatherService(const WeatherCitySearchResult.failed());

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text("The search could not be completed. Check the connection and try again."), findsOneWidget);
    expect(find.text("No city matches that name."), findsNothing);
  });

  testWidgets("A search that throws anyway shows the failure message rather than an exception", (tester) async {
    // `searchCities` contracts never to throw; this is the backstop for the
    // day something changes and it does.
    final settingsService = _mkSettingsService();
    final weatherService = MockWeatherService();
    when(weatherService.searchCities(any, language: anyNamed("language"), count: anyNamed("count")))
        .thenThrow(StateError("the network went away"));

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text("The search could not be completed. Check the connection and try again."), findsOneWidget);
    expect(find.text("No city matches that name."), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Results are listed with their full label and the first one takes the focus", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService(results: [_sevilla, _seville]);

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text("Sevilla, Andalucía, España"), findsOneWidget);
    expect(find.text("Seville, United States"), findsOneWidget);

    // The list is a Column, not a lazy ListView, so every result really is in
    // the tree and the focus request can reach the first of them — which is
    // what makes the results usable with a remote at all.
    final firstResult = tester.element(find.ancestor(
      of: find.text("Sevilla, Andalucía, España"),
      matching: find.byType(FocusableSettingsTile),
    ));
    expect(isFocused(firstResult), isTrue);
  });

  testWidgets("Choosing a result stores its coordinates and its label", (tester) async {
    final settingsService = _mkSettingsService();
    final weatherService = _mkWeatherService(results: [_sevilla, _seville]);

    await _pumpPage(tester, settingsService, weatherService);

    await tester.enterText(find.byType(TextField), "Sevilla");
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text("Seville, United States"));
    await tester.pumpAndSettle();

    verify(settingsService.setWeatherLocation(
      latitude: 28.01474,
      longitude: -82.08312,
      label: "Seville, United States",
    )).called(1);
    verifyNever(settingsService.clearWeatherLocation());
  });

  testWidgets("A stored city is shown and can be cleared", (tester) async {
    final settingsService = _mkSettingsService(locationLabel: "Sevilla, Andalucía, España");
    final weatherService = _mkWeatherService();

    await _pumpPage(tester, settingsService, weatherService);

    expect(find.text("Sevilla, Andalucía, España"), findsOneWidget);
    expect(find.text("No city chosen"), findsNothing);

    await tester.tap(find.text("Clear city"));
    await tester.pumpAndSettle();

    verify(settingsService.clearWeatherLocation()).called(1);
    // Clearing the city is not the same as switching the block off.
    verifyNever(settingsService.setShowWeather(any));
    // The tile that had the focus is the one that just went away, so the focus
    // is handed back to the switch. A settings page with nothing focused is a
    // dead end for a remote.
    final switchTile = tester.element(find.ancestor(
      of: find.text("Show in the status bar"),
      matching: find.byType(FocusableSettingsTile),
    ));
    expect(isFocused(switchTile), isTrue);
  });

  testWidgets("The status-bar page is where the weather page is reached from", (tester) async {
    final settingsService = _mkSettingsService();
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.showDateInStatusBar).thenReturn(true);
    when(settingsService.showTimeInStatusBar).thenReturn(true);
    when(settingsService.showWifiWidgetInStatusBar).thenReturn(false);
    when(settingsService.showNetworkIndicatorInStatusBar).thenReturn(false);
    String? pushedRoute;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settingsService,
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StatusBarPanelPage()),
          onGenerateRoute: (settings) {
            pushedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Alongside the date, the clock, the Wi-Fi usage and the network
    // indicator: the weather is one more thing the status bar can show.
    await tester.tap(find.text("Weather"));
    await tester.pumpAndSettle();

    expect(pushedRoute, WeatherPanelPage.routeName);
  });

  testWidgets("The settings panel knows how to build that route", (tester) async {
    // A route name that `SettingsPanel.onGenerateRoute` does not handle throws
    // an ArgumentError, so simply reaching the page proves the registration.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: _mkSettingsService()),
          ChangeNotifierProvider<WeatherService>.value(value: _mkWeatherService()),
        ],
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPanel(initialRoute: WeatherPanelPage.routeName),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeatherPanelPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

MockSettingsService _mkSettingsService({bool showWeather = false, String? locationLabel}) {
  final settingsService = MockSettingsService();
  when(settingsService.showWeather).thenReturn(showWeather);
  when(settingsService.weatherLocationLabel).thenReturn(locationLabel);
  when(settingsService.setShowWeather(any)).thenAnswer((_) async {});
  when(settingsService.setWeatherLocation(
    latitude: anyNamed("latitude"),
    longitude: anyNamed("longitude"),
    label: anyNamed("label"),
  )).thenAnswer((_) async {});
  when(settingsService.clearWeatherLocation()).thenAnswer((_) async {});
  return settingsService;
}

/// A weather service whose city search completes — with [results], which being
/// empty means a genuine "no city is called that".
MockWeatherService _mkWeatherService({List<WeatherCity> results = const []}) =>
    _mkSearchingWeatherService(WeatherCitySearchResult.completed(results));

MockWeatherService _mkSearchingWeatherService(WeatherCitySearchResult result) {
  final weatherService = MockWeatherService();
  when(weatherService.searchCities(any, language: anyNamed("language"), count: anyNamed("count")))
      .thenAnswer((_) async => result);
  return weatherService;
}

Future<void> _pumpPage(
  WidgetTester tester,
  MockSettingsService settingsService,
  MockWeatherService weatherService, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<WeatherService>.value(value: weatherService),
      ],
      builder: (_, __) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WeatherPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
