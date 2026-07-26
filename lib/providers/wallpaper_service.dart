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
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

/// The resolved wallpaper background: a static [image], an active
/// [videoFile], and/or a [gradient] fallback shown when neither is present.
///
/// This is used both for the "user layer" (resolved purely from the user's
/// own day/night settings and files) and for the "effective layer" (what is
/// actually rendered on screen). [gradient] is always present on both layers
/// so it can diverge independently of [image]/[videoFile]: an active scene's
/// wallpaper override — a gradient or an image, the two are mutually
/// exclusive on [Scene] — replaces the whole layer (see
/// [WallpaperService._resolveEffectiveLayer]) so image, video and gradient
/// are resolved and cached together, in a single pass, and can never disagree
/// between the two widgets that read them (`lib/flauncher.dart` and
/// `lib/widgets/cached_blur_backdrop.dart`).
class _WallpaperLayer {
  final ImageProvider? image;
  final File? videoFile;
  final FLauncherGradient gradient;

  const _WallpaperLayer({required this.image, required this.videoFile, required this.gradient});
}

class WallpaperService extends ChangeNotifier {
  final SettingsService _settingsService;
  final ScenesService _scenesService;

  late File _wallpaperFile;
  late File _wallpaperDayFile;
  late File _wallpaperNightFile;
  late File _wallpaperVideoFile;
  late File _wallpaperDayVideoFile;
  late File _wallpaperNightVideoFile;

  /// Path of the documents directory, kept around so [_sceneWallpaperFile]
  /// can derive a scene's image path on demand, the same way the six fields
  /// above are built once in [_init] rather than re-resolved on every call.
  late String _documentsPath;

  bool _initialized = false;
  Timer? _timer;
  int _wallpaperRevision = 0;

  ImageProvider? _wallpaper;
  int get wallpaperRevision => _wallpaperRevision;

  ImageProvider? get wallpaper => _wallpaper;

  /// The active video, or `null` when there is none *or* the active scene
  /// overrides the background with a gradient or an image. A scene override
  /// takes precedence over everything the user has configured (see
  /// [_resolveEffectiveLayer]); without this check here too, an active user
  /// video would keep showing through the override, since `flauncher.dart`
  /// consults this getter directly rather than the cached effective layer.
  ///
  /// Deliberately does not go through [_resolveUserLayer]: that also resolves
  /// the image, which touches file fields not yet set before [_init]
  /// completes. [_resolveActiveVideoFile] already guards on [isInitialized],
  /// so this getter stays safe to call at any time, exactly as before.
  File? get wallpaperVideoFile {
    if (_sceneGradientOverride() != null) return null;
    if (_sceneImageOverride() != null) return null;
    final f = _resolveActiveVideoFile();
    return f != null && f.existsSync() ? f : null;
  }

  /// The effective gradient: the active scene's override if it has one and it
  /// resolves to a known gradient, otherwise the user's own gradient.
  ///
  /// Computed live rather than cached, unlike [wallpaper]: unlike image/video
  /// resolution, this never touches the file system or [isInitialized], so
  /// there is no benefit to caching and no risk in always resolving fresh.
  FLauncherGradient get gradient => _sceneGradientOverride() ?? _resolveUserGradient();

  /// The user's own gradient, ignoring any scene override: `SettingsService`'s
  /// `gradientUuid`, or [FLauncherGradients.saintPetersburg] when it is unset
  /// or unknown.
  FLauncherGradient _resolveUserGradient() => FLauncherGradients.all.firstWhere(
        (candidate) => candidate.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.saintPetersburg,
      );

  /// The active scene's gradient override, or `null` when the scene has none
  /// or its `gradientUuid` does not match any known [FLauncherGradient].
  ///
  /// An unknown uuid (e.g. a scene restored from a different build's
  /// payload, where a gradient may since have been removed) must never
  /// resolve to an arbitrary gradient: it degrades to "no override", so the
  /// user's own background is what's shown.
  FLauncherGradient? _sceneGradientOverride() {
    final uuid = _scenesService.activeScene.gradientUuid;
    if (uuid == null) return null;
    for (final candidate in FLauncherGradients.all) {
      if (candidate.uuid == uuid) return candidate;
    }
    return null;
  }

  /// Path of the namespaced wallpaper image file for the scene identified by
  /// [sceneKey]: `scene_wallpaper_<sceneKey>` in the documents directory,
  /// alongside — never colliding with — the six fixed user wallpaper
  /// filenames (`wallpaper`, `wallpaper_day`, `wallpaper_night` and their
  /// `_video` variants). [cleanImageWallpaperFiles] and
  /// [cleanVideoWallpaperFiles] enumerate exactly those six by field, so they
  /// never touch a file built from this method.
  ///
  /// Deliberately derived only from [sceneKey] and the current documents
  /// directory, never from `Scene.wallpaperPath`'s stored value: see
  /// [importSceneWallpaper] for why.
  File _sceneWallpaperFile(String sceneKey) => File("$_documentsPath/scene_wallpaper_$sceneKey");

