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

// Regression tests for docs/PRD.md section 13.3: a video wallpaper's revision
// must only bump when the *effective video file actually changes*, not just
// because a video is present. Before this fix, `_updateWallpaper` bumped
// `_wallpaperRevision` unconditionally whenever a video was active, so the
// day/night `Timer.periodic` (every 60s) advanced the revision every minute
// even when nothing changed, causing `lib/flauncher.dart`'s
// `ValueKey("background_video_$wallpaperRevision")` to discard and recreate
// the video player widget once per minute.
//
// See test/providers/wallpaper_service_layer_test.dart for the equivalent
// image/gradient identity tests (phases 0/1 of scene wallpaper overrides).

import 'dart:io';

import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mocks.mocks.dart';

/// A scene with no wallpaper override: these tests are about the user's own
/// video-identity/revision-bump logic, not scene overrides.
final _sceneWithoutOverride = Scene(key: "normal", name: "Normal");

MockScenesService _mkScenesService() {
  final scenesService = MockScenesService();
  when(scenesService.activeScene).thenReturn(_sceneWithoutOverride);
  return scenesService;
}

void main() {
  // Own scratch directory: other wallpaper_service test files mock the
  // documents directory too and run concurrently in the same process/cwd, so
  // sharing a directory name would race (see wallpaper_service_layer_test.dart).
  late final Directory documentsDirectory;
  late final _MockPathProviderPlatform pathProviderPlatform;
  setUpAll(() async {
    documentsDirectory = await Directory("./test_tmp_wallpaper_video").create(recursive: true);
    pathProviderPlatform = _MockPathProviderPlatform();
    when(
      pathProviderPlatform.getApplicationDocumentsPath(),
    ).thenAnswer((_) => Future.value(documentsDirectory.path));
    PathProviderPlatform.instance = pathProviderPlatform;
  });
  tearDownAll(() async {
    if (await documentsDirectory.exists()) await documentsDirectory.delete(recursive: true);
  });

  test("re-resolving the same active video does not bump the revision", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final videoFile = File("${documentsDirectory.path}/wallpaper_video");
    await videoFile.writeAsBytes([0x01, 0x02, 0x03]);
    addTearDown(() async {
      if (await videoFile.exists()) await videoFile.delete();
    });

    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(null);
    final wallpaperService = WallpaperService(settingsService, _mkScenesService());

    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    final revisionAfterInit = wallpaperService.wallpaperRevision;
    expect(wallpaperService.wallpaperVideoFile, isNotNull);

    // Simulate the Timer.periodic tick: nothing on disk changed, so the
    // effective video identity is unchanged. This is the regression test for
    // PRD section 13.3: before the fix, this alone bumped the revision every
    // time, once per minute in production.
    wallpaperService.debugResolveNow();
    wallpaperService.debugResolveNow();

    expect(wallpaperService.wallpaperRevision, revisionAfterInit);
  });

  test("a day-to-night tick that resolves a different video file bumps the revision", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final dayVideoFile = File("${documentsDirectory.path}/wallpaper_day_video");
    final nightVideoFile = File("${documentsDirectory.path}/wallpaper_night_video");
    await dayVideoFile.writeAsBytes([0x01, 0x02, 0x03]);
    await nightVideoFile.writeAsBytes([0x04, 0x05, 0x06]);
    addTearDown(() async {
      if (await dayVideoFile.exists()) await dayVideoFile.delete();
      if (await nightVideoFile.exists()) await nightVideoFile.delete();
    });

    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(true);
    when(settingsService.gradientUuid).thenReturn(null);
    final wallpaperService = WallpaperService(settingsService, _mkScenesService());
    // Deterministic "day": both files exist, so this is genuinely resolving
    // the day-specific video, not falling back to a shared file.
    wallpaperService.debugNow = () => DateTime(2024, 1, 1, 12);

    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);
    wallpaperService.debugResolveNow();

    final revisionDuringDay = wallpaperService.wallpaperRevision;
    expect(wallpaperService.wallpaperVideoFile?.path, dayVideoFile.path);

    // The Timer.periodic tick that crosses into night: the resolved video
    // file genuinely changes from wallpaper_day_video to
    // wallpaper_night_video, which is the whole reason the timer exists.
    wallpaperService.debugNow = () => DateTime(2024, 1, 1, 22);
    wallpaperService.debugResolveNow();

    expect(wallpaperService.wallpaperVideoFile?.path, nightVideoFile.path);
    expect(wallpaperService.wallpaperRevision, greaterThan(revisionDuringDay));
  });

  test("picking a new video over the same fixed filename bumps the revision", () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(null);
    final wallpaperService = WallpaperService(settingsService, _mkScenesService());
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    final firstSource = File("${documentsDirectory.path}/video_src_1");
    final secondSource = File("${documentsDirectory.path}/video_src_2");
    await firstSource.writeAsBytes([0x01, 0x02]);
    await secondSource.writeAsBytes([0x03, 0x04, 0x05]);
    final dest = File("${documentsDirectory.path}/wallpaper_video");
    addTearDown(() async {
      if (await firstSource.exists()) await firstSource.delete();
      if (await secondSource.exists()) await secondSource.delete();
      if (await dest.exists()) await dest.delete();
    });

    await wallpaperService.pickVideoWallpaper(firstSource);
    final revisionAfterFirstPick = wallpaperService.wallpaperRevision;
    expect(await dest.readAsBytes(), [0x01, 0x02]);

    // Same destination path as before ("wallpaper_video" is a fixed
    // filename), but different content: a path-only comparison would not
    // notice this, which is exactly why the pick/save call sites force a bump.
    await wallpaperService.pickVideoWallpaper(secondSource);

    expect(await dest.readAsBytes(), [0x03, 0x04, 0x05]);
    expect(wallpaperService.wallpaperRevision, greaterThan(revisionAfterFirstPick));
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
