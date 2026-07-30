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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The single frosted-glass surface used by every element of the status bar
/// (PRD section 10): the same two translucencies, radius and blur as the
/// dock's own light surface in `lib/flauncher.dart`, factored out so there is
/// exactly one definition of what a status-bar glass card looks like instead
/// of one copy per element.
///
/// [StatusBarWeatherWidget] was the original, hand-written implementation of
/// this card; it now builds on top of this widget instead of duplicating it.
///
/// This widget never creates a [Focus] node of its own: wrapping a focusable
/// child in a card must not insert or remove a node from the focus tree, so
/// focusable elements of the bar stay focusable, with the same traversal
/// order, and non-focusable ones (like the weather card) stay that way too.
class StatusBarGlassCard extends StatelessWidget {
  static const double _blurSigma = 5;
  static const BorderRadius _defaultBorderRadius = BorderRadius.all(Radius.circular(16));
  static const EdgeInsetsGeometry _defaultPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 4);

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  const StatusBarGlassCard({
    super.key,
    required this.child,
    this.borderRadius = _defaultBorderRadius,
    this.padding = _defaultPadding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Same two translucencies as the dock's light surface in
        // `lib/flauncher.dart`, spelled with the non-deprecated API.
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      child: child,
    );

    // The dock's own escape hatch for GPUs that cannot afford a blur applies
    // here too: one setting, one visual language, no status-bar surface
    // quietly ignoring it.
    final backdropDisabled = context.select<SettingsService, bool>((s) => s.dockBackdropFilterDisabled);
    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: backdropDisabled ? content : CachedBlurBackdrop(sigma: _blurSigma, child: content),
    );
  }
}
