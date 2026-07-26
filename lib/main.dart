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

import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/backup_service.dart';
import 'package:flauncher/providers/configuration_reloader.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/brightness_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'flauncher_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();

  final sharedPreferences = await SharedPreferences.getInstance();
  final fLauncherChannel = FLauncherChannel();
  final fLauncherDatabase = FLauncherDatabase(connect());

  runApp(LauncherRoot(
    sharedPreferences: sharedPreferences,
    fLauncherChannel: fLauncherChannel,
    fLauncherDatabase: fLauncherDatabase,
  ));
}

/// Root of the application: owns the launcher's provider tree and the one
/// thing that can throw it away and build it again.
///
/// Stateful only to hold [_generation]. Every service below lives in a
/// [MultiProvider] keyed on that counter, so bumping it makes Flutter discard
/// the whole subtree — providers included — and inflate a new one, re-creating
/// every service from the store as it is at that moment. That is exactly what a
/// restored backup needs: `BackupService.importBackup` replaces the database
/// and the preferences underneath services that read them once, at
/// construction time, and this launcher is the device's only home screen, so
/// restarting the process is off the table.
class LauncherRoot extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  final FLauncherChannel fLauncherChannel;
  final FLauncherDatabase fLauncherDatabase;

  const LauncherRoot({
    super.key,
    required this.sharedPreferences,
    required this.fLauncherChannel,
    required this.fLauncherDatabase,
  });

  @override
  State<LauncherRoot> createState() => _LauncherRootState();
}

class _LauncherRootState extends State<LauncherRoot> {
  /// Bumped by [ConfigurationReloader.reload]; keys the [MultiProvider] below.
  int _generation = 0;

  late final ConfigurationReloader _configurationReloader = ConfigurationReloader(_reloadConfiguration);

  void _reloadConfiguration() {
    if (!mounted) {
      return;
    }
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) => Provider<ConfigurationReloader>.value(
        // Deliberately *above* the keyed subtree: the reloader must outlive the
        // very rebuild it triggers. Placed inside the MultiProvider it would be
        // destroyed together with the page that just called it — and the
        // instance a page reads would be a different one on every generation.
        value: _configurationReloader,
        child: MultiProvider(
          key: ValueKey(_generation),
          providers: [
            // ScenesService must be created before SettingsService: the latter
            // composes the active scene's presentation overrides into its own
            // getters (see SettingsService's constructor doc), the same way
            // WallpaperService below depends on both.
            ChangeNotifierProvider(
                create: (_) => ScenesService(widget.sharedPreferences),
                lazy: false),
            ChangeNotifierProvider(
                create: (context) {
                  ScenesService scenesService = Provider.of(context, listen: false);
                  return SettingsService(widget.sharedPreferences, scenesService);
                },
                lazy: false),
            ChangeNotifierProvider(create: (_) => AppsService(widget.fLauncherChannel, widget.fLauncherDatabase)),
            ChangeNotifierProvider(create: (_) => LauncherState()),
            ChangeNotifierProvider(create: (_) => NetworkService(widget.fLauncherChannel)),
            ChangeNotifierProvider(
                create: (context) {
                  SettingsService settingsService = Provider.of(context, listen: false);
                  ScenesService scenesService = Provider.of(context, listen: false);
                  return WallpaperService(settingsService, scenesService);
                }
            ),
            ChangeNotifierProvider(
                create: (_) => BrightnessService(widget.sharedPreferences),
                lazy: false
            ),
            ChangeNotifierProvider(
                create: (_) => WatchNextService(widget.fLauncherChannel),
                lazy: false
            ),
            // After SettingsService, like WallpaperService above: it reads the
            // weather toggle and the picked city from it, and listens to it.
            ChangeNotifierProvider(
                create: (context) {
                  SettingsService settingsService = Provider.of(context, listen: false);
                  return WeatherService(settingsService, widget.sharedPreferences);
                }
            ),
            // Plain Provider: BackupService is not a ChangeNotifier — it owns
            // no in-memory state to listen to.
            Provider(
                create: (_) =>
                    BackupService(widget.fLauncherDatabase, widget.sharedPreferences, widget.fLauncherChannel)),
          ],
          child: FLauncherApp(),
        ),
      );
}
