import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lets the user switch the active [Scene] with a D-pad.
///
/// Opens focused on the currently active scene rather than the first item in
/// the list, so the remote's thumb starts where the user already is. The
/// active scene is also marked with a checkmark independently of focus: focus
/// moves around the list as the user navigates, but which scene is actually
/// active must stay visible regardless of where focus lands.
class ScenePickerPanel extends StatelessWidget {
  const ScenePickerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SidePanelDialog(
      width: 300,
      isRightSide: false,
      child: Consumer<ScenesService>(
        builder: (context, scenesService, _) {
          final scenes = scenesService.scenes;
          final activeKey = scenesService.activeSceneKey;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.scenes, style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final scene in scenes)
                        FocusableSettingsTile(
                          autofocus: scene.key == activeKey,
                          leading: Icon(sceneIconFor(scene.key)),
                          title: Text(
                            sceneDisplayName(localizations, scene),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: scene.key == activeKey
                              ? Semantics(
                                  label: localizations.sceneActiveSemanticLabel,
                                  child: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                                )
                              : null,
                          onPressed: () => _activate(context, scene.key),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _activate(BuildContext context, String key) async {
    final scenesService = context.read<ScenesService>();
    final result = await scenesService.activateScene(key);
    if (!context.mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    switch (result) {
      case SceneActivationResult.activated:
      case SceneActivationResult.alreadyActive:
        Navigator.of(context).pop();
        break;
      case SceneActivationResult.persistenceFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.sceneActivationFailed)),
        );
        break;
      case SceneActivationResult.pinRequired:
      case SceneActivationResult.pinRejected:
        // Unreachable today: no seeded scene carries a PIN, so nothing here can
        // trigger this path. Handled anyway so a future PIN-protected scene
        // fails loudly instead of silently doing nothing.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.scenePinProtected)),
        );
        break;
      case SceneActivationResult.unknownScene:
        // Unreachable: every key offered here comes straight from
        // `scenesService.scenes`.
        break;
    }
  }
}

/// Resolves the localized display name of [scene] by its stable [Scene.key].
///
/// Falls back to the persisted [Scene.name] for any key that isn't one of the
/// four seeded scenes (e.g. a custom scene added in a later phase), so an
/// unrecognized key never shows a blank label.
String sceneDisplayName(AppLocalizations localizations, Scene scene) {
  switch (scene.key) {
    case SceneKeys.normal:
      return localizations.sceneNormal;
    case SceneKeys.cinema:
      return localizations.sceneCinema;
    case SceneKeys.night:
      return localizations.sceneNight;
    case SceneKeys.kids:
      return localizations.sceneKids;
    default:
      return scene.name;
  }
}

/// Icon representing the scene identified by [key], so the active scene is
/// recognizable at a glance instead of behind a single generic icon.
IconData sceneIconFor(String key) {
  switch (key) {
    case SceneKeys.normal:
      return Icons.home_outlined;
    case SceneKeys.cinema:
      return Icons.theaters_outlined;
    case SceneKeys.night:
      return Icons.bedtime_outlined;
    case SceneKeys.kids:
      return Icons.child_care_outlined;
    default:
      return Icons.dashboard_customize_outlined;
  }
}
