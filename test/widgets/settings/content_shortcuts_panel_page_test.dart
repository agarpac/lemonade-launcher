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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/content_shortcut_panel_page.dart';
import 'package:flauncher/widgets/settings/content_shortcuts_panel_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../flauncher_test.dart' show isFocused;
import '../../mocks.mocks.dart';

const _smartTube = "com.teamsmart.videomanager.tv";

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Every shortcut of the section is listed, in its stored order", (tester) async {
    final appsService = MockAppsService();
    final section = _mkSection([_mkShortcut(1, "Subscriptions"), _mkShortcut(2, "Lo-fi radio")]);
    when(appsService.contentShortcutSections).thenReturn([section]);

    await _pumpPage(tester, appsService);

    expect(find.text("Subscriptions"), findsOneWidget);
    expect(find.text("Lo-fi radio"), findsOneWidget);
    expect(
      tester.getCenter(find.text("Subscriptions")).dy < tester.getCenter(find.text("Lo-fi radio")).dy,
      isTrue,
    );
  });

  testWidgets("The first shortcut takes the focus as soon as the panel opens", (tester) async {
    // Regression test for defect 13.6: this panel is pushed from another panel
    // that still holds the focus, so `autofocus` never fires and OK does
    // nothing until the user presses Down first.
    final appsService = MockAppsService();
    final firstShortcut = _mkShortcut(1, "Subscriptions");
    when(appsService.contentShortcutSections)
        .thenReturn([_mkSection([firstShortcut, _mkShortcut(2, "Lo-fi radio")])]);

    await _pumpPage(tester, appsService);

    // By the shortcut's own key rather than `find.byType(Focus)`: the page's
    // ancestor chain (MaterialApp, Actions, Shortcuts...) contains more than
    // one `Focus` widget, so matching by type alone is ambiguous.
    final firstTile = tester.element(find.byKey(ObjectKey(firstShortcut)));
    expect(isFocused(firstTile), isTrue);
  });

  testWidgets("'Add shortcut' takes the focus instead, when the section is empty", (tester) async {
    // The empty-section message is not a tile and cannot hold focus, so the
    // panel must never be left with nothing focused at all.
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections).thenReturn([]);

    await _pumpPage(tester, appsService);

    final addTile =
        tester.element(find.ancestor(of: find.text("Add shortcut"), matching: find.byType(FocusableSettingsTile)));
    expect(isFocused(addTile), isTrue);
  });

  testWidgets("An unavailable shortcut is marked as such here too", (tester) async {
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections)
        .thenReturn([_mkSection([_mkShortcut(1, "Subscriptions", available: false)])]);

    await _pumpPage(tester, appsService);

    expect(find.text("Unavailable"), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  testWidgets("Choosing a shortcut opens it for editing", (tester) async {
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections).thenReturn([_mkSection([_mkShortcut(1, "Subscriptions")])]);

    final routes = await _pumpPage(tester, appsService);

    await tester.tap(find.text("Subscriptions"));
    await tester.pumpAndSettle();

    expect(routes.pushedName, ContentShortcutPanelPage.routeName);
    final arguments = routes.pushedArguments as ContentShortcutPanelPageArguments;
    expect(arguments.shortcut?.id, 1);
  });

  testWidgets("'Add shortcut' opens a new one in this very section", (tester) async {
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections).thenReturn([_mkSection([_mkShortcut(1, "Subscriptions")])]);

    final routes = await _pumpPage(tester, appsService);

    await tester.tap(find.text("Add shortcut"));
    await tester.pumpAndSettle();

    expect(routes.pushedName, ContentShortcutPanelPage.routeName);
    final arguments = routes.pushedArguments as ContentShortcutPanelPageArguments;
    expect(arguments.sectionId, 7);
    expect(arguments.shortcut, isNull);
  });

  testWidgets("Left, then Down, then Enter moves a shortcut and stores the new order", (tester) async {
    final appsService = MockAppsService();
    // `reorderContentShortcut` must really reorder the backing list: the page
    // re-reads the section afterwards while still treating the same shortcut as
    // the one being moved, by its new position.
    final shortcuts = [_mkShortcut(1, "Subscriptions"), _mkShortcut(2, "Lo-fi radio")];
    when(appsService.contentShortcutSections).thenAnswer((_) => [_mkSection(List.of(shortcuts))]);
    when(appsService.reorderContentShortcut(any, any, any)).thenAnswer((invocation) {
      final oldIndex = invocation.positionalArguments[1] as int;
      final newIndex = invocation.positionalArguments[2] as int;
      shortcuts.insert(newIndex, shortcuts.removeAt(oldIndex));
    });
    when(appsService.saveContentShortcutOrder(any)).thenAnswer((_) async {});

    await _pumpPage(tester, appsService);

    // A tile only reacts to arrow and select keys while it holds the focus;
    // long-pressing puts it into "moving" mode but does not grant focus, exactly
    // as in the sections list.
    await tester.longPress(find.text("Subscriptions"));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text("Subscriptions"))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    verify(appsService.reorderContentShortcut(any, 0, 1)).called(1);
    verify(appsService.saveContentShortcutOrder(any)).called(1);
    expect(shortcuts.map((shortcut) => shortcut.label), ["Lo-fi radio", "Subscriptions"]);
  });

  testWidgets("Moving is bounded by the ends of the list", (tester) async {
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections)
        .thenReturn([_mkSection([_mkShortcut(1, "Subscriptions"), _mkShortcut(2, "Lo-fi radio")])]);
    when(appsService.saveContentShortcutOrder(any)).thenAnswer((_) async {});

    await _pumpPage(tester, appsService);

    await tester.longPress(find.text("Subscriptions"));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text("Subscriptions"))).requestFocus();
    await tester.pumpAndSettle();
    // Already the first one.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    verifyNever(appsService.reorderContentShortcut(any, any, any));
  });

  testWidgets("A section whose last shortcut was deleted says so, and is never a dead end", (tester) async {
    // A section *is* the shortcuts that share its id, so deleting the last one
    // deleted the section. Coming back here must explain that rather than show an
    // empty page, and "Add shortcut" must still work — it simply starts a new
    // section.
    final appsService = MockAppsService();
    when(appsService.contentShortcutSections).thenReturn([]);

    final routes = await _pumpPage(tester, appsService);

    expect(find.text("This section has no shortcuts."), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("Add shortcut"));
    await tester.pumpAndSettle();

    expect(routes.pushedName, ContentShortcutPanelPage.routeName);
  });
}

ContentShortcut _mkShortcut(int id, String label, {bool available = true}) => ContentShortcut(
      id: id,
      sectionId: 7,
      order: id,
      label: label,
      uri: "https://www.youtube.com/feed/subscriptions",
      targetPackage: _smartTube,
      available: available,
    );

ContentShortcutSection _mkSection(List<ContentShortcut> shortcuts) =>
    ContentShortcutSection(id: 7, order: 0, shortcuts: shortcuts);

/// Captures what the page pushed, so the tests can assert the route and its
/// arguments without building the pushed page.
class _PushedRoutes {
  String? pushedName;
  Object? pushedArguments;
}

Future<_PushedRoutes> _pumpPage(WidgetTester tester, MockAppsService appsService) async {
  final routes = _PushedRoutes();

  await tester.pumpWidget(
    ChangeNotifierProvider<AppsService>.value(
      value: appsService,
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ContentShortcutsPanelPage(sectionId: 7)),
        onGenerateRoute: (settings) {
          routes.pushedName = settings.name;
          routes.pushedArguments = settings.arguments;
          return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return routes;
}
