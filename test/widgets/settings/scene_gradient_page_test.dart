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

import 'package:flauncher/gradients.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/scene_gradient_page.dart';
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

  testWidgets("The 'no override' option names the user's current gradient", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(gradientUuid: null));
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.greatWhale.uuid);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneGradientPage(sceneKey: SceneKeys.cinema),
    );

    expect(find.text("Inherit (Great Whale)"), findsOneWidget);
  });

  testWidgets("Selecting a gradient calls ScenesService.setSceneGradientUuid with its uuid", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(gradientUuid: null));
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(scenesService.setSceneGradientUuid(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneGradientPage(sceneKey: SceneKeys.cinema),
    );

    // "Old Hat" is a few rows down the grid, below the initial viewport.
    final oldHatCard = find.byKey(Key("scene-gradient-${FLauncherGradients.oldHat.uuid}"));
    await _scrollIntoView(tester, oldHatCard);
    await tester.tap(oldHatCard);
    await tester.pumpAndSettle();

    verify(scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.oldHat.uuid));
    // The whole point of this feature: a scene gradient edit must never reach
    // the global setter.
    verifyNever(settingsService.setGradientUuid(any));
  });

  testWidgets("Selecting 'no override' calls ScenesService.setSceneGradientUuid with null", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(gradientUuid: FLauncherGradients.oldHat.uuid));
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(scenesService.setSceneGradientUuid(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneGradientPage(sceneKey: SceneKeys.cinema),
    );

    // "Old Hat" is the current override here, so it - not "no override" - is
    // what autofocus scrolled into view on open; scroll back to reach it.
    final inheritCard = find.byKey(Key("scene-gradient-inherit"));
    await _scrollIntoView(tester, inheritCard);
    await tester.tap(inheritCard);
    await tester.pumpAndSettle();

    verify(scenesService.setSceneGradientUuid(SceneKeys.cinema, null));
    verifyNever(settingsService.setGradientUuid(any));
  });

  testWidgets("The currently overridden gradient is checked and autofocused", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(gradientUuid: FLauncherGradients.oldHat.uuid));
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneGradientPage(sceneKey: SceneKeys.cinema),
    );

    final overriddenCardKey = Key("scene-gradient-${FLauncherGradients.oldHat.uuid}");
    await _scrollIntoView(tester, find.byKey(overriddenCardKey));

    // The checkmark shows on the overridden gradient's card, and nowhere else.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(overriddenCardKey), matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );

    // That same card is the one marked autofocus, so a TV remote's D-pad
    // lands on the already-selected gradient when this page opens.
    expect(tester.widget<InkWell>(find.byKey(overriddenCardKey)).autofocus, isTrue);
  });

  testWidgets("A persistenceFailed result is surfaced with a snackbar, not swallowed", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(gradientUuid: null));
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(scenesService.setSceneGradientUuid(any, any))
        .thenAnswer((_) async => SceneUpdateResult.persistenceFailed);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneGradientPage(sceneKey: SceneKeys.cinema),
    );

    final oldHatCard = find.byKey(Key("scene-gradient-${FLauncherGradients.oldHat.uuid}"));
    await _scrollIntoView(tester, oldHatCard);
    await tester.tap(oldHatCard);
    await tester.pumpAndSettle();

    expect(find.text("Could not save this change."), findsOneWidget);
  });
}

/// Scrolls the page's outer [SingleChildScrollView] so [finder] - already
/// built (see [SceneGradientPage]'s `shrinkWrap` grid) but possibly a few
/// rows below the initial viewport - is fully on-screen and tappable.
Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
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
