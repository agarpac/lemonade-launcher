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
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Key of the cached last reading. One JSON object rather than four scalar
/// keys, so a half-written cache is impossible and the coordinates the reading
/// belongs to travel with it (see [WeatherService._loadCachedReading]).
const String _cachedReadingKey = "weather_cached_reading";

/// Current version of the cached payload's shape, mirroring
/// `ScenesService`'s versioned payload. A cache written by a future build with
/// a different shape is ignored, not misread.
const int _cachedReadingVersion = 1;

/// Current weather for the city the user picked, from Open-Meteo (PRD section
/// 6): no API key, no registration, no GPS and no IP geolocation.
///
/// Every failure mode is silent. No network, a timeout, a non-200, a body that
/// is not the JSON we expect: none of them throw, none of them clear what is
/// already on screen, and none of them surface an error. The status bar of the
/// device's only home screen is not a place to report that a weather server is
/// down — the block simply keeps showing the last reading, or nothing at all.
class WeatherService extends ChangeNotifier {
  /// PRD section 6: a 15-minute refresh is far inside Open-Meteo's ~10.000
  /// requests/day free allowance (96 requests a day).
  static const Duration refreshInterval = Duration(minutes: 15);

  /// A launcher must never hang on a dead network: every request is bounded.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Coordinates equal to within this many degrees are the same place (~10 cm).
  /// Used to decide whether a cached reading still belongs to the configured
  /// city; a plain `==` on doubles that have been through JSON and the
  /// preference store is technically exact but needlessly brittle.
  static const double _coordinateEpsilon = 1e-6;

  final SettingsService _settingsService;
  final SharedPreferences _sharedPreferences;
  final http.Client _httpClient;

  /// Whether [_httpClient] is ours to close. A client handed in by a caller
  /// (a test, or a future caller that pools connections) outlives this
  /// service, so [dispose] must not close it.
  final bool _ownsHttpClient;

  WeatherReading? _reading;
  Timer? _timer;
  bool _fetching = false;
  bool _disposed = false;

  /// Last known values of the two settings this service reacts to.
  /// `SettingsService` notifies on *every* preference write and on every scene
  /// change, so — exactly like `WallpaperService._onSettingsChanged` — the
  /// listener compares against these instead of re-acting to unrelated
  /// changes.
  bool _lastEnabled = false;
  ({double latitude, double longitude})? _lastLocation;

  /// Test-only seam for "now", matching `WallpaperService.debugNow`. Stamps
  /// [WeatherReading.observedAt] on a freshly fetched reading.
  @visibleForTesting
  DateTime Function() debugNow = DateTime.now;

