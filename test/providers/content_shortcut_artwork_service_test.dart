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

// The og:image fetch, its storage, and — above all — every way it fails.
// Reading somebody else's markup is fragile by choice (see the class doc of
// ContentShortcutArtworkService), so half of this file is about failures ending
// with the card on its generic icon and nothing thrown.
//
// Nothing here touches the network: every request goes through an injected
// http.Client, exactly like WeatherService's tests.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flauncher/providers/content_shortcut_artwork_service.dart';
import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const String _channelUri = "https://www.youtube.com/@LinusTechTips";
const String _avatarUrl = "https://yt3.googleusercontent.com/ytc/avatar.jpg?s=900&c=k";

/// A JPEG, as far as anything that inspects the first bytes of a download is
/// concerned. The bytes after the magic number are the payload this launcher
/// stores verbatim, so a distinguishable tail is what lets a test tell one
/// avatar from another.
Uint8List _jpeg(int tail) => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, tail]);

/// The shape of a real YouTube channel page's head: the og:image is one meta
/// tag among many, the attributes are not in a helpful order, and the URL's
/// query string is HTML-escaped the way a browser receives it.
String _channelPage({String imageUrl = _avatarUrl}) => """
<!DOCTYPE html><html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Linus Tech Tips - YouTube</title>
<meta name="description" content="Tech can be complicated;">
<meta property="og:site_name" content="YouTube">
<meta property="og:url" content="$_channelUri">
<meta property="og:title" content="Linus Tech Tips">
<meta content="${imageUrl.replaceAll("&", "&amp;")}" property="og:image">
<meta property="og:image:width" content="900">
<meta property="og:type" content="profile">
</head><body><div id="content">nothing to see here</div></body></html>
""";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Its own scratch directory: test files run in parallel in the same process
  // and the artwork file names are derived from shortcut ids, so two files
  // sharing a documents directory would collide on `shortcut_banner_1`.
  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp("content_shortcut_artwork_service_test");
    final pathProvider = _MockPathProviderPlatform();
    when(pathProvider.getApplicationDocumentsPath()).thenAnswer((_) async => documentsDirectory.path);
    PathProviderPlatform.instance = pathProvider;
  });

  tearDown(() async {
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  File artworkFile(int shortcutId) => File("${documentsDirectory.path}/shortcut_banner_$shortcutId");

  File partialFile(int shortcutId) => File("${artworkFile(shortcutId).path}.part");

  /// The bytes the service is serving for [shortcutId], unwrapped from the
  /// provider it renders through, or null when it has no artwork for it.
  Uint8List? servedBytes(ContentShortcutArtworkService service, int shortcutId) {
    final provider = service.artworkFor(shortcutId);
    if (provider == null) {
      return null;
    }
    return ((provider as ResizeImage).imageProvider as MemoryImage).bytes;
  }

  /// A service whose page request is answered by [page] and whose image request
  /// is answered by [image].
  Future<ContentShortcutArtworkService> serviceWith({
    Future<http.Response> Function(http.Request request)? page,
    Future<http.Response> Function(http.Request request)? image,
    List<http.Request>? requests,
  }) async {
    final client = MockClient((request) async {
      requests?.add(request);
      if (request.url.host == "www.youtube.com") {
        return page?.call(request) ?? http.Response(_channelPage(), 200);
      }
      return image?.call(request) ?? http.Response.bytes(_jpeg(1), 200, headers: {"content-type": "image/jpeg"});
    });
    final service = ContentShortcutArtworkService(httpClient: client);
    addTearDown(service.dispose);
    await service.debugReady;
    return service;
  }

  group("fetching", () {
    test("stores the og:image of the page and serves it", () async {
      final requests = <http.Request>[];
      final service = await serviceWith(requests: requests);

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).readAsBytes(), _jpeg(1));
      expect(servedBytes(service, 1), _jpeg(1));
      // The escaped query string is un-escaped, or the avatar URL would be a
      // 404 with a literal "&amp;" between its parameters.
      expect(requests.last.url.toString(), _avatarUrl);
      expect(requests.length, 2, reason: "one request for the page, one for the image");
    });

    test("asks for the page as a browser would", () async {
      // Without a browser-like User-Agent, YouTube may answer with a consent
      // interstitial: a perfectly valid 200 carrying no og:image at all.
      final requests = <http.Request>[];
      final service = await serviceWith(requests: requests);

      await service.refreshArtwork(1, _channelUri);

      expect(requests.first.headers["User-Agent"], contains("Mozilla/5.0"));
      expect(requests.first.headers["User-Agent"], ContentShortcutArtworkService.userAgent);
    });

    test("bounds both requests with the timeout the launcher already uses", () async {
      expect(ContentShortcutArtworkService.requestTimeout, WeatherService.requestTimeout);
      expect(ContentShortcutArtworkService.requestTimeout, const Duration(seconds: 10));
    });

    test("resolves a protocol-relative og:image against the page", () async {
      final requests = <http.Request>[];
      final service = await serviceWith(
        page: (_) async => http.Response(_channelPage(imageUrl: "//yt3.googleusercontent.com/avatar.jpg"), 200),
        requests: requests,
      );

      await service.refreshArtwork(1, _channelUri);

      expect(requests.last.url.toString(), "https://yt3.googleusercontent.com/avatar.jpg");
      expect(servedBytes(service, 1), isNotNull);
    });

    test("notifies its listeners once the artwork is there", () async {
      final service = await serviceWith();
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.refreshArtwork(1, _channelUri);

      expect(notifications, 1);
    });
  });

  group("every failure leaves the card on its generic icon", () {
    test("a page with no og:image", () async {
      final service = await serviceWith(
        page: (_) async => http.Response("<html><head><title>Consent</title></head><body/></html>", 200),
      );

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });

    test("a non-200 page", () async {
      final service = await serviceWith(page: (_) async => http.Response("nope", 429));

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });

    test("a timeout", () async {
      // The real path is `.timeout(requestTimeout)`; raising the very error it
      // would raise keeps the suite from waiting ten real seconds for it.
      final service = await serviceWith(
        page: (_) => Future.error(TimeoutException("no response", ContentShortcutArtworkService.requestTimeout)),
      );

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });

    test("a socket-level failure", () async {
      final service = await serviceWith(page: (_) => Future.error(const SocketException("network is unreachable")));

      await service.refreshArtwork(1, _channelUri);

      expect(service.artworkFor(1), isNull);
    });

    test("a non-200 on the image itself", () async {
      final service = await serviceWith(image: (_) async => http.Response("gone", 404));

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });

    test("a download that dies midway", () async {
      final service = await serviceWith(image: (_) => Future.error(const SocketException("connection reset")));

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(await partialFile(1).exists(), isFalse, reason: "no half-written file is left behind");
      expect(service.artworkFor(1), isNull);
    });

    test("an og:image that is not an image at all", () async {
      final service = await serviceWith(
        image: (_) async => http.Response("<html>login required</html>", 200, headers: {"content-type": "text/html"}),
      );

      await service.refreshArtwork(1, _channelUri);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });

    test("an image larger than a link preview has any business being", () async {
      final oversized = Uint8List(ContentShortcutArtworkService.maxArtworkBytes + 1);
      oversized.setAll(0, const [0xFF, 0xD8, 0xFF]);
      final service = await serviceWith(
        image: (_) async => http.Response.bytes(oversized, 200, headers: {"content-type": "image/jpeg"}),
      );

      await service.refreshArtwork(1, _channelUri);

      expect(service.artworkFor(1), isNull);
    });

    test("an og:image pointing at a local file, which is never fetched", () async {
      final requests = <http.Request>[];
      final service = await serviceWith(
        page: (_) async => http.Response(_channelPage(imageUrl: "file:///etc/hosts"), 200),
        requests: requests,
      );

      await service.refreshArtwork(1, _channelUri);

      expect(requests.length, 1, reason: "only the page was ever asked for");
      expect(service.artworkFor(1), isNull);
    });

    test("a shortcut URI that is an app scheme rather than a page", () async {
      final requests = <http.Request>[];
      final service = await serviceWith(requests: requests);

      await service.refreshArtwork(1, "vnd.youtube://www.youtube.com/@LinusTechTips");

      expect(requests, isEmpty);
      expect(service.artworkFor(1), isNull);
    });

    test("a file that cannot be written", () async {
      // A directory sitting where the artwork file goes: the write fails the way
      // a full disk or a revoked permission would.
      await Directory(artworkFile(1).path).create();
      final service = await serviceWith();

      await service.refreshArtwork(1, _channelUri);

      expect(service.artworkFor(1), isNull);
      expect(await partialFile(1).exists(), isFalse);
      expect(await Directory(artworkFile(1).path).exists(), isTrue, reason: "nothing was destroyed either");
    });
  });

  group("editing a shortcut's address", () {
    test("replaces the artwork with the new destination's", () async {
      var tail = 1;
      final service = await serviceWith(
        image: (_) async => http.Response.bytes(_jpeg(tail), 200, headers: {"content-type": "image/jpeg"}),
      );
      await service.refreshArtwork(1, _channelUri);
      expect(servedBytes(service, 1), _jpeg(1));

      tail = 2;
      await service.refreshArtwork(1, "https://www.youtube.com/@Veritasium");

      expect(servedBytes(service, 1), _jpeg(2));
      expect(await artworkFile(1).readAsBytes(), _jpeg(2));
    });

    test("clears the previous artwork when the new fetch produces nothing", () async {
      // Better no image than the wrong channel's face.
      var pageAnswer = () async => http.Response(_channelPage(), 200);
      final service = await serviceWith(page: (_) => pageAnswer());
      await service.refreshArtwork(1, _channelUri);
      expect(await artworkFile(1).exists(), isTrue);

      pageAnswer = () async => http.Response("<html><head/></html>", 200);
      await service.refreshArtwork(1, "https://www.youtube.com/@Veritasium");

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
    });
  });

  group("requests that land after the user has moved on", () {
    /// A service whose page requests hang until they are released by URL, so a
    /// slow first edit can be made to answer after a fast second one.
    ({ContentShortcutArtworkService service, Map<String, Completer<http.Response>> pending}) heldService() {
      final pending = <String, Completer<http.Response>>{};
      final client = MockClient((request) {
        final String url = request.url.toString();
        if (request.url.host == "www.youtube.com") {
          return (pending[url] ??= Completer<http.Response>()).future;
        }
        return Future.value(
          http.Response.bytes(_jpeg(url.contains("second") ? 2 : 1), 200, headers: {"content-type": "image/jpeg"}),
        );
      });
      final service = ContentShortcutArtworkService(httpClient: client);
      addTearDown(service.dispose);
      return (service: service, pending: pending);
    }

    /// The pending request for [url], once the service has actually issued it.
    Future<Completer<http.Response>> issued(Map<String, Completer<http.Response>> pending, String url) async {
      for (int attempt = 0; attempt < 100 && !pending.containsKey(url); ++attempt) {
        await Future.delayed(Duration.zero);
      }
      return pending[url]!;
    }

    test("a slow edit that answers after a newer one does not overwrite it", () async {
      final held = heldService();
      await held.service.debugReady;
      const String second = "https://www.youtube.com/@Veritasium";

      final Future<void> slow = held.service.refreshArtwork(1, _channelUri);
      final Completer<http.Response> slowRequest = await issued(held.pending, _channelUri);
      // The second edit answers first, and its artwork is what the card shows.
      final Future<void> fast = held.service.refreshArtwork(1, second);
      (await issued(held.pending, second))
          .complete(http.Response(_channelPage(imageUrl: "https://images.test/second.png"), 200));
      await fast;
      expect(servedBytes(held.service, 1), _jpeg(2));

      slowRequest.complete(http.Response(_channelPage(imageUrl: "https://images.test/first.png"), 200));
      await slow;

      expect(servedBytes(held.service, 1), _jpeg(2), reason: "the answer to the replaced edit is dropped");
      expect(await artworkFile(1).readAsBytes(), _jpeg(2));
    });

    test("an answer for a shortcut that has been deleted leaves nothing behind", () async {
      final held = heldService();
      await held.service.debugReady;

      final Future<void> slow = held.service.refreshArtwork(1, _channelUri);
      final Completer<http.Response> slowRequest = await issued(held.pending, _channelUri);
      await held.service.deleteArtwork(1);
      slowRequest.complete(http.Response(_channelPage(imageUrl: "https://images.test/first.png"), 200));
      await slow;

      expect(await artworkFile(1).exists(), isFalse);
      expect(held.service.artworkFor(1), isNull);
    });
  });

  group("deleting", () {
    test("deletes the file of the shortcut that is gone", () async {
      final service = await serviceWith();
      await service.refreshArtwork(1, _channelUri);
      await service.refreshArtwork(2, _channelUri);

      await service.deleteArtwork(1);

      expect(await artworkFile(1).exists(), isFalse);
      expect(service.artworkFor(1), isNull);
      expect(await artworkFile(2).exists(), isTrue, reason: "no other shortcut's artwork was touched");
    });

    test("says nothing and throws nothing for a shortcut that never had artwork", () async {
      final service = await serviceWith();
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.deleteArtwork(404);

      expect(notifications, 0);
    });
  });

  group("starting up", () {
    test("serves the artwork already on disk", () async {
      await artworkFile(9).writeAsBytes(_jpeg(9));

      final service = await serviceWith();

      expect(servedBytes(service, 9), _jpeg(9));
    });

    test("sweeps away the leftovers of a download that never finished", () async {
      await partialFile(9).writeAsBytes(_jpeg(9));

      final service = await serviceWith();

      expect(await partialFile(9).exists(), isFalse);
      expect(service.artworkFor(9), isNull);
    });
  });
}

class _MockPathProviderPlatform extends Mock with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() =>
      super.noSuchMethod(Invocation.method(#getApplicationDocumentsPath, []), returnValue: Future<String?>.value());
}
