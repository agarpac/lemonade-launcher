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

// How AppsService hands its content shortcuts to the artwork service: after the
// insert (the id it names the file after does not exist before it), without
// waiting for the network, and for every shortcut that stops existing.
//
// The artwork service itself is mocked here; what it does with a URI is
// content_shortcut_artwork_service_test.dart's job.

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mocks.mocks.dart';

const String _smartTube = "com.teamsmart.videomanager.tv";
const String _channelUri = "https://www.youtube.com/@LinusTechTips";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();

  late Directory temporaryDirectory;
  late FLauncherDatabase database;
  late MockFLauncherChannel channel;
  late MockContentShortcutArtworkService artworkService;

  setUp(() async {
    // Its own directory: test files run in parallel.
    temporaryDirectory = await Directory.systemTemp.createTemp("apps_service_content_shortcut_artwork_test");
    final databaseFile = File("${temporaryDirectory.path}/db.sqlite");

    // Opened once and closed, so the second open reports `wasCreated == false`
    // and no default categories are injected.
    final creator = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));
    await creator.getContentShortcuts();
    await creator.close();
    database = FLauncherDatabase(DatabaseConnection(NativeDatabase(databaseFile)));

    channel = MockFLauncherChannel();
    when(channel.getApplications()).thenAnswer((_) => Future.value([
          {"packageName": _smartTube, "name": "SmartTube", "version": "1.0.0", "sideloaded": true},
        ]));
    when(channel.applicationExists(any)).thenAnswer((_) => Future.value(true));
    when(channel.getApplicationIcon(any)).thenAnswer((_) => Future.value(Uint8List(0)));
    when(channel.getApplicationBanner(any)).thenAnswer((_) => Future.value(Uint8List(0)));

    artworkService = MockContentShortcutArtworkService();
  });

  tearDown(() async {
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<AppsService> buildAppsService() async {
    final appsService = AppsService(channel, database, contentShortcutArtworkService: artworkService);
    await untilCalled(channel.addAppsChangedListener(any));
    return appsService;
  }

  ContentShortcut onlyShortcut(AppsService appsService) =>
      appsService.contentShortcutSections.single.shortcuts.single;

  test("the artwork is fetched for the id the inserted row was given", () async {
    final appsService = await buildAppsService();

    final int shortcutId = await appsService.addContentShortcut(
      label: "Linus Tech Tips",
      uri: _channelUri,
      targetPackage: _smartTube,
    );

    verify(artworkService.refreshArtwork(shortcutId, _channelUri)).called(1);
    expect(shortcutId, greaterThan(0), reason: "the id only exists once the row is written");
  });

  test("saving does not wait for the fetch", () async {
    // The fetch reaches out to somebody else's web server; the user pressed
    // Save. A fetch that never answers must not keep the shortcut from being
    // written, nor the settings page from closing.
    final never = Completer<void>();
    when(artworkService.refreshArtwork(any, any)).thenAnswer((_) => never.future);
    final appsService = await buildAppsService();

    await appsService
        .addContentShortcut(label: "Linus Tech Tips", uri: _channelUri, targetPackage: _smartTube)
        .timeout(const Duration(seconds: 5));

    expect(never.isCompleted, isFalse, reason: "the fetch is still in flight");
    expect(appsService.contentShortcutSections.single.shortcuts.single.label, "Linus Tech Tips");
    expect((await database.getContentShortcuts()).single.uri, _channelUri);
  });

  test("editing the address refetches the artwork", () async {
    final appsService = await buildAppsService();
    await appsService.addContentShortcut(label: "Linus Tech Tips", uri: _channelUri, targetPackage: _smartTube);
    final ContentShortcut shortcut = onlyShortcut(appsService);
    clearInteractions(artworkService);

    await appsService.updateContentShortcut(shortcut, uri: "https://www.youtube.com/@Veritasium");

    verify(artworkService.refreshArtwork(shortcut.id, "https://www.youtube.com/@Veritasium")).called(1);
  });

  test("editing only the name leaves the artwork alone", () async {
    // Re-fetching here would mean a card that loses its picture, for a few
    // seconds or for good, because its name was corrected.
    final appsService = await buildAppsService();
    await appsService.addContentShortcut(label: "Linus", uri: _channelUri, targetPackage: _smartTube);
    final ContentShortcut shortcut = onlyShortcut(appsService);
    clearInteractions(artworkService);

    await appsService.updateContentShortcut(shortcut, label: "Linus Tech Tips");

    verifyNever(artworkService.refreshArtwork(any, any));
    verifyNever(artworkService.deleteArtwork(any));
  });

  test("deleting a shortcut deletes its artwork", () async {
    final appsService = await buildAppsService();
    await appsService.addContentShortcut(label: "Linus Tech Tips", uri: _channelUri, targetPackage: _smartTube);
    final ContentShortcut shortcut = onlyShortcut(appsService);

    await appsService.deleteContentShortcut(shortcut);

    verify(artworkService.deleteArtwork(shortcut.id)).called(1);
    // The section went with the last shortcut of it, which is exactly why the
    // file has to be deleted here: nothing renders it any more.
    expect(appsService.contentShortcutSections, isEmpty);
  });

  test("deleting a whole shortcut section deletes the artwork of every shortcut in it", () async {
    final appsService = await buildAppsService();
    final int first = await appsService.addContentShortcut(label: "One", uri: _channelUri, targetPackage: _smartTube);
    final int sectionId = appsService.contentShortcutSections.single.id;
    final int second = await appsService.addContentShortcut(
      label: "Two",
      uri: "https://www.youtube.com/@Veritasium",
      targetPackage: _smartTube,
      sectionId: sectionId,
    );
    final int sectionIndex =
        appsService.launcherSections.indexWhere((section) => section is ContentShortcutSection);

    await appsService.deleteSection(sectionIndex);

    verify(artworkService.deleteArtwork(first)).called(1);
    verify(artworkService.deleteArtwork(second)).called(1);
    expect(await database.getContentShortcuts(), isEmpty);
  });
}
