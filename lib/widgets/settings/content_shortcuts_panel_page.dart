/*
 * FLauncher
 * Copyright (C) 2026  Lemonade Launcher contributors
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

import 'package:collection/collection.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/content_shortcut_panel_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The shortcuts of one section: what they are, in which order, and the way in
/// to adding, editing and deleting them.
///
/// Reordering works exactly like reordering the launcher's sections
/// (`LauncherSectionsPanelPage`): left/right puts a shortcut into "moving" mode,
/// up/down moves it, select confirms. Up/down here is left/right on the home
/// screen, because this vertical list is that horizontal row.
class ContentShortcutsPanelPage extends StatefulWidget {
  static const String routeName = "content_shortcuts_panel";

  /// Id of the section whose shortcuts are listed. Not a widget-held object: the
  /// section is looked up again on every build, because deleting a shortcut can
  /// destroy and rebuild it.
  final int sectionId;

  const ContentShortcutsPanelPage({Key? key, required this.sectionId}) : super(key: key);

  @override
  State<ContentShortcutsPanelPage> createState() => _ContentShortcutsPanelPageState();
}

class _ContentShortcutsPanelPageState extends State<ContentShortcutsPanelPage> {
  int? _movingIndex;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(localizations.contentShortcuts, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Consumer<AppsService>(
          builder: (context, service, __) {
            final ContentShortcutSection? section =
                service.contentShortcutSections.firstWhereOrNull((s) => s.id == widget.sectionId);
            final List<ContentShortcut> shortcuts = section?.shortcuts ?? const [];

            return Expanded(
              // A Column inside a scroll view rather than a ListView: a lazy list
              // only builds the children that happen to be on screen, and both
              // reordering and the focus that follows a moved shortcut need every
              // one of them to exist.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (shortcuts.isEmpty)
                      // Reachable by deleting the last shortcut of the section:
                      // the section stopped existing with it. "Add shortcut"
                      // below still works and starts a new section, so this is
                      // never a dead end.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text(
                          localizations.contentShortcutSectionEmpty,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    for (int i = 0; i < shortcuts.length; i++)
                      _shortcutTile(context, section!, shortcuts[i], i, shortcuts.length),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        FocusableSettingsTile(
          leading: const Icon(Icons.add),
          title: Text(localizations.contentShortcutAdd, style: Theme.of(context).textTheme.bodyMedium),
          onPressed: () => Navigator.pushNamed(
            context,
            ContentShortcutPanelPage.routeName,
            arguments: ContentShortcutPanelPageArguments(sectionId: widget.sectionId),
          ),
        ),
      ],
    );
  }

  Widget _shortcutTile(
    BuildContext context,
    ContentShortcutSection section,
    ContentShortcut shortcut,
    int index,
    int totalCount,
  ) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final bool isMoving = _movingIndex == index;
    final bool available = shortcut.available && shortcut.launchable;

    return Focus(
      // The shortcut object itself, so the focused element follows a shortcut
      // that the user is moving rather than staying on a list position.
      key: ObjectKey(shortcut),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (isMoving) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (index > 0) {
              _move(section, index, index - 1);
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (index < totalCount - 1) {
              _move(section, index, index + 1);
              return KeyEventResult.handled;
            }
          } else if (_isConfirmKey(event.logicalKey) ||
              event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _endMove(section);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() => _movingIndex = index);
          return KeyEventResult.handled;
        }
        if (_isConfirmKey(event.logicalKey)) {
          _edit(shortcut);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool focused = Focus.of(context).hasFocus;
          final ColorScheme colorScheme = Theme.of(context).colorScheme;

          return GestureDetector(
            onTap: () {
              if (isMoving) {
                _endMove(section);
              } else {
                _edit(shortcut);
              }
            },
            onLongPress: () {
              if (!isMoving) {
                setState(() => _movingIndex = index);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMoving ? colorScheme.primaryContainer : (focused ? Colors.white10 : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: focused || isMoving ? colorScheme.primary : Colors.transparent,
                    width: focused ? 2 : (isMoving ? 1 : 0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      available ? Icons.play_circle_outline : Icons.link_off,
                      color: available ? null : Theme.of(context).disabledColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(shortcut.label, style: Theme.of(context).textTheme.bodyMedium),
                          if (!available)
                            Text(
                              localizations.contentShortcutUnavailable,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).disabledColor),
                            ),
                        ],
                      ),
                    ),
                    if (isMoving) ...[
                      const Icon(Icons.keyboard_arrow_up),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down),
                    ] else
                      const Icon(Icons.chevron_right, color: Colors.white24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isConfirmKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.gameButtonA;

  void _edit(ContentShortcut shortcut) => Navigator.pushNamed(
        context,
        ContentShortcutPanelPage.routeName,
        arguments: ContentShortcutPanelPageArguments(shortcut: shortcut),
      );

  void _move(ContentShortcutSection section, int oldIndex, int newIndex) {
    context.read<AppsService>().reorderContentShortcut(section, oldIndex, newIndex);
    setState(() => _movingIndex = newIndex);
  }

  void _endMove(ContentShortcutSection section) {
    context.read<AppsService>().saveContentShortcutOrder(section);
    setState(() => _movingIndex = null);
  }
}
