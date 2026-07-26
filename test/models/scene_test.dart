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
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("defaults", () {
    test("seeds the three scenes from the PRD with stable keys", () {
      final defaults = Scene.defaults();

      expect(defaults.map((scene) => scene.key), [SceneKeys.normal, SceneKeys.cinema, SceneKeys.night]);
      expect(defaults.map((scene) => scene.name), ["Normal", "Cinema", "Night"]);
    });

    test("normal overrides nothing", () {
      final normal = Scene.defaults().firstWhere((scene) => scene.key == SceneKeys.normal);

      expect(normal.hideAppBar, null);
      expect(normal.showWatchNext, null);
      expect(normal.showAppNames, null);
      expect(normal.disableBackgroundBlur, null);
      expect(normal.showCategoryTitles, null);
      expect(normal.accentColorHex, null);
      expect(normal.overridesWallpaper, false);
    });

    test("cinema hides the app bar, watch next and app names", () {
      final cinema = Scene.defaults().firstWhere((scene) => scene.key == SceneKeys.cinema);

      expect(cinema.hideAppBar, true);
      expect(cinema.showWatchNext, false);
      expect(cinema.showAppNames, false);
      expect(cinema.disableBackgroundBlur, null);
      expect(cinema.showCategoryTitles, null);
      expect(cinema.accentColorHex, null);
    });

    test("night only disables the background blur", () {
      final night = Scene.defaults().firstWhere((scene) => scene.key == SceneKeys.night);

      expect(night.disableBackgroundBlur, true);
      expect(night.hideAppBar, null);
      expect(night.showWatchNext, null);
      expect(night.showAppNames, null);
      expect(night.showCategoryTitles, null);
      expect(night.accentColorHex, null);
    });

    test("leaves the wallpaper and the PIN untouched", () {
      for (final scene in Scene.defaults()) {
        expect(scene.overridesWallpaper, false, reason: "${scene.key} should not override the wallpaper");
        expect(scene.isPinProtected, false, reason: "${scene.key} should not ship with a PIN");
      }
    });
  });

  group("PIN", () {
    test("accepts the right PIN and rejects a wrong one", () {
      final scene = Scene(key: SceneKeys.night, name: "Night").withPin("1234");

      expect(scene.isPinProtected, true);
      expect(scene.verifyPin("1234"), true);
      expect(scene.verifyPin("4321"), false);
      expect(scene.verifyPin(""), false);
    });

    test("is never stored in plain text", () {
      final scene = Scene(key: SceneKeys.night, name: "Night").withPin("1234");

      expect(jsonEncode(scene.toJson()), isNot(contains("1234")));
    });

    test("uses a different salt per scene, so the same PIN yields a different hash", () {
      final first = Scene(key: SceneKeys.night, name: "Night").withPin("1234");
      final second = Scene(key: SceneKeys.cinema, name: "Cinema").withPin("1234");

      expect(first.toJson()["pinSalt"], isNot(second.toJson()["pinSalt"]));
      expect(first.toJson()["pinHash"], isNot(second.toJson()["pinHash"]));
      expect(second.verifyPin("1234"), true);
    });

    test("an unprotected scene needs no PIN to be left", () {
      final scene = Scene(key: SceneKeys.normal, name: "Normal");

      expect(scene.isPinProtected, false);
      expect(scene.verifyPin("anything"), true);
    });

    test("withoutPin removes the lock but keeps the rest of the configuration", () {
      final scene = Scene(
        key: SceneKeys.night,
        name: "Night",
        hideAppBar: true,
        disableBackgroundBlur: true,
        wallpaperPath: "/wallpapers/night",
      ).withPin("1234");

      final unlocked = scene.withoutPin();

      expect(unlocked.isPinProtected, false);
      expect(unlocked.hideAppBar, true);
      expect(unlocked.disableBackgroundBlur, true);
      expect(unlocked.wallpaperPath, "/wallpapers/night");
    });

    test("a PIN survives a JSON round-trip", () {
      final scene = Scene(key: SceneKeys.night, name: "Night").withPin("1234");

      final restored = Scene.fromJson(jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>);

      expect(restored.isPinProtected, true);
      expect(restored.verifyPin("1234"), true);
      expect(restored.verifyPin("0000"), false);
    });
  });

  group("JSON", () {
    test("round-trips every field", () {
      final scene = Scene(
        key: SceneKeys.cinema,
        name: "Cinema",
        hideAppBar: true,
        showWatchNext: false,
        showAppNames: false,
        disableBackgroundBlur: true,
        showCategoryTitles: false,
        accentColorHex: "7C4DFF",
        wallpaperPath: "/wallpapers/cinema",
      );

      final restored = Scene.fromJson(jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>);

      expect(restored.key, SceneKeys.cinema);
      expect(restored.name, "Cinema");
      expect(restored.hideAppBar, true);
      expect(restored.showWatchNext, false);
      expect(restored.showAppNames, false);
      expect(restored.disableBackgroundBlur, true);
      expect(restored.showCategoryTitles, false);
      expect(restored.accentColorHex, "7C4DFF");
      expect(restored.wallpaperPath, "/wallpapers/cinema");
      expect(restored.isPinProtected, false);
    });

    test("treats every missing presentation override as no override", () {
      final restored = Scene.fromJson({"key": SceneKeys.normal, "name": "Normal"});

      expect(restored.hideAppBar, null);
      expect(restored.showWatchNext, null);
      expect(restored.showAppNames, null);
      expect(restored.disableBackgroundBlur, null);
      expect(restored.showCategoryTitles, null);
      expect(restored.accentColorHex, null);
      expect(restored.wallpaperPath, null);
    });

    test("ignores the retired dockPackageNames and brightness fields instead of rejecting the entry", () {
      // A payload written by the build that still had these two fields must
      // keep loading after they are removed from the model: see the PRD,
      // section 9.1.4, and ScenesService._scenesPayloadVersion.
      final restored = Scene.fromJson({
        "key": SceneKeys.cinema,
        "name": "Cinema",
        "dockPackageNames": ["com.netflix.ninja"],
        "brightness": 100,
        "wallpaperPath": "/wallpapers/cinema",
      });

      expect(restored.key, SceneKeys.cinema);
      expect(restored.name, "Cinema");
      expect(restored.wallpaperPath, "/wallpapers/cinema");
      expect(restored.hideAppBar, null);
    });

    test("rejects an entry without a usable key or name", () {
      expect(() => Scene.fromJson({"name": "Normal"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "", "name": "Normal"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": SceneKeys.normal}), throwsFormatException);
      expect(() => Scene.fromJson({"key": SceneKeys.normal, "name": 7}), throwsFormatException);
    });

    test("rejects a half-written PIN lock", () {
      expect(
        () => Scene.fromJson({"key": SceneKeys.night, "name": "Night", "pinSalt": "c2FsdA=="}),
        throwsFormatException,
      );
      expect(
        () => Scene.fromJson({"key": SceneKeys.night, "name": "Night", "pinHash": "abc"}),
        throwsFormatException,
      );
    });

    test("rejects fields of the wrong type", () {
      expect(() => Scene.fromJson({"key": "a", "name": "A", "wallpaperPath": 3}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "hideAppBar": "yes"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "showWatchNext": 1}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "showAppNames": "no"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "disableBackgroundBlur": "no"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "showCategoryTitles": "no"}), throwsFormatException);
      expect(() => Scene.fromJson({"key": "a", "name": "A", "accentColorHex": 7}), throwsFormatException);
    });

    test("never leaks the PIN hash in an error message", () {
      try {
        Scene.fromJson({"key": "", "name": "Kids", "pinSalt": "c2FsdA==", "pinHash": "deadbeef"});
        fail("expected a FormatException");
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains("deadbeef")));
        expect(e.toString(), isNot(contains("c2FsdA==")));
      }
    });
  });

  group("copyWith", () {
    test("replaces the given fields and keeps the others", () {
      final scene = Scene(key: SceneKeys.cinema, name: "Cinema", hideAppBar: true).withPin("1234");

      final updated = scene.copyWith(name: "Movies", showWatchNext: false);

      expect(updated.key, SceneKeys.cinema);
      expect(updated.name, "Movies");
      expect(updated.hideAppBar, true);
      expect(updated.showWatchNext, false);
      expect(updated.verifyPin("1234"), true);
    });

    test("clears the optional overrides only when asked to", () {
      final scene = Scene(
        key: SceneKeys.night,
        name: "Night",
        hideAppBar: true,
        showWatchNext: false,
        showAppNames: true,
        disableBackgroundBlur: true,
        showCategoryTitles: false,
        accentColorHex: "00BFA5",
        wallpaperPath: "/wallpapers/night",
      );

      expect(scene.copyWith().hideAppBar, true);
      expect(scene.copyWith(clearHideAppBar: true).hideAppBar, null);
      expect(scene.copyWith(clearHideAppBar: true).wallpaperPath, "/wallpapers/night");

      expect(scene.copyWith(clearShowWatchNext: true).showWatchNext, null);
      expect(scene.copyWith(clearShowAppNames: true).showAppNames, null);
      expect(scene.copyWith(clearDisableBackgroundBlur: true).disableBackgroundBlur, null);
      expect(scene.copyWith(clearShowCategoryTitles: true).showCategoryTitles, null);
      expect(scene.copyWith(clearAccentColorHex: true).accentColorHex, null);

      expect(scene.copyWith(clearWallpaper: true).wallpaperPath, null);
      expect(scene.copyWith(clearWallpaper: true).hideAppBar, true);
    });

    test("a bool override can be flipped from true to false and back", () {
      final scene = Scene(key: SceneKeys.cinema, name: "Cinema", showAppNames: true);

      expect(scene.copyWith(showAppNames: false).showAppNames, false);
      expect(scene.copyWith(showAppNames: false).copyWith(showAppNames: true).showAppNames, true);
    });
  });

  group("wallpaper overrides", () {
    test("a scene can override the wallpaper with a gradient", () {
      final scene = Scene(key: SceneKeys.night, name: "Night", gradientUuid: "4730aa2d-1a90-49a6-9942-ffe82f470e26");

      expect(scene.gradientUuid, "4730aa2d-1a90-49a6-9942-ffe82f470e26");
      expect(scene.wallpaperPath, null);
      expect(scene.overridesWallpaper, true);
    });

    test("a scene can override the wallpaper with a file", () {
      final scene = Scene(key: SceneKeys.cinema, name: "Cinema", wallpaperPath: "/wallpapers/cinema");

      expect(scene.overridesWallpaper, true);
      expect(scene.gradientUuid, null);
    });

    test("a scene with neither overrides nothing", () {
      expect(Scene(key: SceneKeys.normal, name: "Normal").overridesWallpaper, false);
    });

    test("the constructor refuses a file and a gradient at the same time", () {
      expect(
        () => Scene(key: SceneKeys.night, name: "Night", wallpaperPath: "/wallpapers/night", gradientUuid: "uuid"),
        throwsArgumentError,
      );
    });

    test("copyWith refuses a file and a gradient at the same time", () {
      final scene = Scene(key: SceneKeys.night, name: "Night");

      expect(() => scene.copyWith(wallpaperPath: "/wallpapers/night", gradientUuid: "uuid"), throwsArgumentError);
    });

    test("copyWith swaps one wallpaper override for the other instead of holding both", () {
      final withFile = Scene(key: SceneKeys.night, name: "Night", wallpaperPath: "/wallpapers/night");

      final withGradient = withFile.copyWith(gradientUuid: "uuid");
      expect(withGradient.wallpaperPath, null);
      expect(withGradient.gradientUuid, "uuid");

      final backToFile = withGradient.copyWith(wallpaperPath: "/wallpapers/night");
      expect(backToFile.gradientUuid, null);
      expect(backToFile.wallpaperPath, "/wallpapers/night");
    });

    test("clearWallpaper clears whichever override is set", () {
      final withFile = Scene(key: SceneKeys.cinema, name: "Cinema", wallpaperPath: "/wallpapers/cinema");
      final withGradient = Scene(key: SceneKeys.night, name: "Night", gradientUuid: "uuid");

      expect(withFile.copyWith(clearWallpaper: true).overridesWallpaper, false);
      expect(withGradient.copyWith(clearWallpaper: true).overridesWallpaper, false);
      expect(withGradient.copyWith(clearWallpaper: true).gradientUuid, null);
    });

    test("a gradient survives a JSON round-trip", () {
      final scene = Scene(key: SceneKeys.night, name: "Night", disableBackgroundBlur: true, gradientUuid: "uuid");

      final restored = Scene.fromJson(jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>);

      expect(restored.gradientUuid, "uuid");
      expect(restored.wallpaperPath, null);
      expect(restored.disableBackgroundBlur, true);
    });

    test("a payload written before gradients existed still loads", () {
      final restored = Scene.fromJson({
        "key": SceneKeys.cinema,
        "name": "Cinema",
        "wallpaperPath": "/wallpapers/cinema",
        "pinSalt": null,
        "pinHash": null,
      });

      expect(restored.gradientUuid, null);
      expect(restored.wallpaperPath, "/wallpapers/cinema");
      expect(restored.overridesWallpaper, true);
    });

    test("fromJson rejects an entry holding both overrides", () {
      expect(
        () => Scene.fromJson({
          "key": SceneKeys.night,
          "name": "Night",
          "wallpaperPath": "/wallpapers/night",
          "gradientUuid": "uuid",
        }),
        throwsFormatException,
      );
    });

    test("fromJson rejects a gradient of the wrong type", () {
      expect(() => Scene.fromJson({"key": "a", "name": "A", "gradientUuid": 7}), throwsFormatException);
    });

    test("fromJson treats a blank override as not set", () {
      final restored = Scene.fromJson({"key": "a", "name": "A", "wallpaperPath": "", "gradientUuid": ""});

      expect(restored.overridesWallpaper, false);
    });
  });

  group("withPinOf", () {
    test("transfers the lock of another scene", () {
      final locked = Scene(key: SceneKeys.night, name: "Night").withPin("1234");
      final unlocked = Scene(key: SceneKeys.night, name: "Night", disableBackgroundBlur: true);

      final result = unlocked.withPinOf(locked);

      expect(result.isPinProtected, true);
      expect(result.verifyPin("1234"), true);
      expect(result.disableBackgroundBlur, true, reason: "the rest of the configuration must be the receiver's");
    });

    test("transfers the absence of a lock too", () {
      final locked = Scene(key: SceneKeys.night, name: "Night").withPin("1234");
      final unlocked = Scene(key: SceneKeys.night, name: "Night");

      final result = locked.withPinOf(unlocked);

      expect(result.isPinProtected, false);
    });

    test("keeps both wallpaper override kinds intact", () {
      final gradient = Scene(key: SceneKeys.night, name: "Night", gradientUuid: "uuid");
      final file = Scene(key: SceneKeys.cinema, name: "Cinema", wallpaperPath: "/wallpapers/cinema");

      expect(gradient.withPinOf(file).gradientUuid, "uuid");
      expect(file.withPinOf(gradient).wallpaperPath, "/wallpapers/cinema");
    });
  });
}
