/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:provider/provider.dart';
import 'focusable_settings_tile.dart';
import 'backup_panel_page.dart';
import 'brightness_settings_page.dart';
import 'date_time_format_page.dart';
import 'back_button_action_page.dart';
import 'wifi_usage_period_page.dart';
import 'screensaver_clock_style_page.dart';

class GeneralSettingsPage extends StatelessWidget {
  static const String routeName = "general_settings_panel";

  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
      children: [
        Text(localizations.system, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _SectionHeader(localizations.settingsSectionBrightness),
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.brightness_6),
                  title: Text(localizations.brightnessScheduler, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(BrightnessSettingsPage.routeName),
                ),
                _SectionHeader(localizations.settingsSectionScreensaver),
                FocusableSettingsTile(
                  leading: const Icon(Icons.screenshot_monitor),
                  title: Text(localizations.screensaverSettings, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => _openScreensaverSettings(),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.watch_later_outlined),
                  title: Text(localizations.screensaverClockStyle, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(ScreensaverClockStylePage.routeName),
                ),
                _SectionHeader(localizations.settingsSectionDateTime),
                FocusableSettingsTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(localizations.dateAndTimeFormat, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(DateTimeFormatPage.routeName),
                ),
                _SectionHeader(localizations.settingsSectionBehavior),
                FocusableSettingsTile(
                  leading: const Icon(Icons.arrow_back),
                  title: Text(localizations.backButtonAction, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(BackButtonActionPage.routeName),
                ),
                RoundedSwitchListTile(
                  value: settingsService.appKeyClickEnabled,
                  onChanged: (value) => settingsService.setAppKeyClickEnabled(value),
                  title: Text(localizations.appKeyClick, style: Theme.of(context).textTheme.bodyMedium),
                  secondary: const Icon(Icons.notifications_active),
                ),
                _SectionHeader(localizations.settingsSectionNetwork),
                FocusableSettingsTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(localizations.wifiUsagePeriodTitle, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(WifiUsagePeriodPage.routeName),
                ),
                _SectionHeader(localizations.settingsSectionData),
                FocusableSettingsTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(localizations.backupAndRestore, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: () => Navigator.of(context).pushNamed(BackupPanelPage.routeName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openScreensaverSettings() async {
    const platform = MethodChannel('me.efesser.flauncher/method');
    platform.invokeMethod('openScreensaverSettings');
  }
}

/// A plain, non-focusable subheader: this page is a flat scrollable list,
/// not an accordion, so a subheader is just a label, never a target.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
