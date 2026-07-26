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

import 'dart:io';
import 'dart:async';

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

/// The resolved wallpaper background: either a static [image], an active
/// [videoFile], or neither (in which case the gradient is shown instead).
///
/// This is used both for the "user layer" (resolved purely from the user's
/// own day/night settings and files) and for the "effective layer" (what is
/// actually rendered on screen). Today the two are always identical; the
/// distinction exists so a later phase can make the effective layer diverge
/// from the user layer (see [WallpaperService._resolveEffectiveLayer]).
class _WallpaperLayer {
  final ImageProvider? image;
  final File? videoFile;

  const _WallpaperLayer({required this.image, required this.videoFile});
}

class WallpaperService extends ChangeNotifier {
  final SettingsService _settingsService;

  late File _wallpaperFile;
  late File _wallpaperDayFile;
  late File _wallpaperNightFile;
  late File _wallpaperVideoFile;
  late File _wallpaperDayVideoFile;
  late File _wallpaperNightVideoFile;
  bool _initialized = false;
  Timer? _timer;
  int _wallpaperRevision = 0;

  ImageProvider? _wallpaper;
  int get wallpaperRevision => _wallpaperRevision;

  ImageProvider? get wallpaper => _wallpaper;

  File? get wallpaperVideoFile {
    final f = _resolveActiveVideoFile();
    return f != null && f.existsSync() ? f : null;
  }

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.saintPetersburg,
      );

  WallpaperService(this._settingsService) :
    _wallpaper = null
  {
    _settingsService.addListener(_onSettingsChanged);
    _init();
  }

  bool _lastTimeBasedEnabled = false;

  void _onSettingsChanged() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled != _lastTimeBasedEnabled) {
      _lastTimeBasedEnabled = enabled;
      _updateTimerState();
      _updateWallpaper();
    }
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    _wallpaperDayFile = File("${directory.path}/wallpaper_day");
    _wallpaperNightFile = File("${directory.path}/wallpaper_night");
    _wallpaperVideoFile = File("${directory.path}/wallpaper_video");
    _wallpaperDayVideoFile = File("${directory.path}/wallpaper_day_video");
    _wallpaperNightVideoFile = File("${directory.path}/wallpaper_night_video");
    _initialized = true;

    _lastTimeBasedEnabled = _settingsService.timeBasedWallpaperEnabled;
    _updateWallpaper();
    _updateTimerState();
  }

  void _updateTimerState() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled && (_timer == null || !_timer!.isActive)) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateWallpaper());
    } else if (!enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  File? _resolveActiveVideoFile() {
    if (!isInitialized) return null;

    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    if (enabled) {
      if (isDay && _wallpaperDayVideoFile.existsSync()) {
        return _wallpaperDayVideoFile;
      }
      if (!isDay && _wallpaperNightVideoFile.existsSync()) {
        return _wallpaperNightVideoFile;
      }
      if (_wallpaperVideoFile.existsSync()) {
        return _wallpaperVideoFile;
      }
    } else if (_wallpaperVideoFile.existsSync()) {
      return _wallpaperVideoFile;
    }
    return null;
  }

  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------
  // Step 1: user layer.
  //
  // Resolves what the user's own preferences (day/night settings, picked
  // files) say the wallpaper should be *right now*. Knows nothing about
  // scenes.
  // ---------------------------------------------------------------------
  _WallpaperLayer _resolveUserLayer() {
    final now = DateTime.now();
    final isDay = now.hour >= 6 && now.hour < 18;
    final enabled = _settingsService.timeBasedWallpaperEnabled;

    final videoFile = _resolveActiveVideoFile();

    ImageProvider? image;

    if (videoFile != null) {
      image = null;
    } else if (enabled) {
      if (isDay && _wallpaperDayFile.existsSync()) {
        image = FileImage(_wallpaperDayFile);
      } else if (!isDay && _wallpaperNightFile.existsSync()) {
        image = FileImage(_wallpaperNightFile);
      } else if (_wallpaperFile.existsSync()) {
        image = FileImage(_wallpaperFile); // Fallback
      }
    } else if (_wallpaperFile.existsSync()) {
      image = FileImage(_wallpaperFile);
    }

    return _WallpaperLayer(image: image, videoFile: videoFile);
  }

  // ---------------------------------------------------------------------
  // Step 2: effective layer.
  //
  // SCENE_WALLPAPER_OVERRIDE_SEAM: this is where a later phase will let an
  // active scene's wallpaper override take precedence over the user layer,
  // computed at read time (never persisted). Today there is no scene layer,
  // so this is the identity function: effective == user.
  // ---------------------------------------------------------------------
  _WallpaperLayer _resolveEffectiveLayer(_WallpaperLayer userLayer) => userLayer;

  // ---------------------------------------------------------------------
  // Step 3: publish + bump revision only if the effective identity changed.
  //
  // `image` uses FileImage's path+scale equality, so a re-resolution that
  // lands on the same file path (e.g. a day/night tick with no actual
  // change) does NOT bump the revision. An active video always bumps,
  // matching the pre-refactor behaviour (video wallpapers are not static and
  // are rendered via a live blur that does not consult the revision at all).
  // `force` covers the case a user overwrites a fixed wallpaper path (e.g.
  // pickWallpaper) with new file *content*: the path-based identity would
  // otherwise be unchanged, so pick/save call sites explicitly force a bump.
  // ---------------------------------------------------------------------
  void _updateWallpaper({bool force = false}) {
    final userLayer = _resolveUserLayer();
    final effectiveLayer = _resolveEffectiveLayer(userLayer);

    final identityChanged = _wallpaper != effectiveLayer.image;
    if (identityChanged || effectiveLayer.videoFile != null || force) {
      _wallpaper = effectiveLayer.image;
      _wallpaperRevision++;
      notifyListeners();
    }
  }

  /// Test-only seam: re-resolves the wallpaper through the exact same path
  /// [Timer.periodic] uses (see [_updateTimerState]), without waiting a full
  /// minute. Does not exist in any production code path.
  @visibleForTesting
  void debugResolveNow() => _updateWallpaper();

  Future<void> pickWallpaper(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperFile);
  }

  Future<void> pickWallpaperDay(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperDayFile);
  }

  Future<void> pickWallpaperNight(File sourceFile) async {
    await _saveImage(sourceFile, _wallpaperNightFile);
  }

  Future<void> pickVideoWallpaper(File sourceFile) async {
    await _saveVideo(sourceFile, _wallpaperVideoFile);
  }

  Future<void> pickVideoWallpaperDay(File sourceFile) async {
    await _saveVideo(sourceFile, _wallpaperDayVideoFile);
  }

  Future<void> pickVideoWallpaperNight(File sourceFile) async {
    await _saveVideo(sourceFile, _wallpaperNightVideoFile);
  }

  Future<void> _saveImage(File sourceFile, File targetFile) async {
    final pairedVideo = _pairedVideoForImage(targetFile);
    if (pairedVideo != null && await pairedVideo.exists()) {
      await pairedVideo.delete();
      await cleanVideoWallpaperFiles();
    }

    final readStream = sourceFile.openRead();
    final writeStream = targetFile.openWrite();
    await readStream.cast<List<int>>().pipe(writeStream);

    await FileImage(targetFile).evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    _updateWallpaper(force: true);
  }

  Future<void> _saveVideo(File sourceFile, File targetVideoFile) async {
    final pairedImage = _pairedImageForVideo(targetVideoFile);
    if (pairedImage != null && await pairedImage.exists()) {
      await pairedImage.delete();
    }

    final readStream = sourceFile.openRead();
    final writeStream = targetVideoFile.openWrite();
    await readStream.cast<List<int>>().pipe(writeStream);

    _updateWallpaper(force: true);
  }

  File? _pairedVideoForImage(File imageFile) {
    if (imageFile.path == _wallpaperFile.path) return _wallpaperVideoFile;
    if (imageFile.path == _wallpaperDayFile.path) return _wallpaperDayVideoFile;
    if (imageFile.path == _wallpaperNightFile.path) return _wallpaperNightVideoFile;
    return null;
  }

  File? _pairedImageForVideo(File videoFile) {
    if (videoFile.path == _wallpaperVideoFile.path) return _wallpaperFile;
    if (videoFile.path == _wallpaperDayVideoFile.path) return _wallpaperDayFile;
    if (videoFile.path == _wallpaperNightVideoFile.path) return _wallpaperNightFile;
    return null;
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    await cleanImageWallpaperFiles();
    await cleanVideoWallpaperFiles();

    await _settingsService.setGradientUuid(fLauncherGradient.uuid);
    // Drop the in-memory wallpaper provider so the gradient is shown instead of
    // the (now deleted) image/video file. _updateWallpaper notifies listeners.
    _updateWallpaper(force: true);
  }

  // Cleaning methods

  Future<void> cleanVideoWallpaperFiles() async {
    if (await _wallpaperVideoFile.exists()) {
      await _wallpaperVideoFile.delete();
    }

    if (await _wallpaperDayVideoFile.exists()) {
      await _wallpaperDayVideoFile.delete();
    }

    if (await _wallpaperNightVideoFile.exists()) {
      await _wallpaperNightVideoFile.delete();
    }
  }

  Future<void> cleanImageWallpaperFiles() async {
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }

    if (await _wallpaperDayFile.exists()) {
      await _wallpaperDayFile.delete();
    }

    if (await _wallpaperNightFile.exists()) {
      await _wallpaperNightFile.delete();
    }
  }
}
