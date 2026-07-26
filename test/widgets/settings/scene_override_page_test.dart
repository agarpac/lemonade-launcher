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
import 'package:flauncher/widgets/settings/scene_override_page.dart';
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

  testWidgets("The inherit option shows the live global value when it is on", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(hideAppBar: null));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(true);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.cinema, field: SceneOverrideField.hideAppBar),
    );

    expect(find.text("Inherit (on)"), findsOneWidget);
    expect(find.text("Inherit (off)"), findsNothing);
  });

  testWidgets("The inherit option shows the live global value when it is off", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(hideAppBar: null));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.cinema, field: SceneOverrideField.hideAppBar),
    );

    expect(find.text("Inherit (off)"), findsOneWidget);
    expect(find.text("Inherit (on)"), findsNothing);
  });

  testWidgets("Selecting 'On' calls the field's setter with true", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(hideAppBar: null));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(scenesService.setSceneHideAppBar(any, any))
        .thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.cinema, field: SceneOverrideField.hideAppBar),
    );

    await tester.tap(find.text("On"));
    await tester.pumpAndSettle();

    verify(scenesService.setSceneHideAppBar(SceneKeys.cinema, true));
  });

  testWidgets("Selecting 'Off' calls the showCategoryTitles setter with false", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(showCategoryTitles: null));
    when(settingsService.userShowCategoryTitles).thenReturn(true);
    when(scenesService.setSceneShowCategoryTitles(any, any))
        .thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.night, field: SceneOverrideField.showCategoryTitles),
    );

    await tester.tap(find.text("Off"));
    await tester.pumpAndSettle();

    verify(scenesService.setSceneShowCategoryTitles(SceneKeys.night, false));
  });

  testWidgets("The three-state control cycles through inherit, on, off and back to inherit", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(hideAppBar: null));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(true);
    when(scenesService.setSceneHideAppBar(any, any))
        .thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.cinema, field: SceneOverrideField.hideAppBar),
    );

    // Inherit -> On -> Off -> back to Inherit. All three options stay on
    // screen throughout, so the full cycle is exercised in a single pump.
    await tester.tap(find.text("On"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Off"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Inherit (on)"));
    await tester.pumpAndSettle();

    verify(scenesService.setSceneHideAppBar(SceneKeys.cinema, true));
    verify(scenesService.setSceneHideAppBar(SceneKeys.cinema, false));
    verify(scenesService.setSceneHideAppBar(SceneKeys.cinema, null));
  });

  testWidgets("A persistenceFailed result is surfaced with a snackbar, not swallowed", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(hideAppBar: null));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(scenesService.setSceneHideAppBar(any, any))
        .thenAnswer((_) async => SceneUpdateResult.persistenceFailed);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneOverridePage(sceneKey: SceneKeys.cinema, field: SceneOverrideField.hideAppBar),
    );

    await tester.tap(find.text("On"));
    await tester.pumpAndSettle();

    expect(find.text("Could not save this change."), findsOneWidget);
  });
}

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  ScenesService scenesService,
  SettingsService settingsService,
  Widget child,
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
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
