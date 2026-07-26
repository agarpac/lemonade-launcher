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
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Stable identifiers of the scenes seeded on first run.
///
/// These keys are the identity of a scene in persisted data: they must never
/// change, even if the display label is renamed or localized later.
class SceneKeys {
  static const String normal = "normal";
  static const String cinema = "cinema";
  static const String night = "night";
  static const String kids = "kids";

  SceneKeys._();
}

/// Lowest brightness the "night" scene ships with. Not zero: a black screen on
/// a TV launcher looks like a broken device.
const int _nightSceneBrightness = 10;

/// A user-selected preset grouping dock visibility, brightness, wallpaper and
/// an optional exit PIN.
///
/// Activation is manual only. A [Scene] holds no schedule, timer or trigger of
/// any kind, by product decision.
class Scene {
  /// Stable machine key, never shown to the user. See [SceneKeys].
  final String key;

  /// Display label. English for now; localization arrives with the UI phase.
  final String name;

  /// Package names of the applications visible in the dock while this scene is
  /// active. Empty means "no override": the normal dock is shown.
  ///
  /// Package names are stored instead of database ids so the configuration
  /// survives reinstalls and database rebuilds.
  final List<String> dockPackageNames;

  /// System brightness, [minBrightness] to [maxBrightness], matching
  /// `BrightnessService`. `null` means "no override": whatever the user has set
  /// is left alone.
  ///
  /// Always in range: the constructor clamps, so no path can store a value that
  /// would silently change on the next restart.
  final int? brightness;

  /// Bounds of [brightness], matching the 0-100 scale of `BrightnessService`.
  static const int minBrightness = 0;
  static const int maxBrightness = 100;

  /// Path of the wallpaper file associated with this scene. `null` means the
  /// scene does not override the wallpaper with a file.
  ///
  /// Mutually exclusive with [gradientUuid]: `WallpaperService` shows either a
  /// file or a gradient, never both.
  final String? wallpaperPath;

  /// Uuid of the `FLauncherGradient` associated with this scene, as used by
  /// `SettingsService.gradientUuid`. `null` means the scene does not override
  /// the wallpaper with a gradient.
  ///
  /// Mutually exclusive with [wallpaperPath].
  final String? gradientUuid;

  /// Base64 salt used to derive [_pinHash]. `null` when the scene has no PIN.
  final String? _pinSalt;

  /// Hex SHA-256 of salt + PIN. Never exposed, never logged.
  final String? _pinHash;

  /// Clamps [brightness] into range, and throws [ArgumentError] when both
  /// wallpaper overrides are supplied: both invariants are enforced here rather
  /// than trusted to callers, so `copyWith` and [Scene.fromJson] inherit them.
  Scene({
    required this.key,
    required this.name,
    List<String> dockPackageNames = const [],
    int? brightness,
    this.wallpaperPath,
    this.gradientUuid,
    String? pinSalt,
    String? pinHash,
  })  : dockPackageNames = List.unmodifiable(dockPackageNames),
        brightness = brightness?.clamp(minBrightness, maxBrightness),
        _pinSalt = pinSalt,
        _pinHash = pinHash {
    if (wallpaperPath != null && gradientUuid != null) {
      throw ArgumentError("Scene '$key' cannot override the wallpaper with a file and a gradient at the same time");
    }
  }

  /// Whether leaving this scene requires a PIN.
  bool get isPinProtected => _pinSalt != null && _pinHash != null;

  /// Whether this scene restricts the dock. `false` means the normal dock wins.
  bool get overridesDock => dockPackageNames.isNotEmpty;

  bool get overridesBrightness => brightness != null;

  /// Whether this scene replaces the wallpaper, with either a file or a
  /// gradient.
  bool get overridesWallpaper => wallpaperPath != null || gradientUuid != null;

  /// Returns `true` when [pin] matches the stored hash.
  ///
  /// An unprotected scene accepts anything: there is nothing to unlock.
  bool verifyPin(String pin) {
    final salt = _pinSalt;
    final hash = _pinHash;
    if (salt == null || hash == null) {
      return true;
    }
    return _constantTimeEquals(_hashPin(pin, salt), hash);
  }

