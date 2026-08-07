import 'package:flauncher/widgets/scene_picker_panel.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/launcher_state.dart';
import '../providers/scenes_service.dart';
import '../providers/settings_service.dart';
import 'daily_wifi_usage_widget.dart';
import 'date_time_widget.dart';
import 'network_widget.dart';
import 'status_bar_glass_card.dart';
import 'status_bar_weather_widget.dart';

class FocusAwareAppBar extends StatefulWidget implements PreferredSizeWidget
{
  const FocusAwareAppBar({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return FocusAwareAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class FocusAwareAppBarState extends State<FocusAwareAppBar>
{
  bool focused = false;
  late FocusNode _settingsFocusNode;
  late FocusNode _scenesFocusNode;

  @override
  void initState() {
    super.initState();
    _settingsFocusNode = FocusNode();
    _scenesFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _settingsFocusNode.dispose();
    _scenesFocusNode.dispose();
    super.dispose();
  }

  void focusSettings() {
    _settingsFocusNode.requestFocus();
  }

  /// Opens the scene picker, then returns focus to this button once it
  /// closes (however it closed: Back or activating a scene), so the remote
  /// never ends up focused on a widget that's no longer on screen.
  Future<void> _openScenePicker(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const ScenePickerPanel());
    // `_scenesFocusNode` is only attached to a widget while the scenes icon is
    // actually built (see `scenesEnabled` gating in `build`), so this checks
    // attachment rather than only `mounted`: the icon can only be reached
    // through this same method, but a dangling `requestFocus()` on a
    // detached node is cheap to guard against and expensive to debug if the
    // gating above ever changes shape.
    if (mounted && _scenesFocusNode.context != null) {
      _scenesFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The Focus wrapper (and its focus tracking) stays mounted unconditionally,
    // regardless of `autoHide`. It used to be built only inside the `autoHide`
    // branch, which meant toggling `autoHide` — e.g. a scene activation, which
    // can happen instantly rather than through a user tapping this exact
    // button — inserted/removed this FocusNode from the tree at the same
    // moment `focused` was read to decide the height, so a descendant that
    // already held focus at that instant could be judged "not focused" for a
    // frame before the focus manager caught up. Keeping it always mounted
    // means `focused` is already accurate by the time `autoHide` changes, so
    // the bar never collapses out from under a focused control.
    return Focus(
      canRequestFocus: false,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          context.read<LauncherState>().setAppGridFocused(false);
        }
        this.setState(() {
          focused = hasFocus;
        });
      },
      child: Selector<SettingsService, bool>(
        selector: (_, settings) => settings.autoHideAppBarEnabled,
        builder: (context, autoHide, widget) {
          final visible = !autoHide || focused;
          return AnimatedContainer(
            curve: Curves.decelerate,
            duration: Duration(milliseconds: 150),
            height: visible ? kToolbarHeight : 0,
            child: widget
          );
        },
        child: RepaintBoundary(
        child: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          // Left side: Settings, Network indicator, WiFi usage
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Settings button (moved to left side). A tight padding keeps the
              // card close to the icon's own bounds rather than the wider pill
              // used for text content elsewhere in the bar, while the radius and
              // translucency stay the same everywhere.
              // Each left-side item carries its own gap to the right, applied
              // only while it is shown. That way hiding any of them — the scenes
              // icon when the feature is off, the network or Wi-Fi indicator when
              // switched off — never glues two neighbours together nor leaves an
              // uneven gap: the spacing belongs to the item, not to a fixed
              // SizedBox that survives when its icon does not.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _FocusableIconButton(
                  icon: Icons.settings_outlined,
                  focusNode: _settingsFocusNode,
                  onPressed: () => showDialog(context: context, builder: (_) => const SettingsPanel()),
                ),
              ),
              // The master Scenes switch (default off, see
              // `SettingsService.scenesEnabled`) gates only this home-bar entry
              // point, never the Scenes tile inside Settings — so when the
              // feature is off, nothing here is built at all: no spacing, no
              // icon, and critically no `_FocusableIconButton` for
              // `_scenesFocusNode` to attach to. A hidden control never gets a
              // chance to request focus (see `_openScenePicker`'s own
              // attachment guard), and turning the feature back on rebuilds
              // this exactly as if it had never been hidden.
              Selector<SettingsService, bool>(
                selector: (_, settings) => settings.scenesEnabled,
                builder: (context, scenesEnabled, _) => scenesEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      // Scoped to just this icon: it must not trigger a rebuild of the whole
                      // app bar every time the active scene changes.
                      child: Selector<ScenesService, String>(
                        selector: (_, scenesService) => scenesService.activeSceneKey,
                        builder: (context, activeSceneKey, _) => Tooltip(
                          message: AppLocalizations.of(context)!.scenes,
                          child: _FocusableIconButton(
                            icon: sceneIconFor(activeSceneKey),
                            focusNode: _scenesFocusNode,
                            onPressed: () => _openScenePicker(context),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
              // Network indicator (conditionally shown)
              Selector<SettingsService, bool>(
                selector: (_, settings) => settings.showNetworkIndicatorInStatusBar,
                builder: (context, showNetwork, _) => showNetwork
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _FocusableNetworkWidget(),
                    )
                  : const SizedBox.shrink(),
              ),
              // WiFi usage widget
              Selector<SettingsService, bool>(
                selector: (_, settings) => settings.showWifiWidgetInStatusBar,
                builder: (context, showWifi, _) => showWifi
                  ? const StatusBarGlassCard(child: DailyWifiUsageWidget())
                  : const SizedBox.shrink(),
              ),
            ],
          ),
          // Right side: weather, then Date/Time
          actions: [
            // To the *left* of the clock on purpose: the date and time keep the
            // corner the user's eye already goes to, and the weather grows
            // inwards from there.
            //
            // Gated on the setting here rather than only inside the widget so
            // that a launcher with the weather switched off — the default —
            // never even looks up `WeatherService`. Same shape as the network
            // and Wi-Fi indicators on the other side of the bar.
            //
            // `AppBar` lays its actions out with `CrossAxisAlignment.stretch`,
            // so the card is centred explicitly; without this it would grow to
            // the full toolbar height.
            Center(
              child: Selector<SettingsService, bool>(
                selector: (_, settings) => settings.showWeather,
                builder: (context, showWeather, _) =>
                    showWeather ? const StatusBarWeatherWidget() : const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 32),
              child: Selector<SettingsService,
                  ({
                    bool showDateInStatusBar,
                    bool showTimeInStatusBar,
                    String dateFormat,
                    String timeFormat })>(
                selector: (context, service) => (
                showDateInStatusBar: service.showDateInStatusBar,
                showTimeInStatusBar: service.showTimeInStatusBar,
                dateFormat: service.dateFormat,
                timeFormat: service.timeFormat),
                builder: (context, dateTimeSettings, _) {
                  // Same "nothing to say, nothing drawn" rule as the weather,
                  // network and Wi-Fi cards: with both switched off there is no
                  // content, so no empty frosted pill should appear either.
                  if (!dateTimeSettings.showDateInStatusBar && !dateTimeSettings.showTimeInStatusBar) {
                    return const SizedBox.shrink();
                  }

                  // Define standard text style
                  const textStyle = TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)
                    ],
                  );

                  // The date and the clock always sit together as one glance
                  // ("what time is it, on what day"), so they share a single
                  // card rather than one each.
                  return StatusBarGlassCard(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Date
                        if (dateTimeSettings.showDateInStatusBar)
                          DateTimeWidget(
                            dateTimeSettings.dateFormat,
                            key: const Key("statusbar_date"),
                            updateInterval: const Duration(minutes: 1),
                            textStyle: textStyle,
                          ),

                        if (dateTimeSettings.showDateInStatusBar && dateTimeSettings.showTimeInStatusBar)
                            const SizedBox(width: 16),

                        // Clock
                        if (dateTimeSettings.showTimeInStatusBar)
                          DateTimeWidget(
                            dateTimeSettings.timeFormat,
                            key: const Key("statusbar_clock"),
                            updateInterval: const Duration(minutes: 1),
                            textStyle: textStyle.copyWith(fontWeight: FontWeight.bold),
                          ),
                      ]
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Reusable focusable icon button with consistent outline focus indicator
class _FocusableIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _FocusableIconButton({required this.icon, required this.onPressed, this.focusNode});

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // The card is built here, around the `Focus` node, rather than by the
    // caller: `StatusBarGlassCard` never owns focus state (see its class
    // doc), so the widget that does own it — this one — is the only place
    // that can tell the card whether to paint the outline.
    return StatusBarGlassCard(
      padding: const EdgeInsets.all(6),
      focused: _focused,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => widget.onPressed()),
        },
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              context.read<LauncherState>().setAppGridFocused(false);
            }
            setState(() => _focused = hasFocus);
          },
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),  // Match network indicator padding
              child: Icon(widget.icon,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Network widget with consistent focus indicator
class _FocusableNetworkWidget extends StatefulWidget {
  @override
  State<_FocusableNetworkWidget> createState() => _FocusableNetworkWidgetState();
}

class _FocusableNetworkWidgetState extends State<_FocusableNetworkWidget> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Same rationale as `_FocusableIconButton`: the card is built here so the
    // state that knows about focus is the state that drives the card's
    // outline, without `StatusBarGlassCard` itself ever touching focus.
    return StatusBarGlassCard(
      padding: const EdgeInsets.all(6),
      focused: _focused,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            context.read<LauncherState>().setAppGridFocused(false);
          }
          setState(() => _focused = hasFocus);
        },
        child: const NetworkWidget(),
      ),
    );
  }
}