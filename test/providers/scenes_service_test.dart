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
    test("seeds the four default scenes", () {
      final scenesService = restart();

      expect(
        scenesService.scenes.map((scene) => scene.key),
        [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night, SceneKeys.kids],
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
      expect(scenesService.activeScene.brightness, 100);
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
    /// Locks the kids scene with [pin] and activates it, as the user would.
    Future<ScenesService> lockedInKidsScene(String pin) async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, pin);
      await scenesService.activateScene(SceneKeys.kids);
      return scenesService;
    }

    test("entering a PIN-protected scene requires no PIN", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(scenesService.activeSceneKey, SceneKeys.kids);
      expect(scenesService.activeSceneRequiresPinToExit, true);
    });

    test("leaving without a PIN is refused", () async {
      final scenesService = await lockedInKidsScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal);

      expect(result, SceneActivationResult.pinRequired);
      expect(scenesService.activeSceneKey, SceneKeys.kids);
    });

    test("leaving with a wrong PIN is refused", () async {
      final scenesService = await lockedInKidsScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal, pin: "4321");

      expect(result, SceneActivationResult.pinRejected);
      expect(scenesService.activeSceneKey, SceneKeys.kids);
    });

    test("leaving with the right PIN is accepted", () async {
      final scenesService = await lockedInKidsScene("1234");

      final result = await scenesService.activateScene(SceneKeys.normal, pin: "1234");

      expect(result, SceneActivationResult.activated);
      expect(scenesService.activeSceneKey, SceneKeys.normal);
    });

    test("verifyExitPin checks the active scene", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(scenesService.verifyExitPin("1234"), true);
      expect(scenesService.verifyExitPin("0000"), false);
    });

    test("the PIN survives a restart and is never stored in plain text", () async {
      await restart().setScenePin(SceneKeys.kids, "1234");

      expect(sharedPreferences.getString("scenes"), isNot(contains("1234")));

      final afterRestart = restart();

      expect(afterRestart.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
      expect(afterRestart.sceneByKey(SceneKeys.kids)!.verifyPin("9999"), false);
    });

    test("clearScenePin removes the lock when the PIN is supplied", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.kids, pin: "1234"), SceneUpdateResult.applied);

      expect(scenesService.activeSceneRequiresPinToExit, false);
      expect(await scenesService.activateScene(SceneKeys.normal), SceneActivationResult.activated);
    });
  });

  group("the PIN cannot be removed or reset away without it", () {
    /// Locks the kids scene with [pin] and activates it, as the user would.
    Future<ScenesService> lockedInKidsScene(String pin) async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, pin);
      await scenesService.activateScene(SceneKeys.kids);
      return scenesService;
    }

    test("clearScenePin without a PIN is refused and the lock survives a restart", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.kids), SceneUpdateResult.pinRequired);

      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, true);
      expect(restart().sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
    });

    test("clearScenePin with a wrong PIN is refused", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.clearScenePin(SceneKeys.kids, pin: "4321"), SceneUpdateResult.pinRejected);

      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, true);
    });

    test("clearScenePin still requires the PIN from outside the protected scene", () async {
      final scenesService = await lockedInKidsScene("1234");
      await scenesService.activateScene(SceneKeys.normal, pin: "1234");

      expect(scenesService.activeSceneRequiresPinToExit, false);
      expect(await scenesService.clearScenePin(SceneKeys.kids), SceneUpdateResult.pinRequired);
      expect(await scenesService.clearScenePin(SceneKeys.kids, pin: "0000"), SceneUpdateResult.pinRejected);
      expect(await scenesService.clearScenePin(SceneKeys.kids, pin: "1234"), SceneUpdateResult.applied);
    });

    test("clearScenePin on an unprotected scene needs no PIN", () async {
      final scenesService = restart();

      expect(await scenesService.clearScenePin(SceneKeys.normal), SceneUpdateResult.applied);
    });

    test("setScenePin cannot replace an existing PIN without the current one", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.setScenePin(SceneKeys.kids, "9999"), SceneUpdateResult.pinRequired);
      expect(await scenesService.setScenePin(SceneKeys.kids, "9999", currentPin: "0000"), SceneUpdateResult.pinRejected);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);

      expect(await scenesService.setScenePin(SceneKeys.kids, "9999", currentPin: "1234"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("9999"), true);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), false);
    });

    test("setScenePin on an unprotected scene needs no current PIN", () async {
      final scenesService = restart();

      expect(await scenesService.setScenePin(SceneKeys.kids, "1234"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
    });

    test("setScenePin on another scene is refused while locked inside a protected one", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.setScenePin(SceneKeys.night, "5555"), SceneUpdateResult.pinRequired);
      expect(scenesService.sceneByKey(SceneKeys.night)!.isPinProtected, false);
    });

    test("restoreDefaults without the PIN is refused and the lock survives", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.restoreDefaults(), SceneUpdateResult.pinRequired);

      expect(scenesService.activeSceneKey, SceneKeys.kids);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
      expect(restart().sceneByKey(SceneKeys.kids)!.isPinProtected, true);
    });

    test("restoreDefaults with a wrong PIN is refused", () async {
      final scenesService = await lockedInKidsScene("1234");

      expect(await scenesService.restoreDefaults(pin: "4321"), SceneUpdateResult.pinRejected);

      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, true);
    });

    test("restoreDefaults is refused from outside the protected scene as well", () async {
      final scenesService = await lockedInKidsScene("1234");
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
      await scenesService.setScenePin(SceneKeys.kids, "1111");
      await scenesService.setScenePin(SceneKeys.night, "2222");

      expect(await scenesService.restoreDefaults(pin: "1111"), SceneUpdateResult.pinRejected);
      expect(await scenesService.restoreDefaults(pin: "2222"), SceneUpdateResult.pinRejected);

      // Not a dead end: clearing the locks one by one, each with its own PIN,
      // leaves a reachable path to the reset.
      expect(await scenesService.clearScenePin(SceneKeys.night, pin: "2222"), SceneUpdateResult.applied);
      expect(await scenesService.restoreDefaults(pin: "1111"), SceneUpdateResult.applied);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, false);
    });
  });

  group("saveScene cannot be used to bypass the PIN", () {
    test("a scene handed over with the lock stripped does not remove it", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, "1234");

      final stripped = scenesService.sceneByKey(SceneKeys.kids)!.withoutPin();
      await scenesService.saveScene(stripped);

      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, true);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
      expect(restart().sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
    });

    test("a scene handed over with a replaced lock keeps the stored one", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, "1234");

      final relocked = scenesService.sceneByKey(SceneKeys.kids)!.withPin("9999");
      await scenesService.saveScene(relocked);

      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.verifyPin("9999"), false);
    });

    test("a scene rebuilt from scratch cannot smuggle a lock onto an existing key", () async {
      final scenesService = restart();

      await scenesService.saveScene(Scene(key: SceneKeys.normal, name: "Normal").withPin("1234"));

      expect(scenesService.sceneByKey(SceneKeys.normal)!.isPinProtected, false);
      expect(scenesService.activeSceneRequiresPinToExit, false);
    });

    test("configuration changes still go through while the lock is preserved", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, "1234");

      await scenesService.saveScene(
        scenesService.sceneByKey(SceneKeys.kids)!.withoutPin().copyWith(
              name: "Children",
              brightness: 35,
              dockPackageNames: const ["com.kids.tv"],
            ),
      );

      final stored = restart().sceneByKey(SceneKeys.kids)!;
      expect(stored.name, "Children");
      expect(stored.brightness, 35);
      expect(stored.dockPackageNames, ["com.kids.tv"]);
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
              dockPackageNames: const ["com.netflix.ninja", "com.disney.disneyplus"],
              brightness: 90,
              wallpaperPath: "/wallpapers/cinema",
            ),
      );

      final restored = restart().sceneByKey(SceneKeys.cinema)!;

      expect(restored.name, "Movies");
      expect(restored.dockPackageNames, ["com.netflix.ninja", "com.disney.disneyplus"]);
      expect(restored.brightness, 90);
      expect(restored.wallpaperPath, "/wallpapers/cinema");
    });

    test("saving an unknown key appends a new scene", () async {
      final scenesService = restart();

      await scenesService.saveScene(Scene(key: "party", name: "Party", brightness: 70));

      expect(scenesService.scenes.length, 5);
      expect(restart().sceneByKey("party")!.brightness, 70);
    });

    test("setSceneDockPackageNames sets and clears the dock override", () async {
      final scenesService = restart();

      await scenesService.setSceneDockPackageNames(SceneKeys.kids, ["com.kids.tv"]);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.overridesDock, true);

      await scenesService.setSceneDockPackageNames(SceneKeys.kids, []);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.overridesDock, false);
    });

    test("setSceneBrightness sets, clamps and clears the brightness override", () async {
      final scenesService = restart();

      await scenesService.setSceneBrightness(SceneKeys.normal, 55);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.brightness, 55);

      await scenesService.setSceneBrightness(SceneKeys.normal, 200);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.brightness, 100);

      await scenesService.setSceneBrightness(SceneKeys.normal, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.brightness, null);
      expect(scenesService.sceneByKey(SceneKeys.normal)!.overridesBrightness, false);
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

      expect(await scenesService.setSceneBrightness("does-not-exist", 50), SceneUpdateResult.unknownScene);
      expect(
        await scenesService.setSceneDockPackageNames("does-not-exist", ["com.kids.tv"]),
        SceneUpdateResult.unknownScene,
      );
      expect(
        await scenesService.setSceneWallpaperPath("does-not-exist", "/wallpapers/none"),
        SceneUpdateResult.unknownScene,
      );
      expect(await scenesService.setSceneGradientUuid("does-not-exist", "uuid"), SceneUpdateResult.unknownScene);
      expect(await scenesService.setScenePin("does-not-exist", "1234"), SceneUpdateResult.unknownScene);
      expect(await scenesService.clearScenePin("does-not-exist"), SceneUpdateResult.unknownScene);

      expect(scenesService.scenes.length, 4);
      expect(notifications, 0);
    });

    test("restoreDefaults discards customizations and activates the normal scene", () async {
      final scenesService = restart();
      await scenesService.setScenePin(SceneKeys.kids, "1234");
      await scenesService.setSceneDockPackageNames(SceneKeys.kids, ["com.kids.tv"]);
      await scenesService.activateScene(SceneKeys.cinema);

      expect(await scenesService.restoreDefaults(pin: "1234"), SceneUpdateResult.applied);

      expect(scenesService.activeSceneKey, SceneKeys.normal);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.isPinProtected, false);
      expect(scenesService.sceneByKey(SceneKeys.kids)!.overridesDock, false);
      expect(restart().sceneByKey(SceneKeys.kids)!.overridesDock, false);
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

    test("no default scene seeds a gradient", () {
      for (final scene in restart().scenes) {
        expect(scene.gradientUuid, null, reason: "${scene.key} must not seed a gradient");
      }
    });
  });

  group("payload versions", () {
    test("a version 1 payload, written before gradients existed, still loads", () {
      sharedPreferences.setString(
        "scenes",
        jsonEncode({
          "version": 1,
          "scenes": [
            {"key": SceneKeys.normal, "name": "Normal", "dockPackageNames": [], "brightness": null},
            {
              "key": SceneKeys.cinema,
              "name": "Movies",
              "dockPackageNames": ["com.netflix.ninja"],
              "brightness": 100,
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
      expect(scenesService.sceneByKey(SceneKeys.cinema)!.dockPackageNames, ["com.netflix.ninja"]);
    });

    test("a version 1 PIN still unlocks after the bump", () {
      final locked = Scene(key: SceneKeys.kids, name: "Kids").withPin("1234").toJson()..remove("gradientUuid");
      sharedPreferences.setString("scenes", jsonEncode({"version": 1, "scenes": [locked]}));

      expect(restart().sceneByKey(SceneKeys.kids)!.verifyPin("1234"), true);
    });

    test("saving rewrites the payload at the current version", () async {
      await restart().setSceneBrightness(SceneKeys.normal, 50);

      final payload = jsonDecode(sharedPreferences.getString("scenes")!) as Map<String, dynamic>;

      expect(payload["version"], 2);
    });
  });

  group("stored data that cannot be read", () {
    /// The launcher runs on the user's only television: an unreadable payload
    /// must degrade to the defaults, never prevent a start.
    void expectFallsBackToDefaults(String storedPayload, String reason) {
      sharedPreferences.setString("scenes", storedPayload);

      final scenesService = restart();

      expect(
        scenesService.scenes.map((scene) => scene.key),
        [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night, SceneKeys.kids],
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
            {"key": SceneKeys.kids, "name": "Kids", "pinHash": "abc"},
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
