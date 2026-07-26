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

  SceneKeys._();
}

/// A user-selected preset grouping presentation settings and an optional exit
/// PIN.
///
/// A scene never touches the dock: every favourite application is always
/// visible, in every scene, in its usual order (see the PRD, section 9.1).
/// What a scene groups instead is **presentation**: the wallpaper and a
/// handful of display toggles that otherwise live scattered across the
/// Settings panel.
///
/// Activation is manual only. A [Scene] holds no schedule, timer or trigger of
/// any kind, by product decision.
class Scene {
  /// Stable machine key, never shown to the user. See [SceneKeys].
  final String key;

  /// Display label. English for now; localization arrives with the UI phase.
  final String name;

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

  /// Overrides `SettingsService.autoHideAppBarEnabled`. `null` means "no
  /// override": whatever the user has set is left alone.
  final bool? hideAppBar;

  /// Overrides `SettingsService.showWatchNextSection`. `null` means "no
  /// override".
  final bool? showWatchNext;

  /// Overrides `SettingsService.showAppNamesBelowIcons`. `null` means "no
  /// override".
  final bool? showAppNames;

  /// Overrides `SettingsService.backgroundBlurDisabled`. `null` means "no
  /// override".
  final bool? disableBackgroundBlur;

  /// Overrides `SettingsService.showCategoryTitles`. `null` means "no
  /// override".
  final bool? showCategoryTitles;

  /// Overrides `SettingsService.accentColorHex`. `null` means "no override".
  final String? accentColorHex;

  /// Base64 salt used to derive [_pinHash]. `null` when the scene has no PIN.
  final String? _pinSalt;

  /// Hex SHA-256 of salt + PIN. Never exposed, never logged.
  final String? _pinHash;

  /// Throws [ArgumentError] when both wallpaper overrides are supplied: the
  /// invariant is enforced here rather than trusted to callers, so `copyWith`
  /// and [Scene.fromJson] inherit it.
  Scene({
    required this.key,
    required this.name,
    this.wallpaperPath,
    this.gradientUuid,
    this.hideAppBar,
    this.showWatchNext,
    this.showAppNames,
    this.disableBackgroundBlur,
    this.showCategoryTitles,
    this.accentColorHex,
    String? pinSalt,
    String? pinHash,
  })  : _pinSalt = pinSalt,
        _pinHash = pinHash {
    if (wallpaperPath != null && gradientUuid != null) {
      throw ArgumentError("Scene '$key' cannot override the wallpaper with a file and a gradient at the same time");
    }
  }