  /// The active scene's wallpaper image override, or `null` when the scene
  /// has no `wallpaperPath` override, or the namespaced file is missing from
  /// disk.
  ///
  /// A missing file — the app was reinstalled, a backup was restored on
  /// another device, the file was deleted by hand — degrades to "no
  /// override" here, exactly like [_sceneGradientOverride] degrading on an
  /// unknown uuid: this launcher is the device's only home screen, so a scene
  /// claiming an image it cannot find must fall through to the user's own
  /// wallpaper rather than show nothing.
  ///
  /// `null` before [_init] completes, matching [_resolveActiveVideoFile]'s
  /// [isInitialized] guard: [_documentsPath] is not set yet.
  File? _sceneImageOverride() {
    if (!isInitialized) return null;
    final wallpaperPath = _scenesService.activeScene.wallpaperPath;
    if (wallpaperPath == null) return null;
    final file = _sceneWallpaperFile(_scenesService.activeScene.key);
    return file.existsSync() ? file : null;
  }

  /// Bookkeeping only, for the revision-bump comparison in [_updateWallpaper].
  /// Not the value returned by [gradient], which is always computed live.
  /// `null` means "not resolved yet", which [_updateWallpaper] treats as
  /// always changed, exactly like [_wallpaper] starting out `null`. Left
  /// unresolved here (rather than eagerly reading [gradient]) so construction
  /// itself never touches `_settingsService`/`_scenesService` beyond
  /// registering listeners: only [_updateWallpaper] does, once [_init] (or a
  /// listener) actually runs it.
  FLauncherGradient? _lastGradient;

  /// Bookkeeping only, for the revision-bump comparison in [_updateWallpaper].
  /// Compared by *path*, not by [File] identity/equality (two [File] instances
  /// for the same path are not `==`), so a day/night tick that re-resolves to
  /// the same video does not bump the revision. `null` means "no video
  /// resolved yet", matching [_lastGradient]'s convention.
  File? _lastVideoFile;

  WallpaperService(this._settingsService, this._scenesService) :
    _wallpaper = null
  {
    _settingsService.addListener(_onSettingsChanged);
    _scenesService.addListener(_onScenesChanged);
    _init();
  }

  /// Test-only seam for the "current time" used by day/night resolution
  /// ([_resolveActiveVideoFile], [_resolveUserLayer]), matching the existing
  /// [debugResolveNow] pattern. Defaults to the real wall clock in
  /// production; tests override it to deterministically exercise a
  /// day-to-night (or night-to-day) switch without waiting on real time.
  @visibleForTesting
  DateTime Function() debugNow = DateTime.now;

  bool _lastTimeBasedEnabled = false;

  void _onSettingsChanged() {
    final enabled = _settingsService.timeBasedWallpaperEnabled;
    if (enabled != _lastTimeBasedEnabled) {
      _lastTimeBasedEnabled = enabled;
      _updateTimerState();
      _updateWallpaper();
    }
  }

  /// A scene change may change the effective gradient or the effective
  /// wallpaper image, so always re-resolves — unlike [_onSettingsChanged],
  /// which only cares about one specific setting.
  void _onScenesChanged() {
    _updateWallpaper();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _scenesService.removeListener(_onScenesChanged);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _documentsPath = directory.path;
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

    final now = debugNow();
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
    final now = debugNow();
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

    return _WallpaperLayer(image: image, videoFile: videoFile, gradient: _resolveUserGradient());
  }

  // ---------------------------------------------------------------------
  // Step 2: effective layer.
  //
  // Either a scene gradient override or a scene image override takes
  // precedence over everything the user has configured, including an active
  // video: it replaces the whole layer, not just one field, so `image` and
  // `videoFile` are also suppressed (see PRD section 9.1.4 — without
  // suppressing the video, the override would be invisible to any user with
  // a video wallpaper active). `Scene.wallpaperPath` and `Scene.gradientUuid`
  // are mutually exclusive (enforced in the model), so at most one of the two
  // branches below can ever apply for a given scene. An unknown/missing
  // scene gradient or a scene image file absent from disk both degrade to
  // the user layer unchanged, never to a blank screen.
  //
  // The image branch reuses `userLayer.gradient`, not a scene one: a scene
  // that overrides the image never overrides the gradient too (mutual
  // exclusion again), so the gradient shown here — invisible behind the
  // image, but still cached in `_lastGradient` — must match what the public
  // `gradient` getter independently computes, which is the user's own.
  // ---------------------------------------------------------------------
  _WallpaperLayer _resolveEffectiveLayer(_WallpaperLayer userLayer) {
    final sceneGradient = _sceneGradientOverride();
    if (sceneGradient != null) {
      return _WallpaperLayer(image: null, videoFile: null, gradient: sceneGradient);
    }
    final sceneImageFile = _sceneImageOverride();
    if (sceneImageFile != null) {
      return _WallpaperLayer(image: FileImage(sceneImageFile), videoFile: null, gradient: userLayer.gradient);
    }
    return userLayer;
  }

