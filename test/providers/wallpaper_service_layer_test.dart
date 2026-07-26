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

// Regression tests for the wallpaper_service.dart user-layer / effective-layer
// split (phase 0 of scene wallpaper overrides). See docs/PRD.md section 9.1.4.
//
// These cover the two edge cases the refactor must get right:
//  1. Re-resolving to the *same* wallpaper (e.g. a day/night timer tick) must
//     NOT bump wallpaperRevision (avoids an unnecessary full-screen re-blur).
//  2. Picking a new image over a fixed filename (the on-disk path never
//     changes) MUST still bump wallpaperRevision, otherwise consumers that key
//     off the revision (e.g. the cached blur snapshot) never learn that the
//     file content changed and the new wallpaper never becomes visible.

import 'dart:io';

import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mocks.mocks.dart';

/// A scene with no wallpaper override: these tests are about the user's own
/// image-identity/revision-bump logic, not scene overrides.
final _sceneWithoutOverride = Scene(key: "normal", name: "Normal");

MockScenesService _mkScenesService() {
  final scenesService = MockScenesService();
  when(scenesService.activeScene).thenReturn(_sceneWithoutOverride);
  return scenesService;
}

void main() {
  // Own scratch directory: wallpaper_service_test.dart mocks the documents
  // directory as "." too and runs concurrently in the same process/cwd, so
  // sharing fixed filenames like "wallpaper" across test files would race.
  late final Directory documentsDirectory;
  late final _MockPathProviderPlatform pathProviderPlatform;
  setUpAll(() async {
    documentsDirectory = await Directory("./test_tmp_wallpaper_layer").create(recursive: true);
    pathProviderPlatform = _MockPathProviderPlatform();
    when(
      pathProviderPlatform.getApplicationDocumentsPath(),
    ).thenAnswer((_) => Future.value(documentsDirectory.path));
    PathProviderPlatform.instance = pathProviderPlatform;
  });
  tearDownAll(() async {
    if (await documentsDirectory.exists()) await documentsDirectory.delete(recursive: true);
  });

  test("re-resolving the same wallpaper does not bump the revision", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final dayFile = File("${documentsDirectory.path}/wallpaper_day");
    final nightFile = File("${documentsDirectory.path}/wallpaper_night");
    await dayFile.writeAsBytes([0x01, 0x02, 0x03]);
    await nightFile.writeAsBytes([0x01, 0x02, 0x03]);
    addTearDown(() async {
      if (await dayFile.exists()) await dayFile.delete();
      if (await nightFile.exists()) await nightFile.delete();
    });

    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(true);
    when(settingsService.gradientUuid).thenReturn(null);
    final wallpaperService = WallpaperService(settingsService, _mkScenesService());

    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    final revisionAfterInit = wallpaperService.wallpaperRevision;
    expect(wallpaperService.wallpaper, isNotNull);

    // Simulate the Timer.periodic day/night re-resolution: nothing on disk
    // changed, so the effective identity is unchanged.
    wallpaperService.debugResolveNow();
    wallpaperService.debugResolveNow();

    expect(wallpaperService.wallpaperRevision, revisionAfterInit);
  });

  test("picking a new image over the same fixed filename bumps the revision and is shown", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(null);
    final wallpaperService = WallpaperService(settingsService, _mkScenesService());
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    final firstSource = File("${documentsDirectory.path}/src_1");
    final secondSource = File("${documentsDirectory.path}/src_2");
    await firstSource.writeAsBytes([0x01, 0x02]);
    await secondSource.writeAsBytes([0x03, 0x04, 0x05]);
    final dest = File("${documentsDirectory.path}/wallpaper");
    addTearDown(() async {
      if (await firstSource.exists()) await firstSource.delete();
      if (await secondSource.exists()) await secondSource.delete();
      if (await dest.exists()) await dest.delete();
    });

    await wallpaperService.pickWallpaper(firstSource);
    final revisionAfterFirstPick = wallpaperService.wallpaperRevision;
    expect(await dest.readAsBytes(), [0x01, 0x02]);

    // Same destination path as before ("wallpaper" is a fixed filename), but
    // different content: this is the trap the effective-identity design must
    // not fall into.
    await wallpaperService.pickWallpaper(secondSource);

    expect(await dest.readAsBytes(), [0x03, 0x04, 0x05]);
    expect(wallpaperService.wallpaperRevision, greaterThan(revisionAfterFirstPick));
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
