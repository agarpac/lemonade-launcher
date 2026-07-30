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

import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/content_shortcut_artwork_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/content_shortcut_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

import '../mocks.mocks.dart';

const _smartTube = "com.teamsmart.videomanager.tv";

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Every shortcut of the section is rendered, in order", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([
      _mkShortcut(id: 1, label: "Subscriptions"),
      _mkShortcut(id: 2, label: "Lo-fi radio", uri: "https://www.youtube.com/playlist?list=PL1"),
    ]);

    await _pumpRow(tester, appsService, section);

    expect(find.text("Subscriptions"), findsOneWidget);
    expect(find.text("Lo-fi radio"), findsOneWidget);
    expect(find.byType(ContentShortcutCard), findsNWidgets(2));
    expect(
      tester.widgetList<ContentShortcutCard>(find.byType(ContentShortcutCard)).map((card) => card.shortcut.label),
      ["Subscriptions", "Lo-fi radio"],
    );
  });

  testWidgets("The card shows the destination's handle instead of the name that was typed", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([
      _mkShortcut(id: 1, label: "test", uri: "https://www.youtube.com/@LinusTechTips"),
    ]);

    await _pumpRow(tester, appsService, section);

    // "@LinusTechTips" says what this opens; "test" says nothing.
    expect(find.text("@LinusTechTips"), findsOneWidget);
    expect(find.text("test"), findsNothing);
  });

  testWidgets("The card keeps the typed name when the address names no handle", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([
      _mkShortcut(id: 1, label: "Subscriptions", uri: "https://www.youtube.com/feed/subscriptions"),
    ]);

    await _pumpRow(tester, appsService, section);

    expect(find.text("Subscriptions"), findsOneWidget);
  });

  testWidgets("The first shortcut takes the focus, and pressing it launches it", (tester) async {
    final appsService = _mkAppsService();
    final shortcut = _mkShortcut(id: 1, label: "Subscriptions");
    final section = _mkSection([shortcut, _mkShortcut(id: 2, label: "Lo-fi radio")]);

    await _pumpRow(tester, appsService, section);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    // Like an app card, the press is held for 150ms of visual feedback and reset
    // 500ms later; advance past both so no timer is left pending.
    await tester.pump(const Duration(milliseconds: 200));

    final launched = verify(appsService.launchContentShortcut(captureAny)).captured;
    expect(launched.length, 1);
    expect((launched.single as ContentShortcut).id, shortcut.id);

    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("Right then select launches the second shortcut, not the first", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([
      _mkShortcut(id: 1, label: "Subscriptions"),
      _mkShortcut(id: 2, label: "Lo-fi radio"),
    ]);

    await _pumpRow(tester, appsService, section);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 200));

    final launched = verify(appsService.launchContentShortcut(captureAny)).captured;
    expect((launched.single as ContentShortcut).id, 2);

    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("An unavailable shortcut says so and is not launched when pressed", (tester) async {
    // The target application is not installed. It must look different from a
    // working shortcut *and* refuse to act like one: playing the press animation
    // and asking the channel to open a package that is not there is exactly the
    // silent nothing this has to avoid.
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions", available: false)]);

    await _pumpRow(tester, appsService, section);

    expect(find.text("Subscriptions"), findsOneWidget);
    expect(find.text("Unavailable"), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(appsService.launchContentShortcut(any));
  });

  testWidgets("A shortcut whose stored target package is empty counts as unavailable", (tester) async {
    // Reachable from a hand-edited backup file: nothing can be pinned, so there
    // is nothing to launch.
    final appsService = _mkAppsService();
    final section = _mkSection([
      ContentShortcut(id: 1, sectionId: 7, label: "Broken", uri: "https://youtu.be/a", targetPackage: ""),
    ]);

    await _pumpRow(tester, appsService, section);

    expect(find.text("Unavailable"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(appsService.launchContentShortcut(any));
  });

  testWidgets("Arrow up from the top row asks for the top bar, instead of relying on geometry", (tester) async {
    // The top bar is not reachable by directional traversal. A row that forgot
    // this would leave the user on the home screen with no way into Settings, on
    // the device's only home screen.
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]);
    int settingsRequests = 0;

    await _pumpRow(tester, appsService, section, isFirstSection: true, onSettings: () => settingsRequests++);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(settingsRequests, 1);
  });

  testWidgets("Arrow up from a row that is not the top one asks for nothing", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]);
    int settingsRequests = 0;

    await _pumpRow(tester, appsService, section, isFirstSection: false, onSettings: () => settingsRequests++);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(settingsRequests, 0);
  });

  testWidgets("The label is repeated below the card when app names are switched on", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]);

    await _pumpRow(tester, appsService, section, showAppNames: true);

    // Once inside the card and once under it, exactly like an application whose
    // name is shown below its banner.
    expect(find.text("Subscriptions"), findsNWidgets(2));
  });

  testWidgets("A content shortcut card is clipped with the same squircle shape as an AppCard", (tester) async {
    // Built to look like an app card on purpose (see the class doc comment in
    // content_shortcut_row.dart): the squircle shape has to follow, at the same
    // radius, or the row would visibly stand out from the rest of the launcher.
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]);

    await _pumpRow(tester, appsService, section);

    final Material material = tester.widget<Material>(
      find.descendant(of: find.byType(ContentShortcutCard), matching: find.byType(Material)).first,
    );

    expect(material.shape, isA<RoundedSuperellipseBorder>());
    expect(
      (material.shape! as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(kAppCardCornerRadius),
    );
    expect(material.borderRadius, isNull);
  });

  testWidgets("A shortcut with artwork shows it edge to edge instead of the generic icon", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]);
    final artwork = _fakeArtwork();

    await _pumpRow(tester, appsService, section, artworkByShortcutId: {1: artwork});

    final Ink ink = tester.widget<Ink>(find.descendant(of: find.byType(ContentShortcutCard), matching: find.byType(Ink)));
    final DecorationImage? image = (ink.decoration as BoxDecoration).image;
    expect(image?.image, same(artwork), reason: "the card paints the provider the artwork service handed it");
    // Filled the way an application's banner is, so a channel avatar is not
    // letterboxed inside a 16/9 card.
    expect(image?.fit, BoxFit.cover);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets("A shortcut with no artwork keeps its generic icon, next to one that has artwork", (tester) async {
    // The fallback is the normal state of any shortcut whose page carried no
    // og:image, so both must be able to sit in the same row.
    final appsService = _mkAppsService();
    final section = _mkSection([
      _mkShortcut(id: 1, label: "Subscriptions"),
      _mkShortcut(id: 2, label: "Lo-fi radio"),
    ]);

    await _pumpRow(tester, appsService, section, artworkByShortcutId: {1: _fakeArtwork()});

    expect(find.byType(Ink), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.text("Lo-fi radio"), findsOneWidget);
  });

  testWidgets("Artwork does not change the card's size, shape or focus animation", (tester) async {
    // The row is built to read as one more row of the launcher; a card that grew
    // or lost its squircle the moment a picture arrived would break that.
    final appsService = _mkAppsService();
    final artwork = _fakeArtwork();

    await _pumpRow(tester, appsService, _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]));
    final Size withoutArtwork = tester.getSize(find.byType(ContentShortcutCard));

    await _pumpRow(
      tester,
      _mkAppsService(),
      _mkSection([_mkShortcut(id: 1, label: "Subscriptions")]),
      artworkByShortcutId: {1: artwork},
    );

    expect(tester.getSize(find.byType(ContentShortcutCard)), withoutArtwork);
    final Material material = tester.widget<Material>(
      find.descendant(of: find.byType(ContentShortcutCard), matching: find.byType(Material)).first,
    );
    expect(
      (material.shape! as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(kAppCardCornerRadius),
    );
    final AnimatedScale scale = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).last;
    expect(scale.curve, Curves.easeOutCubic);
    expect(scale.duration, const Duration(milliseconds: 180));
  });

  testWidgets("An unavailable shortcut with artwork is still dimmed and still says so", (tester) async {
    final appsService = _mkAppsService();
    final section = _mkSection([_mkShortcut(id: 1, label: "Subscriptions", available: false)]);

    await _pumpRow(tester, appsService, section, artworkByShortcutId: {1: _fakeArtwork()});

    expect(find.text("Unavailable"), findsOneWidget);
    final Opacity opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(ContentShortcutCard), matching: find.byType(Opacity)).last,
    );
    expect(opacity.opacity, 0.5);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(appsService.launchContentShortcut(any));
  });

  testWidgets("A section left with no shortcuts renders nothing at all", (tester) async {
    // A section *is* the shortcuts that share its id, so an empty one is a
    // section that stopped existing; it must not leave an empty band behind.
    final appsService = _mkAppsService();

    await _pumpRow(tester, appsService, _mkSection([]));

    expect(find.byType(ContentShortcutCard), findsNothing);
    expect(tester.getSize(find.byType(ContentShortcutRow)), Size.zero);
  });
}

