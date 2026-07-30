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

import 'package:flauncher/content_shortcut_uri.dart';
import 'package:flauncher/actions.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/content_shortcut_artwork_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';

const _validationKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

/// A [ContentShortcutSection] rendered as a horizontal row, deliberately built
/// like `CategoryRow` so that it reads as one more row of the launcher rather
/// than a feature bolted on: same padding, same card size, same focus
/// behaviour, same presentation settings.
class ContentShortcutRow extends StatelessWidget {
  final ContentShortcutSection section;

  /// Whether this is the topmost focusable row, which is what makes arrow-up
  /// reach the top bar. Reachability is a programmatic intent, never geometry
  /// (see [ContentShortcutCard.handleUpNavigationToSettings]).
  final bool isFirstSection;

  final VoidCallback? onShortcutFocused;

  const ContentShortcutRow({
    Key? key,
    required this.section,
    this.isFirstSection = false,
    this.onShortcutFocused,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<ContentShortcut> shortcuts = section.shortcuts;
    if (shortcuts.isEmpty) {
      // A section *is* its shortcuts, so an empty one is a section that no
      // longer exists; it must not leave an empty band on the home screen.
      return const SizedBox.shrink();
    }

    final bool showNames = context.select<SettingsService, bool>((s) => s.showAppNamesBelowIcons);

    return SizedBox(
      height: Category.RowHeight.toDouble() + (showNames ? kAppNameLabelHeight : 0),
      child: ListView.custom(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        childrenDelegate: SliverChildBuilderDelegate(
          childCount: shortcuts.length,
          findChildIndexCallback: _findChildIndex,
          (context, index) => Padding(
            key: contentShortcutCardKey(shortcuts[index]),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ContentShortcutCard(
              shortcut: shortcuts[index],
              autofocus: index == 0,
              handleUpNavigationToSettings: isFirstSection,
              onFocused: onShortcutFocused,
            ),
          ),
        ),
      ),
    );
  }

  int? _findChildIndex(Key key) {
    final String value = (key as ValueKey<String>).value;
    final int index = section.shortcuts.indexWhere((shortcut) => contentShortcutCardKey(shortcut).value == value);
    return index >= 0 ? index : null;
  }
}

/// The key of the card of [shortcut]. Shortcut ids and application package
/// names live in the same sliver list on the home screen, so the prefix is what
/// keeps them from colliding.
ValueKey<String> contentShortcutCardKey(ContentShortcut shortcut) => ValueKey("content_shortcut_${shortcut.id}");

/// One deep link, as a card the size and shape of an [AppCard].
///
/// Shows the destination's own picture when there is one —
/// [ContentShortcutArtworkService] fetches it from the page's `og:image` when
/// the shortcut is saved — and falls back to a Material icon plus the label
/// when there is not. That fallback is not a placeholder: reading somebody
/// else's markup is fragile by nature, so the icon is the card's normal,
/// permanent state whenever the fetch found nothing.
class ContentShortcutCard extends StatefulWidget {
  final ContentShortcut shortcut;
  final bool autofocus;

  /// When true, arrow-up hands the focus to the top bar through
  /// [MoveFocusToSettingsIntent] instead of relying on directional traversal.
  ///
  /// The top bar is not reachable by geometry, so a row that forgets this would
  /// leave the user on the home screen with no way into Settings — on the
  /// device's only home screen.
  final bool handleUpNavigationToSettings;

  final VoidCallback? onFocused;

  const ContentShortcutCard({
    Key? key,
    required this.shortcut,
    this.autofocus = false,
    this.handleUpNavigationToSettings = false,
    this.onFocused,
  }) : super(key: key);

  @override
  State<ContentShortcutCard> createState() => _ContentShortcutCardState();
}

class _ContentShortcutCardState extends State<ContentShortcutCard> {
  bool _clicked = false;
  bool _isFocused = false;
  bool _isTraditionalHighlightMode = false;
  String? _accentColorHex;
  Color _accentColor = const Color(0xFF000000);
  final FocusNode _focusNode = FocusNode();

  static const double _focusedScale = 1.07;
  static const Duration _focusAnimationDuration = Duration(milliseconds: 180);

  /// Whether pressing this card can do anything at all.
  ///
  /// Read straight off the model: `available` is recomputed by [AppsService] on
  /// every refresh from what the system reports as installed, and it is the only
  /// source of truth for it. A second, widget-local guess would drift from it.
  bool get _launchable => widget.shortcut.available && widget.shortcut.launchable;

