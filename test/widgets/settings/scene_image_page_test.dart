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

import 'dart:io';

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/scene_image_page.dart';
import 'package:flauncher/widgets/tv_media_picker.dart';
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

  testWidgets("Shows 'No image' with no 'Clear image' tile when the scene has no override", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: null));

    await _pumpWidgetWithProviders(tester, scenesService, wallpaperService, sceneImagePage());

    expect(find.text("No image"), findsOneWidget);
    expect(find.text("Choose image"), findsOneWidget);
    expect(find.text("Clear image"), findsNothing);
  });

  testWidgets("Shows 'Image set' with a 'Clear image' tile when the scene has an override", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: "scene_wallpaper_cinema"));

    await _pumpWidgetWithProviders(tester, scenesService, wallpaperService, sceneImagePage());

    expect(find.text("Image set"), findsOneWidget);
    expect(find.text("Clear image"), findsOneWidget);
  });

  testWidgets("Choosing an image imports it, then records the override, in that order", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: null));
    when(wallpaperService.importSceneWallpaper(any, any))
        .thenAnswer((_) async => "/documents/scene_wallpaper_cinema");
    when(scenesService.setSceneWallpaperPath(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      wallpaperService,
      sceneImagePage(mediaPicker: (_, {required mode}) async => "/picked/photo.jpg"),
    );

    await tester.tap(find.text("Choose image"));
    await tester.pumpAndSettle();

    verifyInOrder([
      wallpaperService.importSceneWallpaper(SceneKeys.cinema, argThat(isA<File>().having((f) => f.path, "path", "/picked/photo.jpg"))),
      scenesService.setSceneWallpaperPath(SceneKeys.cinema, "/documents/scene_wallpaper_cinema"),
    ]);

    // The whole point of this feature: a scene image edit must never reach
    // the user's own, global wallpaper-writing methods.
    verifyNever(wallpaperService.pickWallpaper(any));
    verifyNever(wallpaperService.pickWallpaperDay(any));
    verifyNever(wallpaperService.pickWallpaperNight(any));
    verifyNever(wallpaperService.pickVideoWallpaper(any));
    verifyNever(wallpaperService.pickVideoWallpaperDay(any));
    verifyNever(wallpaperService.pickVideoWallpaperNight(any));
    verifyNever(wallpaperService.setGradient(any));
  });

  testWidgets("A failed copy does not record an override", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: null));
    when(wallpaperService.importSceneWallpaper(any, any)).thenThrow(const FileSystemException("copy failed"));

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      wallpaperService,
      sceneImagePage(mediaPicker: (_, {required mode}) async => "/picked/photo.jpg"),
    );

    await tester.tap(find.text("Choose image"));
    await tester.pumpAndSettle();

    verify(wallpaperService.importSceneWallpaper(SceneKeys.cinema, any));
    verifyNever(scenesService.setSceneWallpaperPath(any, any));
    expect(find.text("Could not save this change."), findsOneWidget);
  });

  testWidgets("Not picking an image (cancelled picker) does not touch either service", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: null));

    await _pumpWidgetWithProviders(
      tester,
      scenesService,
      wallpaperService,
      sceneImagePage(mediaPicker: (_, {required mode}) async => null),
    );

    await tester.tap(find.text("Choose image"));
    await tester.pumpAndSettle();

    verifyNever(wallpaperService.importSceneWallpaper(any, any));
    verifyNever(scenesService.setSceneWallpaperPath(any, any));
  });

  testWidgets("Clearing deletes the file and clears the override, in that order", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: "scene_wallpaper_cinema"));
    when(wallpaperService.deleteSceneWallpaper(any)).thenAnswer((_) async {});
    when(scenesService.setSceneWallpaperPath(any, any)).thenAnswer((_) async => SceneUpdateResult.applied);

    await _pumpWidgetWithProviders(tester, scenesService, wallpaperService, sceneImagePage());

    await tester.tap(find.text("Clear image"));
    await tester.pumpAndSettle();

    verifyInOrder([
      wallpaperService.deleteSceneWallpaper(SceneKeys.cinema),
      scenesService.setSceneWallpaperPath(SceneKeys.cinema, null),
    ]);
    verifyNever(wallpaperService.pickWallpaper(any));
    verifyNever(wallpaperService.setGradient(any));
  });

  testWidgets("A persistenceFailed result on clear is surfaced with a snackbar, not swallowed", (tester) async {
    final scenesService = MockScenesService();
    final wallpaperService = MockWallpaperService();
    when(scenesService.sceneByKey(any)).thenReturn(fakeScene(wallpaperPath: "scene_wallpaper_cinema"));
    when(wallpaperService.deleteSceneWallpaper(any)).thenAnswer((_) async {});
    when(scenesService.setSceneWallpaperPath(any, any))
        .thenAnswer((_) async => SceneUpdateResult.persistenceFailed);

    await _pumpWidgetWithProviders(tester, scenesService, wallpaperService, sceneImagePage());

    await tester.tap(find.text("Clear image"));
    await tester.pumpAndSettle();

    expect(find.text("Could not save this change."), findsOneWidget);
  });
}

/// Builds a [SceneImagePage] for [SceneKeys.cinema], with [mediaPicker]
/// defaulting to one that never actually shows [TvMediaPicker]'s dialog (that
/// dialog talks to a real platform channel with no test double), so a test
/// that never taps "Choose image" doesn't need to supply one at all.
SceneImagePage sceneImagePage({
  Future<String?> Function(BuildContext, {required TvMediaPickerMode mode})? mediaPicker,
}) =>
    SceneImagePage(
      sceneKey: SceneKeys.cinema,
      mediaPicker: mediaPicker ?? (_, {required mode}) async => null,
    );

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  ScenesService scenesService,
  WallpaperService wallpaperService,
  Widget child,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScenesService>.value(value: scenesService),
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
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
