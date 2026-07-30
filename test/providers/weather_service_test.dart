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

import 'dart:async';
import 'dart:convert';

import 'package:flauncher/models/weather.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// The preference key `WeatherService` caches its last reading under. Private
/// there on purpose; repeated here so a rename has to be a deliberate act.
const _cachedReadingKey = "weather_cached_reading";

const _madrid = (latitude: 40.4168, longitude: -3.7038);
const _sevilla = (latitude: 37.38283, longitude: -5.97317);

/// The exact shape Open-Meteo returns for
/// `?current=temperature_2m,weather_code&timezone=auto` (PRD section 6).
String _forecastBody({double temperature = 27.9, int code = 3}) => jsonEncode({
      "latitude": 40.4168,
      "longitude": -3.7038,
      "timezone": "Europe/Madrid",
      "current": {"time": "2026-07-26T12:00", "interval": 900, "temperature_2m": temperature, "weather_code": code},
    });

String _cachedReadingPayload({
  ({double latitude, double longitude}) location = _madrid,
  double temperature = 21.5,
  int code = 0,
  int observedAtMillis = 1000,
}) =>
    jsonEncode({
      "version": 1,
      "latitude": location.latitude,
      "longitude": location.longitude,
      "temperature": temperature,
      "weather_code": code,
      "observed_at": observedAtMillis,
    });

/// A stand-in for the two Open-Meteo endpoints, recording what was asked for.
/// Nothing in this file touches the network.
class _StubServer {
  final List<Uri> requests = [];
  Future<http.Response> Function(Uri uri) handler;

  _StubServer(this.handler);

  late final http.Client client = MockClient((request) {
    requests.add(request.url);
    return handler(request.url);
  });
}

/// Lets every pending microtask and zero-duration future run. Plain `test`
/// bodies are not inside a fake-async zone, so this is enough to let a stubbed
/// request resolve.
Future<void> settle() => Future.delayed(Duration.zero);

