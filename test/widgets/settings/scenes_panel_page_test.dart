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
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/scene_editor_page.dart';
import 'package:flauncher/widgets/settings/scenes_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  MockSettingsService mkSettingsService({bool scenesEnabled = true}) {
    final settingsService = MockSettingsService();
    when(settingsService.scenesEnabled).thenReturn(scenesEnabled);
    return settingsService;
  }

  testWidgets("All scenes are displayed", (tester) async {
    final scenesService = MockScenesService();
    when(scenesService.scenes).thenReturn([
      fakeScene(key: SceneKeys.normal, name: "Normal"),
      fakeScene(key: SceneKeys.cinema, name: "Cinema"),
      fakeScene(key: SceneKeys.night, name: "Night"),
    ]);

    await _pumpWidgetWithProviders(tester, scenesService, mkSettingsService());

    expect(find.text("Normal"), findsOneWidget);
    expect(find.text("Cinema"), findsOneWidget);
    expect(find.text("Night"), findsOneWidget);
  });

  testWidgets("Tapping a scene opens SceneEditorPage", (tester) async {
    final scenesService = MockScenesService();
    when(scenesService.scenes).thenReturn([
      fakeScene(key: SceneKeys.normal, name: "Normal"),
      fakeScene(key: SceneKeys.cinema, name: "Cinema"),
    ]);

    await _pumpWidgetWithProviders(tester, scenesService, mkSettingsService());

    await tester.tap(find.text("Cinema"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("SceneEditorPage")), findsOneWidget);
  });

  testWidgets("The switch is always shown and reflects scenesEnabled", (tester) async {
    final scenesService = MockScenesService();
    when(scenesService.scenes).thenReturn([fakeScene(key: SceneKeys.normal, name: "Normal")]);

    await _pumpWidgetWithProviders(tester, scenesService, mkSettingsService(scenesEnabled: false));

    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    // The switch stays reachable, but the list underneath it is what
    // disappears while the feature is off — see `ScenesPanelPage`.
    expect(find.text("Normal"), findsNothing);
  });

  testWidgets("Flipping the switch persists the setting", (tester) async {
    final scenesService = MockScenesService();
    when(scenesService.scenes).thenReturn([fakeScene(key: SceneKeys.normal, name: "Normal")]);
    final settingsService = mkSettingsService(scenesEnabled: false);
    when(settingsService.setScenesEnabled(true)).thenAnswer((_) async {});

    await _pumpWidgetWithProviders(tester, scenesService, settingsService);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    verify(settingsService.setScenesEnabled(true)).called(1);
  });
}

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  ScenesService scenesService,
  SettingsService settingsService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScenesService>.value(value: scenesService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          SceneEditorPage.routeName: (_) => Container(key: Key("SceneEditorPage")),
        },
        home: Scaffold(body: ScenesPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
