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
import 'package:flauncher/widgets/settings/interface_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Lists Sections, Wallpaper, Status bar, Appearance, Content and Scenes", (tester) async {
    await _pumpPage(tester);

    expect(find.text("Sections"), findsOneWidget);
    expect(find.text("Wallpaper"), findsOneWidget);
    expect(find.text("Status bar"), findsOneWidget);
    expect(find.text("Appearance"), findsOneWidget);
    expect(find.text("Content"), findsOneWidget);
    expect(find.text("Scenes"), findsOneWidget);
  });

  testWidgets("No longer has a Miscellaneous tile: it was deleted, its controls redistributed", (tester) async {
    await _pumpPage(tester);

    expect(find.text("Miscellaneous"), findsNothing);
  });

  testWidgets("No longer has a standalone Accent color tile: it moved inside Appearance", (tester) async {
    await _pumpPage(tester);

    expect(find.text("Accent color"), findsNothing);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: InterfaceSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}
