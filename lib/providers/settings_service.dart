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

import 'dart:async';

import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBar = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonAction = "back_button_action";
const _dateFormat = "date_format";
const _showCategoryTitles = "show_category_titles";
const _showAppNamesBelowIcons = "show_app_names_below_icons";
const _showDateInStatusBar = "show_date_in_status_bar";
const _showTimeInStatusBar = "show_time_in_status_bar";
const _timeFormat = "time_format";
const _wifiUsagePeriod = "wifi_usage_period";
const _showWifiWidgetInStatusBar = "show_wifi_widget_in_status_bar";
const String _showNetworkIndicatorInStatusBar = "show_network_indicator_in_status_bar";
const String _accentColor = "accent_color";
const String _screensaverClockStyle = "screensaver_clock_style";
const String _dockBackdropFilterDisabled = "dock_backdrop_filter_disabled";
const String _backgroundBlurDisabled = "background_blur_disabled";
const String _showWatchNextSection = "show_watch_next_section";
const String _dockDarkBackground = "dock_dark_background";
const String _dockShadowEnabled = "dock_shadow_enabled";
const String _showFocusBorders = "show_focus_borders";

// WiFi usage period options
const String WIFI_USAGE_DAILY = "daily";
const String WIFI_USAGE_WEEKLY = "weekly";
const String WIFI_USAGE_MONTHLY = "monthly";

