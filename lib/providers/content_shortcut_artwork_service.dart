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

import 'dart:async';
import 'dart:io';

import 'package:flauncher/providers/weather_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Prefix of the per-shortcut artwork files, `shortcut_banner_<shortcutId>` in
/// the application documents directory.
///
/// Public because `BackupService` has to recognise these files by name (see
/// [ContentShortcutArtworkService] for why a restore drops them), and a second
/// copy of the literal over there would be free to drift away from this one.
const String contentShortcutArtworkFileNamePrefix = "shortcut_banner_";

/// Suffix of the file a download is written to before it is renamed onto its
/// final name. A crash, a full disk or a dead socket halfway through must never
/// leave a truncated image sitting under the name the card renders.
const String _partialFileNameSuffix = ".part";

/// Every `<meta …>` tag of a document, attributes included.
final RegExp _metaTagPattern = RegExp(r"<meta\b[^>]*>", caseSensitive: false);

/// One `name="value"` attribute, quoted with `"`, with `'`, or not at all.
final RegExp _attributePattern = RegExp(
  "([A-Za-z_:][A-Za-z0-9_:.-]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))",
);

/// The five entities that actually turn up inside an `og:image` URL. `&amp;` is
/// the one that matters — a query string in an HTML attribute is escaped, and a
/// URL still carrying `&amp;` between its parameters is a 404 waiting to happen.
const Map<String, String> _htmlEntities = {
  "&amp;": "&",
  "&quot;": "\"",
  "&apos;": "'",
  "&#39;": "'",
  "&#38;": "&",
};

/// The artwork of the launcher's content shortcuts: the destination's own
/// picture — a YouTube channel's avatar — read from the page's `og:image` link
/// preview metadata.
///
/// `og:image` is public metadata that every link preview in every chat
/// application already reads, so it needs no API key and no registration, which
/// is the same reason the weather block uses Open-Meteo (PRD section 6).
///
/// It is also **fragile, by choice**: YouTube can change its markup, answer a
/// request that does not look like a browser with a consent interstitial that
/// carries no `og:image` at all, or simply refuse. So the fallback is half the
/// feature: every failure — no network, a timeout, a non-200, no `og:image`, a
/// URL that is not an image, a download that dies midway, a write that fails —
/// is silent and total. Nothing throws, nothing blocks the save, and the card
/// keeps the generic icon it has always had. There is no error to show, because
/// there is nothing the user could do about it.
///
/// ## Where the artwork lives
///
/// One file per shortcut, `shortcut_banner_<shortcutId>` in the documents
/// directory, so **the file's existence is the "has artwork" flag**. Nothing is
/// written to `shared_preferences` and no column is added:
///
///  * stored preference values are untrusted input here (`BackupService`
///    imports a user-supplied JSON straight into the store, and `getString` is
///    a hard cast that throws on a wrong type);
///  * `BackupService` deliberately refuses to export `custom_banner_`
///    preferences precisely because they hold absolute paths to files that are
///    not in the backup and would point at nothing on another device. A stored
///    path for a shortcut would have exactly that problem, and deriving the
///    name from the id avoids it — the same reasoning as
///    `WallpaperService.importSceneWallpaper`.
///
/// A restore is the one case the id cannot survive: the ids in a backup file
/// were minted by whichever device wrote it, so a `shortcut_banner_3` left over
/// from the local shortcut 3 would put one channel's face on another channel's
/// card. `BackupService` deletes these files on a successful import rather than
/// risk that; the artwork comes back the next time the shortcut is saved.
///
/// ## Why the bytes are kept in memory
///
/// Rendering goes through [artworkFor], never through a `FileImage`, and this
/// is deliberate. Flutter's [ImageCache] keys a `FileImage` on **path plus
/// scale**, not on contents, and these paths are derived from the shortcut id —
/// which does not change when the user re-points a shortcut at another channel.
/// A `FileImage` would therefore keep painting the previous channel's avatar
/// from the cache until the process restarted (the same class of bug the
/// `force: true` wallpaper save paths exist for). A [MemoryImage] is keyed on
/// the byte buffer itself, so freshly read bytes are a new cache key by
/// construction and stale bytes cannot be served at all. On top of that,
/// [_publish] evicts the previous provider so the old decoded image does not
/// linger in the cache — [_providerFor] builds the identity used for both
/// rendering and eviction, so the two can never drift apart.
class ContentShortcutArtworkService extends ChangeNotifier {
  /// A launcher must never hang on a dead network: every request is bounded,
  /// with the timeout `WeatherService` already established for this app.
  static const Duration requestTimeout = WeatherService.requestTimeout;

