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

import 'dart:convert';

import 'package:flauncher/gradients.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() async {
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final sharedPreferences = await SharedPreferences.getInstance();

  setUp(() async {
    await sharedPreferences.clear();
  });

  /// Builds a service on the current preferences, as a launcher restart would.
  ScenesService restart() => ScenesService(sharedPreferences);

  group("first run", () {
    test("seeds the three default scenes", () {
      final scenesService = restart();

      expect(
        scenesService.scenes.map((scene) => scene.key),
        [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night],
      );
    });

    test("activates the normal scene", () {
      final scenesService = restart();

      expect(scenesService.activeSceneKey, SceneKeys.normal);
      expect(scenesService.activeScene.name, "Normal");
      expect(scenesService.activeSceneRequiresPinToExit, false);
    });

    test("exposes an unmodifiable scene list", () {
      final scenesService = restart();

      expect(
        () => scenesService.scenes.add(Scene(key: "extra", name: "Extra")),
        throwsUnsupportedError,
      );
    });
  });

  group("activateScene", () {
    test("activates a known scene and notifies listeners", () async {
      final scenesService = restart();
      var notifications = 0;
      scenesService.addListener(() => notifications++);

      final result = await scenesService.activateScene(SceneKeys.cinema);

      expect(result, SceneActivationResult.activated);
      expect(scenesService.activeSceneKey, SceneKeys.cinema);
      expect(scenesService.activeScene.hideAppBar, true);
      expect(notifications, 1);
    });

    test("reports an unknown key without changing the active scene", () async {
      final scenesService = restart();
      var notifications = 0;
      scenesService.addListener(() => notifications++);

      final result = await scenesService.activateScene("does-not-exist");

      expect(result, SceneActivationResult.unknownScene);
      expect(scenesService.activeSceneKey, SceneKeys.normal);
      expect(notifications, 0);
    });

    test("reports an already active scene without notifying", () async {
      final scenesService = restart();
      var notifications = 0;
      scenesService.addListener(() => notifications++);

      final result = await scenesService.activateScene(SceneKeys.normal);

      expect(result, SceneActivationResult.alreadyActive);
      expect(notifications, 0);
    });

    test("keeps the active scene across a restart, with no automatic reversion", () async {
      await restart().activateScene(SceneKeys.night);

      final afterRestart = restart();

      expect(afterRestart.activeSceneKey, SceneKeys.night);
    });

    test("falls back to the first scene when the stored active key is unknown", () async {
      await sharedPreferences.setString("active_scene_key", "removed-scene");

      final scenesService = restart();

      expect(scenesService.activeSceneKey, SceneKeys.normal);
    });
  });

  group("PIN protection", () {
    /// Locks the night scene with [pin] and activates it, as the user would.
    ///
    /// The PIN capability is dormant (no seeded scene ships with one) but
    /// remains fully wired in the service; any scene works to exercise it.
    Future<ScenesService> lockedInNightScene(String pin) async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, pin);
      await scenesService.activateScene(SceneKeys.night);
      return scenesService;
    }

    test("entering a PIN-protected scene requires no PIN", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(scenesService.activeSceneKey, SceneKeys.night);
      expect(scenesService.activeSceneRequiresPinToExit, true);
    });

    test("leaving without a PIN is refused", () async {
      final scenesService = await lockedInNightScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal);

      expect(result, SceneActivationResult.pinRequired);
      expect(scenesService.activeSceneKey, SceneKeys.night);
    });

    test("leaving with a wrong PIN is refused", () async {
      final scenesService = await lockedInNightScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal, pin: "4321");

      expect(result, SceneActivationResult.pinRejected);
      expect(scenesService.activeSceneKey, SceneKeys.night);
    });

    test("leaving with the right PIN is accepted", () async {
      final scenesService = await lockedInNightScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal, pin: "1234");

      expect(result, SceneActivationResult.activated);
      expect(scenesService.activeSceneKey, SceneKeys.normal);
    });

    test("verifyExitPin checks the active scene", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(scenesService.verifyExitPin("1234"), true);
      expect(scenesService.verifyExitPin("0000"), false);
    });

    test("the PIN survives a restart and is never stored in plain text", () async {
      await restart().setScenePin(SceneKeys.night, "1234");

      expect(sharedPreferences.getString("scenes"), isNot(contains("1234")));

      final afterRestart = restart();

      expect(afterRestart.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
      expect(afterRestart.sceneByKey(SceneKeys.night)!.verifyPin("9999"), false);
    });

    test("clearScenePin removes the lock when the PIN is supplied", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.night, pin: "1234"), SceneUpdateResult.applied);

      expect(scenesService.activeSceneRequiresPinToExit, false);
      expect(await scenesService.activateScene(SceneKeys.normal), SceneActivationResult.activated);
    });
  });

  group("the PIN cannot be removed or reset away without it", () {
    /// Locks the night scene with [pin] and activates it, as the user would.
    Future<ScenesService> lockedInNightScene(String pin) async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, pin);
      await scenesService.activateScene(SceneKeys.night);
      return scenesService;
    }

    test("clearScenePin without a PIN is refused and the lock survives a restart", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.night), SceneUpdateResult.pinRequired);

      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, true);
      expect(restart().sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
    });

    test("clearScenePin with a wrong PIN is refused", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.night, pin: "4321"), SceneUpdateResult.pinRejected);

      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, true);
    });

    test("clearScenePin still requires the PIN from outside the protected scene", () async {
      final scenesService = await lockedInNightScene("1234");
      await scenesService.activateScene(SceneKeys.normal, pin: "1234");

      expect(scenesService.activeSceneRequiresPinToExit, false);
      expect(await scenesService.clearScenePin(SceneKeys.night), SceneUpdateResult.pinRequired);
      expect(await scenesService.clearScenePin(SceneKeys.night, pin: "0000"), SceneUpdateResult.pinRejected);
      expect(await scenesService.clearScenePin(SceneKeys.night, pin: "1234"), SceneUpdateResult.applied);
    });

    test("clearScenePin on an unprotected scene needs no PIN", () async {
      final scenesService = restart();

      expect(await scenesService.clearScenePin(SceneKeys.normal), SceneUpdateResult.applied);
    });

    test("setScenePin cannot replace an existing PIN without the current one", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.setScenePin(SceneKeys.night, "9999"), SceneUpdateResult.pinRequired);
      expect(await scenesService.setScenePin(SceneKeys.night, "9999", currentPin: "0000"), SceneUpdateResult.pinRejected);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);

      expect(await scenesService.setScenePin(SceneKeys.night, "9999", currentPin: "1234"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("9999"), true);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), false);
    });

    test("setScenePin on an unprotected scene needs no current PIN", () async {
      final scenesService = restart();

      expect(await scenesService.setScenePin(SceneKeys.night, "1234"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
    });

    test("setScenePin on another scene is refused while locked inside a protected one", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.setScenePin(SceneKeys.cinema, "5555"), SceneUpdateResult.pinRequired);
      expect(scenesService.sceneByKey(SceneKeys.cinema)!.isPinProtected, false);
    });

    test("restoreDefaults without the PIN is refused and the lock survives", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.restoreDefaults(), SceneUpdateResult.pinRequired);

      expect(scenesService.activeSceneKey, SceneKeys.night);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
      expect(restart().sceneByKey(SceneKeys.night)!.isPinProtected, true);
    });

    test("restoreDefaults with a wrong PIN is refused", () async {
      final scenesService = await lockedInNightScene("1234");

      expect(await scenesService.restoreDefaults(pin: "4321"), SceneUpdateResult.pinRejected);

      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, true);
    });

    test("restoreDefaults is refused from outside the protected scene as well", () async {
      final scenesService = await lockedInNightScene("1234");
      await scenesService.activateScene(SceneKeys.normal, pin: "1234");

      expect(await scenesService.restoreDefaults(), SceneUpdateResult.pinRequired);
      expect(await scenesService.restoreDefaults(pin: "1234"), SceneUpdateResult.applied);
    });

    test("restoreDefaults needs no PIN when no scene is protected", () async {
      final scenesService = restart();

      expect(await scenesService.restoreDefaults(), SceneUpdateResult.applied);
    });

    test("restoreDefaults fails closed when two scenes carry different PINs", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1111");
      await scenesService.setScenePin(SceneKeys.cinema, "2222");

      expect(await scenesService.restoreDefaults(pin: "1111"), SceneUpdateResult.pinRejected);
      expect(await scenesService.restoreDefaults(pin: "2222"), SceneUpdateResult.pinRejected);

      // Not a dead end: clearing the locks one by one, each with its own PIN,
      // leaves a reachable path to the reset.
      expect(await scenesService.clearScenePin(SceneKeys.cinema, pin: "2222"), SceneUpdateResult.applied);
      expect(await scenesService.restoreDefaults(pin: "1111"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, false);
    });
  });

  group("saveScene cannot be used to bypass the PIN", () {
    test("a scene handed over with the lock stripped does not remove it", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1234");

      final stripped = scenesService.sceneByKey(SceneKeys.night)!.withoutPin();
      await scenesService.saveScene(stripped);

      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, true);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
      expect(restart().sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
    });

    test("a scene handed over with a replaced lock keeps the stored one", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1234");

      final relocked = scenesService.sceneByKey(SceneKeys.night)!.withPin("9999");
      await scenesService.saveScene(relocked);

      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("9999"), false);
    });

    test("a scene rebuilt from scratch cannot smuggle a lock onto an existing key", () async {
      final scenesService = restart();

      await scenesService.saveScene(Scene(key: SceneKeys.normal, name: "Normal").withPin("1234"));

      expect(scenesService.sceneByKey(SceneKeys.normal)!.isPinProtected, false);
      expect(scenesService.activeSceneRequiresPinToExit, false);
    });

    test("configuration changes still go through while the lock is preserved", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1234");

      await scenesService.saveScene(
        scenesService.sceneByKey(SceneKeys.night)!.withoutPin().copyWith(
              name: "Bedtime",
              disableBackgroundBlur: true,
              hideAppBar: true,
            ),
      );

      final stored = restart().sceneByKey(SceneKeys.night)!;
      expect(stored.name, "Bedtime");
      expect(stored.disableBackgroundBlur, true);
      expect(stored.hideAppBar, true);
      expect(stored.verifyPin("1234"), true);
    });

    test("a brand-new scene keeps the lock it arrives with", () async {
      final scenesService = restart();

      await scenesService.saveScene(Scene(key: "guest", name: "Guest").withPin("1234"));

      expect(scenesService.sceneByKey("guest")!.verifyPin("1234"), true);
    });
  });

  group("scene configuration", () {
    test("round-trips a saved scene through shared preferences", () async {
      final scenesService = restart();
      await scenesService.saveScene(
        scenesService.sceneByKey(SceneKeys.cinema)!.copyWith(
              name: "Movies",
              hideAppBar: true,
              showWatchNext: false,
              wallpaperPath: "/wallpapers/cinema",
            ),
      );

      final restored = restart().sceneByKey(SceneKeys.cinema)!;

      expect(restored.name, "Movies");
      expect(restored.hideAppBar, true);
      expect(restored.showWatchNext, false);
      expect(restored.wallpaperPath, "/wallpapers/cinema");
    });

    test("saving an unknown key appends a new scene", () async {
      final scenesService = restart();

      await scenesService.saveScene(Scene(key: "party", name: "Party", disableBackgroundBlur: true));

      expect(scenesService.scenes.length, 4);
      expect(restart().sceneByKey("party")!.disableBackgroundBlur, true);
    });

    test("setSceneHideAppBar sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneHideAppBar(SceneKeys.normal, true);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.hideAppBar, true);

      await scenesService.setSceneHideAppBar(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.hideAppBar, null);
    });

    test("setSceneShowWatchNext sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneShowWatchNext(SceneKeys.normal, false);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showWatchNext, false);

      await scenesService.setSceneShowWatchNext(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showWatchNext, null);
    });

    test("setSceneShowAppNames sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneShowAppNames(SceneKeys.normal, false);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showAppNames, false);

      await scenesService.setSceneShowAppNames(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showAppNames, null);
    });

    test("setSceneDisableBackgroundBlur sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneDisableBackgroundBlur(SceneKeys.normal, true);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.disableBackgroundBlur, true);

      await scenesService.setSceneDisableBackgroundBlur(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.disableBackgroundBlur, null);
    });

    test("setSceneShowCategoryTitles sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneShowCategoryTitles(SceneKeys.normal, true);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showCategoryTitles, true);

      await scenesService.setSceneShowCategoryTitles(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.showCategoryTitles, null);
    });

    test("setSceneAccentColorHex sets and clears the override", () async {
      final scenesService = restart();

      await scenesService.setSceneAccentColorHex(SceneKeys.normal, "7C4DFF");
      expect(scenesService.sceneByKey(SceneKeys.normal)!.accentColorHex, "7C4DFF");

      await scenesService.setSceneAccentColorHex(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.accentColorHex, null);
    });

    test("setSceneWallpaperPath sets and clears the wallpaper override", () async {
      final scenesService = restart();

      await scenesService.setSceneWallpaperPath(SceneKeys.night, "/wallpapers/night");
      expect(scenesService.sceneByKey(SceneKeys.night)!.wallpaperPath, "/wallpapers/night");

      await scenesService.setSceneWallpaperPath(SceneKeys.night, null);
      expect(scenesService.sceneByKey(SceneKeys.night)!.wallpaperPath, null);
    });

    test("updating an unknown scene reports it instead of silently doing nothing", () async {
      final scenesService = restart();
      var notifications = 0;
      scenesService.addListener(() => notifications++);

      expect(await scenesService.setSceneHideAppBar("does-not-exist", true), SceneUpdateResult.unknownScene);
      expect(await scenesService.setSceneShowWatchNext("does-not-exist", true), SceneUpdateResult.unknownScene);
      expect(await scenesService.setSceneShowAppNames("does-not-exist", true), SceneUpdateResult.unknownScene);
      expect(
        await scenesService.setSceneDisableBackgroundBlur("does-not-exist", true),
        SceneUpdateResult.unknownScene,
      );
      expect(await scenesService.setSceneShowCategoryTitles("does-not-exist", true), SceneUpdateResult.unknownScene);
      expect(await scenesService.setSceneAccentColorHex("does-not-exist", "7C4DFF"), SceneUpdateResult.unknownScene);
      expect(
        await scenesService.setSceneWallpaperPath("does-not-exist", "/wallpapers/none"),
        SceneUpdateResult.unknownScene,
      );
      expect(await scenesService.setSceneGradientUuid("does-not-exist", "uuid"), SceneUpdateResult.unknownScene);
      expect(await scenesService.setScenePin("does-not-exist", "1234"), SceneUpdateResult.unknownScene);
      expect(await scenesService.clearScenePin("does-not-exist"), SceneUpdateResult.unknownScene);

      expect(scenesService.scenes.length, 3);
      expect(notifications, 0);
    });

    test("restoreDefaults discards customizations and activates the normal scene", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1234");
      await scenesService.setSceneShowCategoryTitles(SceneKeys.night, true);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(await scenesService.restoreDefaults(pin: "1234"), SceneUpdateResult.applied);

      expect(scenesService.activeSceneKey, SceneKeys.normal);
      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, false);
      expect(scenesService.sceneByKey(SceneKeys.night)!.showCategoryTitles, null);
      expect(restart().sceneByKey(SceneKeys.night)!.showCategoryTitles, null);
    });
  });

  group("wallpaper and gradient overrides", () {
    test("setSceneGradientUuid sets and clears the gradient override", () async {
      final scenesService = restart();

      expect(
        await scenesService.setSceneGradientUuid(SceneKeys.night, "4730aa2d-1a90-49a6-9942-ffe82f470e26"),
        SceneUpdateResult.applied,
      );
      expect(scenesService.sceneByKey(SceneKeys.night)!.gradientUuid, "4730aa2d-1a90-49a6-9942-ffe82f470e26");
      expect(scenesService.sceneByKey(SceneKeys.night)!.overridesWallpaper, true);

      await scenesService.setSceneGradientUuid(SceneKeys.night, null);
      expect(scenesService.sceneByKey(SceneKeys.night)!.overridesWallpaper, false);
    });

    test("a gradient survives a restart", () async {
      await restart().setSceneGradientUuid(SceneKeys.night, "uuid");

      expect(restart().sceneByKey(SceneKeys.night)!.gradientUuid, "uuid");
    });

    test("setting a gradient drops a wallpaper file, and the other way round", () async {
      final scenesService = restart();

      await scenesService.setSceneWallpaperPath(SceneKeys.night, "/wallpapers/night");
      await scenesService.setSceneGradientUuid(SceneKeys.night, "uuid");
      expect(scenesService.sceneByKey(SceneKeys.night)!.wallpaperPath, null);
      expect(scenesService.sceneByKey(SceneKeys.night)!.gradientUuid, "uuid");

      await scenesService.setSceneWallpaperPath(SceneKeys.night, "/wallpapers/night");
      expect(scenesService.sceneByKey(SceneKeys.night)!.gradientUuid, null);
      expect(scenesService.sceneByKey(SceneKeys.night)!.wallpaperPath, "/wallpapers/night");
    });

    test("only normal seeds no gradient; cinema and night seed pitch black", () {
      for (final scene in restart().scenes) {
        if (scene.key == SceneKeys.normal) {
          expect(scene.gradientUuid, null, reason: "${scene.key} must not seed a gradient");
        } else {
          expect(scene.gradientUuid, FLauncherGradients.pitchBlack.uuid, reason: "${scene.key} must seed pitch black");
        }
      }
    });
  });

  group("stored values of the wrong type", () {
    // `SharedPreferences.getString` casts, so a value of another type under one
    // of our keys throws a TypeError on the startup path. The planned
    // backup/restore feature imports a user-supplied JSON file into
    // shared_preferences, so this is reachable, and on this device a launcher
    // that does not start needs a computer and an ADB cable to recover.
    final writers = <String, void Function(String key)>{
      "a bool": (key) => sharedPreferences.setBool(key, true),
      "an int": (key) => sharedPreferences.setInt(key, 7),
      "a double": (key) => sharedPreferences.setDouble(key, 1.5),
      "a string list": (key) => sharedPreferences.setStringList(key, ["normal"]),
    };

    for (final key in ["scenes", "active_scene_key"]) {
      for (final writer in writers.entries) {
        test("'$key' holding ${writer.key} still starts on the defaults", () {
          writer.value(key);

          final scenesService = restart();

          expect(
            scenesService.scenes.map((scene) => scene.key),
            [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night],
          );
          expect(scenesService.activeSceneKey, SceneKeys.normal);
        });
      }
    }

    test("a readable payload survives an unreadable active scene key", () async {
      await restart().setSceneHideAppBar(SceneKeys.cinema, true);
      sharedPreferences.setBool("active_scene_key", true);

      final scenesService = restart();

      expect(scenesService.sceneByKey(SceneKeys.cinema)!.hideAppBar, true, reason: "the scenes are still readable");
      expect(scenesService.activeSceneKey, SceneKeys.normal, reason: "only the active key falls back");
    });

    test("both keys unreadable at once still starts", () {
      sharedPreferences.setInt("scenes", 1);
      sharedPreferences.setInt("active_scene_key", 2);

      expect(restart().scenes.length, 3);
    });
  });

  group("a storage failure never escapes into the caller", () {
    /// Swaps in a store whose writes throw, restoring the working one after the
    /// test so `setUp`'s clear() is not affected.
    void breakWrites() {
      final workingStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingWriteStore();
      addTearDown(() => SharedPreferencesStorePlatform.instance = workingStore);
    }

    test("activateScene reports the failure instead of throwing", () async {
      final scenesService = restart();
      breakWrites();

      expect(await scenesService.activateScene(SceneKeys.cinema), SceneActivationResult.persistenceFailed);
    });

    test("every configuration mutator reports the failure instead of throwing", () async {
      final scenesService = restart();
      breakWrites();

      expect(await scenesService.setSceneHideAppBar(SceneKeys.normal, true), SceneUpdateResult.persistenceFailed);
      expect(
        await scenesService.setSceneShowCategoryTitles(SceneKeys.night, true),
        SceneUpdateResult.persistenceFailed,
      );
      expect(
        await scenesService.setSceneWallpaperPath(SceneKeys.night, "/wallpapers/night"),
        SceneUpdateResult.persistenceFailed,
      );
      expect(await scenesService.setSceneGradientUuid(SceneKeys.night, "uuid"), SceneUpdateResult.persistenceFailed);
      expect(await scenesService.saveScene(Scene(key: "party", name: "Party")), SceneUpdateResult.persistenceFailed);
      expect(await scenesService.restoreDefaults(), SceneUpdateResult.persistenceFailed);
      expect(await scenesService.clearScenePin(SceneKeys.normal), SceneUpdateResult.persistenceFailed);
      // Last on purpose: see the test below for why a failed PIN write still
      // changes what the following calls observe.
      expect(await scenesService.setScenePin(SceneKeys.night, "1234"), SceneUpdateResult.persistenceFailed);
    });

    test("a PIN whose write failed is still honoured for the rest of the session", () async {
      // shared_preferences updates its own read cache before delegating to the
      // platform store (shared_preferences_legacy.dart `_setValue`), so a write
      // that fails is still what every later read returns until a restart.
      // Resynchronizing from storage therefore adopts the lock, and the next
      // reset fails closed rather than treating it as absent.
      final scenesService = restart();
      breakWrites();

      expect(await scenesService.setScenePin(SceneKeys.night, "1234"), SceneUpdateResult.persistenceFailed);

      expect(scenesService.sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
      expect(await scenesService.restoreDefaults(), SceneUpdateResult.pinRequired);
      expect(await scenesService.restoreDefaults(pin: "1234"), SceneUpdateResult.persistenceFailed);
    });

    test("in-memory state still agrees with what storage reports", () async {
      final scenesService = restart();
      breakWrites();

      await scenesService.setSceneHideAppBar(SceneKeys.cinema, true);
      await scenesService.activateScene(SceneKeys.night);

      final asStored = restart();
      expect(
        scenesService.sceneByKey(SceneKeys.cinema)!.hideAppBar,
        asStored.sceneByKey(SceneKeys.cinema)!.hideAppBar,
      );
      expect(scenesService.activeSceneKey, asStored.activeSceneKey);
    });

    test("a failure while locked in a protected scene does not unlock it", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.night, "1234");
      await scenesService.activateScene(SceneKeys.night);
      breakWrites();

      expect(await scenesService.clearScenePin(SceneKeys.night), SceneUpdateResult.pinRequired);
      expect(await scenesService.activateScene(SceneKeys.normal), SceneActivationResult.pinRequired);
      expect(scenesService.activeSceneRequiresPinToExit, true);
    });
  });

  group("concurrent mutators", () {
    test("do not lose each other's change", () async {
      final scenesService = restart();

      await Future.wait([
        scenesService.setSceneHideAppBar(SceneKeys.cinema, true),
        scenesService.setSceneShowCategoryTitles(SceneKeys.night, true),
        scenesService.saveScene(Scene(key: "party", name: "Party")),
      ]);

      expect(scenesService.sceneByKey(SceneKeys.cinema)!.hideAppBar, true);
      expect(scenesService.sceneByKey(SceneKeys.night)!.showCategoryTitles, true);
      expect(scenesService.sceneByKey("party"), isNotNull);

      final asStored = restart();
      expect(asStored.sceneByKey(SceneKeys.cinema)!.hideAppBar, true);
      expect(asStored.sceneByKey(SceneKeys.night)!.showCategoryTitles, true);
      expect(asStored.sceneByKey("party"), isNotNull);
    });
  });

  group("payload versions", () {
    test("a version 1 payload, written before gradients existed, still loads", () {
      sharedPreferences.setString(
        "scenes",
        jsonEncode({
          "version": 1,
          "scenes": [
            {"key": SceneKeys.normal, "name": "Normal"},
            {
              "key": SceneKeys.cinema,
              "name": "Movies",
              "wallpaperPath": "/wallpapers/cinema",
              "pinSalt": null,
              "pinHash": null,
            },
          ],
        }),
      );

      final scenesService = restart();

      expect(scenesService.scenes.map((scene) => scene.key), [SceneKeys.normal, SceneKeys.cinema]);
      expect(scenesService.sceneByKey(SceneKeys.cinema)!.name, "Movies");
      expect(scenesService.sceneByKey(SceneKeys.cinema)!.wallpaperPath, "/wallpapers/cinema");
      expect(scenesService.sceneByKey(SceneKeys.cinema)!.gradientUuid, null);
    });

    test("a version 1 PIN still unlocks after the bump", () {
      final locked = Scene(key: SceneKeys.night, name: "Night").withPin("1234").toJson()..remove("gradientUuid");
      sharedPreferences.setString("scenes", jsonEncode({"version": 1, "scenes": [locked]}));

      expect(restart().sceneByKey(SceneKeys.night)!.verifyPin("1234"), true);
    });

    test("saving rewrites the payload at the current version", () async {
      await restart().setSceneHideAppBar(SceneKeys.normal, true);

      final payload = jsonDecode(sharedPreferences.getString("scenes")!) as Map<String, dynamic>;

      expect(payload["version"], 2);
    });

    test(
      "a version 2 payload written by the previous build, still holding dockPackageNames and brightness, "
      "still loads",
      () {
        // This is the exact shape written by the build immediately before the
        // Scene reshape: it still carries the two retired fields and none of
        // the six new presentation overrides. The payload version was
        // deliberately not bumped for this reshape (see
        // ScenesService._scenesPayloadVersion), so this must load without
        // throwing and without losing the user's configuration, silently
        // ignoring the two retired keys.
        sharedPreferences.setString(
          "scenes",
          jsonEncode({
            "version": 2,
            "scenes": [
              {
                "key": SceneKeys.normal,
                "name": "Normal",
                "dockPackageNames": [],
                "brightness": null,
                "wallpaperPath": null,
                "gradientUuid": null,
                "pinSalt": null,
                "pinHash": null,
              },
              {
                "key": SceneKeys.cinema,
                "name": "Movies",
                "dockPackageNames": ["com.netflix.ninja", "com.disney.disneyplus"],
                "brightness": 100,
                "wallpaperPath": "/wallpapers/cinema",
                "gradientUuid": null,
                "pinSalt": null,
                "pinHash": null,
              },
              {
                "key": SceneKeys.night,
                "name": "Night",
                "dockPackageNames": ["com.music.tv"],
                "brightness": 10,
                "wallpaperPath": null,
                "gradientUuid": "4730aa2d-1a90-49a6-9942-ffe82f470e26",
                "pinSalt": null,
                "pinHash": null,
              },
            ],
          }),
        );

        final scenesService = restart();

        expect(scenesService.scenes.map((scene) => scene.key), [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night]);
        expect(scenesService.activeSceneKey, SceneKeys.normal);

        final cinema = scenesService.sceneByKey(SceneKeys.cinema)!;
        expect(cinema.name, "Movies");
        expect(cinema.wallpaperPath, "/wallpapers/cinema");
        // None of the retired fields exist on Scene any more; the proof that
        // they were ignored rather than causing a fallback to the defaults is
        // that the rest of the entry (name, wallpaper, gradient) survived.
        expect(cinema.hideAppBar, null);
        expect(cinema.showWatchNext, null);

        final night = scenesService.sceneByKey(SceneKeys.night)!;
        expect(night.gradientUuid, "4730aa2d-1a90-49a6-9942-ffe82f470e26");
        expect(night.disableBackgroundBlur, null);
      },
    );
  });

  group("stored data that cannot be read", () {
    /// The launcher runs on the user's only television: an unreadable payload
    /// must degrade to the defaults, never prevent a start.
    void expectFallsBackToDefaults(String storedPayload, String reason) {
      sharedPreferences.setString("scenes", storedPayload);

      final scenesService = restart();

      expect(
        scenesService.scenes.map((scene) => scene.key),
        [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night],
        reason: reason,
      );
      expect(scenesService.activeSceneKey, SceneKeys.normal, reason: reason);
    }

    test("payload that is not JSON at all", () {
      expectFallsBackToDefaults("}{ not json", "truncated or garbage payload");
    });

    test("payload that is JSON but not an object", () {
      expectFallsBackToDefaults("[]", "JSON array instead of the expected object");
    });

    test("payload without a version", () {
      expectFallsBackToDefaults(jsonEncode({"scenes": []}), "missing version field");
    });

    test("payload written by a newer version", () {
      expectFallsBackToDefaults(
        jsonEncode({"version": 99, "scenes": [Scene(key: "x", name: "X").toJson()]}),
        "unsupported future payload version",
      );
    });

    test("payload with an empty scene list", () {
      expectFallsBackToDefaults(jsonEncode({"version": 1, "scenes": []}), "no scene would leave the launcher empty");
    });

    test("payload with a malformed scene entry", () {
      expectFallsBackToDefaults(
        jsonEncode({
          "version": 1,
          "scenes": [
            Scene(key: SceneKeys.normal, name: "Normal").toJson(),
            {"name": "Broken"},
          ],
        }),
        "one broken entry must not produce a half-built configuration",
      );
    });

    test("payload with a scene entry that is not an object", () {
      expectFallsBackToDefaults(jsonEncode({"version": 1, "scenes": ["normal"]}), "scene entry is a bare string");
    });

    test("payload with duplicate scene keys", () {
      expectFallsBackToDefaults(
        jsonEncode({
          "version": 1,
          "scenes": [
            Scene(key: SceneKeys.normal, name: "Normal").toJson(),
            Scene(key: SceneKeys.normal, name: "Normal again").toJson(),
          ],
        }),
        "duplicate keys make the active scene ambiguous",
      );
    });

    test("payload with a version below the first one", () {
      expectFallsBackToDefaults(
        jsonEncode({"version": 0, "scenes": [Scene(key: "x", name: "X").toJson()]}),
        "there has never been a version 0 payload",
      );
    });

    test("payload with a scene overriding the wallpaper twice", () {
      expectFallsBackToDefaults(
        jsonEncode({
          "version": 2,
          "scenes": [
            {"key": SceneKeys.night, "name": "Night", "wallpaperPath": "/wallpapers/night", "gradientUuid": "uuid"},
          ],
        }),
        "a file and a gradient at once is ambiguous",
      );
    });

    test("payload with a half-written PIN lock", () {
      expectFallsBackToDefaults(
        jsonEncode({
          "version": 1,
          "scenes": [
            {"key": SceneKeys.night, "name": "Night", "pinHash": "abc"},
          ],
        }),
        "a lock without its salt can never be unlocked",
      );
    });

    test("a fallback is not persisted over the stored payload until the user saves", () {
      sharedPreferences.setString("scenes", "}{ not json");

      restart();

      expect(sharedPreferences.getString("scenes"), "}{ not json");
    });
  });
}

/// A store whose writes always fail, to exercise the persistence error path.
class _FailingWriteStore extends InMemorySharedPreferencesStore {
  _FailingWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception("simulated storage failure");
}
