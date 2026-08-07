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
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../flauncher_test.dart' show isFocused;
import '../../mocks.mocks.dart';

const _smartTube = "com.teamsmart.videomanager.tv";
const _otherPlayer = "org.example.player";

const _invalidAddressMessage =
    "This is not a channel or an address that can be opened. Try @handle, a channel id, or a full address.";
const _noTargetMessage = "No installed app reported that it can open this address. "
    "The address may well be right: this also happens when the app is installed but this version of Android "
    "does not let the launcher see it.";

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Starts on the prompt, with nothing to save and no target chosen", (tester) async {
    final appsService = _mkAppsService();

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());

    expect(find.text("New shortcut"), findsOneWidget);
    expect(find.text("No app chosen yet"), findsOneWidget);
    // Never a blank space where the answer will be.
    expect(
      find.text("Type @handle, a channel id or a full address, "
          "then confirm to look for the apps that can open it."),
      findsOneWidget,
    );
    // Nothing has been typed, so there is nothing to store yet.
    expect(find.text("Save"), findsNothing);
  });

  testWidgets("Creating a shortcut pre-fills the address with '@', caret after it", (tester) async {
    // Hunting for "@" on a D-pad keyboard is the slow part of adding a channel,
    // so the field starts with it and the caret sits just past it.
    final appsService = _mkAppsService();

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());

    final TextField addressField = tester.widget<TextField>(_addressField);
    expect(addressField.controller!.text, "@");
    expect(addressField.controller!.selection.baseOffset, 1);
    // A lone "@" is not a valid address, so there is still nothing to save.
    expect(find.text("Save"), findsNothing);
  });

  testWidgets("Editing an existing shortcut does not force a '@' over its address", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, ContentShortcutPanelPageArguments(shortcut: _mkShortcut()));

    expect(
      tester.widget<TextField>(_addressField).controller!.text,
      "https://www.youtube.com/feed/subscriptions",
    );
  });

  testWidgets("Typing the address resolves nothing; submitting it resolves exactly once", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());

    await tester.enterText(_addressField, "@LinusTechTips");
    await tester.pumpAndSettle();

    // Fourteen characters entered one D-pad press at a time must not be fourteen
    // round trips through the platform channel.
    verifyNever(appsService.resolveContentShortcutTargets(any));

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(appsService.resolveContentShortcutTargets("https://www.youtube.com/@LinusTechTips")).called(1);
  });

  testWidgets("A channel id and a full address are both normalized before resolving", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());

    await _submitAddress(tester, "UCXuqSBlHAE6Xw-yeJA0Tunw");
    verify(appsService.resolveContentShortcutTargets("https://www.youtube.com/channel/UCXuqSBlHAE6Xw-yeJA0Tunw"))
        .called(1);

    // A full address is passed through untouched, whatever its host.
    await _submitAddress(tester, "https://example.org/live");
    verify(appsService.resolveContentShortcutTargets("https://example.org/live")).called(1);
  });

  testWidgets("Submitting a handle offers it as the shortcut's name", (tester) async {
    // Naming the shortcut is one more thing to type with a remote.
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "@LinusTechTips");

    expect(tester.widget<TextField>(_nameField).controller!.text, "LinusTechTips");
  });

  testWidgets("A name already typed is never overwritten by the suggestion", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await tester.enterText(_nameField, "Linus");
    await tester.pumpAndSettle();
    await _submitAddress(tester, "@LinusTechTips");

    expect(tester.widget<TextField>(_nameField).controller!.text, "Linus");
  });

  testWidgets("Input that is not a channel or an address says so, and resolves nothing", (tester) async {
    final appsService = _mkAppsService();

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "just some words");

    expect(find.text(_invalidAddressMessage), findsOneWidget);
    // The two failures are not the same thing and must never share a message.
    expect(find.text(_noTargetMessage), findsNothing);
    verifyNever(appsService.resolveContentShortcutTargets(any));
    expect(find.text("Save"), findsNothing);
  });

  testWidgets("An empty answer gets its own message, not 'your address is wrong'", (tester) async {
    // The highest-risk failure of the whole feature: on Android 11 and later a
    // missing package-visibility declaration comes back as an empty list, which
    // is indistinguishable from "no app is installed". Telling the user their
    // address is wrong would send them editing a perfectly good address forever.
    final appsService = _mkAppsService(targets: const []);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "@LinusTechTips");

    expect(find.text(_noTargetMessage), findsOneWidget);
    expect(find.text(_invalidAddressMessage), findsNothing);
    // Nothing was picked, so there is nothing to store.
    expect(find.text("Save"), findsNothing);
  });

  testWidgets("The applications the system reported are listed, and the first takes the focus", (tester) async {
    final appsService = _mkAppsService(targets: [
      _target(_smartTube, "SmartTube"),
      _target(_otherPlayer, "Example Player"),
    ]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "@LinusTechTips");

    expect(find.text("Choose the app that will open it:"), findsOneWidget);
    expect(find.text("SmartTube"), findsOneWidget);
    expect(find.text("Example Player"), findsOneWidget);

    // The list is a Column, not a lazy ListView, so every result really is in the
    // tree and the focus request can reach the first of them — which is what
    // makes the list usable with a remote at all.
    final firstTarget = tester.element(find.ancestor(
      of: find.text("SmartTube"),
      matching: find.byType(FocusableSettingsTile),
    ));
    expect(isFocused(firstTarget), isTrue);
  });

  testWidgets("An application with no readable name is listed under its package", (tester) async {
    final appsService = _mkAppsService(targets: [
      {"packageName": _smartTube},
    ]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "@LinusTechTips");

    expect(find.text(_smartTube), findsOneWidget);
  });

  testWidgets("Picking an application and saving creates the shortcut in its own new section", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await tester.enterText(_nameField, "Linus");
    await _submitAddress(tester, "@LinusTechTips");

    await tester.tap(find.text("SmartTube"));
    await tester.pumpAndSettle();

    expect(find.text("Opens in SmartTube"), findsOneWidget);

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.addContentShortcut(
      label: "Linus",
      uri: "https://www.youtube.com/@LinusTechTips",
      targetPackage: _smartTube,
      sectionId: null,
    )).called(1);
    // The page is done and gone.
    expect(find.byType(ContentShortcutPanelPage), findsNothing);
  });

  testWidgets("Saving with a section given adds the shortcut to that section", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments(sectionId: 7));
    await tester.enterText(_nameField, "Linus");
    await _submitAddress(tester, "@LinusTechTips");
    await tester.tap(find.text("SmartTube"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.addContentShortcut(
      label: "Linus",
      uri: "https://www.youtube.com/@LinusTechTips",
      targetPackage: _smartTube,
      sectionId: 7,
    )).called(1);
  });

  testWidgets("An existing shortcut opens pre-filled and saves as an edit", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_smartTube, "SmartTube")]);
    final shortcut = _mkShortcut();

    await _pumpPage(tester, appsService, ContentShortcutPanelPageArguments(shortcut: shortcut));

    expect(find.text("Modify shortcut"), findsOneWidget);
    expect(tester.widget<TextField>(_nameField).controller!.text, "Subscriptions");
    expect(
      tester.widget<TextField>(_addressField).controller!.text,
      "https://www.youtube.com/feed/subscriptions",
    );
    expect(find.text("Opens in $_smartTube"), findsOneWidget);

    await tester.enterText(_nameField, "My subscriptions");
    await tester.pumpAndSettle();
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateContentShortcut(
      shortcut,
      label: "My subscriptions",
      uri: "https://www.youtube.com/feed/subscriptions",
      targetPackage: _smartTube,
    )).called(1);
    verifyNever(appsService.addContentShortcut(
      label: anyNamed("label"),
      uri: anyNamed("uri"),
      targetPackage: anyNamed("targetPackage"),
      sectionId: anyNamed("sectionId"),
    ));
  });

  testWidgets("An existing shortcut can have its target changed", (tester) async {
    final appsService = _mkAppsService(targets: [_target(_otherPlayer, "Example Player")]);
    final shortcut = _mkShortcut();

    await _pumpPage(tester, appsService, ContentShortcutPanelPageArguments(shortcut: shortcut));
    await _submitAddress(tester, "https://www.youtube.com/feed/subscriptions");
    await tester.tap(find.text("Example Player"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(appsService.updateContentShortcut(
      shortcut,
      label: "Subscriptions",
      uri: "https://www.youtube.com/feed/subscriptions",
      targetPackage: _otherPlayer,
    )).called(1);
  });

  testWidgets("An existing shortcut can be deleted, and only an existing one", (tester) async {
    final appsService = _mkAppsService();
    final shortcut = _mkShortcut();

    await _pumpPage(tester, appsService, ContentShortcutPanelPageArguments(shortcut: shortcut));

    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();

    verify(appsService.deleteContentShortcut(shortcut)).called(1);
    expect(find.byType(ContentShortcutPanelPage), findsNothing);
  });

  testWidgets("There is nothing to delete while creating one", (tester) async {
    final appsService = _mkAppsService();

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());

    expect(find.text("Delete"), findsNothing);
  });

  testWidgets("A resolution that throws shows the empty answer instead of an error screen", (tester) async {
    // `resolveUriTargets` contracts to answer with an empty list rather than
    // throw; this is the backstop for the day something changes and it does.
    final appsService = MockAppsService();
    when(appsService.resolveContentShortcutTargets(any)).thenThrow(StateError("the channel went away"));

    await _pumpPage(tester, appsService, const ContentShortcutPanelPageArguments());
    await _submitAddress(tester, "@LinusTechTips");

    expect(find.text(_noTargetMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final Finder _nameField = find.byType(TextField).first;
final Finder _addressField = find.byType(TextField).last;

Future<void> _submitAddress(WidgetTester tester, String address) async {
  await tester.enterText(_addressField, address);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _target(String packageName, String name) => {
      "packageName": packageName,
      "name": name,
      "version": "1.0.0",
      "sideloaded": true,
    };

ContentShortcut _mkShortcut() => ContentShortcut(
      id: 3,
      sectionId: 7,
      order: 0,
      label: "Subscriptions",
      uri: "https://www.youtube.com/feed/subscriptions",
      targetPackage: _smartTube,
    );

MockAppsService _mkAppsService({List<Map<String, dynamic>> targets = const []}) {
  final appsService = MockAppsService();
  when(appsService.resolveContentShortcutTargets(any)).thenAnswer((_) async => targets);
  when(appsService.addContentShortcut(
    label: anyNamed("label"),
    uri: anyNamed("uri"),
    targetPackage: anyNamed("targetPackage"),
    sectionId: anyNamed("sectionId"),
  )).thenAnswer((_) async => 11);
  when(appsService.updateContentShortcut(
    any,
    label: anyNamed("label"),
    uri: anyNamed("uri"),
    targetPackage: anyNamed("targetPackage"),
  )).thenAnswer((_) async {});
  when(appsService.deleteContentShortcut(any)).thenAnswer((_) async {});
  return appsService;
}

/// Pushes the page onto a route of its own, so that saving and deleting can pop
/// it the way they do inside the settings panel.
Future<void> _pumpPage(
  WidgetTester tester,
  MockAppsService appsService,
  ContentShortcutPanelPageArguments arguments,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    ChangeNotifierProvider<AppsService>.value(
      value: appsService,
      builder: (_, __) => MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  // Deliberately not awaited: `push` completes when the route is *popped*.
  navigatorKey.currentState!.push(
    MaterialPageRoute(builder: (_) => Scaffold(body: ContentShortcutPanelPage(arguments: arguments))),
  );
  await tester.pumpAndSettle();
}
