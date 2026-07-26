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

import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/category_clean_row.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';

// FLauncher's home page was restructured: it used to read a single flattened
// `AppsService.categoriesWithApps` list and render every category as either a CategoryRow (row
// type, via an AppsGrid-less ListView) or a discrete AppsGrid widget (grid type). It now reads
// `AppsService.categories` (to find the "Favorites" category, which always renders as a
// horizontal dock via CategoryCleanRow regardless of its own `type`) and
// `AppsService.launcherSections` (every other section, rendered inline: CategoryRow for row type,
// a plain SliverGrid of AppCards for grid type — the old `AppsGrid` widget is no longer used on
// this screen). Categories with zero applications are skipped entirely (no title, no
// "This category is empty" placeholder) rather than rendered with an empty-state message.
void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Home page shows categories with apps", (tester) async {
    final appsService = mkAppService();
    final favoritesCategory = fakeCategory(name: "Favorites", order: 0, type: CategoryType.row);
    favoritesCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.1",
      name: "FLauncher 1",
      version: "1.0.0",
    ));
    final applicationsCategory = fakeCategory(name: "Applications", order: 1);
    applicationsCategory.applications.add(fakeApp(
      packageName: "me.efesser.flauncher.2",
      name: "FLauncher 2",
      version: "2.0.0",
    ));
    mockSections(appsService, [favoritesCategory, applicationsCategory]);

    await _pumpWidgetWith(tester, appsService);

    expect(find.byType(CategoryCleanRow), findsOneWidget, reason: "Favorites renders as the dock");
    expect(findAppCardByPackageName(tester, "me.efesser.flauncher.1"), isNotNull);

    // The dock reserves a tall spacer above it, pushing "otherSections" (like Applications)
    // below the initial viewport; scroll down so the CustomScrollView builds those slivers.
    await tester.scrollUntilVisible(find.text("Applications"), 300, scrollable: find.byType(Scrollable).first);

    expect(find.text("Applications"), findsOneWidget);
    expect(findAppCardByPackageName(tester, "me.efesser.flauncher.2"), isNotNull);
  });

  testWidgets("Home page hides categories with no applications", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 0, type: CategoryType.grid);
    final favoritesCategory = fakeCategory(name: "Favorites", order: 1, type: CategoryType.row);
    mockSections(appsService, [applicationsCategory, favoritesCategory]);

    await _pumpWidgetWith(tester, appsService);

    expect(find.text("Applications"), findsNothing);
    expect(find.text("Favorites"), findsNothing);
    expect(find.byType(CategoryCleanRow), findsNothing);
  });

  testWidgets("Home page displays background image", (tester) async {
    final appsService = mkAppService();
    mockSections(appsService, []);

    await _pumpWidgetWith(tester, appsService);

    // The background Image's key is now "background_<wallpaperRevision>" instead of a static
    // "background" key.
    expect(tester.widget(find.byKey(ValueKey("background_0"))), isA<Image>());
  });

  testWidgets("Home page displays background gradient", (tester) async {
    final appsService = mkAppService();
    mockSections(appsService, []);

    await _pumpWidgetWithProviders(tester, mkWallpaperService(false), appsService, mkSettingsService());

    // The gradient background is now rendered by a private _CachedGradientBackground widget
    // (rasterized once into a texture) instead of a plain Container; check it's not the Image
    // path used when a wallpaper is set, rather than a specific (private) widget type.
    expect(find.byKey(Key("background")), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key("background")), matching: find.byType(Image)), findsNothing);
  });

  testWidgets("Pressing select on settings icon opens SettingsPanel", (tester) async {
    final appsService = mkAppService();
    mockSections(appsService, [
      fakeCategory(name: "Favorites", order: 0),
      fakeCategory(name: "Applications", order: 1),
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.byType(SettingsPanelPage), findsOneWidget);
  });

  testWidgets("Pressing select on app launches it", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    );
    final applicationsCategory = fakeCategory(name: "Applications", order: 1);
    applicationsCategory.applications.add(app);
    mockSections(appsService, [
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    // AppCard now delays the actual launch by 150ms for a "clicked" visual feedback state, then
    // resets that state after another 500ms; advance past both so no timer is left pending.
    await tester.pump(const Duration(milliseconds: 200));
    verify(appsService.launchApp(app));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("Long pressing on app opens ApplicationInfoPanel", (tester) async {
    final appsService = mkAppService();
    final app = fakeApp(
      packageName: "me.efesser.flauncher",
      name: "FLauncher",
      version: "1.0.0",
    );
    when(appsService.hasCustomBanner(app.packageName)).thenAnswer((_) => Future.value(false));
    when(appsService.isAppInFavorites(app)).thenReturn(false);
    final applicationsCategory = fakeCategory(name: "Applications", order: 1);
    applicationsCategory.applications.add(app);
    mockSections(appsService, [
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pump();

    expect(find.byType(ApplicationInfoPanel), findsOneWidget);
  });

  testWidgets("AppCard moves in grid", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1, type: CategoryType.grid);
    applicationsCategory.applications.addAll([
      fakeApp(
        packageName: "me.efesser.flauncher",
        name: "FLauncher",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.flauncher.2",
        name: "FLauncher 2",
        version: "1.0.0",
      )
    ]);
    mockSections(appsService, [
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    verify(appsService.reorderApplication(applicationsCategory, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    verify(appsService.saveApplicationOrderInCategory(applicationsCategory));
  });

  testWidgets("AppCard moves in row", (tester) async {
    final appsService = mkAppService();
    final applicationsCategory = fakeCategory(name: "Applications", order: 1, type: CategoryType.row);
    applicationsCategory.applications.addAll([
      fakeApp(
        packageName: "me.efesser.flauncher",
        name: "FLauncher",
        version: "1.0.0",
      ),
      fakeApp(
        packageName: "me.efesser.flauncher.2",
        name: "FLauncher 2",
        version: "1.0.0",
      )
    ]);
    mockSections(appsService, [
      fakeCategory(name: "Favorites", order: 0),
      applicationsCategory,
    ]);
    await _pumpWidgetWith(tester, appsService);

    await tester.longPress(find.byKey(Key("me.efesser.flauncher")));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    verify(appsService.reorderApplication(applicationsCategory, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    verify(appsService.saveApplicationOrderInCategory(applicationsCategory));
  });

  testWidgets("Moving down does not skip row", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 3 rows like the following:
     * ▭ ▭ ▭
     * ▭ ▭
     * ▭ ▭ ▭
     */
    final tv = fakeCategory(name: "tv", order: 0);
    tv.applications.addAll([
      fakeApp(packageName: "me.efesser.tv1", name: "tv 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.tv2", name: "tv 2", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.tv3", name: "tv 3", version: "1.0.0"),
    ]);
    final music = fakeCategory(name: "music", order: 1);
    music.applications.addAll([
      fakeApp(packageName: "me.efesser.music1", name: "music 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music2", name: "music 2", version: "1.0.0"),
    ]);
    final games = fakeCategory(name: "games", order: 2);
    games.applications.addAll([
      fakeApp(packageName: "me.efesser.game1", name: "game 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.game2", name: "game 2", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.game3", name: "game 3", version: "1.0.0"),
    ]);
    mockSections(appsService, [tv, music, games]);

    await _pumpWidgetWith(tester, appsService);
    // when
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    Element? music2 = findAppCardByPackageName(tester, "me.efesser.music2");
    expect(music2, isNotNull);
    expect(isFocused(tv1!), isFalse);
    expect(isFocused(music2!), isTrue); // this is new, before it was going straight to the third row

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    Element? game2 = findAppCardByPackageName(tester, "me.efesser.game2");
    expect(game2, isNotNull);
    expect(isFocused(tv1), isFalse);
    expect(isFocused(music2), isFalse);
    expect(isFocused(game2!), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(isFocused(tv1), isFalse);
    expect(isFocused(music2), isTrue);
    expect(isFocused(game2), isFalse);
  });

  testWidgets("Moving left or right stays on the same row", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 2 rows like the following:
     * ▭ ▭
     * ▭ ▭ ▭ ▭ ▭
     */
    final tv = fakeCategory(name: "tv", order: 0);
    tv.applications.addAll([
      fakeApp(packageName: "me.efesser.tv1", name: "tv 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.tv2", name: "tv 2", version: "1.0.0"),
    ]);
    final music = fakeCategory(name: "music", order: 1, columnsCount: 5);
    music.applications.addAll([
      fakeApp(packageName: "me.efesser.music1", name: "music 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music2", name: "music 2", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music3", name: "music 3", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music4", name: "music 4", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music5", name: "music 5", version: "1.0.0"),
    ]);
    mockSections(appsService, [tv, music]);

    await _pumpWidgetWith(tester, appsService);

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    expect(isFocused(tv1!), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    Element? music1 = findAppCardByPackageName(tester, "me.efesser.music1");
    expect(music1, isNotNull);
    expect(isFocused(tv1), isFalse);
    expect(isFocused(music1!), isTrue);

    // check right direction
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    Element? music2 = findAppCardByPackageName(tester, "me.efesser.music2");
    expect(music2, isNotNull);
    expect(isFocused(tv1), isFalse);
    expect(isFocused(music1), isFalse);
    expect(isFocused(music2!), isTrue);

    // check if right on the last app stays on the same app
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    Element? music5 = findAppCardByPackageName(tester, "me.efesser.music5");
    expect(music5, isNotNull);
    expect(isFocused(music5!), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    Element? tv2 = findAppCardByPackageName(tester, "me.efesser.tv2");
    expect(tv2, isNotNull);
    expect(isFocused(tv2!), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(isFocused(music2), isTrue);

    // check left direction
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(isFocused(music1), isTrue);

    // check if going left on the first app stays on the same app
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(isFocused(music1), isTrue);
  });

  testWidgets("Moving up from the first row goes to the settings icon", (tester) async {
    // given
    final appsService = mkAppService();

    /*
     * we are creating 2 rows like the following:
     * ▭ ▭
     * ▭ ▭ ▭
     */
    final tv = fakeCategory(name: "tv", order: 0);
    tv.applications.addAll([
      fakeApp(packageName: "me.efesser.tv1", name: "tv 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.tv2", name: "tv 2", version: "1.0.0"),
    ]);
    final music = fakeCategory(name: "music", order: 1);
    music.applications.addAll([
      fakeApp(packageName: "me.efesser.music1", name: "music 1", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music2", name: "music 2", version: "1.0.0"),
      fakeApp(packageName: "me.efesser.music3", name: "music 3", version: "1.0.0"),
    ]);
    mockSections(appsService, [tv, music]);

    await _pumpWidgetWith(tester, appsService);

    // then
    Element? tv1 = findAppCardByPackageName(tester, "me.efesser.tv1");
    expect(tv1, isNotNull);
    expect(isFocused(tv1!), isTrue);

    // The settings button moved from the app bar's actions (right side) to its title (left
    // side), so it's no longer directly to the right of the grid; reaching it now relies on the
    // explicit "arrow up from the first row" shortcut (AppCard.handleUpNavigationToSettings)
    // rather than plain geometric right-navigation.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

    Element? settingsIcon = findSettingsIcon(tester);
    expect(settingsIcon, isNotNull);
    expect(isFocused(tv1), isFalse);
    expect(isFocused(settingsIcon!), isTrue);

    // The settings button now sits on the left of the app bar, so moving down from it lands
    // back on the leftmost card (tv1) rather than tv2 (which was the case when the button used
    // to be on the right).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(isFocused(settingsIcon), isFalse);
    expect(isFocused(tv1), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(isFocused(settingsIcon), isTrue);
  });
}

SettingsService mkSettingsService() {
  final settingsService = MockSettingsService();
  when(settingsService.dateFormat).thenReturn(SettingsService.defaultDateFormat);
  when(settingsService.timeFormat).thenReturn(SettingsService.defaultTimeFormat);
  when(settingsService.appHighlightAnimationEnabled).thenReturn(true);
  when(settingsService.backgroundBlurDisabled).thenReturn(false);
  when(settingsService.showWatchNextSection).thenReturn(false);
  when(settingsService.showCategoryTitles).thenReturn(true);
  when(settingsService.showAppNamesBelowIcons).thenReturn(false);
  when(settingsService.dockBackdropFilterDisabled).thenReturn(true);
  when(settingsService.dockDarkBackground).thenReturn(false);
  when(settingsService.dockShadowEnabled).thenReturn(false);
  when(settingsService.accentColorHex).thenReturn("FFFFFF");
  when(settingsService.showFocusBorders).thenReturn(true);
  when(settingsService.autoHideAppBarEnabled).thenReturn(false);
  when(settingsService.showNetworkIndicatorInStatusBar).thenReturn(false);
  when(settingsService.showWifiWidgetInStatusBar).thenReturn(false);
  when(settingsService.showDateInStatusBar).thenReturn(false);
  when(settingsService.showTimeInStatusBar).thenReturn(false);
  return settingsService;
}

WallpaperService mkWallpaperService([bool wallpaper = true]) {
  final wallpaperService = MockWallpaperService();
  when(wallpaperService.gradient).thenReturn(FLauncherGradients.greatWhale);
  when(wallpaperService.wallpaper).thenReturn(wallpaper ? Image.asset('assets/icon.png').image : null);
  when(wallpaperService.wallpaperVideoFile).thenReturn(null);
  when(wallpaperService.wallpaperRevision).thenReturn(0);
  return wallpaperService;
}

AppsService mkAppService() {
  final appsService = MockAppsService();
  when(appsService.initialized).thenReturn(true);
  when(appsService.layoutVersion).thenReturn(0);
  when(appsService.pendingReorderFocusPackage).thenReturn(null);
  when(appsService.pendingReorderFocusCategoryId).thenReturn(null);
  // Long-pressing any AppCard opens ApplicationInfoPanel, which unconditionally reads these.
  when(appsService.hasCustomBanner(any)).thenAnswer((_) => Future.value(false));
  when(appsService.isAppInFavorites(any)).thenReturn(false);
  return appsService;
}

/// Whether the currently focused widget visually overlaps [element]'s render box. This is more
/// robust than `Focus.of(element).hasFocus` for these tests: `Focus.of()` resolves to the
/// *nearest* Focus ancestor of `element`, which depends on incidental nesting details (e.g. some
/// buttons wrap an outer explicit FocusNode around an inner InkWell that creates its own implicit
/// one, so `Focus.of()` on a descendant can resolve to the wrong node and report `hasFocus: false`
/// even though that exact button is what's focused). Comparing screen geometry to the
/// FocusManager's primary focus rect sidesteps that entirely.
bool isFocused(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  final focusRect = WidgetsBinding.instance.focusManager.primaryFocus?.rect;
  return focusRect != null && rect.overlaps(focusRect);
}

/// Stubs both AppsService.categories and AppsService.launcherSections with the same list of
/// categories (no spacers are used by these tests), matching how the real AppsService exposes
/// the same underlying sections through both getters.
void mockSections(AppsService appsService, List<Category> categories) {
  when(appsService.categories).thenReturn(categories);
  when(appsService.launcherSections).thenReturn(categories);
}

Future<void> _pumpWidgetWith(
  WidgetTester tester,
  AppsService appsService,
) async {
  return _pumpWidgetWithProviders(tester, mkWallpaperService(), appsService, mkSettingsService());
}

Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  WallpaperService wallpaperService,
  AppsService appsService,
  SettingsService settingsService,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider(create: (_) => LauncherState()),
        ChangeNotifierProvider(create: (_) => NetworkService(FLauncherChannel())),
        ChangeNotifierProvider(create: (_) => WatchNextService(FLauncherChannel())),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FLauncher(),
      ),
    ),
  );
  await tester.pump(Duration(seconds: 30), EnginePhase.sendSemanticsUpdate);
}
