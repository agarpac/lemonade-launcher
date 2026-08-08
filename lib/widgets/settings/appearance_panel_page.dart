import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Dock, visual-effect and accent-color controls, grouped under subheaders.
///
/// The accent-color entry point used to be its own top-level tile in
/// [InterfaceSettingsPage]; it moved here because "what colour is the UI"
/// belongs next to "how does the UI look", not one level up. It still opens
/// the same [AccentColorPage] and writes through the same
/// [SettingsService.setAccentColor], only the entry point moved.
class AppearancePanelPage extends StatelessWidget {
  static const String routeName = "appearance_panel";

  const AppearancePanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settingsService = Provider.of<SettingsService>(context);

    return Column(
      children: [
        Text(localizations.appearanceSettings, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _SectionHeader(localizations.settingsSectionDock),
              RoundedSwitchListTile(
                autofocus: true,
                value: !settingsService.dockBackdropFilterDisabled,
                onChanged: (value) => settingsService.setDockBackdropFilterDisabled(!value),
                title: Text(localizations.dockBlur, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.blur_circular),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockShadowEnabled,
                onChanged: settingsService.setDockShadowEnabled,
                title: Text(localizations.dockShadow, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.layers),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockDarkBackground,
                onChanged: settingsService.setDockDarkBackground,
                title: Text(localizations.dockDarkBackground, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.dark_mode),
              ),
              _SectionHeader(localizations.settingsSectionEffects),
              RoundedSwitchListTile(
                value: !settingsService.userBackgroundBlurDisabled,
                onChanged: (value) => settingsService.setBackgroundBlurDisabled(!value),
                title: Text(localizations.backgroundBlur, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.blur_on),
              ),
              RoundedSwitchListTile(
                value: settingsService.showFocusBorders,
                onChanged: (value) => settingsService.setShowFocusBorders(value),
                title: Text(localizations.showFocusBorders, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.border_outer),
              ),
              // Depends on showFocusBorders (see SettingsService.setAppHighlightAnimationEnabled),
              // so it stays listed right after it.
              RoundedSwitchListTile(
                value: settingsService.appHighlightAnimationEnabled,
                onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                title: Text(localizations.appCardHighlightAnimation, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.filter_center_focus),
              ),
              _SectionHeader(localizations.settingsSectionColor),
              FocusableSettingsTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(localizations.sceneOverrideAccentColor, style: Theme.of(context).textTheme.bodyMedium),
                trailing: const Icon(Icons.chevron_right),
                onPressed: () => Navigator.of(context).pushNamed(AccentColorPage.routeName),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain, non-focusable subheader: these pages are flat scrollable lists,
/// not accordions, so a subheader is just a label, never a target.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
