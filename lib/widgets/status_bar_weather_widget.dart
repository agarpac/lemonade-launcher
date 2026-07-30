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
import 'package:flauncher/providers/weather_service.dart';
import 'package:flauncher/widgets/status_bar_glass_card.dart';
import 'package:flauncher/widgets/weather_condition_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// PRD section 3.A: the current temperature and a condition glyph, on the
/// right of the status bar, in a frosted-glass card matching the dock's.
///
/// Three properties this widget is built around, all of them deliberate:
///
///  * **It occupies nothing when there is nothing to say.** Weather switched
///    off, no city picked, no reading yet, a dead network: every one of them
///    renders a zero-size box. No placeholder, no spinner, no error text — the
///    PRD is explicit that the block simply disappears rather than reporting a
///    weather server's problems on the device's only home screen.
///  * **It is not focusable.** Nothing here creates a [Focus], so the card
///    never enters the D-pad traversal order and cannot come between the
///    settings button and the rest of the bar.
///  * **It does not depend on the bar's geometry.** It is an ordinary child of
///    the app bar's `actions`, so a collapsed (auto-hidden) bar hides it along
///    with everything else, and the programmatic route into Settings keeps
///    working at zero height.
class StatusBarWeatherWidget extends StatelessWidget {
  const StatusBarWeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // `hasWeather` already folds in "switched off" and "no city set", so a
    // null here is the single answer to every reason there is nothing to draw.
    final reading = context.select<WeatherService, WeatherReading?>(
      (service) => service.hasWeather ? service.reading : null,
    );
    if (reading == null) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context)!;
    // Whole degrees, in the app's locale: `NumberFormat` is what turns -3 into
    // "−3" where the locale wants a real minus sign, and picks the right digit
    // shapes. The degree symbol itself comes from the ARB so a translation can
    // move or drop it.
    final degrees = NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
        .format(reading.temperatureCelsius.round());

    // Same text treatment as the date and the clock a few pixels to the right.
    const textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      color: Colors.white,
      shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
    );

    return StatusBarGlassCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            weatherConditionIcon(reading.condition),
            size: 20,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
          ),
          const SizedBox(width: 8),
          Text(localizations.weatherTemperature(degrees), style: textStyle),
        ],
      ),
    );
  }
}
