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

/// The weather data types, deliberately free of any Flutter import — like
/// every other file in `lib/models/`.
///
/// In particular there is **no `IconData` here**. Open-Meteo reports a WMO
/// code; turning that into a glyph is a presentation decision that belongs to
/// the status-bar widget, next to the rest of the launcher's iconography.
/// Naming a Material icon in this file would drag `package:flutter/widgets.dart`
/// into the data layer, make the mapping untestable without a Flutter binding,
/// and freeze one visual answer for what may later be a custom icon set (PRD
/// section 6 explicitly says "iconos propios"). [WeatherCondition] is the
/// stable contract; the UI maps it to whatever it draws.

/// The small set of conditions the launcher distinguishes, condensed from the
/// WMO weather-code table Open-Meteo reports (see [weatherConditionFromWmoCode]).
///
/// Deliberately coarse: this feeds a single glyph in a television status bar,
/// where "light, moderate or dense drizzle" is a distinction nobody can see
/// from the sofa.
enum WeatherCondition {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  freezingDrizzle,
  rain,
  freezingRain,
  snow,
  snowGrains,
  rainShowers,
  snowShowers,
  thunderstorm,
  thunderstormWithHail,

  /// A code outside the documented WMO table, or one this launcher does not
  /// map. Never an error: the widget still shows the temperature.
  unknown,
}

/// Maps a WMO weather interpretation code — the `weather_code` field of
/// Open-Meteo's `current` block — onto a [WeatherCondition].
///
/// Covers the full documented table:
/// 0 clear; 1-3 mainly clear/partly cloudy/overcast; 45,48 fog;
/// 51,53,55 drizzle; 56,57 freezing drizzle; 61,63,65 rain;
/// 66,67 freezing rain; 71,73,75 snowfall; 77 snow grains;
/// 80,81,82 rain showers; 85,86 snow showers; 95 thunderstorm;
/// 96,99 thunderstorm with hail.
///
/// Anything else — a code from a future revision of the table, a negative
/// number, a value the provider invented — degrades to
/// [WeatherCondition.unknown]. It never throws: this runs on the device's only
/// home screen.
WeatherCondition weatherConditionFromWmoCode(int code) {
  switch (code) {
    case 0:
      return WeatherCondition.clear;
    case 1:
      return WeatherCondition.mainlyClear;
    case 2:
      return WeatherCondition.partlyCloudy;
    case 3:
      return WeatherCondition.overcast;
    case 45:
    case 48:
      return WeatherCondition.fog;
    case 51:
    case 53:
    case 55:
      return WeatherCondition.drizzle;
    case 56:
    case 57:
      return WeatherCondition.freezingDrizzle;
    case 61:
    case 63:
    case 65:
      return WeatherCondition.rain;
    case 66:
    case 67:
      return WeatherCondition.freezingRain;
    case 71:
    case 73:
    case 75:
      return WeatherCondition.snow;
    case 77:
      return WeatherCondition.snowGrains;
    case 80:
    case 81:
    case 82:
      return WeatherCondition.rainShowers;
    case 85:
    case 86:
      return WeatherCondition.snowShowers;
    case 95:
      return WeatherCondition.thunderstorm;
    case 96:
    case 99:
      return WeatherCondition.thunderstormWithHail;
    default:
      return WeatherCondition.unknown;
  }
}

/// One observation: the temperature in degrees Celsius, the raw WMO code, and
/// when the launcher took the reading.
///
/// The raw [wmoCode] is what gets stored and compared, not the derived
/// [condition]: an enum name persisted in `shared_preferences` would break the
/// moment [WeatherCondition] gains or loses a value, while the WMO table is a
/// published standard that does not renumber itself. [condition] is computed
/// on demand from it.
class WeatherReading {
  /// Temperature in degrees Celsius. Open-Meteo's default unit for
  /// `temperature_2m`, so no conversion happens anywhere.
  final double temperatureCelsius;

  /// The provider's raw WMO weather interpretation code.
  final int wmoCode;

  /// When this launcher fetched the reading, on the *device* clock.
  ///
  /// Not Open-Meteo's `current.time`: with `timezone=auto` that field is local
  /// to the requested coordinates and carries no offset, so it cannot be
  /// compared against the device clock to tell how stale a cached reading is.
  final DateTime observedAt;

  const WeatherReading({
    required this.temperatureCelsius,
    required this.wmoCode,
    required this.observedAt,
  });

  WeatherCondition get condition => weatherConditionFromWmoCode(wmoCode);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherReading &&
          other.temperatureCelsius == temperatureCelsius &&
          other.wmoCode == wmoCode &&
          other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(temperatureCelsius, wmoCode, observedAt);

  @override
  String toString() => "WeatherReading(${temperatureCelsius}C, wmo $wmoCode, at $observedAt)";
}

/// One hit from Open-Meteo's geocoding endpoint: what the (later) settings page
/// lists so the user can pick a city with the D-pad.
///
/// [admin1] is the first-level administrative division the provider reports
/// (a region, a state, a province). Both it and [country] are optional: the
/// endpoint omits them for some places, and a missing region must not stop the
/// city from being selectable.
class WeatherCity {
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? admin1;

  const WeatherCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
  });

  /// What to show in a list and to persist as the location's display label,
  /// e.g. "Sevilla, Andalucía, España". Skips the parts the provider did not
  /// report rather than leaving dangling separators.
  String get label => [
        name,
        if (admin1 != null && admin1!.isNotEmpty) admin1,
        if (country != null && country!.isNotEmpty) country,
      ].join(", ");

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherCity &&
          other.name == name &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.country == country &&
          other.admin1 == admin1;

  @override
  int get hashCode => Object.hash(name, latitude, longitude, country, admin1);

  @override
  String toString() => "WeatherCity($label, $latitude, $longitude)";
}
