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

import 'package:flauncher/models/weather.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("weatherConditionFromWmoCode", () {
    /// The whole documented WMO table, exactly as Open-Meteo publishes it.
    const documented = <int, WeatherCondition>{
      0: WeatherCondition.clear,
      1: WeatherCondition.mainlyClear,
      2: WeatherCondition.partlyCloudy,
      3: WeatherCondition.overcast,
      45: WeatherCondition.fog,
      48: WeatherCondition.fog,
      51: WeatherCondition.drizzle,
      53: WeatherCondition.drizzle,
      55: WeatherCondition.drizzle,
      56: WeatherCondition.freezingDrizzle,
      57: WeatherCondition.freezingDrizzle,
      61: WeatherCondition.rain,
      63: WeatherCondition.rain,
      65: WeatherCondition.rain,
      66: WeatherCondition.freezingRain,
      67: WeatherCondition.freezingRain,
      71: WeatherCondition.snow,
      73: WeatherCondition.snow,
      75: WeatherCondition.snow,
      77: WeatherCondition.snowGrains,
      80: WeatherCondition.rainShowers,
      81: WeatherCondition.rainShowers,
      82: WeatherCondition.rainShowers,
      85: WeatherCondition.snowShowers,
      86: WeatherCondition.snowShowers,
      95: WeatherCondition.thunderstorm,
      96: WeatherCondition.thunderstormWithHail,
      99: WeatherCondition.thunderstormWithHail,
    };

    test("maps every documented WMO code", () {
      documented.forEach((code, expected) {
        expect(weatherConditionFromWmoCode(code), expected, reason: "WMO code $code");
      });
    });

    test("never reports unknown for a documented code", () {
      for (final code in documented.keys) {
        expect(weatherConditionFromWmoCode(code), isNot(WeatherCondition.unknown));
      }
    });

    test("degrades to unknown for codes outside the table, without throwing", () {
      for (final code in [-1, 4, 44, 50, 68, 78, 83, 87, 97, 100, 1000, 0x7fffffff]) {
        expect(weatherConditionFromWmoCode(code), WeatherCondition.unknown, reason: "WMO code $code");
      }
    });
  });

  group("WeatherReading", () {
    test("derives its condition from the raw WMO code", () {
      final reading = WeatherReading(
        temperatureCelsius: 27.9,
        wmoCode: 3,
        observedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(reading.condition, WeatherCondition.overcast);
      expect(reading.temperatureCelsius, 27.9);
    });

    test("an unmapped code still yields a usable reading", () {
      final reading = WeatherReading(
        temperatureCelsius: -4.5,
        wmoCode: 12345,
        observedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

      expect(reading.condition, WeatherCondition.unknown);
      expect(reading.temperatureCelsius, -4.5);
    });

    test("compares by value", () {
      final at = DateTime.fromMillisecondsSinceEpoch(1000);

      expect(
        WeatherReading(temperatureCelsius: 1, wmoCode: 0, observedAt: at),
        WeatherReading(temperatureCelsius: 1, wmoCode: 0, observedAt: at),
      );
      expect(
        WeatherReading(temperatureCelsius: 1, wmoCode: 0, observedAt: at),
        isNot(WeatherReading(temperatureCelsius: 2, wmoCode: 0, observedAt: at)),
      );
    });
  });

  group("WeatherCity", () {
    test("labels a city with its region and country", () {
      const city = WeatherCity(
        name: "Sevilla",
        latitude: 37.38283,
        longitude: -5.97317,
        country: "España",
        admin1: "Andalucía",
      );

      expect(city.label, "Sevilla, Andalucía, España");
    });

    test("skips the parts the provider did not report", () {
      const withoutRegion = WeatherCity(name: "Sevilla", latitude: 0, longitude: 0, country: "España");
      const bare = WeatherCity(name: "Sevilla", latitude: 0, longitude: 0);

      expect(withoutRegion.label, "Sevilla, España");
      expect(bare.label, "Sevilla");
    });
  });
}
