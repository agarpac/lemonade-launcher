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

  /// The change could not be written to storage. In-memory state has been
  /// resynchronized with what storage reports, so nothing is left half-applied.
  persistenceFailed,
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

  /// The change could not be written to storage. In-memory state has been
  /// resynchronized with what storage reports, so nothing is left half-applied.
  persistenceFailed,
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

    // Adopted synchronously, before the first await. See [_replaceScene].
    _activeKey = key;
    notifyListeners();
    if (!await _persistString(_activeSceneKey, key)) {
      _resyncWithStoredState();
      return SceneActivationResult.persistenceFailed;
    }
    return SceneActivationResult.activated;
  }

  /// Persists [scene], replacing the entry with the same key or appending it.
  ///
  /// The PIN lock of an existing scene is never taken from [scene]: whatever is
  /// stored wins. Handing over a scene built with `withoutPin()` or `withPin()`
  /// therefore cannot remove or replace a lock — that goes through
  /// [setScenePin] and [clearScenePin], which verify it. A brand-new key has no
  /// stored lock to protect, so it keeps whatever it arrives with.
  Future<SceneUpdateResult> saveScene(Scene scene) {
    final stored = sceneByKey(scene.key);
    return _replaceScene(stored == null ? scene : scene.withPinOf(stored));
  }

  /// Replaces the dock override of the scene identified by [key].
  ///
  /// An empty list clears the override, so the normal dock is shown again.
  Future<SceneUpdateResult> setSceneDockPackageNames(String key, List<String> packageNames) =>
      _updateScene(key, (scene) => scene.copyWith(dockPackageNames: packageNames));

  /// Sets the brightness override of the scene identified by [key], or clears it
  /// when [brightness] is `null`.
  ///
  /// Out-of-range values are clamped by [Scene] itself.
  Future<SceneUpdateResult> setSceneBrightness(String key, int? brightness) => _updateScene(
        key,
        (scene) => brightness == null ? scene.copyWith(clearBrightness: true) : scene.copyWith(brightness: brightness),
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
    return _replaceScene(scene.withPin(pin));
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
    return _replaceScene(scene.withoutPin());
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

    final defaults = Scene.defaults();
    // Adopted synchronously, before the first await. See [_replaceScene].
    _scenes = defaults;
    _activeKey = SceneKeys.normal;
    notifyListeners();
    // Short-circuits: the second write is skipped when the first one failed.
    if (!await _persistString(_scenesKey, _encodeScenes(defaults)) ||
        !await _persistString(_activeSceneKey, SceneKeys.normal)) {
      _resyncWithStoredState();
      return SceneUpdateResult.persistenceFailed;
    }
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
  Future<SceneUpdateResult> _updateScene(String key, Scene Function(Scene scene) change) {
    final scene = sceneByKey(key);
    if (scene == null) {
      return Future.value(SceneUpdateResult.unknownScene);
    }
    return _replaceScene(change(scene));
  }

  /// Writes [scene] verbatim. Private: every public caller has already either
  /// preserved or verified the PIN lock.
  ///
  /// The whole read-modify-assign runs synchronously, before the first `await`.
  /// Dart's run-to-completion then guarantees a second concurrent mutator reads
  /// this version rather than a stale snapshot, so no change is lost. Deferring
  /// the assignment until after the write would reintroduce exactly that race,
  /// which is why a failed write resynchronizes from storage instead of rolling
  /// back to a snapshot that a concurrent caller may already have superseded.
  Future<SceneUpdateResult> _replaceScene(Scene scene) async {
    final scenes = List<Scene>.from(_scenes);
    final index = scenes.indexWhere((existing) => existing.key == scene.key);
    if (index >= 0) {
      scenes[index] = scene;
    } else {
      scenes.add(scene);
    }
    _scenes = scenes;
    notifyListeners();

    if (!await _persistString(_scenesKey, _encodeScenes(scenes))) {
      _resyncWithStoredState();
      return SceneUpdateResult.persistenceFailed;
    }
    return SceneUpdateResult.applied;
  }

  /// Loads the stored scenes, seeding the defaults on first run.
  ///
  /// This runs on the launcher's startup path on the user's only television, so
  /// it never throws: anything unreadable falls back to the defaults. That
  /// includes values of the wrong type — `SharedPreferences.getString` casts,
  /// and the planned backup/restore feature will let a hand-edited file put a
  /// bool or a list under these keys. Stored values are untrusted input.
  void _load() {
    try {
      _scenes = _decodeScenes(_readString(_scenesKey));

      final storedActiveKey = _readString(_activeSceneKey);
      _activeKey = _scenes.any((scene) => scene.key == storedActiveKey) ? storedActiveKey! : _scenes.first.key;
    } catch (e) {
      // Belt and braces: nothing above is expected to throw, and if it ever
      // does, starting with the defaults beats not starting at all.
      debugPrint("ScenesService: could not load the stored scenes, falling back to defaults ($e)");
      _scenes = Scene.defaults();
      _activeKey = SceneKeys.normal;
    }
    if (_scenes.isEmpty) {
      // Invariant relied upon by [activeScene] and by _load's own fallback.
      _scenes = Scene.defaults();
      _activeKey = SceneKeys.normal;
    }
  }

  /// Reads a string value, treating a value of any other type as absent.
  String? _readString(String key) {
    try {
      return _sharedPreferences.getString(key);
    } catch (e) {
      debugPrint("ScenesService: stored value under '$key' is not a string, ignoring it ($e)");
      return null;
    }
  }

  /// Rebuilds in-memory state from storage, so a failed write can never leave
  /// the service reporting something storage does not.
  void _resyncWithStoredState() {
    _load();
    notifyListeners();
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

  String _encodeScenes(List<Scene> scenes) => jsonEncode({
        "version": _scenesPayloadVersion,
        "scenes": scenes.map((scene) => scene.toJson()).toList(),
      });

  /// Writes [value] under [key], reporting failure instead of throwing.
  ///
  /// A storage failure must not escape into the widget tree: after this round
  /// the callers are dock and settings code reacting to a remote-control press,
  /// and an uncaught exception there is a visible crash on the television.
  Future<bool> _persistString(String key, String value) async {
    try {
      await _sharedPreferences.setString(key, value);
      return true;
    } catch (e) {
      debugPrint("ScenesService: could not persist '$key' ($e)");
      return false;
    }
  }
}
