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

// Regression tests for scene *image* wallpaper overrides wired into
// WallpaperService (phase 2 of scene wallpaper overrides). See docs/PRD.md
// section 9.1.4, and wallpaper_service_scene_test.dart for the equivalent
// gradient-override tests (phase 1).
//
// Uses a *real* ScenesService (backed by an in-memory SharedPreferences
// store), because several tests exercise the actual wiring:
// importSceneWallpaper/deleteSceneWallpaper writing/removing the namespaced
// file on disk, and setSceneWallpaperPath/activateScene driving the scene
// listener that recomputes the effective wallpaper. SettingsService stays
// mocked for a simple, explicit user wallpaper/video/gradient.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.mocks.dart';

void main() {
  // Own scratch directory: every wallpaper_service test file mocks the
  // documents directory too and they all run concurrently in the same
  // process/cwd, so sharing a directory name would race (see
  // wallpaper_service_layer_test.dart).
  late final Directory documentsDirectory;
  late final _MockPathProviderPlatform pathProviderPlatform;
  setUpAll(() async {
    documentsDirectory = await Directory("./test_tmp_wallpaper_scene_image").create(recursive: true);
    pathProviderPlatform = _MockPathProviderPlatform();
    when(
      pathProviderPlatform.getApplicationDocumentsPath(),
    ).thenAnswer((_) => Future.value(documentsDirectory.path));
    PathProviderPlatform.instance = pathProviderPlatform;
  });
  tearDownAll(() async {
    if (await documentsDirectory.exists()) await documentsDirectory.delete(recursive: true);
  });

  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final sharedPreferencesFuture = SharedPreferences.getInstance();

  Future<ScenesService> mkScenesService() async {
    final sharedPreferences = await sharedPreferencesFuture;
    await sharedPreferences.clear();
    return ScenesService(sharedPreferences);
  }

  MockSettingsService mkUserSettings({bool timeBasedEnabled = false}) {
    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(timeBasedEnabled);
    when(settingsService.gradientUuid).thenReturn(null);
    return settingsService;
  }

  /// The six fixed user wallpaper files, so tests can assert none of them was
  /// ever touched by scene image code.
  List<File> userFixedFiles() => [
        File("${documentsDirectory.path}/wallpaper"),
        File("${documentsDirectory.path}/wallpaper_day"),
        File("${documentsDirectory.path}/wallpaper_night"),
        File("${documentsDirectory.path}/wallpaper_video"),
        File("${documentsDirectory.path}/wallpaper_day_video"),
        File("${documentsDirectory.path}/wallpaper_night_video"),
      ];

  File sceneWallpaperFile(String sceneKey) => File("${documentsDirectory.path}/scene_wallpaper_$sceneKey");

  test("a scene image override renders the scene's image, and the user's six files stay byte-identical", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final userFiles = userFixedFiles();
    for (var i = 0; i < userFiles.length; i++) {
      await userFiles[i].writeAsBytes([i, i + 1, i + 2]);
    }
    addTearDown(() async {
      for (final file in userFiles) {
        if (await file.exists()) await file.delete();
      }
    });
    final digestsBefore = [for (final file in userFiles) sha256.convert(await file.readAsBytes())];

    final scenesService = await mkScenesService();
    final settingsService = mkUserSettings();
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    final source = File("${documentsDirectory.path}/scene_src_cinema_1");
    await source.writeAsBytes([0x10, 0x20, 0x30]);
    addTearDown(() async {
      if (await source.exists()) await source.delete();
      await wallpaperService.deleteSceneWallpaper(SceneKeys.cinema);
    });

    final storedPath = await wallpaperService.importSceneWallpaper(SceneKeys.cinema, source);
    await scenesService.setSceneWallpaperPath(SceneKeys.cinema, storedPath);
    await scenesService.activateScene(SceneKeys.cinema);

    final wallpaper = wallpaperService.wallpaper;
    expect(wallpaper, isA<FileImage>());
    expect((wallpaper as FileImage).file.path, sceneWallpaperFile(SceneKeys.cinema).path);
    expect(await wallpaper.file.readAsBytes(), [0x10, 0x20, 0x30]);

    final digestsAfter = [for (final file in userFiles) sha256.convert(await file.readAsBytes())];
    expect(digestsAfter, digestsBefore);
  });

  test("a scene claiming an image that is not on disk falls through to the user's own wallpaper, never blank",
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final wallpaperFile = File("${documentsDirectory.path}/wallpaper");
    await wallpaperFile.writeAsBytes([0x01, 0x02, 0x03]);
    addTearDown(() async {
      if (await wallpaperFile.exists()) await wallpaperFile.delete();
    });

    final scenesService = await mkScenesService();
    // Claims an image override without ever calling importSceneWallpaper, so
    // the namespaced file never exists on disk: this is what a restored
    // backup missing its wallpaper file, an uninstall/reinstall, or a manual
    // deletion all look like from WallpaperService's point of view.
    await scenesService.setSceneWallpaperPath(SceneKeys.cinema, "scene_wallpaper_${SceneKeys.cinema}");

    final settingsService = mkUserSettings();
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    await scenesService.activateScene(SceneKeys.cinema);

    final wallpaper = wallpaperService.wallpaper;
    expect(wallpaper, isA<FileImage>());
    expect((wallpaper as FileImage).file.path, wallpaperFile.path);
  });

  test("with a user video wallpaper active, a scene image override wins and the video does not show through",
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final videoFile = File("${documentsDirectory.path}/wallpaper_video");
    await videoFile.writeAsBytes([0x01, 0x02, 0x03]);
    addTearDown(() async {
      if (await videoFile.exists()) await videoFile.delete();
    });

    final scenesService = await mkScenesService();
    final settingsService = mkUserSettings();
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    // Sanity check: before any scene override, the user's video is active.
    expect(wallpaperService.wallpaperVideoFile?.path, videoFile.path);

    final source = File("${documentsDirectory.path}/scene_src_night_1");
    await source.writeAsBytes([0x40, 0x50]);
    addTearDown(() async {
      if (await source.exists()) await source.delete();
      await wallpaperService.deleteSceneWallpaper(SceneKeys.night);
    });
    final storedPath = await wallpaperService.importSceneWallpaper(SceneKeys.night, source);
    await scenesService.setSceneWallpaperPath(SceneKeys.night, storedPath);
    await scenesService.activateScene(SceneKeys.night);

    expect(wallpaperService.wallpaperVideoFile, isNull);
    final wallpaper = wallpaperService.wallpaper;
    expect(wallpaper, isA<FileImage>());
    expect((wallpaper as FileImage).file.path, sceneWallpaperFile(SceneKeys.night).path);
  });

  test("importSceneWallpaper writes only the namespaced path, and deleteSceneWallpaper removes only it", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final scenesService = await mkScenesService();
    final settingsService = mkUserSettings();
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    final cinemaSource = File("${documentsDirectory.path}/scene_src_cinema_2");
    final nightSource = File("${documentsDirectory.path}/scene_src_night_2");
    await cinemaSource.writeAsBytes([0x01]);
    await nightSource.writeAsBytes([0x02]);
    addTearDown(() async {
      if (await cinemaSource.exists()) await cinemaSource.delete();
      if (await nightSource.exists()) await nightSource.delete();
    });

    await wallpaperService.importSceneWallpaper(SceneKeys.cinema, cinemaSource);
    await wallpaperService.importSceneWallpaper(SceneKeys.night, nightSource);

    final cinemaFile = sceneWallpaperFile(SceneKeys.cinema);
    final nightFile = sceneWallpaperFile(SceneKeys.night);
    addTearDown(() async {
      if (await cinemaFile.exists()) await cinemaFile.delete();
      if (await nightFile.exists()) await nightFile.delete();
    });

    expect(await cinemaFile.exists(), isTrue);
    expect(await nightFile.exists(), isTrue);
    expect(await cinemaFile.readAsBytes(), [0x01]);
    expect(await nightFile.readAsBytes(), [0x02]);
    for (final file in userFixedFiles()) {
      expect(await file.exists(), isFalse);
    }

    await wallpaperService.deleteSceneWallpaper(SceneKeys.cinema);

    expect(await cinemaFile.exists(), isFalse);
    expect(await nightFile.exists(), isTrue);
    for (final file in userFixedFiles()) {
      expect(await file.exists(), isFalse);
    }
  });

  test("a scene's image and gradient overrides remain mutually exclusive end to end", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final scenesService = await mkScenesService();
    final settingsService = mkUserSettings();
    when(settingsService.gradientUuid).thenReturn(FLauncherGradients.grassShampoo.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    await scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.viciousStance.uuid);
    await scenesService.activateScene(SceneKeys.cinema);

    expect(wallpaperService.gradient, FLauncherGradients.viciousStance);
    expect(wallpaperService.wallpaper, isNull);

    final source = File("${documentsDirectory.path}/scene_src_exclusivity");
    await source.writeAsBytes([0x99]);
    addTearDown(() async {
      if (await source.exists()) await source.delete();
      await wallpaperService.deleteSceneWallpaper(SceneKeys.cinema);
    });

    // Setting the image override on the same scene must drop the gradient
    // override: Scene's own mutual-exclusion invariant (scene.dart,
    // scenes_service.dart), unchanged by this phase, is what this asserts.
    final storedPath = await wallpaperService.importSceneWallpaper(SceneKeys.cinema, source);
    await scenesService.setSceneWallpaperPath(SceneKeys.cinema, storedPath);

    expect(wallpaperService.gradient, FLauncherGradients.grassShampoo);
    final wallpaper = wallpaperService.wallpaper;
    expect(wallpaper, isA<FileImage>());
    expect((wallpaper as FileImage).file.path, sceneWallpaperFile(SceneKeys.cinema).path);
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