// Accent color presets (hex values)
const String ACCENT_COLOR_PURPLE = "7C4DFF";
const String ACCENT_COLOR_TEAL = "00BFA5";
const String ACCENT_COLOR_BLUE = "2979FF";
const String ACCENT_COLOR_ORANGE = "FF6D00";
const String ACCENT_COLOR_PINK = "F50057";
const String ACCENT_COLOR_GREEN = "00C853";
const String ACCENT_COLOR_WHITE = "FFFFFF";
const String ACCENT_COLOR_YELLOW = "FFD600";
const String ACCENT_COLOR_RED = "D50000";
const String ACCENT_COLOR_CYAN = "00E5FF";
const String ACCENT_COLOR_INDIGO = "536DFE";
const String ACCENT_COLOR_LIME = "AEEA00";
const String ACCENT_COLOR_AMBER = "FFAB00";
const String ACCENT_COLOR_ROSE = "FF4081";
const String ACCENT_COLOR_ICE_BLUE = "80D8FF";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  final SharedPreferences _sharedPreferences;
  final ScenesService _scenesService;

  bool get appHighlightAnimationEnabled =>
      showFocusBorders && (_sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? false);

  bool get appKeyClickEnabled => _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;

  /// The user's own "auto-hide app bar" preference, ignoring any active scene
  /// override. Settings UI must read this one, never [autoHideAppBarEnabled]:
  /// showing the effective (possibly scene-overridden) value on a
  /// configuration screen would make a toggle look broken the moment a scene
  /// masks it.
  bool get userAutoHideAppBarEnabled => _sharedPreferences.getBool(_autoHideAppBar) ?? false;

  /// The effective "auto-hide app bar" setting: the active scene's override
  /// when it has one, otherwise [userAutoHideAppBarEnabled]. Every consumer
  /// outside the settings UI (e.g. the app bar itself) must read this one,
  /// never the user-only getter, so a scene applies wherever the app bar is
  /// actually rendered.
  bool get autoHideAppBarEnabled => _scenesService.activeScene.hideAppBar ?? userAutoHideAppBarEnabled;

  /// The user's own "show category titles" preference. See
  /// [userAutoHideAppBarEnabled] for why the settings UI must use this getter.
  bool get userShowCategoryTitles => _sharedPreferences.getBool(_showCategoryTitles) ?? false;

  /// The effective "show category titles" setting. See
  /// [autoHideAppBarEnabled] for why every other consumer must use this getter.
  bool get showCategoryTitles => _scenesService.activeScene.showCategoryTitles ?? userShowCategoryTitles;

  /// The user's own "show app names below icons" preference. See
  /// [userAutoHideAppBarEnabled] for why the settings UI must use this getter.
  bool get userShowAppNamesBelowIcons => _sharedPreferences.getBool(_showAppNamesBelowIcons) ?? false;

  /// The effective "show app names below icons" setting. See
  /// [autoHideAppBarEnabled] for why every other consumer must use this getter.
  bool get showAppNamesBelowIcons => _scenesService.activeScene.showAppNames ?? userShowAppNamesBelowIcons;

  bool get showDateInStatusBar => _sharedPreferences.getBool(_showDateInStatusBar) ?? false;

  bool get showTimeInStatusBar => _sharedPreferences.getBool(_showTimeInStatusBar) ?? true;

  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);

  String get backButtonAction => _sharedPreferences.getString(_backButtonAction) ?? BACK_BUTTON_ACTION_NOTHING;

  String get dateFormat => _sharedPreferences.getString(_dateFormat) ?? defaultDateFormat;

  String get timeFormat => _sharedPreferences.getString(_timeFormat) ?? defaultTimeFormat;

  String get wifiUsagePeriod => _sharedPreferences.getString(_wifiUsagePeriod) ?? WIFI_USAGE_DAILY;

  bool get showWifiWidgetInStatusBar => _sharedPreferences.getBool(_showWifiWidgetInStatusBar) ?? false;

  bool get showNetworkIndicatorInStatusBar => _sharedPreferences.getBool(_showNetworkIndicatorInStatusBar) ?? true;

  /// The user's own accent color, ignoring any active scene override. See
  /// [userAutoHideAppBarEnabled] for why the settings UI must use this getter.
  String get userAccentColorHex => _sharedPreferences.getString(_accentColor) ?? ACCENT_COLOR_WHITE;

  /// The effective accent color: the active scene's override when it has one
  /// and it is a well-formed 6-digit hex color, otherwise [userAccentColorHex].
  /// See [autoHideAppBarEnabled] for why every other consumer (including the
  /// theme built in `flauncher_app.dart`) must use this getter.
  ///
  /// A scene override that is missing, malformed, or otherwise not a valid hex
  /// color degrades to the user's own accent color rather than throwing or
  /// rendering something arbitrary — same rule as an unknown gradient uuid
  /// (see `WallpaperService._sceneGradientOverride`).
  String get accentColorHex {
    final sceneOverride = _scenesService.activeScene.accentColorHex;
    if (sceneOverride != null && _isValidHexColor(sceneOverride)) {
      return sceneOverride;
    }
    return userAccentColorHex;
  }

  /// Whether [hex] is exactly 6 hexadecimal digits, i.e. safe to feed into
  /// `Color(int.parse("0xFF$hex"))` without throwing.
  static bool _isValidHexColor(String hex) => hex.length == 6 && int.tryParse(hex, radix: 16) != null;

  String get screensaverClockStyle => _sharedPreferences.getString(_screensaverClockStyle) ?? "minimal";

  bool get dockBackdropFilterDisabled => _sharedPreferences.getBool(_dockBackdropFilterDisabled) ?? false;

  /// The user's own "disable background blur" preference. See
  /// [userAutoHideAppBarEnabled] for why the settings UI must use this getter.
  bool get userBackgroundBlurDisabled => _sharedPreferences.getBool(_backgroundBlurDisabled) ?? false;

  /// The effective "disable background blur" setting. See
  /// [autoHideAppBarEnabled] for why every other consumer must use this getter.
  bool get backgroundBlurDisabled => _scenesService.activeScene.disableBackgroundBlur ?? userBackgroundBlurDisabled;

  /// The user's own "show Watch Next section" preference. See
  /// [userAutoHideAppBarEnabled] for why the settings UI must use this getter.
  bool get userShowWatchNextSection => _sharedPreferences.getBool(_showWatchNextSection) ?? false;

  /// The effective "show Watch Next section" setting. See
  /// [autoHideAppBarEnabled] for why every other consumer must use this getter.
  bool get showWatchNextSection => _scenesService.activeScene.showWatchNext ?? userShowWatchNextSection;

  bool get dockDarkBackground => _sharedPreferences.getBool(_dockDarkBackground) ?? false;

  bool get dockShadowEnabled => _sharedPreferences.getBool(_dockShadowEnabled) ?? false;

  bool get showFocusBorders => _sharedPreferences.getBool(_showFocusBorders) ?? true;

  /// Built from the effective [accentColorHex], not the user-only one: the
  /// whole `ColorScheme` in `flauncher_app.dart` is derived from this getter,
  /// so a scene's accent override reaches the theme the same way it reaches
  /// every other consumer.
  Color get accentColor {
    final hex = accentColorHex;
    return Color(int.parse("0xFF$hex"));
  }

  /// Composes the active scene's presentation overrides into the six getters
  /// above, exactly the way `WallpaperService` composes scene wallpaper
  /// overrides: [_scenesService] is listened to here (see [_onScenesChanged])
  /// so every consumer of this service repaints when the active scene
  /// changes, without any of them having to know scenes exist.
  SettingsService(
    this._sharedPreferences,
    this._scenesService
  ) {
    _scenesService.addListener(_onScenesChanged);
  }

  /// A scene change may change any of the six effective getters above, so this
  /// always notifies rather than checking which ones actually differ: the
  /// cost is a handful of extra reads, and false negatives here would mean a
  /// scene silently not applying somewhere.
  void _onScenesChanged() => notifyListeners();

  @override
  void dispose() {
    _scenesService.removeListener(_onScenesChanged);
    super.dispose();
  }

  Future<void> set(String key, bool value) async {
    await _sharedPreferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    if (value && !showFocusBorders) {
      return;
    }
    return set(_appHighlightAnimationEnabledKey, value);
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    return set(_appKeyClickEnabledKey, value);
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    return set(_autoHideAppBar, value);
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_backButtonAction, value);
    notifyListeners();
  }

  Future<void> setDateTimeFormat(String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_dateFormat, dateFormatString),
      _sharedPreferences.setString(_timeFormat, timeFormatString)
    ]);
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    return set(_showCategoryTitles, show);
  }

  Future<void> setShowAppNamesBelowIcons(bool show) async {
    return set(_showAppNamesBelowIcons, show);
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    return set(_showDateInStatusBar, show);
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    return set(_showTimeInStatusBar, show);
  }

  Future<void> setWifiUsagePeriod(String period) async {
    await _sharedPreferences.setString(_wifiUsagePeriod, period);
    notifyListeners();
  }

  Future<void> setShowWifiWidgetInStatusBar(bool show) async {
    return set(_showWifiWidgetInStatusBar, show);
  }

  Future<void> setShowNetworkIndicatorInStatusBar(bool show) async {
    return set(_showNetworkIndicatorInStatusBar, show);
  }

  Future<void> setAccentColor(String colorHex) async {
    await _sharedPreferences.setString(_accentColor, colorHex);
    notifyListeners();
  }

  Future<void> setScreensaverClockStyle(String style) async {
    await _sharedPreferences.setString(_screensaverClockStyle, style);
    notifyListeners();
  }

  Future<void> setDockBackdropFilterDisabled(bool value) async {
    return set(_dockBackdropFilterDisabled, value);
  }

  Future<void> setBackgroundBlurDisabled(bool value) async {
    return set(_backgroundBlurDisabled, value);
  }

  Future<void> setShowWatchNextSection(bool value) async {
    return set(_showWatchNextSection, value);
  }

  Future<void> setDockDarkBackground(bool value) async {
    return set(_dockDarkBackground, value);
  }

  Future<void> setDockShadowEnabled(bool value) async {
    return set(_dockShadowEnabled, value);
  }

  Future<void> setShowFocusBorders(bool value) async {
    await set(_showFocusBorders, value);
    if (!value) {
      await setAppHighlightAnimationEnabled(false);
    }
  }

  bool get timeBasedWallpaperEnabled => _sharedPreferences.getBool("time_based_wallpaper_enabled") ?? false;

  Future<void> setTimeBasedWallpaperEnabled(bool enabled) async {
    await _sharedPreferences.setBool("time_based_wallpaper_enabled", enabled);
    notifyListeners();
  }
}
