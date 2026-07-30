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

// Regression test for the trap this feature is built around.
//
// Flutter's ImageCache keys a FileImage on *path plus scale*, never on
// contents, and an artwork file is named after the shortcut's id — which does
// not change when the user re-points that shortcut at another channel. So the
// new avatar is written to the same path the old one occupied, and a
// path-keyed cache would happily go on painting the previous channel's face
// until the process restarted. This launcher has been burned by exactly this
// with the fixed wallpaper file names, which is why their save paths force a
// refresh.
//
// The whole path is exercised for real here — a real ContentShortcutArtworkService,
// a real file rewritten in place — with two seams keeping it out of the
// fake-async zone `testWidgets` runs in: the http.Client is injected, and every
// file operation happens inside `tester.runAsync`, because `dart:io` futures
// never complete inside that zone.

import 'dart:io';
import 'dart:typed_data';

import 'package:flauncher/actions.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/content_shortcut_artwork_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/content_shortcut_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

const String _smartTube = "com.teamsmart.videomanager.tv";
const String _firstChannel = "https://www.youtube.com/@LinusTechTips";
const String _secondChannel = "https://www.youtube.com/@Veritasium";

/// Two real, decodable 1×1 PNGs: a red one and a blue one. Decodable matters —
/// the card hands them to the painting pipeline, and the point of the test is
/// that the pipeline is given the second one.
final Uint8List _redPng = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83,
  222, 0, 0, 0, 12, 73, 68, 65, 84, 120, 218, 99, 248, 207, 192, 0, 0, 3, 1, 1, 0, 247, 3, 65, 67, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
]);
final Uint8List _bluePng = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83,
  222, 0, 0, 0, 12, 73, 68, 65, 84, 120, 218, 99, 96, 96, 248, 15, 0, 1, 3, 1, 0, 54, 116, 17, 64, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
]);

String _pageWithImage(String imageUrl) =>
    '<html><head><meta property="og:image" content="$imageUrl"></head><body/></html>';

void main() {
  // Its own scratch directory: test files run in parallel in the same process,
  // and artwork file names are derived from shortcut ids, so a shared documents
  // directory would collide on `shortcut_banner_1`.
  late Directory documentsDirectory;

  setUpAll(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1280, 720);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    final pathProvider = _MockPathProviderPlatform();
    when(pathProvider.getApplicationDocumentsPath()).thenAnswer((_) async => documentsDirectory.path);
    PathProviderPlatform.instance = pathProvider;
  });

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp("content_shortcut_artwork_cache_test");
  });

  tearDown(() async {
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  testWidgets("Re-pointing a shortcut at another channel shows the new avatar, not the cached one", (tester) async {
    final File artworkFile = File("${documentsDirectory.path}/shortcut_banner_1");
    // One image per channel, both advertised by the same page shape.
    final client = MockClient((request) async {
      switch (request.url.toString()) {
        case _firstChannel:
          return http.Response(_pageWithImage("https://images.test/first.png"), 200);
        case _secondChannel:
          return http.Response(_pageWithImage("https://images.test/second.png"), 200);
        case "https://images.test/first.png":
          return http.Response.bytes(_redPng, 200, headers: {"content-type": "image/png"});
        case "https://images.test/second.png":
          return http.Response.bytes(_bluePng, 200, headers: {"content-type": "image/png"});
      }
      return http.Response("not found", 404);
    });
    // Built inside `runAsync` as well: the service reads the documents
    // directory as soon as it exists, and a `dart:io` future created inside the
    // fake-async zone would never complete — not even later, from inside
    // `runAsync`.
    late final ContentShortcutArtworkService artworkService;
    await tester.runAsync(() async {
      artworkService = ContentShortcutArtworkService(httpClient: client);
      await artworkService.debugReady;
      await artworkService.refreshArtwork(1, _firstChannel);
    });
    addTearDown(artworkService.dispose);
    expect(await _fileBytes(tester, artworkFile), _redPng);

    await _pumpRow(tester, artworkService);

    final ImageProvider firstProvider = _paintedArtwork(tester);
    expect(_bytesOf(firstProvider), _redPng);
    final Object firstKey = await tester.runAsync(() => firstProvider.obtainKey(ImageConfiguration.empty)) as Object;
    expect(
      PaintingBinding.instance.imageCache.statusForKey(firstKey).untracked,
      isFalse,
      reason: "the first avatar really is in the image cache, so the test is not vacuous",
    );

    // The user edits the shortcut's address. Same shortcut, same id, therefore
    // the very same file path — with different contents.
    await tester.runAsync(() => artworkService.refreshArtwork(1, _secondChannel));
    await tester.pump();

    expect(await _fileBytes(tester, artworkFile), _bluePng, reason: "the same path now holds the new avatar");
    final ImageProvider secondProvider = _paintedArtwork(tester);
    expect(_bytesOf(secondProvider), _bluePng, reason: "the card paints the new avatar, not the cached one");
    expect(secondProvider, isNot(equals(firstProvider)), reason: "a new picture is a new cache key");
    expect(
      PaintingBinding.instance.imageCache.statusForKey(firstKey).untracked,
      isTrue,
      reason: "the previous avatar was evicted instead of being left in the cache",
    );
  });
}

/// The provider the card is painting its artwork with.
ImageProvider _paintedArtwork(WidgetTester tester) {
  final Ink ink = tester.widget<Ink>(find.descendant(of: find.byType(ContentShortcutCard), matching: find.byType(Ink)));
  return (ink.decoration! as BoxDecoration).image!.image;
}

/// The bytes behind [provider], unwrapped from the resize wrapper the artwork
/// service renders through.
Uint8List _bytesOf(ImageProvider provider) => ((provider as ResizeImage).imageProvider as MemoryImage).bytes;

/// Reads [file] outside the fake-async zone: `dart:io` futures never complete
/// inside it, so an `await` on one from the test body would simply hang.
Future<Uint8List?> _fileBytes(WidgetTester tester, File file) => tester.runAsync(() => file.readAsBytes());

Future<void> _pumpRow(WidgetTester tester, ContentShortcutArtworkService artworkService) async {
  final appsService = MockAppsService();
  when(appsService.launchContentShortcut(any)).thenAnswer((_) async => true);
  final settingsService = MockSettingsService();
  when(settingsService.showAppNamesBelowIcons).thenReturn(false);
  when(settingsService.accentColorHex).thenReturn("FFFFFF");
  when(settingsService.showFocusBorders).thenReturn(true);
  when(settingsService.showContentShortcutHandle).thenReturn(true);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppsService>.value(value: appsService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<ContentShortcutArtworkService>.value(value: artworkService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Actions(
          actions: <Type, Action<Intent>>{
            MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(onInvoke: (_) => null),
          },
          child: Scaffold(
            body: ContentShortcutRow(
              section: ContentShortcutSection(id: 7, order: 0, shortcuts: [
                ContentShortcut(
                  id: 1,
                  sectionId: 7,
                  label: "Linus Tech Tips",
                  uri: _firstChannel,
                  targetPackage: _smartTube,
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