  // ---------------------------------------------------------------------
  // Step 3: publish + bump revision only if the effective identity changed.
  //
  // `image` uses FileImage's path+scale equality, so a re-resolution that
  // lands on the same file path (e.g. a day/night tick with no actual
  // change) does NOT bump the revision. The video file is compared by
  // *path* the same way (see [_lastVideoFile]): a day/night tick that
  // resolves to the same video file does NOT bump the revision either,
  // while a genuine day/night switch to a *different* video path does.
  // `force` covers the case a user overwrites a fixed wallpaper/video path
  // (e.g. pickWallpaper, pickVideoWallpaper) with new file *content*: the
  // path-based identity would otherwise be unchanged, so pick/save call
  // sites explicitly force a bump.
  //
  // The effective gradient (identity-compared against `FLauncherGradients.all`
  // instances, never rebuilt, so `!=` is reference equality) is bumped the
  // same way: a scene activation/deactivation that changes it must invalidate
  // the cached blur exactly like an image change does.
  // ---------------------------------------------------------------------
  void _updateWallpaper({bool force = false}) {
    final userLayer = _resolveUserLayer();
    final effectiveLayer = _resolveEffectiveLayer(userLayer);

    final identityChanged = _wallpaper != effectiveLayer.image ||
        _lastGradient != effectiveLayer.gradient ||
        _lastVideoFile?.path != effectiveLayer.videoFile?.path;
    if (identityChanged || force) {
      _wallpaper = effectiveLayer.image;
      _lastGradient = effectiveLayer.gradient;
      _lastVideoFile = effectiveLayer.videoFile;
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

  // ---------------------------------------------------------------------
  // Scene wallpaper image overrides (phase 2 of scene wallpaper overrides,
  // PRD section 9.1.4). These never touch the user's own files: they read
  // and write only [_sceneWallpaperFile], which is namespaced by scene key
  // and lives alongside, never in place of, the six fixed user filenames.
  // ---------------------------------------------------------------------

  /// Copies [source] into the namespaced wallpaper file of the scene
  /// identified by [sceneKey], and returns the path the caller should store
  /// in `Scene.wallpaperPath`.
  ///
  /// The returned path is informational only — it records that *some* import
  /// happened, for anyone inspecting the persisted scene — and is never read
  /// back to locate the file: [_sceneImageOverride] only checks that
  /// `Scene.wallpaperPath` is non-null, then re-derives the actual file from
  /// [sceneKey] via [_sceneWallpaperFile]. An absolute path baked in here
  /// would point nowhere after a backup is restored on another device, or
  /// after Android relocates this app's documents directory, even though the
  /// copied file is sitting right there under its expected namespaced name.
  /// Deriving the file from the stable scene key instead is what survives
  /// both cases.
  Future<String> importSceneWallpaper(String sceneKey, File source) async {
    final targetFile = _sceneWallpaperFile(sceneKey);

    final readStream = source.openRead();
    final writeStream = targetFile.openWrite();
    await readStream.cast<List<int>>().pipe(writeStream);

    await FileImage(targetFile).evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    _updateWallpaper(force: true);
    return targetFile.path;
  }

  /// Removes the namespaced wallpaper file of the scene identified by
  /// [sceneKey], if one exists. Touches only that one file: never another
  /// scene's, and never any of the user's own six wallpaper files.
  ///
  /// Deliberately the *only* way a scene's wallpaper file is ever deleted:
  /// there is no sweep that removes files of scenes that no longer exist.
  /// `ScenesService` falls back to the default scenes whenever its stored
  /// payload cannot be read, so such a sweep would treat every one of the
  /// user's own scenes as "gone" after a single transient load failure and
  /// delete their wallpapers. A few orphaned megabytes are an acceptable
  /// cost; silently destroying a user's wallpaper is not.
  Future<void> deleteSceneWallpaper(String sceneKey) async {
    final targetFile = _sceneWallpaperFile(sceneKey);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
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
