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
import 'package:flauncher/widgets/settings/scene_accent_color_page.dart';
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

  testWidgets("The 'no override' option names the user's current accent colour", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(accentColorHex: null));
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_TEAL);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneAccentColorPage(sceneKey: SceneKeys.cinema),
    );

    expect(find.text("Inherit (Teal)"), findsOneWidget);
  });

  testWidgets("Selecting a preset calls ScenesService.setSceneAccentColorHex with its hex", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(accentColorHex: null));
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);
    when(scenesService.setSceneAccentColorHex(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneAccentColorPage(sceneKey: SceneKeys.cinema),
    );

    // "Ice Blue" is the last preset, a few rows below the initial viewport.
    final iceBlueCard = find.byKey(Key("scene-accent-$ACCENT_COLOR_ICE_BLUE"));
    await tester.ensureVisible(iceBlueCard);
    await tester.pumpAndSettle();
    await tester.tap(iceBlueCard);
    await tester.pumpAndSettle();

    verify(scenesService.setSceneAccentColorHex(SceneKeys.cinema, ACCENT_COLOR_ICE_BLUE));
    // The whole point of this feature: a scene accent edit must never reach
    // the global setter.
    verifyNever(settingsService.setAccentColor(any));
  });

  testWidgets("Selecting 'no override' calls ScenesService.setSceneAccentColorHex with null", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(accentColorHex: ACCENT_COLOR_ICE_BLUE));
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);
    when(scenesService.setSceneAccentColorHex(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneAccentColorPage(sceneKey: SceneKeys.cinema),
    );

    // "Ice Blue" is the current override here, so it - not "no override" - is
    // what autofocus scrolled into view on open; scroll back to reach it.
    final inheritCard = find.byKey(Key("scene-accent-inherit"));
    await tester.ensureVisible(inheritCard);
    await tester.pumpAndSettle();
    await tester.tap(inheritCard);
    await tester.pumpAndSettle();

    verify(scenesService.setSceneAccentColorHex(SceneKeys.cinema, null));
    verifyNever(settingsService.setAccentColor(any));
  });

  testWidgets("The currently overridden accent colour is checked and autofocused", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(accentColorHex: ACCENT_COLOR_ICE_BLUE));
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneAccentColorPage(sceneKey: SceneKeys.cinema),
    );

    final overriddenCardKey = Key("scene-accent-$ACCENT_COLOR_ICE_BLUE");
    await tester.ensureVisible(find.byKey(overriddenCardKey));
    await tester.pumpAndSettle();

    // The checkmark shows on the overridden preset's card, and nowhere else.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(overriddenCardKey), matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );

    // That same card is the one marked autofocus, so a TV remote's D-pad
    // lands on the already-selected preset when this page opens, even though
    // it sits several rows down among the ~15 presets.
    expect(tester.widget<InkWell>(find.byKey(overriddenCardKey)).autofocus, isTrue);
  });

  testWidgets("A persistenceFailed result is surfaced with a snackbar, not swallowed", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(accentColorHex: null));
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);
    when(scenesService.setSceneAccentColorHex(any, any))
        .thenAnswer((_) async => SceneUpdateResult.persistenceFailed);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneAccentColorPage(sceneKey: SceneKeys.cinema),
    );

    final iceBlueCard = find.byKey(Key("scene-accent-$ACCENT_COLOR_ICE_BLUE"));
    await tester.ensureVisible(iceBlueCard);
    await tester.pumpAndSettle();
    await tester.tap(iceBlueCard);
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