void main() async {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final sharedPreferences = await SharedPreferences.getInstance();

  setUp(() async {
    await sharedPreferences.clear();
  });

  // Lets any request still in flight when a test ended resolve *before* the
  // next test clears the store, so a late cache write can never land in
  // another test's preferences.
  tearDown(() => settle());

  // A real SettingsService over an in-memory store: this service reads four
  // preferences through it and listens to it, and the interplay between the
  // two is most of what is worth testing here.
  SettingsService newSettings() => SettingsService(sharedPreferences, ScenesService(sharedPreferences));

  Future<SettingsService> enabledSettings({
    ({double latitude, double longitude}) location = _madrid,
    String label = "Madrid, España",
  }) async {
    final settings = newSettings();
    await settings.setShowWeather(true);
    await settings.setWeatherLocation(latitude: location.latitude, longitude: location.longitude, label: label);
    return settings;
  }

  _StubServer okServer([String? body]) => _StubServer((_) async => http.Response(body ?? _forecastBody(), 200));

  group("fetching", () {
    test("a successful fetch parses the reading, asks for the configured city and notifies", () async {
      final settings = await enabledSettings();
      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);
      var notifications = 0;
      service.addListener(() => notifications++);

      await settle();

      expect(service.reading, isNotNull);
      expect(service.reading!.temperatureCelsius, 27.9);
      expect(service.reading!.wmoCode, 3);
      expect(service.reading!.condition, WeatherCondition.overcast);
      expect(service.hasWeather, isTrue);
      expect(notifications, 1);

      expect(server.requests, hasLength(1));
      final requested = server.requests.single;
      expect(requested.host, "api.open-meteo.com");
      expect(requested.path, "/v1/forecast");
      expect(requested.queryParameters["latitude"], "40.4168");
      expect(requested.queryParameters["longitude"], "-3.7038");
      expect(requested.queryParameters["current"], "temperature_2m,weather_code");
      expect(requested.queryParameters["timezone"], "auto");
    });

    test("the reading is stamped with the device clock, not the provider's local time", () async {
      // Built with the weather explicitly off so the clock seam is in place
      // before the first request goes out (showWeather now defaults to true).
      final settings = newSettings();
      await settings.setShowWeather(false);
      await settings.setWeatherLocation(latitude: _madrid.latitude, longitude: _madrid.longitude, label: "Madrid");
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);
      final fixedNow = DateTime.fromMillisecondsSinceEpoch(1234567);
      service.debugNow = () => fixedNow;

      await settings.setShowWeather(true);
      await settle();

      expect(service.reading!.observedAt, fixedNow);
    });

    test("a fetched reading is cached for the next start", () async {
      final settings = await enabledSettings();
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);

      await settle();

      final cached = jsonDecode(sharedPreferences.getString(_cachedReadingKey)!);
      expect(cached["temperature"], 27.9);
      expect(cached["weather_code"], 3);
      expect(cached["latitude"], _madrid.latitude);
      expect(cached["longitude"], _madrid.longitude);
    });

    test("refresh does nothing while the weather is switched off", () async {
      final settings = newSettings();
      await settings.setShowWeather(false);
      await settings.setWeatherLocation(latitude: _madrid.latitude, longitude: _madrid.longitude, label: "Madrid");
      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(server.requests, isEmpty);
      expect(service.reading, isNull);
      expect(service.hasWeather, isFalse);
    });

    test("refresh does nothing while no city is set", () async {
      final settings = newSettings();
      await settings.setShowWeather(true);
      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(server.requests, isEmpty);
      expect(service.hasWeather, isFalse);
    });

    test("switching the weather on starts a fetch", () async {
      final settings = newSettings();
      // showWeather defaults to true now, so switch it off explicitly first:
      // the point of this test is the transition, not the resting state.
      await settings.setShowWeather(false);
      await settings.setWeatherLocation(latitude: _madrid.latitude, longitude: _madrid.longitude, label: "Madrid");
      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      await settings.setShowWeather(true);
      await settle();

      expect(server.requests, hasLength(1));
      expect(service.reading!.temperatureCelsius, 27.9);
    });
  });

  group("the cached reading", () {
    test("is served synchronously on construction, before any request returns", () async {
      await sharedPreferences.setString(_cachedReadingKey, _cachedReadingPayload());
      final settings = await enabledSettings();
      final server = _StubServer((_) async => http.Response("", 500));

      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      expect(service.reading, isNotNull);
      expect(service.reading!.temperatureCelsius, 21.5);
      expect(service.reading!.condition, WeatherCondition.clear);
      expect(service.reading!.observedAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(service.hasWeather, isTrue);
    });

    test("is ignored when it belongs to another city", () async {
      await sharedPreferences.setString(_cachedReadingKey, _cachedReadingPayload(location: _sevilla));
      final settings = await enabledSettings();
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);

      expect(service.reading, isNull);
    });

    test("is ignored, without throwing, when the stored value is of another type", () async {
      // The backup feature imports a user-supplied JSON straight into the
      // preference store, and getString is a hard cast.
      await sharedPreferences.setBool(_cachedReadingKey, true);
      final settings = await enabledSettings();

      late WeatherService service;
      expect(() => service = WeatherService(settings, sharedPreferences, httpClient: okServer().client),
          returnsNormally);
      addTearDown(() => service.dispose());

      expect(service.reading, isNull);
    });

    test("is ignored, without throwing, when the stored payload is corrupt", () async {
      for (final payload in <String>[
        "",
        "not json at all",
        "[]",
        jsonEncode({"version": 99, "latitude": 40.4168, "longitude": -3.7038, "temperature": 21.5}),
        jsonEncode({"version": 1, "latitude": "forty", "longitude": -3.7038, "temperature": 21.5, "weather_code": 0}),
        jsonEncode({"version": 1, "latitude": 40.4168, "longitude": -3.7038, "weather_code": 0, "observed_at": 1}),
      ]) {
        await sharedPreferences.setString(_cachedReadingKey, payload);
        final settings = await enabledSettings();

        // A server that never succeeds: the point here is what the *cache*
        // yields, and a successful fetch would overwrite the next iteration's
        // payload from under it.
        final service = WeatherService(settings, sharedPreferences,
            httpClient: _StubServer((_) async => http.Response("", 503)).client);
        expect(service.reading, isNull, reason: "payload: $payload");
        service.dispose();
        await settle();
      }
    });
  });

  group("silent failure", () {
    /// Every case here must leave the reading that is already on screen alone
    /// and throw nothing: the status bar of the device's only home screen
    /// cannot show an error.
    Future<WeatherService> serviceWithCachedReadingAnd(Future<http.Response> Function(Uri uri) handler) async {
      await sharedPreferences.setString(_cachedReadingKey, _cachedReadingPayload());
      final settings = await enabledSettings();
      return WeatherService(settings, sharedPreferences, httpClient: _StubServer(handler).client);
    }

    test("a non-200 keeps the cached reading", () async {
      final service = await serviceWithCachedReadingAnd((_) async => http.Response("Too many requests", 429));
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(service.reading!.temperatureCelsius, 21.5);
      expect(service.hasWeather, isTrue);
    });

    test("a timeout keeps the cached reading", () async {
      // The real path is `.timeout(WeatherService.requestTimeout)`; the stub
      // raises the very error that would surface from it, without making the
      // suite wait ten real seconds for it.
      final service = await serviceWithCachedReadingAnd(
          (_) => Future.error(TimeoutException("no response", WeatherService.requestTimeout)));
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(service.reading!.temperatureCelsius, 21.5);
      expect(WeatherService.requestTimeout, const Duration(seconds: 10));
    });

    test("a socket-level failure keeps the cached reading", () async {
      final service = await serviceWithCachedReadingAnd((_) => Future.error(const SocketExceptionStub()));
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(service.reading!.temperatureCelsius, 21.5);
    });

    test("malformed JSON keeps the cached reading", () async {
      final service = await serviceWithCachedReadingAnd((_) async => http.Response("<html>nope</html>", 200));
      addTearDown(service.dispose);

      await service.refresh();
      await settle();

      expect(service.reading!.temperatureCelsius, 21.5);
    });

    test("a well-formed payload with missing or mistyped fields keeps the cached reading", () async {
      for (final body in <String>[
        jsonEncode({"timezone": "Europe/Madrid"}),
        jsonEncode({"current": null}),
        jsonEncode({"current": {}}),
        jsonEncode({
          "current": {"temperature_2m": "27.9", "weather_code": 3}
        }),
        jsonEncode({
          "current": {"temperature_2m": 27.9}
        }),
      ]) {
        await sharedPreferences.setString(_cachedReadingKey, _cachedReadingPayload());
        final settings = await enabledSettings();
        final service =
            WeatherService(settings, sharedPreferences, httpClient: _StubServer((_) async => http.Response(body, 200)).client);

        await service.refresh();
        await settle();

        expect(service.reading!.temperatureCelsius, 21.5, reason: "body: $body");
        service.dispose();
      }
    });

    test("a preference of the wrong type under the weather settings does not throw", () async {
      // Same untrusted-input rule, one level up: SettingsService's own reads.
      await sharedPreferences.setString("show_weather", "yes");
      await sharedPreferences.setBool("weather_latitude", true);
      await sharedPreferences.setBool("weather_longitude", true);
      await sharedPreferences.setBool("weather_location_label", true);
      final settings = newSettings();

      // show_weather defaults to true, but the stored value here is a string,
      // which the guarded read treats as absent, falling back to the default.
      expect(settings.showWeather, isTrue);
      expect(settings.weatherLatitude, isNull);
      expect(settings.weatherLongitude, isNull);
      expect(settings.weatherLocationLabel, isNull);

      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      expect(service.reading, isNull);
      expect(service.hasWeather, isFalse);
      expect(service.debugTimerIsActive, isFalse);
      expect(server.requests, isEmpty);
    });
  });

  group("the refresh timer", () {
    test("refreshes every fifteen minutes", () {
      expect(WeatherService.refreshInterval, const Duration(minutes: 15));
    });

    test("does not run while the weather is switched off", () async {
      final settings = newSettings();
      await settings.setShowWeather(false);
      await settings.setWeatherLocation(latitude: _madrid.latitude, longitude: _madrid.longitude, label: "Madrid");
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);

      expect(service.debugTimerIsActive, isFalse);
    });

    test("does not run while no city is set", () async {
      final settings = newSettings();
      await settings.setShowWeather(true);
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);

      expect(service.debugTimerIsActive, isFalse);
    });

    test("starts and stops as the settings change", () async {
      final settings = newSettings();
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      addTearDown(service.dispose);
      expect(service.debugTimerIsActive, isFalse);

      await settings.setShowWeather(true);
      expect(service.debugTimerIsActive, isFalse, reason: "still no city");

      await settings.setWeatherLocation(latitude: _madrid.latitude, longitude: _madrid.longitude, label: "Madrid");
      expect(service.debugTimerIsActive, isTrue);

      await settings.setShowWeather(false);
      expect(service.debugTimerIsActive, isFalse);

      await settings.setShowWeather(true);
      expect(service.debugTimerIsActive, isTrue);

      await settings.clearWeatherLocation();
      expect(service.debugTimerIsActive, isFalse);
    });

    test("is cancelled by dispose", () async {
      final settings = await enabledSettings();
      final service = WeatherService(settings, sharedPreferences, httpClient: okServer().client);
      expect(service.debugTimerIsActive, isTrue);

      service.dispose();

      expect(service.debugTimerIsActive, isFalse);
    });

    test("dispose also stops listening to the settings", () async {
      final settings = await enabledSettings();
      final server = okServer();
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      await settle();
      final requestsBeforeDispose = server.requests.length;

      service.dispose();
      // A disposed ChangeNotifier throws on notifyListeners; if the listener
      // were still registered this would blow up rather than be ignored.
      await settings.setShowWeather(false);
      await settings.setShowWeather(true);
      await settle();

      expect(server.requests, hasLength(requestsBeforeDispose));
    });
  });

  group("changing the city", () {
    test("discards the reading from the previous one and fetches the new one", () async {
      final settings = await enabledSettings();
      final server = _StubServer((_) async => http.Response(_forecastBody(), 200));
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);
      await settle();
      expect(service.reading!.temperatureCelsius, 27.9);

      server.handler = (_) async => http.Response(_forecastBody(temperature: 34.1, code: 0), 200);
      await settings.setWeatherLocation(
          latitude: _sevilla.latitude, longitude: _sevilla.longitude, label: "Sevilla, Andalucía, España");

      // Immediately: the old city's temperature must not linger under the new
      // city's name.
      expect(service.reading, isNull);
      expect(service.hasWeather, isFalse);

      await settle();

      expect(service.reading!.temperatureCelsius, 34.1);
      expect(service.reading!.condition, WeatherCondition.clear);
      expect(server.requests.last.queryParameters["latitude"], "37.38283");
    });
  });

  group("searchCities", () {
    test("parses the geocoding results", () async {
      final settings = newSettings();
      final server = _StubServer((_) async => http.Response(
            jsonEncode({
              "results": [
                {
                  "id": 2510911,
                  "name": "Sevilla",
                  "latitude": 37.38283,
                  "longitude": -5.97317,
                  "country": "España",
                  "admin1": "Andalucía",
                },
                {"name": "Sevilla la Nueva", "latitude": 40.34838, "longitude": -4.02779, "country": "España"},
              ],
            }),
            200,
          ));
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      final result = await service.searchCities("Sevilla", language: "es");

      expect(result.status, WeatherCitySearchStatus.completed);
      expect(result.failed, isFalse);
      expect(result.noMatch, isFalse);
      final cities = result.cities;
      expect(cities, hasLength(2));
      expect(cities.first.name, "Sevilla");
      expect(cities.first.latitude, 37.38283);
      expect(cities.first.longitude, -5.97317);
      expect(cities.first.label, "Sevilla, Andalucía, España");
      expect(cities.last.label, "Sevilla la Nueva, España");

      final requested = server.requests.single;
      expect(requested.host, "geocoding-api.open-meteo.com");
      expect(requested.path, "/v1/search");
      expect(requested.queryParameters["name"], "Sevilla");
      expect(requested.queryParameters["count"], "5");
      expect(requested.queryParameters["language"], "es");
    });

    test("uses the language the caller asks for", () async {
      final settings = newSettings();
      final server = _StubServer((_) async => http.Response(jsonEncode({}), 200));
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      await service.searchCities("Seville", language: "en", count: 3);

      expect(server.requests.single.queryParameters["language"], "en");
      expect(server.requests.single.queryParameters["count"], "3");
    });

    test("reports a genuine no-match when the reply has no results key at all", () async {
      // Open-Meteo omits `results` rather than sending an empty array, so an
      // absent key is the provider answering "no such place" — an answer, not
      // a failure, and the settings page says so in different words.
      final settings = newSettings();
      final service = WeatherService(settings, sharedPreferences,
          httpClient: _StubServer((_) async => http.Response(jsonEncode({"generationtime_ms": 0.5}), 200)).client);
      addTearDown(service.dispose);

      final result = await service.searchCities("Xyzzy", language: "es");

      expect(result.status, WeatherCitySearchStatus.completed);
      expect(result.cities, isEmpty);
      expect(result.noMatch, isTrue);
      expect(result.failed, isFalse);
    });

    test("reports a failure when 'results' is present but is not a list", () async {
      // Not the documented no-match shape: a body we cannot read says nothing
      // about whether the city exists.
      final settings = newSettings();
      final service = WeatherService(settings, sharedPreferences,
          httpClient: _StubServer((_) async => http.Response(jsonEncode({"results": "nonsense"}), 200)).client);
      addTearDown(service.dispose);

      final result = await service.searchCities("Sevilla", language: "es");

      expect(result.status, WeatherCitySearchStatus.failed);
      expect(result.failed, isTrue);
      expect(result.noMatch, isFalse);
      expect(result.cities, isEmpty);
    });

    test("skips entries that are missing the fields a city needs", () async {
      final settings = newSettings();
      final service = WeatherService(settings, sharedPreferences,
          httpClient: _StubServer((_) async => http.Response(
                jsonEncode({
                  "results": [
                    "not an object",
                    {"name": "No coordinates"},
                    {"latitude": 1.0, "longitude": 2.0},
                    {"name": "Usable", "latitude": 1.0, "longitude": 2.0},
                  ],
                }),
                200,
              )).client);
      addTearDown(service.dispose);

      final result = await service.searchCities("whatever", language: "es");

      // Unusable entries are dropped, but the search itself did complete.
      expect(result.status, WeatherCitySearchStatus.completed);
      expect(result.cities, hasLength(1));
      expect(result.cities.single.name, "Usable");
    });

    test("an empty query completes with nothing, without touching the network", () async {
      final settings = newSettings();
      final server = _StubServer((_) async => http.Response("", 503));
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      final result = await service.searchCities("   ", language: "es");

      expect(result.cities, isEmpty);
      // Typing nothing is not a network problem, and must not be reported as
      // one: the settings page shows its "type a city name" prompt for this.
      expect(result.failed, isFalse);
      expect(result.status, WeatherCitySearchStatus.completed);
      expect(server.requests, isEmpty, reason: "an empty query must not reach the network");
    });

    test("reports a failure, without throwing, on a non-200, a dead socket and a malformed body", () async {
      final settings = newSettings();
      final server = _StubServer((_) async => http.Response("", 503));
      final service = WeatherService(settings, sharedPreferences, httpClient: server.client);
      addTearDown(service.dispose);

      final nonTwoHundred = await service.searchCities("Sevilla", language: "es");
      expect(nonTwoHundred.status, WeatherCitySearchStatus.failed);
      expect(nonTwoHundred.cities, isEmpty);
      expect(nonTwoHundred.noMatch, isFalse, reason: "a 503 says nothing about whether the city exists");

      server.handler = (_) => Future.error(const SocketExceptionStub());
      final deadSocket = await service.searchCities("Sevilla", language: "es");
      expect(deadSocket.status, WeatherCitySearchStatus.failed);
      expect(deadSocket.cities, isEmpty);
      expect(deadSocket.noMatch, isFalse);

      server.handler = (_) async => http.Response("{not json", 200);
      final malformed = await service.searchCities("Sevilla", language: "es");
      expect(malformed.status, WeatherCitySearchStatus.failed);
      expect(malformed.cities, isEmpty);
      expect(malformed.noMatch, isFalse);

      server.handler = (_) async => http.Response(jsonEncode(["not an object"]), 200);
      final notAnObject = await service.searchCities("Sevilla", language: "es");
      expect(notAnObject.status, WeatherCitySearchStatus.failed);
      expect(notAnObject.cities, isEmpty);
    });
  });
}

/// A network-level failure, without importing `dart:io` into a test that must
/// never touch a real socket.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => "SocketExceptionStub: connection failed";
}