/// A real, decodable image provider: a 1×1 transparent GIF. Real bytes rather
/// than a mock provider, because the card hands whatever it gets straight to the
/// painting pipeline.
ImageProvider _fakeArtwork() => MemoryImage(Uint8List.fromList(kTransparentImage));

ContentShortcut _mkShortcut({
  required int id,
  required String label,
  String uri = "https://www.youtube.com/feed/subscriptions",
  String targetPackage = _smartTube,
  bool available = true,
}) =>
    ContentShortcut(
      id: id,
      sectionId: 7,
      order: id,
      label: label,
      uri: uri,
      targetPackage: targetPackage,
      available: available,
    );

ContentShortcutSection _mkSection(List<ContentShortcut> shortcuts) =>
    ContentShortcutSection(id: 7, order: 0, shortcuts: shortcuts);

MockAppsService _mkAppsService() {
  final appsService = MockAppsService();
  when(appsService.launchContentShortcut(any)).thenAnswer((_) async => true);
  return appsService;
}

/// An artwork service that knows about the artwork of [artworkByShortcutId] and
/// about no other shortcut. Nothing here touches the network or the file system:
/// the real service is the only thing that does, and it is not in this file.
MockContentShortcutArtworkService _mkArtworkService([Map<int, ImageProvider> artworkByShortcutId = const {}]) {
  final artworkService = MockContentShortcutArtworkService();
  when(artworkService.artworkFor(any)).thenAnswer((invocation) => artworkByShortcutId[invocation.positionalArguments[0]]);
  return artworkService;
}

MockSettingsService _mkSettingsService({bool showAppNames = false}) {
  final settingsService = MockSettingsService();
  when(settingsService.showAppNamesBelowIcons).thenReturn(showAppNames);
  when(settingsService.accentColorHex).thenReturn("FFFFFF");
  when(settingsService.showFocusBorders).thenReturn(true);
  return settingsService;
}

Future<void> _pumpRow(
  WidgetTester tester,
  MockAppsService appsService,
  ContentShortcutSection section, {
  bool isFirstSection = false,
  bool showAppNames = false,
  VoidCallback? onSettings,
  Map<int, ImageProvider> artworkByShortcutId = const {},
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: _mkSettingsService(showAppNames: showAppNames)),
        ChangeNotifierProvider<ContentShortcutArtworkService>.value(value: _mkArtworkService(artworkByShortcutId)),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Actions(
          actions: <Type, Action<Intent>>{
            MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
              onInvoke: (_) {
                onSettings?.call();
                return null;
              },
            ),
          },
          child: FocusTraversalGroup(
            policy: RowByRowTraversalPolicy(),
            child: Scaffold(
              body: ContentShortcutRow(section: section, isFirstSection: isFirstSection),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