  /// Copy of this scene protected by [pin], with a freshly generated salt.
  Scene withPin(String pin) {
    final salt = _generateSalt();
    return copyWith(pinSalt: salt, pinHash: _hashPin(pin, salt));
  }

  /// Copy of this scene with the PIN lock removed.
  Scene withoutPin() => Scene(
        key: key,
        name: name,
        dockPackageNames: dockPackageNames,
        brightness: brightness,
        wallpaperPath: wallpaperPath,
        gradientUuid: gradientUuid,
      );

  /// Copy of this scene carrying the exact PIN state of [other], including the
  /// absence of one.
  ///
  /// This is how `ScenesService` keeps a caller-supplied scene from changing a
  /// lock it never proved it owns; the salt and hash never leave the class.
  Scene withPinOf(Scene other) => Scene(
        key: key,
        name: name,
        dockPackageNames: dockPackageNames,
        brightness: brightness,
        wallpaperPath: wallpaperPath,
        gradientUuid: gradientUuid,
        pinSalt: other._pinSalt,
        pinHash: other._pinHash,
      );

  /// Copy of this scene with the given fields replaced.
  ///
  /// Optional overrides cannot be cleared by passing `null` (that is
  /// indistinguishable from "not provided"); use [clearBrightness],
  /// [clearWallpaper] and [withoutPin] instead.
  ///
  /// Setting one wallpaper override clears the other, so the mutual exclusion
  /// cannot be broken by a copy. Supplying both throws [ArgumentError].
  Scene copyWith({
    String? name,
    List<String>? dockPackageNames,
    int? brightness,
    String? wallpaperPath,
    String? gradientUuid,
    String? pinSalt,
    String? pinHash,
    bool clearBrightness = false,
    bool clearWallpaper = false,
  }) {
    if (wallpaperPath != null && gradientUuid != null) {
      throw ArgumentError("Scene '$key' cannot override the wallpaper with a file and a gradient at the same time");
    }

    final String? resolvedWallpaperPath;
    final String? resolvedGradientUuid;
    if (clearWallpaper) {
      resolvedWallpaperPath = null;
      resolvedGradientUuid = null;
    } else if (wallpaperPath != null) {
      resolvedWallpaperPath = wallpaperPath;
      resolvedGradientUuid = null;
    } else if (gradientUuid != null) {
      resolvedWallpaperPath = null;
      resolvedGradientUuid = gradientUuid;
    } else {
      resolvedWallpaperPath = this.wallpaperPath;
      resolvedGradientUuid = this.gradientUuid;
    }

    return Scene(
      key: key,
      name: name ?? this.name,
      dockPackageNames: dockPackageNames ?? this.dockPackageNames,
      brightness: clearBrightness ? null : (brightness ?? this.brightness),
      wallpaperPath: resolvedWallpaperPath,
      gradientUuid: resolvedGradientUuid,
      pinSalt: pinSalt ?? _pinSalt,
      pinHash: pinHash ?? _pinHash,
    );
  }

  Map<String, dynamic> toJson() => {
        "key": key,
        "name": name,
        "dockPackageNames": dockPackageNames,
        "brightness": brightness,
        "wallpaperPath": wallpaperPath,
        "gradientUuid": gradientUuid,
        "pinSalt": _pinSalt,
        "pinHash": _pinHash,
      };

