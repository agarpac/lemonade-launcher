/*
 * FLauncher
 * Copyright (C) 2026  Lemonade Launcher contributors
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
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/misc_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

const _handleSettingLabel = "Show the channel handle instead of the shortcut name";

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("The handle switch reflects the default: on, i.e. the handle", (tester) async {
    final settingsService = _mkSettingsService();

    await _pumpPage(tester, settingsService);

    final Switch handleSwitch = tester.widget<Switch>(
      find.descendant(of: _handleTile, matching: find.byType(Switch)),
    );
    expect(handleSwitch.value, isTrue);
  });

  testWidgets("Flipping the handle switch off writes the preference", (tester) async {
    final settingsService = _mkSettingsService(showContentShortcutHandle: true);

    await _pumpPage(tester, settingsService);

    await tester.tap(find.text(_handleSettingLabel));
    await tester.pumpAndSettle();

    verify(settingsService.setShowContentShortcutHandle(false)).called(1);
  });

  testWidgets("Flipping the handle switch back on writes the preference", (tester) async {
    final settingsService = _mkSettingsService(showContentShortcutHandle: false);

    await _pumpPage(tester, settingsService);

    final Switch handleSwitch = tester.widget<Switch>(
      find.descendant(of: _handleTile, matching: find.byType(Switch)),
    );
    expect(handleSwitch.value, isFalse);

    await tester.tap(find.text(_handleSettingLabel));
    await tester.pumpAndSettle();

    verify(settingsService.setShowContentShortcutHandle(true)).called(1);
  });
}

/// The finder for the handle switch's own tile, so its [Switch] is not
/// confused with any other switch on the page.
Finder get _handleTile => find.ancestor(
      of: find.text(_handleSettingLabel),
      matching: find.byType(FocusableSettingsTile),
    );

MockSettingsService _mkSettingsService({
  bool showContentShortcutHandle = true,
}) {
  final settingsService = MockSettingsService();
  when(settingsService.appHighlightAnimationEnabled).thenReturn(false);
  when(settingsService.appKeyClickEnabled).thenReturn(true);
  when(settingsService.userShowCategoryTitles).thenReturn(false);
  when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
  when(settingsService.showFocusBorders).thenReturn(true);
  when(settingsService.userShowWatchNextSection).thenReturn(false);
  when(settingsService.showContentShortcutHandle).thenReturn(showContentShortcutHandle);
  when(settingsService.setAppHighlightAnimationEnabled(any)).thenAnswer((_) async {});
  when(settingsService.setAppKeyClickEnabled(any)).thenAnswer((_) async {});
  when(settingsService.setShowCategoryTitles(any)).thenAnswer((_) async {});
  when(settingsService.setShowAppNamesBelowIcons(any)).thenAnswer((_) async {});
  when(settingsService.setShowFocusBorders(any)).thenAnswer((_) async {});
  when(settingsService.setShowWatchNextSection(any)).thenAnswer((_) async {});
  when(settingsService.setShowContentShortcutHandle(any)).thenAnswer((_) async {});
  return settingsService;
}

Future<void> _pumpPage(WidgetTester tester, MockSettingsService settingsService) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: settingsService,
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: MiscPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