  WeatherService(
    this._settingsService,
    this._sharedPreferences, {
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    _lastEnabled = _settingsService.showWeather;
    _lastLocation = _configuredLocation();
    // Served straight from the cache, synchronously, before anything is
    // fetched: a restart must not show an empty gap where the temperature was
    // (PRD section 6).
    _reading = _loadCachedReading();
    _settingsService.addListener(_onSettingsChanged);
    _updateTimerState();
    if (isEnabled) {
      unawaited(refresh());
    }
  }

  /// The last reading, or `null` when there has never been one for the
  /// configured city.
  WeatherReading? get reading => _reading;

  /// Whether the weather block is switched on *and* has somewhere to report
  /// the weather of. Both are required before a single request is made.
  bool get isEnabled => _settingsService.showWeather && _configuredLocation() != null;

  /// What the (later) status-bar widget checks: `false` means render nothing
  /// at all — no placeholder, no spinner, no error.
  bool get hasWeather => isEnabled && _reading != null;

  /// Display name of the configured city, or `null` when none is set.
  String? get locationLabel => _settingsService.weatherLocationLabel;

  /// Whether the periodic refresh is currently scheduled. Test-only: a
  /// `Timer.periodic` exposes neither its period nor its existence otherwise.
  @visibleForTesting
  bool get debugTimerIsActive => _timer?.isActive ?? false;

  ({double latitude, double longitude})? _configuredLocation() {
    final latitude = _settingsService.weatherLatitude;
    final longitude = _settingsService.weatherLongitude;
    if (latitude == null || longitude == null) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }

  /// Reacts only to the two things that matter: the toggle and the city.
  ///
  /// A new city invalidates the reading on screen immediately — showing
  /// Madrid's temperature under the label "Sevilla" until the next request
  /// lands would be worse than showing nothing — and starts a fetch for the
  /// new one.
  void _onSettingsChanged() {
    final enabled = _settingsService.showWeather;
    final location = _configuredLocation();
    final locationChanged = location != _lastLocation;
    if (enabled == _lastEnabled && !locationChanged) {
      return;
    }
    _lastEnabled = enabled;
    _lastLocation = location;

    if (locationChanged) {
      _reading = null;
      notifyListeners();
    }
    _updateTimerState();
    if (isEnabled) {
      unawaited(refresh());
    }
  }

  /// Runs the periodic refresh only while there is something to refresh, the
  /// way `WallpaperService._updateTimerState` does: a timer that wakes the
  /// device every 15 minutes to decide it has nothing to do is worse than no
  /// timer.
  void _updateTimerState() {
    if (isEnabled && (_timer == null || !_timer!.isActive)) {
      _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    } else if (!isEnabled && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  /// Fetches the current weather for the configured city.
  ///
  /// Does nothing at all — no request, no notification — while the feature is
  /// off or no city is set, and never throws whatever the network or the
  /// provider does. On any failure the previous reading is kept: stale weather
  /// beats a hole in the status bar.
  Future<void> refresh() async {
    final location = _configuredLocation();
    if (!_settingsService.showWeather || location == null || _fetching) {
      return;
    }
    _fetching = true;
    try {
      final uri = Uri.https("api.open-meteo.com", "/v1/forecast", {
        "latitude": location.latitude.toString(),
        "longitude": location.longitude.toString(),
        "current": "temperature_2m,weather_code",
        "timezone": "auto",
      });
      final response = await _httpClient.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) {
        debugPrint("WeatherService: forecast request returned ${response.statusCode}, keeping the cached reading");
        return;
      }
      final reading = _parseReading(response.body);
      if (reading == null) {
        debugPrint("WeatherService: unusable forecast payload, keeping the cached reading");
        return;
      }
      // The user may have switched city while the request was in flight; that
      // reply describes somewhere else now.
      if (_configuredLocation() != location) {
        return;
      }
      _reading = reading;
      await _persistReading(reading, location);
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      // Timeouts, socket errors, malformed JSON, a preference write that
      // failed: all the same thing here — nothing changed on screen.
      debugPrint("WeatherService: could not refresh the weather, keeping the cached reading ($e)");
    } finally {
      _fetching = false;
    }
  }

  /// Searches Open-Meteo's geocoding endpoint for cities matching [query].
  ///
  /// [language] is the caller's: the settings page knows the active locale,
  /// this service does not. Returns an empty list for an empty query, for a
  /// failed request, and for a reply with no `results` key at all — the
  /// endpoint *omits* that key when nothing matches rather than sending an
  /// empty array, so "absent" is the ordinary no-match answer, not an error.
  Future<List<WeatherCity>> searchCities(String query, {required String language, int count = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    try {
      final uri = Uri.https("geocoding-api.open-meteo.com", "/v1/search", {
        "name": trimmed,
        "count": count.toString(),
        "language": language,
        "format": "json",
      });
      final response = await _httpClient.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const [];
      }
      final results = decoded["results"];
      if (results is! List) {
        return const [];
      }
      final cities = <WeatherCity>[];
      for (final entry in results) {
        if (entry is! Map) {
          continue;
        }
        final name = entry["name"];
        final latitude = entry["latitude"];
        final longitude = entry["longitude"];
        if (name is! String || latitude is! num || longitude is! num) {
          continue;
        }
        final country = entry["country"];
        final admin1 = entry["admin1"];
        cities.add(WeatherCity(
          name: name,
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          country: country is String ? country : null,
          admin1: admin1 is String ? admin1 : null,
        ));
      }
      return cities;
    } catch (e) {
      debugPrint("WeatherService: city search failed ($e)");
      return const [];
    }
  }

  /// Parses Open-Meteo's `current` block. Returns `null` — never throws — for
  /// anything that is not the shape documented in PRD section 6.
  WeatherReading? _parseReading(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return null;
    }
    final current = decoded["current"];
    if (current is! Map) {
      return null;
    }
    final temperature = current["temperature_2m"];
    final code = current["weather_code"];
    if (temperature is! num || code is! num) {
      return null;
    }
    return WeatherReading(
      temperatureCelsius: temperature.toDouble(),
      wmoCode: code.toInt(),
      observedAt: debugNow(),
    );
  }

  Future<void> _persistReading(WeatherReading reading, ({double latitude, double longitude}) location) async {
    await _sharedPreferences.setString(
      _cachedReadingKey,
      jsonEncode({
        "version": _cachedReadingVersion,
        "latitude": location.latitude,
        "longitude": location.longitude,
        "temperature": reading.temperatureCelsius,
        "weather_code": reading.wmoCode,
        "observed_at": reading.observedAt.millisecondsSinceEpoch,
      }),
    );
  }

  /// The cached reading, or `null` when there is none, it cannot be read, or
  /// it belongs to a different city than the one currently configured.
  ///
  /// Runs on the launcher's startup path, so it never throws: the stored value
  /// is untrusted input (`getString` is a hard cast, and the backup feature
  /// imports a user-supplied JSON straight into the preference store), and an
  /// unreadable cache is simply no cache.
  WeatherReading? _loadCachedReading() {
    final location = _configuredLocation();
    if (location == null) {
      return null;
    }
    try {
      final raw = _sharedPreferences.getString(_cachedReadingKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      if (decoded["version"] != _cachedReadingVersion) {
        return null;
      }
      final latitude = decoded["latitude"];
      final longitude = decoded["longitude"];
      final temperature = decoded["temperature"];
      final code = decoded["weather_code"];
      final observedAt = decoded["observed_at"];
      if (latitude is! num || longitude is! num || temperature is! num || code is! num || observedAt is! int) {
        return null;
      }
      if ((latitude - location.latitude).abs() > _coordinateEpsilon ||
          (longitude - location.longitude).abs() > _coordinateEpsilon) {
        // The user picked another city since this was written.
        return null;
      }
      return WeatherReading(
        temperatureCelsius: temperature.toDouble(),
        wmoCode: code.toInt(),
        observedAt: DateTime.fromMillisecondsSinceEpoch(observedAt),
      );
    } catch (e) {
      debugPrint("WeatherService: could not read the cached reading, ignoring it ($e)");
      return null;
    }
  }

  /// Cancels the periodic refresh.
  ///
  /// Not optional: `LauncherRoot` throws the whole provider tree away and
  /// builds a new one after a backup is restored, so a timer left running here
  /// would leak one more wake-up every 15 minutes per restore, each of them
  /// notifying a dead `ChangeNotifier`.
  @override
  void dispose() {
    _disposed = true;
    _settingsService.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _timer = null;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }
}