  /// Ceiling on a downloaded image. An `og:image` is a link preview — a few
  /// hundred kilobytes — and this launcher runs on a TV box that holds the
  /// bytes in memory to render them.
  static const int maxArtworkBytes = 4 * 1024 * 1024;

  /// Width the artwork is decoded at, matching the app banners in
  /// `AppCard._loadAppImage`: a channel avatar is often 900×900, and a card is
  /// a fraction of that.
  static const int artworkCacheWidth = 480;

  /// Sent on both requests. Without a browser-like `User-Agent` YouTube may
  /// answer with a consent interstitial, which is a perfectly valid 200 that
  /// carries no `og:image` at all.
  static const String userAgent =
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

  final http.Client _httpClient;

  /// Whether [_httpClient] is ours to close, exactly as in `WeatherService`: a
  /// client handed in by a caller (a test) outlives this service.
  final bool _ownsHttpClient;

  /// Bytes of the artwork of every shortcut that has one, by shortcut id.
  final Map<int, Uint8List> _artworkByShortcutId = {};

  /// Which request for a given shortcut is the current one, so that an answer
  /// the user has already replaced cannot land on top of a newer one — the same
  /// discriminator `ContentShortcutPanelPage` uses for its target lookups.
  ///
  /// Two edits in a row, or a delete while a download is in flight, are both
  /// plausible with a remote in hand, and both would otherwise end with the
  /// wrong picture on the card or a file belonging to a shortcut that no longer
  /// exists.
  final Map<int, int> _operationByShortcutId = {};

  /// Documents directory, or null while it has not been resolved yet or could
  /// not be resolved at all. Null makes every path below a silent no-op.
  String? _documentsPath;

  late final Future<void> _initialization;

  bool _disposed = false;

