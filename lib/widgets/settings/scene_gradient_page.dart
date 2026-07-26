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

import 'package:flauncher/gradients.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Per-scene gradient override picker: every [FLauncherGradients.all] entry,
/// plus a "no override" option representing `Scene.gradientUuid == null`.
///
/// This mirrors [GradientPanelPage]'s visual layout (a grid of gradient
/// preview cards) rather than reusing it directly: that page's cards always
/// write through `WallpaperService.setGradient` — i.e. the user's *global*
/// gradient — and always autofocus a fixed gradient regardless of what is
/// actually selected. Neither behavior is appropriate here, and threading a
/// "which service, which key, which selection" parameter through that page
/// would touch code whose write path this feature must never reuse. A
/// separate page keeps that boundary explicit: every selection here goes
/// through `ScenesService.setSceneGradientUuid`, never
/// `SettingsService.setGradientUuid` (see the PRD, section 9.1.4, on scene
/// overrides never touching global settings).
class SceneGradientPage extends StatelessWidget {
  static const String routeName = "scene_gradient_panel";

  final String sceneKey;

  const SceneGradientPage({super.key, required this.sceneKey});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Selector2<ScenesService, SettingsService, (String?, String?)>(
      selector: (_, scenesService, settingsService) => (
        scenesService.sceneByKey(sceneKey)?.gradientUuid,
        // The user's own, raw gradient — never WallpaperService.gradient,
        // which would already resolve any scene override and make the "no
        // override" option describe itself instead of what it inherits.
        settingsService.gradientUuid,
      ),
      builder: (context, data, _) {
        final (override, userGradientUuid) = data;
        final inheritedGradient = _gradientByUuid(userGradientUuid);

        return Column(
          children: [
            Text(localizations.gradient, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              // A plain (lazy) GridView only builds/lays out the cards
              // currently near the viewport, which would leave autofocus
              // unable to reach the overridden gradient's card whenever it
              // sits a few rows down: an unbuilt widget can neither receive
              // autofocus nor be a D-pad traversal target. `shrinkWrap` forces
              // every card to be laid out up front — cheap here, since there
              // are only about a dozen of them — so autofocus and D-pad
              // traversal always reach whichever one is actually selected.
              // The outer `SingleChildScrollView` is then the one and only
              // `Scrollable` that actually scrolls, which is what
              // `EnsureVisible`'s `Scrollable.ensureVisible` calls act on.
              child: SingleChildScrollView(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 4 / 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    EnsureVisible(
                      alignment: 0.5,
                      child: _GradientOptionCard(
                        cardKey: const Key("scene-gradient-inherit"),
                        gradient: inheritedGradient.gradient,
                        label: localizations.sceneOverrideInheritGradient(inheritedGradient.name),
                        selected: override == null,
                        autofocus: override == null,
                        onSelect: () => _apply(context, null),
                      ),
                    ),
                    for (final gradient in FLauncherGradients.all)
                      EnsureVisible(
                        alignment: 0.5,
                        child: _GradientOptionCard(
                          cardKey: Key("scene-gradient-${gradient.uuid}"),
                          gradient: gradient.gradient,
                          label: gradient.name,
                          selected: override == gradient.uuid,
                          autofocus: override == gradient.uuid,
                          onSelect: () => _apply(context, gradient.uuid),
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

  /// Applies [gradientUuid] as the scene's gradient override, surfacing a
  /// [SceneUpdateResult.persistenceFailed] result with a snackbar instead of
  /// swallowing it — the same handling [SceneOverridePage] gives every other
  /// override.
  Future<void> _apply(BuildContext context, String? gradientUuid) async {
    final scenesService = context.read<ScenesService>();
    final result = await scenesService.setSceneGradientUuid(sceneKey, gradientUuid);
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

/// The gradient identified by [uuid], or [FLauncherGradients.saintPetersburg]
/// when [uuid] is `null` or unknown — the exact fallback
/// `WallpaperService._resolveUserGradient` uses for the user's own gradient,
/// reproduced here since that private method isn't reachable from the UI.
FLauncherGradient _gradientByUuid(String? uuid) => FLauncherGradients.all.firstWhere(
      (candidate) => candidate.uuid == uuid,
      orElse: () => FLauncherGradients.saintPetersburg,
    );

class _GradientOptionCard extends StatelessWidget {
  final Gradient gradient;
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

  const _GradientOptionCard({
    required this.cardKey,
    required this.gradient,
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
                          Container(decoration: BoxDecoration(gradient: gradient)),
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
