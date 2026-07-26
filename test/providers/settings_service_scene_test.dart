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

// Regression tests for the six scene presentation overrides wired into
// SettingsService (see docs/PRD.md section 9.1.4, and the equivalent
// wallpaper_service_scene_test.dart for the wallpaper overrides).
//
// A real ScenesService (backed by an in-memory SharedPreferences store) is
// used throughout, because the point of these tests is the wiring itself:
// the scene listener genuinely firing and switching the effective value, not
// just the pure resolution logic. SettingsService is also real here, unlike
// wallpaper_service_scene_test.dart's mocked SettingsService: it is the class
// under test in this file (the equivalent of WallpaperService there), so
// there is no separate "user settings" collaborator left to mock out.
//
// Because of that, "no setter was called" is proven by reading the *raw*
// persisted preference across the activation rather than with Mockito's
// verifyNever (there is nothing to attach verifyNever to): a setter is the
// only thing that can change that raw value, so an unchanged raw value after
// activating/deactivating a scene is exactly the same proof.

import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final sharedPreferencesFuture = SharedPreferences.getInstance();

  Future<(SharedPreferences, ScenesService, SettingsService)> mkServices() async {
    final sharedPreferences = await sharedPreferencesFuture;
    await sharedPreferences.clear();
    final scenesService = ScenesService(sharedPreferences);
    final settingsService = SettingsService(sharedPreferences, scenesService);
    return (sharedPreferences, scenesService, settingsService);
  }

  group("hideAppBar / autoHideAppBarEnabled", () {
    test("a scene override wins over the user's own preference, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setAutoHideAppBarEnabled(false);
      final rawBefore = sharedPreferences.getBool("auto_hide_app_bar");

      await scenesService.setSceneHideAppBar(SceneKeys.cinema, true);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.autoHideAppBarEnabled, true);
      expect(settingsService.userAutoHideAppBarEnabled, false);
      expect(sharedPreferences.getBool("auto_hide_app_bar"), rawBefore);
    });

    test("a scene with no override falls back to the user's own preference", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setAutoHideAppBarEnabled(true);

      await scenesService.setSceneHideAppBar(SceneKeys.cinema, true);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.autoHideAppBarEnabled, true);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.autoHideAppBarEnabled, true);

      await settingsService.setAutoHideAppBarEnabled(false);
      expect(settingsService.autoHideAppBarEnabled, false);
    });
  });

  group("showWatchNext / showWatchNextSection", () {
    test("a scene override wins over the user's own preference, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setShowWatchNextSection(true);
      final rawBefore = sharedPreferences.getBool("show_watch_next_section");

      await scenesService.setSceneShowWatchNext(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.showWatchNextSection, false);
      expect(settingsService.userShowWatchNextSection, true);
      expect(sharedPreferences.getBool("show_watch_next_section"), rawBefore);
    });

    test("leaving the scene returns the user's own preference", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setShowWatchNextSection(true);
      await scenesService.setSceneShowWatchNext(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.showWatchNextSection, false);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.showWatchNextSection, true);
    });
  });

  group("showAppNames / showAppNamesBelowIcons", () {
    test("a scene override wins over the user's own preference, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setShowAppNamesBelowIcons(true);
      final rawBefore = sharedPreferences.getBool("show_app_names_below_icons");

      await scenesService.setSceneShowAppNames(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.showAppNamesBelowIcons, false);
      expect(settingsService.userShowAppNamesBelowIcons, true);
      expect(sharedPreferences.getBool("show_app_names_below_icons"), rawBefore);
    });

    test("leaving the scene returns the user's own preference", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setShowAppNamesBelowIcons(true);
      await scenesService.setSceneShowAppNames(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.showAppNamesBelowIcons, false);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.showAppNamesBelowIcons, true);
    });
  });

  group("disableBackgroundBlur / backgroundBlurDisabled", () {
    test("a scene override wins over the user's own preference, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setBackgroundBlurDisabled(false);
      final rawBefore = sharedPreferences.getBool("background_blur_disabled");

      await scenesService.setSceneDisableBackgroundBlur(SceneKeys.cinema, true);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.backgroundBlurDisabled, true);
      expect(settingsService.userBackgroundBlurDisabled, false);
      expect(sharedPreferences.getBool("background_blur_disabled"), rawBefore);
    });

    test("leaving the scene returns the user's own preference", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setBackgroundBlurDisabled(false);
      await scenesService.setSceneDisableBackgroundBlur(SceneKeys.cinema, true);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.backgroundBlurDisabled, true);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.backgroundBlurDisabled, false);
    });
  });

  group("showCategoryTitles", () {
    test("a scene override wins over the user's own preference, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setShowCategoryTitles(true);
      final rawBefore = sharedPreferences.getBool("show_category_titles");

      await scenesService.setSceneShowCategoryTitles(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.showCategoryTitles, false);
      expect(settingsService.userShowCategoryTitles, true);
      expect(sharedPreferences.getBool("show_category_titles"), rawBefore);
    });

    test("leaving the scene returns the user's own preference", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setShowCategoryTitles(true);
      await scenesService.setSceneShowCategoryTitles(SceneKeys.cinema, false);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.showCategoryTitles, false);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.showCategoryTitles, true);
    });
  });

  group("accentColorHex", () {
    test("a scene override wins over the user's own accent, without touching it", () async {
      final (sharedPreferences, scenesService, settingsService) = await mkServices();
      await settingsService.setAccentColor(ACCENT_COLOR_BLUE);
      final rawBefore = sharedPreferences.getString("accent_color");

      await scenesService.setSceneAccentColorHex(SceneKeys.cinema, ACCENT_COLOR_RED);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.accentColorHex, ACCENT_COLOR_RED);
      expect(settingsService.userAccentColorHex, ACCENT_COLOR_BLUE);
      expect(sharedPreferences.getString("accent_color"), rawBefore);
    });

    test("leaving the scene returns the user's own accent", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setAccentColor(ACCENT_COLOR_BLUE);
      await scenesService.setSceneAccentColorHex(SceneKeys.cinema, ACCENT_COLOR_RED);
      await scenesService.activateScene(SceneKeys.cinema);
      expect(settingsService.accentColorHex, ACCENT_COLOR_RED);

      await scenesService.activateScene(SceneKeys.normal);
      expect(settingsService.accentColorHex, ACCENT_COLOR_BLUE);
    });

    test("an invalid hex in the scene falls back to the user's accent, not an arbitrary one", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setAccentColor(ACCENT_COLOR_BLUE);

      await scenesService.setSceneAccentColorHex(SceneKeys.cinema, "not-a-hex-color");
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.accentColorHex, ACCENT_COLOR_BLUE);
      // accentColor must not throw on the malformed override either.
      expect(() => settingsService.accentColor, returnsNormally);
      expect(settingsService.accentColor, Color(int.parse("0xFF$ACCENT_COLOR_BLUE")));
    });

    test("a too-short hex in the scene also falls back to the user's accent", () async {
      final (_, scenesService, settingsService) = await mkServices();
      await settingsService.setAccentColor(ACCENT_COLOR_GREEN);

      await scenesService.setSceneAccentColorHex(SceneKeys.cinema, "FFF");
      await scenesService.activateScene(SceneKeys.cinema);

      expect(settingsService.accentColorHex, ACCENT_COLOR_GREEN);
    });
  });

  test(
      "killing the launcher mid-scene never rewrites any of the six user preferences "
      "(the non-destructive proof, across all six overrides at once)", () async {
    final sharedPreferences = await sharedPreferencesFuture;
    await sharedPreferences.clear();

    // First "process": set every user preference to a known baseline, then
    // build the full, real service graph and activate a scene overriding
    // every single one of them the other way.
    final scenesService = ScenesService(sharedPreferences);
    final settingsService = SettingsService(sharedPreferences, scenesService);

    await settingsService.setAutoHideAppBarEnabled(false);
    await settingsService.setShowWatchNextSection(true);
    await settingsService.setShowAppNamesBelowIcons(true);
    await settingsService.setBackgroundBlurDisabled(false);
    await settingsService.setShowCategoryTitles(true);
    await settingsService.setAccentColor(ACCENT_COLOR_BLUE);

    await scenesService.setSceneHideAppBar(SceneKeys.cinema, true);
    await scenesService.setSceneShowWatchNext(SceneKeys.cinema, false);
    await scenesService.setSceneShowAppNames(SceneKeys.cinema, false);
    await scenesService.setSceneDisableBackgroundBlur(SceneKeys.cinema, true);
    await scenesService.setSceneShowCategoryTitles(SceneKeys.cinema, false);
    await scenesService.setSceneAccentColorHex(SceneKeys.cinema, ACCENT_COLOR_RED);
    await scenesService.activateScene(SceneKeys.cinema);

    expect(settingsService.autoHideAppBarEnabled, true);
    expect(settingsService.showWatchNextSection, false);
    expect(settingsService.showAppNamesBelowIcons, false);
    expect(settingsService.backgroundBlurDisabled, true);
    expect(settingsService.showCategoryTitles, false);
    expect(settingsService.accentColorHex, ACCENT_COLOR_RED);

    final rawBefore = <String, Object?>{
      "auto_hide_app_bar": sharedPreferences.getBool("auto_hide_app_bar"),
      "show_watch_next_section": sharedPreferences.getBool("show_watch_next_section"),
      "show_app_names_below_icons": sharedPreferences.getBool("show_app_names_below_icons"),
      "background_blur_disabled": sharedPreferences.getBool("background_blur_disabled"),
      "show_category_titles": sharedPreferences.getBool("show_category_titles"),
      "accent_color": sharedPreferences.getString("accent_color"),
    };

    // Simulate the process being killed mid-scene (no clean shutdown, no
    // "leaving the scene" step) and restarted: discard every in-memory
    // service and rebuild from the exact same persisted store.
    final scenesServiceAfterRestart = ScenesService(sharedPreferences);
    final settingsServiceAfterRestart = SettingsService(sharedPreferences, scenesServiceAfterRestart);

    expect(scenesServiceAfterRestart.activeSceneKey, SceneKeys.cinema);
    expect(settingsServiceAfterRestart.autoHideAppBarEnabled, true);
    expect(settingsServiceAfterRestart.showWatchNextSection, false);
    expect(settingsServiceAfterRestart.showAppNamesBelowIcons, false);
    expect(settingsServiceAfterRestart.backgroundBlurDisabled, true);
    expect(settingsServiceAfterRestart.showCategoryTitles, false);
    expect(settingsServiceAfterRestart.accentColorHex, ACCENT_COLOR_RED);

    // The user's own preferences, read raw, are byte-identical to what they
    // were right after activation: nothing was ever rewritten by the scene.
    expect(sharedPreferences.getBool("auto_hide_app_bar"), rawBefore["auto_hide_app_bar"]);
    expect(sharedPreferences.getBool("show_watch_next_section"), rawBefore["show_watch_next_section"]);
    expect(sharedPreferences.getBool("show_app_names_below_icons"), rawBefore["show_app_names_below_icons"]);
    expect(sharedPreferences.getBool("background_blur_disabled"), rawBefore["background_blur_disabled"]);
    expect(sharedPreferences.getBool("show_category_titles"), rawBefore["show_category_titles"]);
    expect(sharedPreferences.getString("accent_color"), rawBefore["accent_color"]);

    // And the user-value getters still report the original baseline, not the
    // scene's override.
    expect(settingsServiceAfterRestart.userAutoHideAppBarEnabled, false);
    expect(settingsServiceAfterRestart.userShowWatchNextSection, true);
    expect(settingsServiceAfterRestart.userShowAppNamesBelowIcons, true);
    expect(settingsServiceAfterRestart.userBackgroundBlurDisabled, false);
    expect(settingsServiceAfterRestart.userShowCategoryTitles, true);
    expect(settingsServiceAfterRestart.userAccentColorHex, ACCENT_COLOR_BLUE);
  });
}
