import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';

class RoundedSwitchListTile extends StatelessWidget {
  final bool value;
  final bool autofocus;
  final ValueChanged<bool> onChanged;
  final Widget title;
  final Widget secondary;

  /// Forwarded to [FocusableSettingsTile.focusNode], so a page can put the
  /// remote's focus back on this switch after the tile that had it disappeared.
  final FocusNode? focusNode;

  const RoundedSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.secondary,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableSettingsTile(
      autofocus: autofocus,
      focusNode: focusNode,
      onPressed: () => onChanged(!value),
      leading: secondary,
      title: title,
      trailing: Container(
        constraints: const BoxConstraints(maxHeight: 16),
        child: Switch(
          value: value,
          onChanged: onChanged,
        )
      ),
    );
  }
}
