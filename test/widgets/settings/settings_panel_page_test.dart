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
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/interface_settings_page.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

// SettingsPanelPage's top-level menu was consolidated: "Categories" and "Wallpaper" moved one
// level deeper into InterfaceSettingsPage (behind a new "Interface" entry), "24-hour time format"
// moved into DateTimeFormatPage behind GeneralSettingsPage's "System" entry, and the "Crash
// Reporting"/"Analytics Reporting" toggles were removed outright (no telemetry setting exists
// anywhere in the app anymore). The top level now is: Applications, Interface, System, [divider],
// System Settings, [Update check, only if kSelfUpdaterAvailable which defaults to false], About.
// The about dialog class was also renamed from FLauncherAboutDialog to LTvLauncherAboutDialog.
void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("'Applications' opens ApplicationsPanelPage", (tester) async {
    final settingsService = MockSettingsService();
    final appsService = MockAppsService();
    when(settingsService.appHighlightAnimationEnabled).thenReturn(true);

    await _pumpWidgetWithProviders(tester, settingsService, appsService);

    // "Applications" is the first tile and is autofocused.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(Key("ApplicationsPanelPage")), findsOneWidget);
  });

  testWidgets("'Interface' opens InterfaceSettingsPage", (tester) async {
    final settingsService = MockSettingsService();
    final appsService = MockAppsService();
    when(settingsService.appHighlightAnimationEnabled).thenReturn(true);

    await _pumpWidgetWithProviders(tester, settingsService, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(Key("InterfaceSettingsPage")), findsOneWidget);
  });

  testWidgets("'System' opens GeneralSettingsPage", (tester) async {
    final settingsService = MockSettingsService();
    final appsService = MockAppsService();
    when(settingsService.appHighlightAnimationEnabled).thenReturn(true);

    await _pumpWidgetWithProviders(tester, settingsService, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(Key("GeneralSettingsPage")), findsOneWidget);
  });

  testWidgets("'System Settings' calls AppsService.openSettings", (tester) async {
    final settingsService = MockSettingsService();
    final appsService = MockAppsService();
    when(settingsService.appHighlightAnimationEnabled).thenReturn(true);

    await _pumpWidgetWithProviders(tester, settingsService, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    verify(appsService.openSettings());
  });

  testWidgets("'About FLauncher' opens the about dialog", (tester) async {
    final settingsService = MockSettingsService();
    final appsService = MockAppsService();
    when(settingsService.appHighlightAnimationEnabled).thenReturn(true);
    PackageInfoPlatform.instance = _MockPackageInfoPlatform();

    await _pumpWidgetWithProviders(tester, settingsService, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(LTvLauncherAboutDialog), findsOneWidget);
  });
}

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  SettingsService settingsService,
  AppsService appsService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          InterfaceSettingsPage.routeName: (_) => Container(key: Key("InterfaceSettingsPage")),
          GeneralSettingsPage.routeName: (_) => Container(key: Key("GeneralSettingsPage")),
          ApplicationsPanelPage.routeName: (_) => Container(key: Key("ApplicationsPanelPage")),
        },
        home: Material(child: SettingsPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MockPackageInfoPlatform with MockPlatformInterfaceMixin implements PackageInfoPlatform {
  @override
  Future<PackageInfoData> getAll({String? baseUrl}) async => PackageInfoData(
        appName: "FLauncher",
        packageName: "me.efesser.flauncher",
        version: "1.0.0",
        buildNumber: "1",
        buildSignature: "",
      );
}
