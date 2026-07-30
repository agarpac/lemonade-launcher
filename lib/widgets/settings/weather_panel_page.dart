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
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What the results area of the page is showing at any moment. There is always
/// exactly one of these on screen: the user must never be left looking at a
/// blank space wondering whether the launcher did anything.
enum _SearchStatus {
  /// Nothing has been searched yet, or the user submitted an empty field.
  prompt,
  searching,
  results,
  noMatch,
  failed,
}

/// PRD section 5: the weather page — a visibility switch and a city search.
///
/// Reached from the status-bar page, because the weather block *is* a
/// status-bar element; it sits next to the date, the clock, the Wi-Fi usage
/// and the network indicator, which are all configured there.
class WeatherPanelPage extends StatefulWidget {
  static const String routeName = "weather_panel";

  const WeatherPanelPage({Key? key}) : super(key: key);

  @override
  State<WeatherPanelPage> createState() => _WeatherPanelPageState();
}

class _WeatherPanelPageState extends State<WeatherPanelPage> {
  final TextEditingController _queryController = TextEditingController();

  /// Focus target for the first hit, so submitting the field lands the remote
  /// on something it can press. See [FocusableSettingsTile.focusNode] for why
  /// `autofocus` cannot do this job here.
  final FocusNode _firstResultFocusNode = FocusNode();

  /// Focus target for the switch. Clearing the city removes the tile that had
  /// the focus, and a settings page with nothing focused is a dead end for a
  /// remote.
  final FocusNode _visibilitySwitchFocusNode = FocusNode();

  _SearchStatus _status = _SearchStatus.prompt;
  List<WeatherCity> _results = const [];

  /// Discriminates the reply the user is still waiting for from the reply to a
  /// search they have already replaced. Without it a slow first request can
  /// land after a fast second one and overwrite its results.
  int _searchGeneration = 0;

  @override
  void dispose() {
    _queryController.dispose();
    _firstResultFocusNode.dispose();
    _visibilitySwitchFocusNode.dispose();
    super.dispose();
  }

  /// Runs one search. Only ever called from the field's submit handler: a
  /// request per keystroke would hammer the geocoding endpoint for every
  /// letter of a name typed one D-pad press at a time.
  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _status = _SearchStatus.prompt;
        _results = const [];
      });
      return;
    }

    // Both of these have to be read before the first `await`: the element may
    // be gone by the time the reply arrives.
    final weatherService = context.read<WeatherService>();
    final language = Localizations.localeOf(context).languageCode;

    final generation = ++_searchGeneration;
    setState(() {
      _status = _SearchStatus.searching;
      _results = const [];
    });

    WeatherCitySearchResult result;
    try {
      result = await weatherService.searchCities(query, language: language);
    } catch (e) {
      // `WeatherService.searchCities` contracts never to throw, and reports a
      // failed request through its result instead. This stays as a backstop:
      // the alternative to a localized "the search failed" message is a red
      // error screen on the device's only home screen.
      debugPrint("WeatherPanelPage: the city search threw ($e)");
      result = const WeatherCitySearchResult.failed();
    }

    if (!mounted || generation != _searchGeneration) {
      return;
    }
    final cities = result.cities;
    setState(() {
      _results = cities;
      // Three different answers, three different messages. "The provider has
      // never heard of that place" and "the request never got through" are not
      // the same thing, and telling a user with no network that their own city
      // does not exist just makes them type it again.
      _status = result.failed
          ? _SearchStatus.failed
          : (cities.isEmpty ? _SearchStatus.noMatch : _SearchStatus.results);
    });
    if (cities.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _firstResultFocusNode.requestFocus();
        }
      });
    }
  }

  /// Stores the picked city's coordinates and label. `SettingsService`
  /// notifies, `WeatherService` notices the new location and fetches it, and
  /// the status bar catches up on its own — no restart, and nothing here has
  /// to know that.
  ///
  /// The result list deliberately stays on screen: it is what the remote is
  /// focused on, and tearing it down under the user's cursor would throw the
  /// focus away.
  Future<void> _pickCity(WeatherCity city) async {
    await context.read<SettingsService>().setWeatherLocation(
          latitude: city.latitude,
          longitude: city.longitude,
          label: city.label,
        );
  }

  Future<void> _clearCity() async {
    // Requested before the await so the focus never sits on a tile that the
    // rebuild is about to remove.
    _visibilitySwitchFocusNode.requestFocus();
    await context.read<SettingsService>().clearWeatherLocation();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settingsService = context.watch<SettingsService>();
    final locationLabel = settingsService.weatherLocationLabel;

    return Column(
      children: [
        Text(localizations.weather, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          // A `Column` inside a scroll view rather than a `ListView`: the
          // result tiles have to exist for the focus request in [_search] to
          // reach the first one, and a lazy list would only have built the
          // handful of children that happen to be on screen.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoundedSwitchListTile(
                  autofocus: true,
                  focusNode: _visibilitySwitchFocusNode,
                  value: settingsService.showWeather,
                  onChanged: (value) => settingsService.setShowWeather(value),
                  title: Text(localizations.weatherShowInStatusBar, style: Theme.of(context).textTheme.bodyMedium),
                  secondary: const Icon(Icons.wb_sunny_outlined),
                ),
                const Divider(),
                _currentCity(context, localizations, locationLabel),
                if (locationLabel != null)
                  FocusableSettingsTile(
                    leading: const Icon(Icons.location_off_outlined),
                    title: Text(localizations.weatherClearCity, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _clearCity,
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: TextField(
                    controller: _queryController,
                    // Typing a city name with a remote is slow and painful, so
                    // the request waits for an explicit submit. Never one per
                    // keystroke: there is no `onChanged` here on purpose.
                    onSubmitted: _search,
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: localizations.weatherSearchCity,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                ..._searchArea(context, localizations),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _currentCity(BuildContext context, AppLocalizations localizations, String? locationLabel) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                locationLabel ?? localizations.weatherNoCity,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );

  List<Widget> _searchArea(BuildContext context, AppLocalizations localizations) {
    switch (_status) {
      case _SearchStatus.prompt:
        return [_message(context, localizations.weatherSearchPrompt)];
      case _SearchStatus.searching:
        // A text line, not a spinner: an indeterminate progress animation never
        // stops scheduling frames, which would hang every `pumpAndSettle` that
        // ever renders this page.
        return [_message(context, localizations.weatherSearching)];
      case _SearchStatus.noMatch:
        return [_message(context, localizations.weatherSearchNoResults)];
      case _SearchStatus.failed:
        return [_message(context, localizations.weatherSearchFailed)];
      case _SearchStatus.results:
        return [
          for (var i = 0; i < _results.length; i++)
            FocusableSettingsTile(
              key: ValueKey("weather_city_${_results[i].latitude}_${_results[i].longitude}"),
              focusNode: i == 0 ? _firstResultFocusNode : null,
              leading: const Icon(Icons.location_city_outlined),
              title: Text(_results[i].label, style: Theme.of(context).textTheme.bodyMedium),
              onPressed: () => _pickCity(_results[i]),
            ),
        ];
    }
  }

  Widget _message(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
