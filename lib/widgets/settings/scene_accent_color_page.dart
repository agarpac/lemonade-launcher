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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Per-scene accent colour override picker: every
/// [AccentColorPage.colorPresets] entry, plus a "no override" option
/// representing `Scene.accentColorHex == null`.
///
/// This mirrors [SceneGradientPage]'s approach rather than reusing
/// [AccentColorPage] directly: that page's swatches always write through
/// `SettingsService.setAccentColor` — i.e. the user's *global* accent — and
/// always autofocus a fixed preset (the first one) regardless of what is
/// actually selected. Neither behavior is appropriate here. Every selection on
/// this page instead goes through `ScenesService.setSceneAccentColorHex`,
/// never `SettingsService.setAccentColor` (see the PRD, section 9.1.4, on
/// scene overrides never touching global settings). The preset list and its
/// hex-to-name mapping are reused as-is from [AccentColorPage.colorPresets]
/// rather than duplicated, so the two pickers can never drift apart.
class SceneAccentColorPage extends StatelessWidget {
  static const String routeName = "scene_accent_color_panel";

  final String sceneKey;

  const SceneAccentColorPage({super.key, required this.sceneKey});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Selector2<ScenesService, SettingsService, (String?, String)>(
      selector: (_, scenesService, settingsService) => (
        scenesService.sceneByKey(sceneKey)?.accentColorHex,
        // The user's own, raw accent color — never SettingsService.accentColorHex,
        // which would already resolve any scene override and make the "no
        // override" option describe itself instead of what it inherits.
        settingsService.userAccentColorHex,
      ),
      builder: (context, data, _) {
        final (override, userAccentColorHex) = data;
        final inheritedName = accentColorPresetNameByHex(userAccentColorHex);

        return Column(
          children: [
            Text(localizations.sceneOverrideAccentColor, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              // A plain (lazy) GridView only builds/lays out the cards
              // currently near the viewport, which would leave autofocus
              // unable to reach the overridden preset's card whenever it sits
              // a few rows down: an unbuilt widget can neither receive
              // autofocus nor be a D-pad traversal target. `shrinkWrap` forces
              // every card to be laid out up front — with around fifteen
              // presets plus "no override" this matters even more than it
              // does for [SceneGradientPage]'s dozen gradients. The outer
              // `SingleChildScrollView` is then the one and only `Scrollable`
              // that actually scrolls, which is what `EnsureVisible`'s
              // `Scrollable.ensureVisible` calls act on.
              child: SingleChildScrollView(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  childAspectRatio: 4 / 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    EnsureVisible(
                      alignment: 0.5,
                      child: _AccentColorOptionCard(
                        cardKey: const Key("scene-accent-inherit"),
                        color: _hexToColor(userAccentColorHex),
                        label: localizations.sceneOverrideInheritAccentColor(inheritedName),
                        selected: override == null,
                        autofocus: override == null,
                        onSelect: () => _apply(context, null),
                      ),
                    ),
                    for (final preset in AccentColorPage.colorPresets)
                      EnsureVisible(
                        alignment: 0.5,
                        child: _AccentColorOptionCard(
                          cardKey: Key("scene-accent-${preset.$1}"),
                          color: _hexToColor(preset.$1),
                          label: preset.$2,
                          selected: override == preset.$1,
                          autofocus: override == preset.$1,
                          onSelect: () => _apply(context, preset.$1),
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

  /// Applies [accentColorHex] as the scene's accent colour override,
  /// surfacing a [SceneUpdateResult.persistenceFailed] result with a snackbar
  /// instead of swallowing it — the same handling [SceneOverridePage] and
  /// [SceneGradientPage] give every other override.
  Future<void> _apply(BuildContext context, String? accentColorHex) async {
    final scenesService = context.read<ScenesService>();
    final result = await scenesService.setSceneAccentColorHex(sceneKey, accentColorHex);
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

/// The display name of the preset identified by [hex] in
/// [AccentColorPage.colorPresets], falling back to that list's White preset
/// when [hex] matches none of them — the exact fallback
/// `SettingsService.userAccentColorHex` itself uses for an unset value.
///
/// Public (not prefixed with `_`) so [SceneEditorPage]'s compact tile can
/// reuse the exact same mapping for its trailing label instead of
/// duplicating it.
String accentColorPresetNameByHex(String hex) => AccentColorPage.colorPresets
    .firstWhere(
      (preset) => preset.$1 == hex,
      orElse: () => AccentColorPage.colorPresets.firstWhere((preset) => preset.$1 == ACCENT_COLOR_WHITE),
    )
    .$2;

/// Same conversion [AccentColorPage] uses privately to turn one of its preset
/// hex strings into a [Color], reproduced here since that method isn't
/// reachable from outside that class.
Color _hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

class _AccentColorOptionCard extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelect;

  /// Key of the tappable [InkWell] itself. A dedicated field rather than this
  /// widget's own `key`: assigning the same [Key] to both would make
  /// `find.byKey` in tests match two widgets instead of the one that is
  /// actually tappable, since this widget carries no other identity that
  /// needs a Flutter [Key] of its own.
  final Key cardKey;

  const _AccentColorOptionCard({
    required this.cardKey,
    required this.color,
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onSelect()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => onSelect()),
        },
        child: Focus(
          canRequestFocus: false,
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: _cardBorder(Focus.of(context).hasFocus),
                    child: InkWell(
                      key: cardKey,
                      autofocus: autofocus,
                      onTap: onSelect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: color),
                          if (selected)
                            const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.check_circle, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedDefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          decoration: TextDecoration.underline,
                          color: Focus.of(context).hasFocus ? Colors.white : null,
                        ),
                    duration: const Duration(milliseconds: 50),
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  ShapeBorder? _cardBorder(bool hasFocus) => hasFocus
      ? RoundedRectangleBorder(side: const BorderSide(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(12))
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
}
