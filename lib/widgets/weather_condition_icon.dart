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
import 'package:flutter/material.dart';

/// The presentation half of [WeatherCondition]: the glyph the status bar draws
/// for each condition.
///
/// This lives in the widget layer on purpose. `lib/models/weather.dart`
/// imports no Flutter at all, so it cannot name an [IconData]; keeping the
/// mapping here also means PRD section 6's eventual custom icon set only has
/// to replace this one function.
///
/// Material icons only — no asset, no font, no new dependency.
IconData weatherConditionIcon(WeatherCondition condition) {
  switch (condition) {
    case WeatherCondition.clear:
      return Icons.wb_sunny_outlined;
    case WeatherCondition.mainlyClear:
      return Icons.wb_twilight_outlined;
    case WeatherCondition.partlyCloudy:
      return Icons.wb_cloudy_outlined;
    case WeatherCondition.overcast:
      return Icons.cloud_outlined;
    case WeatherCondition.fog:
      return Icons.foggy;
    case WeatherCondition.drizzle:
      return Icons.grain_outlined;
    case WeatherCondition.freezingDrizzle:
      return Icons.severe_cold;
    case WeatherCondition.rain:
      return Icons.water_drop_outlined;
    case WeatherCondition.freezingRain:
      return Icons.severe_cold;
    case WeatherCondition.snow:
      return Icons.ac_unit;
    case WeatherCondition.snowGrains:
      return Icons.ac_unit;
    case WeatherCondition.rainShowers:
      return Icons.umbrella_outlined;
    case WeatherCondition.snowShowers:
      return Icons.cloudy_snowing;
    case WeatherCondition.thunderstorm:
      return Icons.thunderstorm_outlined;
    case WeatherCondition.thunderstormWithHail:
      return Icons.thunderstorm_outlined;
    // A code this launcher does not know about still gets a glyph: the
    // temperature next to it is the useful half, and a hole where the icon
    // should be would look like a rendering bug.
    case WeatherCondition.unknown:
      return Icons.thermostat_outlined;
  }
}
