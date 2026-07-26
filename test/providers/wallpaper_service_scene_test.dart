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

// Regression tests for scene gradient overrides wired into WallpaperService
// (phase 1 of scene wallpaper overrides). See docs/PRD.md section 9.1.4.
//
// Tests 1-4 use a *real* ScenesService (backed by an in-memory
// SharedPreferences store) rather than a mock, because the point of these
// tests is the wiring itself: the scene listener genuinely firing and
// switching the effective gradient, not just the pure resolution function.
// `SettingsService` stays mocked there for a simple, explicit user gradient
// and for `verifyNever`.
//
// Test 5 additionally uses a *real* `SettingsService`, because it inspects
// the raw persisted preferences to prove the user's own gradient is never
// touched, even across a simulated restart.

import 'package:flauncher/gradients.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.mocks.dart';

// Mirrors the private `_gradientUuidKey` constant in settings_service.dart:
// there is no public accessor, and reading the raw key is the whole point of
// the kill-mid-scene test (it must bypass the service layer).
const _rawGradientUuidKey = "gradient_uuid";

void main() {
  late final _MockPathProviderPlatform pathProviderPlatform;
  setUpAll(() {
    pathProviderPlatform = _MockPathProviderPlatform();
    // No test in this file reads or writes an actual wallpaper file, so the
    // path itself is never touched on disk; it only has to be distinct from
    // the scratch directories other test files use, since they all run
    // concurrently in the same process/cwd.
    when(
      pathProviderPlatform.getApplicationDocumentsPath(),
    ).thenAnswer((_) => Future.value("./test_tmp_wallpaper_scene"));
    PathProviderPlatform.instance = pathProviderPlatform;
  });

  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final sharedPreferencesFuture = SharedPreferences.getInstance();

  Future<ScenesService> mkScenesService() async {
    final sharedPreferences = await sharedPreferencesFuture;
    await sharedPreferences.clear();
    return ScenesService(sharedPreferences);
  }

  MockSettingsService mkUserSettings(String userGradientUuid) {
    final settingsService = MockSettingsService();
    when(settingsService.timeBasedWallpaperEnabled).thenReturn(false);
    when(settingsService.gradientUuid).thenReturn(userGradientUuid);
    return settingsService;
  }

  test("a scene gradient override wins over the user's gradient, without touching it", () async {
    final scenesService = await mkScenesService();
    await scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.viciousStance.uuid);
    await scenesService.activateScene(SceneKeys.cinema);

    final settingsService = mkUserSettings(FLauncherGradients.grassShampoo.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    expect(wallpaperService.gradient, FLauncherGradients.viciousStance);
    verifyNever(settingsService.setGradientUuid(any));
  });

  test("switching back to a scene with no override returns the user's gradient", () async {
    final scenesService = await mkScenesService();
    await scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.viciousStance.uuid);
    await scenesService.activateScene(SceneKeys.cinema);

    final settingsService = mkUserSettings(FLauncherGradients.grassShampoo.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    expect(wallpaperService.gradient, FLauncherGradients.viciousStance);

    await scenesService.activateScene(SceneKeys.normal);

    expect(wallpaperService.gradient, FLauncherGradients.grassShampoo);
  });

  test("an unknown gradient uuid in the scene falls back to the user's gradient, not an arbitrary one", () async {
    final scenesService = await mkScenesService();
    await scenesService.setSceneGradientUuid(SceneKeys.cinema, "not-a-known-gradient-uuid");
    await scenesService.activateScene(SceneKeys.cinema);

    final settingsService = mkUserSettings(FLauncherGradients.grassShampoo.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    expect(wallpaperService.gradient, FLauncherGradients.grassShampoo);
  });

  test("activating a scene with a gradient override bumps wallpaperRevision", () async {
    final scenesService = await mkScenesService();
    await scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.viciousStance.uuid);

    final settingsService = mkUserSettings(FLauncherGradients.grassShampoo.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());
    await Future.delayed(Duration.zero);

    final revisionBeforeActivation = wallpaperService.wallpaperRevision;

    await scenesService.activateScene(SceneKeys.cinema);

    expect(wallpaperService.gradient, FLauncherGradients.viciousStance);
    expect(wallpaperService.wallpaperRevision, greaterThan(revisionBeforeActivation));
  });

  test("killing the launcher mid-scene never rewrites the user's own gradient", () async {
    final sharedPreferences = await sharedPreferencesFuture;
    await sharedPreferences.clear();
    await sharedPreferences.setString(_rawGradientUuidKey, FLauncherGradients.grassShampoo.uuid);

    // First "process": build the full, real service graph and activate a
    // scene with a gradient override.
    final scenesService = ScenesService(sharedPreferences);
    final settingsService = SettingsService(sharedPreferences, scenesService);
    await scenesService.setSceneGradientUuid(SceneKeys.cinema, FLauncherGradients.viciousStance.uuid);
    final wallpaperService = WallpaperService(settingsService, scenesService);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    await scenesService.activateScene(SceneKeys.cinema);
    expect(wallpaperService.gradient, FLauncherGradients.viciousStance);

    final rawGradientUuidBeforeRestart = sharedPreferences.getString(_rawGradientUuidKey);
    expect(rawGradientUuidBeforeRestart, FLauncherGradients.grassShampoo.uuid);

    // Simulate the process being killed mid-scene (no clean shutdown, no
    // "leaving the scene" step) and restarted: discard every in-memory
    // service and rebuild from the exact same persisted store. There is no
    // save/restore step to race, because there is nothing to restore: the
    // override was never written anywhere.
    final scenesServiceAfterRestart = ScenesService(sharedPreferences);
    final settingsServiceAfterRestart = SettingsService(sharedPreferences, scenesServiceAfterRestart);
    final wallpaperServiceAfterRestart = WallpaperService(settingsServiceAfterRestart, scenesServiceAfterRestart);
    await untilCalled(pathProviderPlatform.getApplicationDocumentsPath());

    expect(scenesServiceAfterRestart.activeSceneKey, SceneKeys.cinema);
    expect(wallpaperServiceAfterRestart.gradient, FLauncherGradients.viciousStance);
    expect(sharedPreferences.getString(_rawGradientUuidKey), rawGradientUuidBeforeRestart);
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
