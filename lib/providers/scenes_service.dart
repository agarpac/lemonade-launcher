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
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _scenesKey = "scenes";
const String _activeSceneKey = "active_scene_key";

/// Version of the persisted scenes payload. Bump only on a shape change, and
/// keep every older shape loadable in [ScenesService._decodeScenes].
///
/// * 1 — initial shape.
/// * 2 — added the optional `gradientUuid` wallpaper override. A version 1
///   payload loads unchanged: the missing field means "no gradient".
const int _scenesPayloadVersion = 2;

/// Outcome of a scene activation request.
enum SceneActivationResult {
  /// The scene is now the active one.
  activated,

  /// Nothing changed: the requested scene was already active.
  alreadyActive,

  /// No scene exists with the requested key.
  unknownScene,

  /// A PIN was required and none was supplied.
  pinRequired,

  /// The supplied PIN did not match.
  pinRejected,
}

/// Outcome of a request that changes a scene's configuration.
///
/// Kept separate from [SceneActivationResult] because "activated" and
/// "alreadyActive" mean nothing here; the PIN verdicts carry the same names so
/// both contracts read alike at the call site.
enum SceneUpdateResult {
  /// The change was applied and persisted.
  applied,

  /// No scene exists with the requested key; nothing changed.
  unknownScene,

  /// A PIN was required and none was supplied; nothing changed.
  pinRequired,

  /// The supplied PIN did not match; nothing changed.
  pinRejected,
}

/// Holds the scene presets and the active scene.
///
/// Activation is manual only: this service owns no timer, schedule, listener or
/// heuristic that could change the active scene on its own. The active scene
/// persists across restarts exactly as the user left it.
///
/// This service — not the UI — is the security boundary for the exit PIN. Every
/// path that could remove, replace or bypass a lock verifies it here, so a
/// future screen wired carelessly cannot defeat parental control.
class ScenesService extends ChangeNotifier {
  final SharedPreferences _sharedPreferences;

  List<Scene> _scenes = const [];
  String _activeKey = SceneKeys.normal;

  ScenesService(this._sharedPreferences) {
    _load();
  }

  /// The available scenes, in display order.
  List<Scene> get scenes => List.unmodifiable(_scenes);

  /// Key of the active scene.
  String get activeSceneKey => _activeKey;

  /// The active scene. Never null: the list always holds at least one scene.
  Scene get activeScene => _scenes.firstWhere(
        (scene) => scene.key == _activeKey,
        orElse: () => _scenes.first,
      );

  /// Whether leaving the active scene requires a PIN.
  bool get activeSceneRequiresPinToExit => activeScene.isPinProtected;

  Scene? sceneByKey(String key) {
    for (final scene in _scenes) {
      if (scene.key == key) {
        return scene;
      }
    }
    return null;
  }

  /// Checks [pin] against the active scene's PIN.
  ///
  /// Returns `true` when the active scene has no PIN: there is nothing to
  /// unlock.
  bool verifyExitPin(String pin) => activeScene.verifyPin(pin);

  /// Activates the scene identified by [key].
  ///
  /// Entering a scene is always free. Leaving a PIN-protected scene requires the
  /// matching [pin]; without it the active scene is left untouched.
  Future<SceneActivationResult> activateScene(String key, {String? pin}) async {
    if (sceneByKey(key) == null) {
      return SceneActivationResult.unknownScene;
    }
    if (key == _activeKey) {
      return SceneActivationResult.alreadyActive;
    }

    final current = activeScene;
    if (current.isPinProtected) {
      if (pin == null) {
        return SceneActivationResult.pinRequired;
      }
      if (!current.verifyPin(pin)) {
        return SceneActivationResult.pinRejected;
      }
    }

    _activeKey = key;
    await _sharedPreferences.setString(_activeSceneKey, key);
    notifyListeners();
    return SceneActivationResult.activated;
  }

