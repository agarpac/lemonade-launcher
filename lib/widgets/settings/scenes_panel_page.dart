import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
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
///
/// This tile is reachable from the Interface menu regardless of
/// [SettingsService.scenesEnabled] — only the home-bar entry point in
/// `FocusAwareAppBar` is gated on it. Otherwise turning scenes off would also
/// hide the one place that can turn them back on.
class ScenesPanelPage extends StatelessWidget {
  static const String routeName = "scenes_panel";

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settingsService = Provider.of<SettingsService>(context);

    return Consumer<ScenesService>(
      builder: (context, scenesService, _) {
        final scenes = scenesService.scenes;
        final scenesEnabled = settingsService.scenesEnabled;

        return Column(
          children: [
            Text(localizations.scenes, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    RoundedSwitchListTile(
                      autofocus: true,
                      value: scenesEnabled,
                      onChanged: (value) => settingsService.setScenesEnabled(value),
                      title: Text(localizations.scenesEnable, style: Theme.of(context).textTheme.bodyMedium),
                      secondary: const Icon(Icons.theater_comedy_outlined),
                    ),
                    // The switch above must always stay reachable, so the list
                    // below is what disappears when the feature is off — not
                    // the other way round. Turning it off is presentation-only
                    // (see `SettingsService.scenesEnabled`): no scene is
                    // deleted, the list is just not worth showing while its
                    // one entry point on the home bar is hidden.
                    if (scenesEnabled)
                      for (final scene in scenes)
                        FocusableSettingsTile(
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
