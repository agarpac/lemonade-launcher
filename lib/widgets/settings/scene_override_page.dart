import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/scene_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Three-option choice (inherit / on / off) for a single [SceneOverrideField]
/// of the scene identified by [sceneKey].
///
/// Mirrors the radio-list pattern already used for every other multi-value
/// setting in this directory (e.g. `BackButtonActionPage`,
/// `ScreensaverClockStylePage`): a dedicated page listing every option as a
/// [FocusableSettingsTile] with a radio icon, rather than a tile that cycles
/// through values in place. That existing pattern is the reason this page
/// exists instead of a cyclable tile on [SceneEditorPage].
///
/// The "Inherit" option always shows what it currently resolves to (e.g.
/// "Inherit (On)"), read live from `SettingsService`, so the user never has
/// to leave this page to predict what inheriting means right now.
class SceneOverridePage extends StatelessWidget {
  static const String routeName = "scene_override_panel";

  final String sceneKey;
  final SceneOverrideField field;

  const SceneOverridePage({super.key, required this.sceneKey, required this.field});

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
        return Column(
          children: [
            Text(field.title(localizations), style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _radioTile(
                      context,
                      selected: override == null,
                      label: inherited ? localizations.sceneOverrideInheritOn : localizations.sceneOverrideInheritOff,
                      onPressed: () => _apply(context, null),
                    ),
                    _radioTile(
                      context,
                      selected: override == true,
                      label: localizations.sceneOverrideOn,
                      onPressed: () => _apply(context, true),
                    ),
                    _radioTile(
                      context,
                      selected: override == false,
                      label: localizations.sceneOverrideOff,
                      onPressed: () => _apply(context, false),
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

  Widget _radioTile(
    BuildContext context, {
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FocusableSettingsTile(
      autofocus: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.secondary : Colors.grey,
      ),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      onPressed: onPressed,
    );
  }

  /// Applies [value] as this field's override, surfacing a
  /// [SceneUpdateResult.persistenceFailed] result with a snackbar instead of
  /// swallowing it.
  ///
  /// Every other [SceneUpdateResult] case is unreachable from here:
  /// `unknownScene` cannot happen because [sceneKey] always comes from
  /// `ScenesService.scenes`, and these setters carry no PIN gate (unlike
  /// `setScenePin`/`clearScenePin`), so `pinRequired`/`pinRejected` never
  /// occur either.
  Future<void> _apply(BuildContext context, bool? value) async {
    final scenesService = context.read<ScenesService>();
    final result = await field.applyOverride(scenesService, sceneKey, value);
    if (!context.mounted) {
      return;
    }
    if (result == SceneUpdateResult.persistenceFailed) {
      final localizations = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.sceneOverrideUpdateFailed)),
      );
    }
  }
}