  /// Persists [scene], replacing the entry with the same key or appending it.
  ///
  /// The PIN lock of an existing scene is never taken from [scene]: whatever is
  /// stored wins. Handing over a scene built with `withoutPin()` or `withPin()`
  /// therefore cannot remove or replace a lock — that goes through
  /// [setScenePin] and [clearScenePin], which verify it. A brand-new key has no
  /// stored lock to protect, so it keeps whatever it arrives with.
  Future<SceneUpdateResult> saveScene(Scene scene) async {
    final stored = sceneByKey(scene.key);
    await _replaceScene(stored == null ? scene : scene.withPinOf(stored));
    return SceneUpdateResult.applied;
  }

  /// Replaces the dock override of the scene identified by [key].
  ///
  /// An empty list clears the override, so the normal dock is shown again.
  Future<SceneUpdateResult> setSceneDockPackageNames(String key, List<String> packageNames) =>
      _updateScene(key, (scene) => scene.copyWith(dockPackageNames: packageNames));

  /// Sets the brightness override of the scene identified by [key], or clears it
  /// when [brightness] is `null`.
  Future<SceneUpdateResult> setSceneBrightness(String key, int? brightness) => _updateScene(
        key,
        (scene) => brightness == null
            ? scene.copyWith(clearBrightness: true)
            : scene.copyWith(brightness: brightness.clamp(0, 100)),
      );

  /// Sets the wallpaper file override of the scene identified by [key], or
  /// clears the wallpaper override when [wallpaperPath] is `null`.
  ///
  /// Setting a file drops any gradient override: the two are exclusive.
  Future<SceneUpdateResult> setSceneWallpaperPath(String key, String? wallpaperPath) => _updateScene(
        key,
        (scene) =>
            wallpaperPath == null ? scene.copyWith(clearWallpaper: true) : scene.copyWith(wallpaperPath: wallpaperPath),
      );

  /// Sets the gradient override of the scene identified by [key], or clears the
  /// wallpaper override when [gradientUuid] is `null`.
  ///
  /// Setting a gradient drops any wallpaper file override: the two are
  /// exclusive.
  Future<SceneUpdateResult> setSceneGradientUuid(String key, String? gradientUuid) => _updateScene(
        key,
        (scene) =>
            gradientUuid == null ? scene.copyWith(clearWallpaper: true) : scene.copyWith(gradientUuid: gradientUuid),
      );

  /// Protects the scene identified by [key] with [pin].
  ///
  /// Replacing an existing lock requires [currentPin], and so does doing this
  /// while locked inside a protected scene.
  Future<SceneUpdateResult> setScenePin(String key, String pin, {String? currentPin}) async {
    final scene = sceneByKey(key);
    if (scene == null) {
      return SceneUpdateResult.unknownScene;
    }
    final refusal = _verifyLocks(currentPin, [activeScene, scene]);
    if (refusal != null) {
      return refusal;
    }
    await _replaceScene(scene.withPin(pin));
    return SceneUpdateResult.applied;
  }

  /// Removes the PIN lock of the scene identified by [key].
  ///
  /// Requires [pin] when that scene is protected, and also when the user is
  /// currently locked inside another protected scene.
  Future<SceneUpdateResult> clearScenePin(String key, {String? pin}) async {
    final scene = sceneByKey(key);
    if (scene == null) {
      return SceneUpdateResult.unknownScene;
    }
    final refusal = _verifyLocks(pin, [activeScene, scene]);
    if (refusal != null) {
      return refusal;
    }
    await _replaceScene(scene.withoutPin());
    return SceneUpdateResult.applied;
  }

  /// Discards every customization and restores the seeded scenes, activating
  /// the normal one.
  ///
  /// This erases every PIN, so [pin] must satisfy every protected scene. When
  /// two scenes carry different PINs the call is refused; clear them one by one
  /// first. Failing closed is deliberate: a reset must never be the way around
  /// a parental lock.
  Future<SceneUpdateResult> restoreDefaults({String? pin}) async {
    final refusal = _verifyLocks(pin, _scenes);
    if (refusal != null) {
      return refusal;
    }

    _scenes = Scene.defaults();
    _activeKey = SceneKeys.normal;
    await _persistScenes();
    await _sharedPreferences.setString(_activeSceneKey, _activeKey);
    notifyListeners();
    return SceneUpdateResult.applied;
  }

