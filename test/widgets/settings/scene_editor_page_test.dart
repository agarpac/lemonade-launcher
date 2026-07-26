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
import 'package:flauncher/widgets/settings/scene_accent_color_page.dart';
import 'package:flauncher/widgets/settings/scene_editor_page.dart';
import 'package:flauncher/widgets/settings/scene_gradient_page.dart';
import 'package:flauncher/widgets/settings/scene_image_page.dart';
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

  testWidgets("Selecting 'Normal' shows an explanation and no override controls", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.normal, name: "Normal"));

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.normal),
    );

    expect(
      find.text("Normal is your own settings, left untouched. There is nothing to configure here."),
      findsOneWidget,
    );
    // None of the five override tiles are rendered, not even disabled ones.
    expect(find.text("Automatically hide status bar"), findsNothing);
    expect(find.text("Show Watch Next Section"), findsNothing);
    expect(find.text("Show app names below icons"), findsNothing);
    expect(find.text("Disable background blur"), findsNothing);
    expect(find.text("Show category titles"), findsNothing);
    // Nor is the gradient override tile: it follows the exact same rule.
    expect(find.text("Gradient"), findsNothing);
    // Nor is the image override tile: it follows the exact same rule.
    expect(find.text("Image"), findsNothing);
    // Nor is the accent colour override tile: it follows the exact same rule.
    expect(find.text("Accent color"), findsNothing);
  });

  testWidgets("A non-normal scene shows the five override tiles with their inherited state", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    expect(find.text("Automatically hide status bar"), findsOneWidget);
    expect(find.text("Show Watch Next Section"), findsOneWidget);
    expect(find.text("Show app names below icons"), findsOneWidget);
    expect(find.text("Disable background blur"), findsOneWidget);
    expect(find.text("Show category titles"), findsOneWidget);
    // Every field is unset on this fixture, so every tile inherits; the user's
    // own setting is false for all five, so every tile reads "Inherit (off)".
    expect(find.text("Inherit (off)"), findsNWidgets(5));
    // The gradient tile also appears, on this same "no override" fixture,
    // naming the user's own current gradient.
    expect(find.text("Gradient"), findsOneWidget);
    expect(find.text("Inherit (Saint Petersburg)"), findsOneWidget);
    // So does the image tile, showing "no image" since this fixture has no
    // wallpaperPath override.
    expect(find.text("Image"), findsOneWidget);
    expect(find.text("No image"), findsOneWidget);
    // So does the accent colour tile, naming the user's own current accent.
    expect(find.text("Accent color"), findsOneWidget);
    expect(find.text("Inherit (White)"), findsOneWidget);
  });

  testWidgets("The image tile shows 'Image set' when the scene has a wallpaperPath override", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any))
        .thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema", wallpaperPath: "scene_wallpaper_cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    expect(find.text("Image set"), findsOneWidget);
  });

  testWidgets("Tapping the image tile opens SceneImagePage", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    await tester.tap(find.text("Image"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("SceneImagePage")), findsOneWidget);
  });

  testWidgets("Tapping an override tile opens SceneOverridePage", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    await tester.tap(find.text("Automatically hide status bar"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("SceneOverridePage")), findsOneWidget);
  });

  testWidgets("Tapping the gradient tile opens SceneGradientPage", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    await tester.tap(find.text("Gradient"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("SceneGradientPage")), findsOneWidget);
  });

  testWidgets("Tapping the accent colour tile opens SceneAccentColorPage", (tester) async {
    final scenesService = MockScenesService();
    final settingsService = MockSettingsService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(key: SceneKeys.cinema, name: "Cinema"));
    when(settingsService.userAutoHideAppBarEnabled).thenReturn(false);
    when(settingsService.userShowWatchNextSection).thenReturn(false);
    when(settingsService.userShowAppNamesBelowIcons).thenReturn(false);
    when(settingsService.userBackgroundBlurDisabled).thenReturn(false);
    when(settingsService.userShowCategoryTitles).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.saintPetersburg.uuid);
    when(settingsService.userAccentColorHex).thenReturn(ACCENT_COLOR_WHITE);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      settingsService,
      SceneEditorPage(sceneKey: SceneKeys.cinema),
    );

    await tester.tap(find.text("Accent color"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("SceneAccentColorPage")), findsOneWidget);
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
        routes: {
          SceneOverridePage.routeName: (_) => Container(key: Key("SceneOverridePage")),
          SceneGradientPage.routeName: (_) => Container(key: Key("SceneGradientPage")),
          SceneAccentColorPage.routeName: (_) => Container(key: Key("SceneAccentColorPage")),
          SceneImagePage.routeName: (_) => Container(key: Key("SceneImagePage")),
        },
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