  ContentShortcutArtworkService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    _initialization = _init();
  }

  /// Completes once the artwork already on disk has been read.
  ///
  /// Test-only: production code never has to wait for this, because a shortcut
  /// with no artwork loaded yet simply renders its icon until [notifyListeners]
  /// says otherwise.
  @visibleForTesting
  Future<void> get debugReady => _initialization;

  /// The artwork of the shortcut [shortcutId], or null when it has none.
  ///
  /// Synchronous on purpose: it is read from `build`, and a widget that had to
  /// await the file system would both flicker and — inside the fake-async zone
  /// `testWidgets` runs in, where `dart:io` futures never complete — hang every
  /// `pumpAndSettle` that rendered it.
  ImageProvider? artworkFor(int shortcutId) {
    final Uint8List? bytes = _artworkByShortcutId[shortcutId];
    return bytes == null ? null : _providerFor(bytes);
  }

  /// Makes the artwork of the shortcut [shortcutId] be whatever [uri] gives
  /// right now: the fetched image, or **nothing at all**.
  ///
  /// Never throws, and never leaves the previous image behind on failure: after
  /// an edit that re-points a shortcut at another channel, no picture is the
  /// only honest answer — the old one would be the wrong channel's face.
  Future<void> refreshArtwork(int shortcutId, String uri) async {
    final int operation = _beginOperation(shortcutId);
    await _initialization;
    Uint8List? bytes;
    try {
      bytes = await _fetchArtwork(uri);
    } catch (e) {
      // A timeout, a dead socket, a body that is not text, a URL that does not
      // parse: all the same thing here — this shortcut has no artwork.
      debugPrint("ContentShortcutArtworkService: could not fetch the artwork of $uri ($e)");
      bytes = null;
    }
    if (_operationByShortcutId[shortcutId] != operation) {
      // The user edited this shortcut again, or deleted it, while the request
      // was in flight. Whatever came back describes somewhere else now.
      return;
    }
    if (bytes == null) {
      await deleteArtwork(shortcutId);
      return;
    }
    await _store(shortcutId, bytes);
  }

  /// Removes the artwork of the shortcut [shortcutId], file included.
  ///
  /// Called for every shortcut that stops existing, so that deleting the last
  /// shortcut of a section — which deletes the section with it — leaves no
  /// orphaned file behind. Never throws.
  Future<void> deleteArtwork(int shortcutId) async {
    _beginOperation(shortcutId);
    await _initialization;
    final Uint8List? previous = _artworkByShortcutId.remove(shortcutId);
    if (previous != null) {
      await _providerFor(previous).evict();
    }
    final String? documentsPath = _documentsPath;
    if (documentsPath != null) {
      final File target = _artworkFile(documentsPath, shortcutId);
      await _deleteFile(target);
      await _deleteFile(File("${target.path}$_partialFileNameSuffix"));
    }
    if (previous != null) {
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }

  /// Reads the artwork already on disk, and sweeps away the leftovers of a
  /// download that never finished.
  ///
  /// Deliberately does *not* delete files whose shortcut no longer exists: this
  /// service is created before anything has told it which shortcuts there are,
  /// and `WallpaperService.deleteSceneWallpaper` documents why a sweep that
  /// guesses is worse than a few orphaned kilobytes.
  Future<void> _init() async {
    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      _documentsPath = documents.path;
      final Map<int, Uint8List> loaded = {};
      await for (final FileSystemEntity entity in documents.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final String name = entity.uri.pathSegments.last;
        if (!name.startsWith(contentShortcutArtworkFileNamePrefix)) {
          continue;
        }
        if (name.endsWith(_partialFileNameSuffix)) {
          await _deleteFile(entity);
          continue;
        }
        final int? shortcutId = int.tryParse(name.substring(contentShortcutArtworkFileNamePrefix.length));
        if (shortcutId == null) {
          continue;
        }
        final Uint8List bytes = await entity.readAsBytes();
        if (bytes.isNotEmpty) {
          loaded[shortcutId] = bytes;
        }
      }
      _artworkByShortcutId.addAll(loaded);
      if (loaded.isNotEmpty) {
        _notify();
      }
    } catch (e) {
      // An unreadable documents directory is simply a launcher with no
      // artwork; it is not a reason to fail the whole home screen.
      debugPrint("ContentShortcutArtworkService: could not read the stored artwork ($e)");
    }
  }

  /// Downloads the `og:image` of [uri], or returns null when there is nothing
  /// usable at the other end. Throws nothing of its own; [refreshArtwork] owns
  /// the catch for what the network raises.
  Future<Uint8List?> _fetchArtwork(String uri) async {
    final Uri? pageUri = Uri.tryParse(uri);
    if (pageUri == null || !_isFetchable(pageUri)) {
      // `youtube://…` and `vnd.youtube:…` are valid shortcut URIs (see
      // `normalizeContentShortcutUri`) and are not pages: there is no document
      // to read an `og:image` out of.
      return null;
    }

    final http.Response page = await _httpClient
        .get(pageUri, headers: const {"User-Agent": userAgent, "Accept": "text/html,application/xhtml+xml"})
        .timeout(requestTimeout);
    if (page.statusCode != 200) {
      debugPrint("ContentShortcutArtworkService: $pageUri answered ${page.statusCode}, leaving the icon alone");
      return null;
    }

    final String? imageUrl = _extractOpenGraphImage(page.body);
    if (imageUrl == null) {
      debugPrint("ContentShortcutArtworkService: no og:image in $pageUri, leaving the icon alone");
      return null;
    }

    final Uri? imageUri = _resolveImageUri(pageUri, imageUrl);
    if (imageUri == null) {
      return null;
    }

    final http.Response image = await _httpClient
        .get(imageUri, headers: const {"User-Agent": userAgent, "Accept": "image/*"})
        .timeout(requestTimeout);
    if (image.statusCode != 200) {
      debugPrint("ContentShortcutArtworkService: $imageUri answered ${image.statusCode}, leaving the icon alone");
      return null;
    }

    final Uint8List bytes = image.bodyBytes;
    if (bytes.isEmpty || bytes.length > maxArtworkBytes) {
      return null;
    }
    if (!_looksLikeImage(image.headers["content-type"], bytes)) {
      debugPrint("ContentShortcutArtworkService: $imageUri is not an image, leaving the icon alone");
      return null;
    }
    return bytes;
  }

  /// Whether [uri] is a document this service can ask for. Only `http` and
  /// `https`: a `file:` or `data:` og:image target would make the launcher copy
  /// something off its own device into a card.
  bool _isFetchable(Uri uri) => (uri.isScheme("http") || uri.isScheme("https")) && uri.host.isNotEmpty;

  /// The value of the first `og:image` meta tag of [body], or null when the
  /// document carries none.
  ///
  /// Accepts `property=` and `name=` (both are in the wild), either quoting
  /// style, and attributes in any order, because this is somebody else's markup
  /// and it is allowed to change without warning.
  String? _extractOpenGraphImage(String body) {
    for (final RegExpMatch tag in _metaTagPattern.allMatches(body)) {
      final Map<String, String> attributes = {};
      for (final RegExpMatch attribute in _attributePattern.allMatches(tag.group(0)!)) {
        final String name = attribute.group(1)!.toLowerCase();
        attributes[name] = attribute.group(2) ?? attribute.group(3) ?? attribute.group(4) ?? "";
      }
      final String? property = attributes["property"] ?? attributes["name"];
      if (property?.toLowerCase() != "og:image") {
        continue;
      }
      final String content = _unescapeHtml(attributes["content"] ?? "").trim();
      if (content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  String _unescapeHtml(String value) {
    if (!value.contains("&")) {
      return value;
    }
    String unescaped = value;
    for (final MapEntry<String, String> entity in _htmlEntities.entries) {
      unescaped = unescaped.replaceAll(entity.key, entity.value);
    }
    return unescaped;
  }

  /// [imageUrl] resolved against the page it was found in — it is allowed to be
  /// relative, or protocol-relative — or null when it is not an address this
  /// service will fetch.
  Uri? _resolveImageUri(Uri pageUri, String imageUrl) {
    final Uri resolved;
    try {
      resolved = pageUri.resolve(imageUrl);
    } catch (e) {
      debugPrint("ContentShortcutArtworkService: og:image '$imageUrl' is not an address ($e)");
      return null;
    }
    return _isFetchable(resolved) ? resolved : null;
  }

  /// Whether what came back is an image, judged on its declared type *and* its
  /// first bytes: a mislabelled real image is still an image, and an HTML error
  /// page served with a 200 is still not one.
  bool _looksLikeImage(String? contentType, Uint8List bytes) {
    if (_hasImageMagicBytes(bytes)) {
      return true;
    }
    final String declared = (contentType ?? "").trim().toLowerCase();
    return declared.startsWith("image/");
  }

  bool _hasImageMagicBytes(Uint8List bytes) {
    bool startsWith(List<int> magic, {int offset = 0}) {
      if (bytes.length < offset + magic.length) {
        return false;
      }
      for (int i = 0; i < magic.length; ++i) {
        if (bytes[offset + i] != magic[i]) {
          return false;
        }
      }
      return true;
    }

    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return true; // PNG
    if (startsWith(const [0xFF, 0xD8, 0xFF])) return true; // JPEG
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return true; // GIF
    if (startsWith(const [0x42, 0x4D])) return true; // BMP
    // WebP: "RIFF" then four size bytes then "WEBP".
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
      return true;
    }
    return false;
  }

  /// Writes [bytes] as the artwork of [shortcutId].
  ///
  /// Written under a `.part` name and renamed into place, so the name the card
  /// renders never holds half an image; a rename is atomic on the one
  /// filesystem this ever runs on. Any failure ends with the shortcut having no
  /// artwork rather than its previous one.
  Future<void> _store(int shortcutId, Uint8List bytes) async {
    final String? documentsPath = _documentsPath;
    if (documentsPath == null) {
      return;
    }
    final File target = _artworkFile(documentsPath, shortcutId);
    final File partial = File("${target.path}$_partialFileNameSuffix");
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(target.path);
    } catch (e) {
      debugPrint("ContentShortcutArtworkService: could not store the artwork of shortcut $shortcutId ($e)");
      await _deleteFile(partial);
      await deleteArtwork(shortcutId);
      return;
    }
    await _publish(shortcutId, bytes);
  }

  /// Hands [bytes] to whoever is rendering the shortcut, and takes the bytes
  /// they replace out of the image cache.
  ///
  /// The eviction is the point: the file name is derived from the shortcut id,
  /// so re-pointing a shortcut at another channel rewrites *the same path*, and
  /// an entry keyed on that path would go on painting the old avatar. The
  /// provider is built by [_providerFor] for both rendering and eviction, so
  /// what is evicted is exactly what was cached.
  Future<void> _publish(int shortcutId, Uint8List bytes) async {
    final Uint8List? previous = _artworkByShortcutId[shortcutId];
    _artworkByShortcutId[shortcutId] = bytes;
    if (previous != null) {
      await _providerFor(previous).evict();
    }
    _notify();
  }

  ImageProvider _providerFor(Uint8List bytes) => ResizeImage(MemoryImage(bytes), width: artworkCacheWidth);

  /// Marks everything already in flight for [shortcutId] as superseded, and
  /// returns the token of the operation that starts now.
  int _beginOperation(int shortcutId) {
    final int operation = (_operationByShortcutId[shortcutId] ?? 0) + 1;
    _operationByShortcutId[shortcutId] = operation;
    return operation;
  }

  File _artworkFile(String documentsPath, int shortcutId) =>
      File("$documentsPath/$contentShortcutArtworkFileNamePrefix$shortcutId");

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("ContentShortcutArtworkService: could not delete ${file.path} ($e)");
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
