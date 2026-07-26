import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/widgets/scene_picker_panel.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/scene_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lists every [Scene] and opens [SceneEditorPage] on selection.
///
/// Reuses [sceneDisplayName] and [sceneIconFor] from `ScenePickerPanel` so
/// names and icons stay identical between picking a scene and configuring
/// one.
class ScenesPanelPage extends StatelessWidget {
  static const String routeName = "scenes_panel";

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<ScenesService>(
      builder: (context, scenesService, _) {
        final scenes = scenesService.scenes;

        return Column(
          children: [
            Text(localizations.scenes, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final scene in scenes)
                      FocusableSettingsTile(
                        autofocus: scene == scenes.first,
                        leading: Icon(sceneIconFor(scene.key)),
                        title: Text(
                          sceneDisplayName(localizations, scene),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onPressed: () => Navigator.of(context).pushNamed(
                          SceneEditorPage.routeName,
                          arguments: scene.key,
                        ),
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
