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

import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_page.dart';
import 'package:flauncher/widgets/settings/content_shortcut_panel_page.dart';
import 'package:flauncher/widgets/settings/content_shortcuts_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flauncher/widgets/settings/weather_panel_page.dart';
import 'package:flauncher/widgets/settings/wifi_usage_period_page.dart';
import 'package:flauncher/widgets/settings/back_button_action_page.dart';
import 'package:flauncher/widgets/settings/date_time_format_page.dart';
import 'package:flauncher/widgets/settings/app_details_page.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flauncher/widgets/settings/brightness_settings_page.dart';
import 'package:flauncher/widgets/settings/appearance_panel_page.dart';
import 'package:flauncher/widgets/settings/misc_panel_page.dart';
import 'package:flauncher/widgets/settings/interface_settings_page.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/screensaver_clock_style_page.dart';
import 'package:flauncher/widgets/settings/scenes_panel_page.dart';
import 'package:flauncher/widgets/settings/scene_accent_color_page.dart';
import 'package:flauncher/widgets/settings/scene_editor_page.dart';
import 'package:flauncher/widgets/settings/scene_gradient_page.dart';
import 'package:flauncher/widgets/settings/scene_image_page.dart';
import 'package:flauncher/widgets/settings/scene_override_page.dart';
import 'package:flauncher/models/app.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final String? initialRoute;

  const SettingsPanel({Key? key, this.initialRoute}) : super(key: key);

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !await _navigatorKey.currentState!.maybePop(),
      child: Scaffold(
        backgroundColor: Colors.black54, // Dim the background
        body: Stack(
          children: [
            // Tap outside to close
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
            // The side panel
            SidePanelDialog(
              width: 350,
              isRightSide: false,
              child: Navigator(
                key: _navigatorKey,
                initialRoute: widget.initialRoute ?? SettingsPanelPage.routeName,
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case SettingsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => SettingsPanelPage());
                    case GeneralSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => GeneralSettingsPage());
                    case InterfaceSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => InterfaceSettingsPage());
                    case WallpaperPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => WallpaperPanelPage());
                    case StatusBarPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => StatusBarPanelPage());
                    case WeatherPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => const WeatherPanelPage());
                    case GradientPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => GradientPanelPage());
                    case ApplicationsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => ApplicationsPanelPage());
                    case LauncherSectionsPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => LauncherSectionsPanelPage());
                    case LauncherSectionPanelPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => LauncherSectionPanelPage(sectionIndex: settings.arguments as int?));
                    case ContentShortcutsPanelPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => ContentShortcutsPanelPage(sectionId: settings.arguments as int));
                    case ContentShortcutPanelPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => ContentShortcutPanelPage(
                              arguments: settings.arguments as ContentShortcutPanelPageArguments));
                    case WifiUsagePeriodPage.routeName:
                      return _FastPageRoute(builder: (_) => WifiUsagePeriodPage());
                    case BackButtonActionPage.routeName:
                      return _FastPageRoute(builder: (_) => BackButtonActionPage());
                    case DateTimeFormatPage.routeName:
                      return _FastPageRoute(builder: (_) => DateTimeFormatPage());
                    case AppearancePanelPage.routeName:
                      return _FastPageRoute(builder: (_) => const AppearancePanelPage());
                    case MiscPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => MiscPanelPage());
                    case ScreensaverClockStylePage.routeName:
                      return _FastPageRoute(builder: (_) => const ScreensaverClockStylePage());
                    case AccentColorPage.routeName:
                      return _FastPageRoute(builder: (_) => AccentColorPage());
                    case BrightnessSettingsPage.routeName:
                      return _FastPageRoute(builder: (_) => BrightnessSettingsPage());
                    case AppDetailsPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => AppDetailsPage(application: settings.arguments as App));
                    case BackupPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => const BackupPanelPage());
                    case BackupRestorePage.routeName:
                      return _FastPageRoute(builder: (_) => BackupRestorePage());
                    case ScenesPanelPage.routeName:
                      return _FastPageRoute(builder: (_) => ScenesPanelPage());
                    case SceneEditorPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => SceneEditorPage(sceneKey: settings.arguments as String));
                    case SceneOverridePage.routeName:
                      final args = settings.arguments as (String, SceneOverrideField);
                      return _FastPageRoute(
                          builder: (_) => SceneOverridePage(sceneKey: args.$1, field: args.$2));
                    case SceneGradientPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => SceneGradientPage(sceneKey: settings.arguments as String));
                    case SceneAccentColorPage.routeName:
                      return _FastPageRoute(
                          builder: (_) => SceneAccentColorPage(sceneKey: settings.arguments as String));
                    case SceneImagePage.routeName:
                      return _FastPageRoute(
                          builder: (_) => SceneImagePage(sceneKey: settings.arguments as String));
                    default:
                      throw ArgumentError.value(settings.name, "settings.name", "Route not supported.");
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A faster page route with a 150ms slide transition instead of
/// the default 300ms Material transition.
class _FastPageRoute<T> extends MaterialPageRoute<T> {
  _FastPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);
}