  /// Reads a scene from its persisted form.
  ///
  /// Accepts payloads written before `gradientUuid` existed: a missing field is
  /// simply "no gradient override".
  ///
  /// Throws [FormatException] when the entry cannot be understood, so the
  /// caller can fall back to the default scenes instead of starting with a
  /// half-built configuration.
  factory Scene.fromJson(Map<String, dynamic> json) {
    final key = json["key"];
    final name = json["name"];
    if (key is! String || key.isEmpty) {
      throw FormatException("Scene is missing a valid 'key'");
    }
    if (name is! String || name.isEmpty) {
      throw FormatException("Scene '$key' is missing a valid 'name'");
    }

    final rawDock = json["dockPackageNames"];
    final List<String> dockPackageNames;
    if (rawDock == null) {
      dockPackageNames = const [];
    } else if (rawDock is List) {
      dockPackageNames = rawDock.whereType<String>().where((packageName) => packageName.isNotEmpty).toList();
    } else {
      throw FormatException("Scene '$key' has an invalid 'dockPackageNames'");
    }

    final rawBrightness = json["brightness"];
    if (rawBrightness != null && rawBrightness is! int) {
      throw FormatException("Scene '$key' has an invalid 'brightness'");
    }

    final rawWallpaperPath = json["wallpaperPath"];
    if (rawWallpaperPath != null && rawWallpaperPath is! String) {
      throw FormatException("Scene '$key' has an invalid 'wallpaperPath'");
    }

    final rawGradientUuid = json["gradientUuid"];
    if (rawGradientUuid != null && rawGradientUuid is! String) {
      throw FormatException("Scene '$key' has an invalid 'gradientUuid'");
    }

    final wallpaperPath = (rawWallpaperPath as String?)?.nullIfEmpty;
    final gradientUuid = (rawGradientUuid as String?)?.nullIfEmpty;
    if (wallpaperPath != null && gradientUuid != null) {
      throw FormatException("Scene '$key' overrides the wallpaper with a file and a gradient at the same time");
    }

    final rawSalt = json["pinSalt"];
    final rawHash = json["pinHash"];
    if (rawSalt != null && rawSalt is! String) {
      throw FormatException("Scene '$key' has an invalid 'pinSalt'");
    }
    if (rawHash != null && rawHash is! String) {
      throw FormatException("Scene '$key' has an invalid 'pinHash'");
    }
    // A half-written lock would either lock the user out or silently unlock the
    // scene. Neither is acceptable, so require both halves or neither.
    final hasSalt = rawSalt is String && rawSalt.isNotEmpty;
    final hasHash = rawHash is String && rawHash.isNotEmpty;
    if (hasSalt != hasHash) {
      throw FormatException("Scene '$key' has an incomplete PIN lock");
    }

    return Scene(
      key: key,
      name: name,
      dockPackageNames: dockPackageNames,
      // The constructor clamps, so an out-of-range stored value is corrected
      // rather than costing the user the whole scene set.
      brightness: rawBrightness as int?,
      wallpaperPath: wallpaperPath,
      gradientUuid: gradientUuid,
      pinSalt: hasSalt ? rawSalt : null,
      pinHash: hasHash ? rawHash : null,
    );
  }

  /// The four scenes seeded on first run, in display order.
  ///
  /// Dock overrides start empty on purpose: the installed applications are not
  /// known at seeding time, so every scene shows the normal dock until the user
  /// curates it. No scene seeds a wallpaper or a gradient either — picking one
  /// is a product decision that belongs to the UI phase. The kids scene ships
  /// without a PIN for the same reason: a hardcoded default PIN would be no
  /// protection at all.
  static List<Scene> defaults() => [
        Scene(key: SceneKeys.normal, name: "Normal"),
        Scene(key: SceneKeys.cinema, name: "Cinema", brightness: 100),
        Scene(key: SceneKeys.night, name: "Night", brightness: _nightSceneBrightness),
        Scene(key: SceneKeys.kids, name: "Kids"),
      ];

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static String _hashPin(String pin, String salt) => sha256.convert(utf8.encode("$salt:$pin")).toString();

  /// Compares two digests without leaking the position of the first mismatch.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  @override
  String toString() => "Scene($key, brightness: $brightness, dock: ${dockPackageNames.length}, pin: $isPinProtected)";
}

extension _NullIfEmpty on String {
  /// Treats an empty string as "not set", so a blank stored value does not
  /// count as a wallpaper override.
  String? get nullIfEmpty => isEmpty ? null : this;
}
