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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/tv_media_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Per-scene wallpaper *image* override picker: reuses the same
/// [TvMediaPicker] the user's own wallpaper picture picker uses (see
/// [WallpaperPanelPage]'s `_pickWallpaper`), but the picked file is never
/// handed to any `WallpaperService.pickWallpaper*` method — that would write
/// the user's own, global wallpaper. Instead it is copied through
/// `WallpaperService.importSceneWallpaper`, and the resulting path recorded
/// via `ScenesService.setSceneWallpaperPath`, exactly the same two-service
/// split [SceneGradientPage] and [SceneAccentColorPage] use for their own
/// overrides (see the PRD, section 9.1.4).
///
/// Mirrors those two pages' shape rather than [WallpaperPanelPage] itself: a
/// plain scrollable column of [FocusableSettingsTile]s (there is no grid of
/// presets here, just "choose" and, when an image is already set, "clear"),
/// with a short state line above them showing whether this scene currently
/// has an image override. A thumbnail is not used: `WallpaperService` exposes
/// no public, synchronous way to resolve a *given* scene's image file (only
/// its own `_sceneImageOverride`, which resolves the *active* scene and is
/// private) and this feature must not invent new file-resolution logic
/// outside that service — see the class comment on `wallpaperPath` in
/// `lib/models/scene.dart`. `Scene.wallpaperPath`'s nullness is exactly what
/// that service itself keys "has an override" off of, so it is also the
/// cheapest, most honest thing to show here.
class SceneImagePage extends StatelessWidget {
  static const String routeName = "scene_image_panel";

  final String sceneKey;

  /// The media picker invoked by "Choose image". Defaults to the real
  /// [TvMediaPicker.show] in production; tests override this constructor
  /// parameter with a fake so exercising the copy/record flow never has to
  /// drive `TvMediaPicker`'s own UI, which talks to a platform channel with
  /// no test double (matching the `debugNow`-style test seam
  /// `WallpaperService` already uses elsewhere in this codebase).
  @visibleForTesting
  final Future<String?> Function(BuildContext context, {required TvMediaPickerMode mode}) mediaPicker;

  SceneImagePage({super.key, required this.sceneKey, this.mediaPicker = TvMediaPicker.show});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Selector<ScenesService, String?>(
      selector: (_, scenesService) => scenesService.sceneByKey(sceneKey)?.wallpaperPath,
      builder: (context, wallpaperPath, _) {
        final hasImage = wallpaperPath != null;
        return Column(
          children: [
            Text(localizations.sceneOverrideImage, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hasImage ? localizations.sceneOverrideImageSet : localizations.sceneOverrideImageNotSet,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    FocusableSettingsTile(
                      autofocus: true,
                      leading: const Icon(Icons.image_outlined),
                      title: Text(localizations.sceneOverrideChooseImage, style: Theme.of(context).textTheme.bodyMedium),
                      onPressed: () => _chooseImage(context),
                    ),
                    if (hasImage)
                      FocusableSettingsTile(
                        leading: const Icon(Icons.clear),
                        title: Text(localizations.sceneOverrideClearImage, style: Theme.of(context).textTheme.bodyMedium),
                        onPressed: () => _clearImage(context),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Picks an image via the exact same [TvMediaPicker] the user's own
  /// wallpaper picture picker uses, then, in this strict order: (1) copies it
  /// into this scene's namespaced file via
  /// `WallpaperService.importSceneWallpaper`; only if that succeeds,
  /// (2) records the override via `ScenesService.setSceneWallpaperPath`. A
  /// throw from the copy step surfaces the same failure snackbar
  /// [_apply]/[SceneGradientPage] use for a persistence failure, and the
  /// override is never recorded, so a failed copy can never leave the scene
  /// pointing at a file that was never written.
  Future<void> _chooseImage(BuildContext context) async {
    final path = await mediaPicker(context, mode: TvMediaPickerMode.image);
    if (path == null || !context.mounted) {
      return;
    }

    final wallpaperService = context.read<WallpaperService>();
    final String importedPath;
    try {
      importedPath = await wallpaperService.importSceneWallpaper(sceneKey, File(path));
    } catch (_) {
      _showFailureSnackBar(context);
      return;
    }

    if (!context.mounted) {
      return;
    }
    await _apply(context, importedPath);
  }

  /// Deletes the scene's namespaced wallpaper file via
  /// `WallpaperService.deleteSceneWallpaper`, then clears the override via
  /// `ScenesService.setSceneWallpaperPath(sceneKey, null)`. Both steps always
  /// run: a leaked file (override cleared but file left behind) and a
  /// dangling override (file deleted but override still pointing at it) are
  /// both bugs this order avoids.
  Future<void> _clearImage(BuildContext context) async {
    final wallpaperService = context.read<WallpaperService>();
    await wallpaperService.deleteSceneWallpaper(sceneKey);
    if (!context.mounted) {
      return;
    }
    await _apply(context, null);
  }

  /// Applies [wallpaperPath] as the scene's wallpaper override, surfacing a
  /// [SceneUpdateResult.persistenceFailed] result with a snackbar instead of
  /// swallowing it — the same handling [SceneGradientPage] and
  /// [SceneAccentColorPage] give every other override.
  Future<void> _apply(BuildContext context, String? wallpaperPath) async {
    final scenesService = context.read<ScenesService>();
    final result = await scenesService.setSceneWallpaperPath(sceneKey, wallpaperPath);
    if (!context.mounted) {
      return;
    }
    if (result == SceneUpdateResult.persistenceFailed) {
      _showFailureSnackBar(context);
    }
  }

  void _showFailureSnackBar(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.sceneOverrideUpdateFailed)),
    );
  }
}
