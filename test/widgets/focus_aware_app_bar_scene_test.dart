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

// Regression test for FocusAwareAppBar's fix to a focus-stranding bug: the
// `Focus` wrapper tracking whether something inside the app bar is focused
// used to be built only while `autoHideAppBarEnabled` was already true, so
// toggling it — as a scene activation can, instantly, rather than through a
// user tapping this exact button — inserted that FocusNode into the tree at
// the same instant `focused` was read to decide the bar's height. See
// `lib/widgets/focus_aware_app_bar.dart`'s `build` method for the fix (the
// wrapper is now always mounted).
//
// Real SettingsService and ScenesService are used, because the point of this
// test is the wiring itself: a genuine scene activation notifying
// SettingsService, which the app bar's Selector reacts to.

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../flauncher_test.dart' show isFocused;
import '../helpers.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  testWidgets(
      "activating a scene that hides the app bar does not strand focus: "
      "the bar stays visible because the settings button is still focused",
      (tester) async {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    final sharedPreferences = await SharedPreferences.getInstance();
    final scenesService = ScenesService(sharedPreferences);
    final settingsService = SettingsService(sharedPreferences, scenesService);
    // Avoid needing a NetworkService provider just to render the app bar.
    await settingsService.setShowNetworkIndicatorInStatusBar(false);
    await scenesService.setSceneHideAppBar(SceneKeys.cinema, true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ChangeNotifierProvider<ScenesService>.value(value: scenesService),
          ChangeNotifierProvider(create: (_) => LauncherState()),
        ],
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(appBar: FocusAwareAppBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBarState = tester.state<FocusAwareAppBarState>(find.byType(FocusAwareAppBar));
    appBarState.focusSettings();
    await tester.pumpAndSettle();

    final settingsIcon = findSettingsIcon(tester);
    expect(settingsIcon, isNotNull);
    expect(isFocused(settingsIcon!), isTrue);

    // The scene is activated while the settings button already holds focus,
    // exactly the moment the old, conditionally-mounted Focus wrapper could
    // get caught out.
    await scenesService.activateScene(SceneKeys.cinema);
    await tester.pumpAndSettle();

    // Something must still hold focus (the remote must keep working)...
    expect(FocusManager.instance.primaryFocus, isNotNull);
    // ...and specifically the settings button never lost it, which is why the
    // app bar stayed visible instead of collapsing to zero height under it.
    expect(isFocused(settingsIcon), isTrue);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