  /// Returns the refusal to hand back to the caller, or `null` when [pin]
  /// satisfies every protected scene among [guarded].
  ///
  /// Duplicate keys are collapsed, so guarding "the active scene and the target
  /// scene" costs a single verification when they are the same scene.
  SceneUpdateResult? _verifyLocks(String? pin, Iterable<Scene> guarded) {
    final locked = <String, Scene>{};
    for (final scene in guarded) {
      if (scene.isPinProtected) {
        locked[scene.key] = scene;
      }
    }
    if (locked.isEmpty) {
      return null;
    }
    if (pin == null) {
      return SceneUpdateResult.pinRequired;
    }
    for (final scene in locked.values) {
      if (!scene.verifyPin(pin)) {
        return SceneUpdateResult.pinRejected;
      }
    }
    return null;
  }

  /// Applies [change] to the stored scene identified by [key].
  ///
  /// [change] receives the stored scene, so the PIN lock rides along untouched.
  Future<SceneUpdateResult> _updateScene(String key, Scene Function(Scene scene) change) async {
    final scene = sceneByKey(key);
    if (scene == null) {
      return SceneUpdateResult.unknownScene;
    }
    await _replaceScene(change(scene));
    return SceneUpdateResult.applied;
  }

  /// Writes [scene] verbatim. Private: every public caller has already either
  /// preserved or verified the PIN lock.
  Future<void> _replaceScene(Scene scene) async {
    final scenes = List<Scene>.from(_scenes);
    final index = scenes.indexWhere((existing) => existing.key == scene.key);
    if (index >= 0) {
      scenes[index] = scene;
    } else {
      scenes.add(scene);
    }
    _scenes = scenes;
    await _persistScenes();
    notifyListeners();
  }

  /// Loads the stored scenes, seeding the defaults on first run.
  ///
  /// This runs on the launcher's startup path on the user's only television, so
  /// it never throws: anything unreadable falls back to the defaults.
  void _load() {
    _scenes = _decodeScenes(_sharedPreferences.getString(_scenesKey));

    final storedActiveKey = _sharedPreferences.getString(_activeSceneKey);
    _activeKey = _scenes.any((scene) => scene.key == storedActiveKey) ? storedActiveKey! : _scenes.first.key;
  }

  List<Scene> _decodeScenes(String? payload) {
    if (payload == null || payload.isEmpty) {
      return Scene.defaults();
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Stored scenes payload is not an object");
      }
      final version = decoded["version"];
      if (version is! int || version < 1 || version > _scenesPayloadVersion) {
        throw FormatException("Unsupported scenes payload version: $version");
      }
      final rawScenes = decoded["scenes"];
      if (rawScenes is! List) {
        throw const FormatException("Stored scenes payload has no scene list");
      }
      final scenes = <Scene>[];
      for (final rawScene in rawScenes) {
        if (rawScene is! Map<String, dynamic>) {
          throw const FormatException("Stored scene entry is not an object");
        }
        scenes.add(Scene.fromJson(rawScene));
      }
      if (scenes.isEmpty) {
        throw const FormatException("Stored scenes payload is empty");
      }
      final keys = scenes.map((scene) => scene.key).toSet();
      if (keys.length != scenes.length) {
        throw const FormatException("Stored scenes payload has duplicate keys");
      }
      return scenes;
    } catch (e) {
      // Never mention the payload itself here: it carries PIN salts and hashes.
      debugPrint("ScenesService: unreadable stored scenes, falling back to defaults ($e)");
      return Scene.defaults();
    }
  }

  Future<void> _persistScenes() async {
    await _sharedPreferences.setString(
      _scenesKey,
      jsonEncode({
        "version": _scenesPayloadVersion,
        "scenes": _scenes.map((scene) => scene.toJson()).toList(),
      }),
    );
  }
}
