import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/scene_picker_panel.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/scene_override_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One of the five boolean presentation overrides a [Scene] can carry.
///
/// Deliberately excludes the wallpaper overrides (file/gradient) and
/// [Scene.accentColorHex]: those are out of scope for this editor (see the
/// gradient/accent/image pickers planned for later).
enum SceneOverrideField { hideAppBar, showWatchNext, showAppNames, disableBackgroundBlur, showCategoryTitles }

extension SceneOverrideFieldX on SceneOverrideField {
  IconData get icon {
    switch (this) {
      case SceneOverrideField.hideAppBar:
        return Icons.visibility_off_outlined;
      case SceneOverrideField.showWatchNext:
        return Icons.play_circle_outline;
      case SceneOverrideField.showAppNames:
        return Icons.subtitles;
      case SceneOverrideField.disableBackgroundBlur:
        return Icons.blur_on;
      case SceneOverrideField.showCategoryTitles:
        return Icons.abc;
    }
  }

  /// Localized label of this field, shared by the editor tile and the
  /// three-option sub-page it opens.
  String title(AppLocalizations localizations) {
    switch (this) {
      case SceneOverrideField.hideAppBar:
        return localizations.autoHideAppBar;
      case SceneOverrideField.showWatchNext:
        return localizations.showWatchNextSection;
      case SceneOverrideField.showAppNames:
        return localizations.sceneOverrideShowAppNames;
      case SceneOverrideField.disableBackgroundBlur:
        return localizations.sceneOverrideDisableBackgroundBlur;
      case SceneOverrideField.showCategoryTitles:
        return localizations.showCategoryTitles;
    }
  }

  /// This field's current override on [scene]. `null` (including when
  /// [scene] is `null`) means "no override — inherit the user's setting".
  bool? overrideValue(Scene? scene) {
    if (scene == null) {
      return null;
    }
    switch (this) {
      case SceneOverrideField.hideAppBar:
        return scene.hideAppBar;
      case SceneOverrideField.showWatchNext:
        return scene.showWatchNext;
      case SceneOverrideField.showAppNames:
        return scene.showAppNames;
      case SceneOverrideField.disableBackgroundBlur:
        return scene.disableBackgroundBlur;
      case SceneOverrideField.showCategoryTitles:
        return scene.showCategoryTitles;
    }
  }

  /// The user's own setting for this field, ignoring any scene override.
  /// This is what an "Inherit" choice actually resolves to.
  bool inheritedValue(SettingsService settingsService) {
    switch (this) {
      case SceneOverrideField.hideAppBar:
        return settingsService.userAutoHideAppBarEnabled;
      case SceneOverrideField.showWatchNext:
        return settingsService.userShowWatchNextSection;
      case SceneOverrideField.showAppNames:
        return settingsService.userShowAppNamesBelowIcons;
      case SceneOverrideField.disableBackgroundBlur:
        return settingsService.userBackgroundBlurDisabled;
      case SceneOverrideField.showCategoryTitles:
        return settingsService.userShowCategoryTitles;
    }
  }

  /// Applies [value] as this field's override on the scene identified by
  /// [sceneKey]. `null` clears the override back to "inherit".
  Future<SceneUpdateResult> applyOverride(ScenesService scenesService, String sceneKey, bool? value) {
    switch (this) {
      case SceneOverrideField.hideAppBar:
        return scenesService.setSceneHideAppBar(sceneKey, value);
      case SceneOverrideField.showWatchNext:
        return scenesService.setSceneShowWatchNext(sceneKey, value);
      case SceneOverrideField.showAppNames:
        return scenesService.setSceneShowAppNames(sceneKey, value);
      case SceneOverrideField.disableBackgroundBlur:
        return scenesService.setSceneDisableBackgroundBlur(sceneKey, value);
      case SceneOverrideField.showCategoryTitles:
        return scenesService.setSceneShowCategoryTitles(sceneKey, value);
    }
  }
}

/// Localized "Inherit (On)"/"Inherit (Off)"/"On"/"Off" label for a field
/// whose override is [override] and whose inherited value is [inherited].
///
/// Shared by [SceneEditorPage]'s compact tile trailing text and
/// [SceneOverridePage]'s "Inherit" option, so the two pages never drift.
String sceneOverrideStateLabel(AppLocalizations localizations, bool? override, bool inherited) {
  if (override == null) {
    return inherited ? localizations.sceneOverrideInheritOn : localizations.sceneOverrideInheritOff;
  }
  return override ? localizations.sceneOverrideOn : localizations.sceneOverrideOff;
}

/// Editor for a single [Scene]'s presentation overrides.
///
/// The "Normal" scene is the neutral anchor meaning "the user's own
/// settings, untouched" (see [SceneKeys.normal]) and is never editable: it
/// shows an explanation instead of any override control, not even disabled
/// ones.
///
/// The five override tiles are a plain [Column] inside a scrollable body, so
/// a future gradient picker, accent picker or scene image control can be
/// added as further items without restructuring this page.
class SceneEditorPage extends StatelessWidget {
  static const String routeName = "scene_editor_panel";

  final String sceneKey;

  const SceneEditorPage({super.key, required this.sceneKey});

  static const List<SceneOverrideField> _fields = SceneOverrideField.values;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Selector<ScenesService, Scene?>(
      selector: (_, scenesService) => scenesService.sceneByKey(sceneKey),
      builder: (context, scene, _) {
        if (scene == null) {
          // Unreachable in practice: this page is only ever pushed with a key
          // taken straight from ScenesService.scenes, and there is no UI to
          // delete a scene. Handled anyway so a future deletion path never
          // leaves this page pointing at nothing.
          return const SizedBox.shrink();
        }

        final isNormal = scene.key == SceneKeys.normal;
        return Column(
          children: [
            Text(sceneDisplayName(localizations, scene), style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: isNormal
                  ? _NormalExplanation(localizations: localizations)
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final field in _fields)
                            _SceneOverrideTile(
                              sceneKey: sceneKey,
                              field: field,
                              autofocus: field == _fields.first,
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
}

class _NormalExplanation extends StatelessWidget {
  final AppLocalizations localizations;

  const _NormalExplanation({required this.localizations});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 32, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              localizations.sceneEditorNormalExplanation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneOverrideTile extends StatelessWidget {
  final String sceneKey;
  final SceneOverrideField field;
  final bool autofocus;

  const _SceneOverrideTile({required this.sceneKey, required this.field, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Selector2<ScenesService, SettingsService, (bool?, bool)>(
      selector: (_, scenesService, settingsService) => (
        field.overrideValue(scenesService.sceneByKey(sceneKey)),
        field.inheritedValue(settingsService),
      ),
      builder: (context, data, _) {
        final (override, inherited) = data;
        return FocusableSettingsTile(
          autofocus: autofocus,
          leading: Icon(field.icon),
          title: Text(field.title(localizations), style: Theme.of(context).textTheme.bodyMedium),
          trailing: Text(
            sceneOverrideStateLabel(localizations, override, inherited),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          onPressed: () => Navigator.of(context).pushNamed(
            SceneOverridePage.routeName,
            arguments: (sceneKey, field),
          ),
        );
      },
    );
  }
}