  /// Whether leaving this scene requires a PIN.
  bool get isPinProtected => _pinSalt != null && _pinHash != null;

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
        wallpaperPath: wallpaperPath,
        gradientUuid: gradientUuid,
        hideAppBar: hideAppBar,
        showWatchNext: showWatchNext,
        showAppNames: showAppNames,
        disableBackgroundBlur: disableBackgroundBlur,
        showCategoryTitles: showCategoryTitles,
        accentColorHex: accentColorHex,
      );

  /// Copy of this scene carrying the exact PIN state of [other], including the
  /// absence of one.
  ///
  /// This is how `ScenesService` keeps a caller-supplied scene from changing a
  /// lock it never proved it owns; the salt and hash never leave the class.
  Scene withPinOf(Scene other) => Scene(
        key: key,
        name: name,
        wallpaperPath: wallpaperPath,
        gradientUuid: gradientUuid,
        hideAppBar: hideAppBar,
        showWatchNext: showWatchNext,
        showAppNames: showAppNames,
        disableBackgroundBlur: disableBackgroundBlur,
        showCategoryTitles: showCategoryTitles,
        accentColorHex: accentColorHex,
        pinSalt: other._pinSalt,
        pinHash: other._pinHash,
      );

  /// Copy of this scene with the given fields replaced.
  ///
  /// Optional overrides cannot be cleared by passing `null` (that is
  /// indistinguishable from "not provided"); use the matching `clearXxx` flag
  /// instead (e.g. [clearHideAppBar]), or [clearWallpaper] and [withoutPin].
  ///
  /// Setting one wallpaper override clears the other, so the mutual exclusion
  /// cannot be broken by a copy. Supplying both throws [ArgumentError].
  Scene copyWith({
    String? name,
    String? wallpaperPath,
    String? gradientUuid,
    bool? hideAppBar,
    bool? showWatchNext,
    bool? showAppNames,
    bool? disableBackgroundBlur,
    bool? showCategoryTitles,
    String? accentColorHex,
    String? pinSalt,
    String? pinHash,
    bool clearWallpaper = false,
    bool clearHideAppBar = false,
    bool clearShowWatchNext = false,
    bool clearShowAppNames = false,
    bool clearDisableBackgroundBlur = false,
    bool clearShowCategoryTitles = false,
    bool clearAccentColorHex = false,
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
      wallpaperPath: resolvedWallpaperPath,
      gradientUuid: resolvedGradientUuid,
      hideAppBar: clearHideAppBar ? null : (hideAppBar ?? this.hideAppBar),
      showWatchNext: clearShowWatchNext ? null : (showWatchNext ?? this.showWatchNext),
      showAppNames: clearShowAppNames ? null : (showAppNames ?? this.showAppNames),
      disableBackgroundBlur: clearDisableBackgroundBlur ? null : (disableBackgroundBlur ?? this.disableBackgroundBlur),
      showCategoryTitles: clearShowCategoryTitles ? null : (showCategoryTitles ?? this.showCategoryTitles),
      accentColorHex: clearAccentColorHex ? null : (accentColorHex ?? this.accentColorHex),
      pinSalt: pinSalt ?? _pinSalt,
      pinHash: pinHash ?? _pinHash,
    );
  }

  Map<String, dynamic> toJson() => {
        "key": key,
        "name": name,
        "wallpaperPath": wallpaperPath,
        "gradientUuid": gradientUuid,
        "hideAppBar": hideAppBar,
        "showWatchNext": showWatchNext,
        "showAppNames": showAppNames,
        "disableBackgroundBlur": disableBackgroundBlur,
        "showCategoryTitles": showCategoryTitles,
        "accentColorHex": accentColorHex,
        "pinSalt": _pinSalt,
        "pinHash": _pinHash,
      };

  /// Reads a scene from its persisted form.
  ///
  /// Unrecognized keys are ignored rather than rejected, so a payload written
  /// by an older or newer build of this same shape loads unchanged. In
  /// particular this is what lets a payload holding the retired
  /// `dockPackageNames` and `brightness` fields keep loading after they were
  /// removed from this class: those keys are simply never read.
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

    final rawHideAppBar = json["hideAppBar"];
    if (rawHideAppBar != null && rawHideAppBar is! bool) {
      throw FormatException("Scene '$key' has an invalid 'hideAppBar'");
    }

    final rawShowWatchNext = json["showWatchNext"];
    if (rawShowWatchNext != null && rawShowWatchNext is! bool) {
      throw FormatException("Scene '$key' has an invalid 'showWatchNext'");
    }

    final rawShowAppNames = json["showAppNames"];
    if (rawShowAppNames != null && rawShowAppNames is! bool) {
      throw FormatException("Scene '$key' has an invalid 'showAppNames'");
    }

    final rawDisableBackgroundBlur = json["disableBackgroundBlur"];
    if (rawDisableBackgroundBlur != null && rawDisableBackgroundBlur is! bool) {
      throw FormatException("Scene '$key' has an invalid 'disableBackgroundBlur'");
    }

    final rawShowCategoryTitles = json["showCategoryTitles"];
    if (rawShowCategoryTitles != null && rawShowCategoryTitles is! bool) {
      throw FormatException("Scene '$key' has an invalid 'showCategoryTitles'");
    }

    final rawAccentColorHex = json["accentColorHex"];
    if (rawAccentColorHex != null && rawAccentColorHex is! String) {
      throw FormatException("Scene '$key' has an invalid 'accentColorHex'");
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
      wallpaperPath: wallpaperPath,
      gradientUuid: gradientUuid,
      hideAppBar: rawHideAppBar as bool?,
      showWatchNext: rawShowWatchNext as bool?,
      showAppNames: rawShowAppNames as bool?,
      disableBackgroundBlur: rawDisableBackgroundBlur as bool?,
      showCategoryTitles: rawShowCategoryTitles as bool?,
      accentColorHex: rawAccentColorHex as String?,
      pinSalt: hasSalt ? rawSalt : null,
      pinHash: hasHash ? rawHash : null,
    );
  }

  /// The three scenes seeded on first run, in display order.
  ///
  /// No scene seeds a wallpaper: picking a specific file or gradient is a UI-
  /// phase product decision. The "cinema" and "night" scenes ship without a
  /// PIN for the same reason a hardcoded default PIN never protects anything.
  static List<Scene> defaults() => [
        Scene(key: SceneKeys.normal, name: "Normal"),
        Scene(
          key: SceneKeys.cinema,
          name: "Cinema",
          hideAppBar: true,
          showWatchNext: false,
          showAppNames: false,
        ),
        Scene(key: SceneKeys.night, name: "Night", disableBackgroundBlur: true),
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
  String toString() => "Scene($key, wallpaper: $overridesWallpaper, pin: $isPinProtected)";
}

extension _NullIfEmpty on String {
  /// Treats an empty string as "not set", so a blank stored value does not
  /// count as a wallpaper override.
  String? get nullIfEmpty => isEmpty ? null : this;
}