  @override
  void initState() {
    super.initState();
    _isTraditionalHighlightMode = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    FocusManager.instance.addHighlightModeListener(_focusHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_focusHighlightModeChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _focusHighlightModeChanged(FocusHighlightMode mode) {
    final bool nextMode = mode == FocusHighlightMode.traditional;
    if (nextMode == _isTraditionalHighlightMode) {
      return;
    }
    setState(() => _isTraditionalHighlightMode = nextMode);
  }

  bool _shouldHighlight() => _isTraditionalHighlightMode && _isFocused;

  @override
  Widget build(BuildContext context) {
    final (bool showNames, String accentColorHex, bool showFocusBorders, bool showContentShortcutHandle) =
        context.select<SettingsService, (bool, String, bool, bool)>(
      (s) => (s.showAppNamesBelowIcons, s.accentColorHex, s.showFocusBorders, s.showContentShortcutHandle),
    );
    if (accentColorHex != _accentColorHex) {
      _accentColorHex = accentColorHex;
      _accentColor = Color(int.parse('FF$accentColorHex', radix: 16));
    }
    // Selected rather than watched, so a fetch that finished for *another*
    // shortcut does not rebuild this card. Provider compares with `==`, and the
    // artwork's identity is its bytes (see
    // `ContentShortcutArtworkService.artworkFor`), so this changes exactly when
    // the picture does.
    final ImageProvider? artwork = context.select<ContentShortcutArtworkService, ImageProvider?>(
      (service) => service.artworkFor(widget.shortcut.id),
    );
    final bool shouldHighlight = _shouldHighlight();

    return FocusKeyboardListener(
      onPressed: _onPressed,
      child: AnimatedScale(
        scale: _clicked ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _clicked ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AspectRatio(
                  aspectRatio: kAppCardAspectRatio,
                  child: RepaintBoundary(
                    child: AnimatedScale(
                      scale: shouldHighlight ? _focusedScale : 1.0,
                      duration: _focusAnimationDuration,
                      alignment: Alignment.center,
                      curve: Curves.easeOutCubic,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Material(
                            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(kAppCardCornerRadius)),
                            clipBehavior: Clip.antiAlias,
                            elevation: shouldHighlight ? 7 : 4,
                            shadowColor: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                InkWell(
                                  focusNode: _focusNode,
                                  autofocus: widget.autofocus,
                                  focusColor: Colors.transparent,
                                  onTap: () => _onPressed(LogicalKeyboardKey.enter),
                                  onFocusChange: _handleFocusChange,
                                  child: _cardContent(context, artwork, showContentShortcutHandle),
                                ),
                                IgnorePointer(
                                  child: AnimatedOpacity(
                                    duration: _focusAnimationDuration,
                                    curve: Curves.easeInOut,
                                    opacity: shouldHighlight ? 0.0 : 1.0,
                                    child: const ColoredBox(color: Color(0x1A000000)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (shouldHighlight && showFocusBorders)
                            IgnorePointer(
                              child: RepaintBoundary(
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    shape: RoundedSuperellipseBorder(
                                      borderRadius: BorderRadius.circular(kAppCardCornerRadius),
                                      side: BorderSide(color: _accentColor, width: 1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showNames)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    widget.shortcut.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The destination's picture when [artwork] is not null, and the icon plus the
  /// label when it is. Both are greyed out and captioned when the shortcut
  /// cannot be opened, so the unavailable state reads the same either way.
  ///
  /// Everything is inside a [FittedBox] so a long label scales down instead of
  /// overflowing a card whose height the row decides.
  ///
  /// [showHandle] governs the icon-fallback branch's centre text only: when
  /// true (the default) it is the destination's `@handle`, falling back to
  /// the shortcut's own label exactly as before when the address names none;
  /// when false it is always the label. The line under the card, drawn by
  /// [build] when [SettingsService.showAppNamesBelowIcons] is on, is
  /// untouched by this and always shows the label.
  Widget _cardContent(BuildContext context, ImageProvider? artwork, bool showHandle) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final bool launchable = _launchable;
    final Color disabledColor = Theme.of(context).disabledColor;

    if (artwork != null) {
      // Filled edge to edge like an application's banner in [AppCard], inside
      // the same [Material] as the icon variant, so the card keeps its size and
      // its squircle clip whichever branch runs.
      return Opacity(
        opacity: launchable ? 1.0 : 0.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Ink.image(image: artwork, fit: BoxFit.cover),
            if (!launchable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      localizations.contentShortcutUnavailable,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: disabledColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Opacity(
      opacity: launchable ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  launchable ? Icons.play_circle_outline : Icons.link_off,
                  size: 24,
                  color: launchable ? null : disabledColor,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The handle when [showHandle] asks for it and the
                        // destination has one, the user's label otherwise:
                        // "@canal" says what this opens, while a name like
                        // "test" says nothing once there are several. The
                        // label still appears under the card when app names
                        // are switched on, regardless of this setting.
                        (showHandle ? contentShortcutHandle(widget.shortcut.uri) : null) ?? widget.shortcut.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (!launchable)
                        Text(
                          localizations.contentShortcutUnavailable,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: disabledColor,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleFocusChange(bool focused) {
    if (_isFocused != focused) {
      setState(() => _isFocused = focused);
    }
    if (focused) {
      widget.onFocused?.call();
    }
  }

  KeyEventResult _onPressed(LogicalKeyboardKey key) {
    if (_validationKeys.contains(key)) {
      // An unavailable shortcut is handled and *not* launched. Playing the press
      // animation and asking the platform channel to open a package that is not
      // there would look exactly like a working shortcut that silently does
      // nothing; the card already says it is unavailable.
      if (!_launchable) {
        return KeyEventResult.handled;
      }
      if (!_clicked) {
        setState(() => _clicked = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) {
            return;
          }
          context.read<AppsService>().launchContentShortcut(widget.shortcut);
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _clicked = false);
            }
          });
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp && widget.handleUpNavigationToSettings) {
      Actions.invoke(context, const MoveFocusToSettingsIntent());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
