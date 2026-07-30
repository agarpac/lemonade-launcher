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

import 'package:flauncher/content_shortcut_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("contentShortcutHandle", () {
    test("returns the handle a channel address points at", () {
      expect(contentShortcutHandle("https://www.youtube.com/@LinusTechTips"), "@LinusTechTips");
      expect(contentShortcutHandle("https://youtube.com/@a_b.c-d/videos"), "@a_b.c-d");
    });

    test("returns nothing for a channel id, which is not a name", () {
      // Showing `UCxxxx…` on the card would be worse than the label the user
      // typed, which is the whole reason this returns null instead of the id.
      expect(contentShortcutHandle("https://www.youtube.com/channel/UCXuqSBlHAE6Xw-yeJA0Tunw"), isNull);
    });

    test("returns nothing for an address that names no handle at all", () {
      expect(contentShortcutHandle("https://www.youtube.com/feed/subscriptions"), isNull);
      expect(contentShortcutHandle("https://example.com/some/path"), isNull);
    });

    test("returns nothing rather than throwing on unparseable input", () {
      expect(contentShortcutHandle(""), isNull);
      expect(contentShortcutHandle("::::"), isNull);
    });
  });

  group("normalizeContentShortcutUri", () {
    test("turns a short handle into the channel's address", () {
      // The main case (PRD 12.3, point 2): this is the one thing that is
      // actually viable to type with a D-pad.
      expect(normalizeContentShortcutUri("@LinusTechTips"), "https://www.youtube.com/@LinusTechTips");
      expect(normalizeContentShortcutUri("@a_b.c-d"), "https://www.youtube.com/@a_b.c-d");
    });

    test("trims the surrounding whitespace of a handle instead of rejecting it", () {
      expect(normalizeContentShortcutUri("  @Handle  "), "https://www.youtube.com/@Handle");
    });

    test("turns a channel id into the channel's address", () {
      expect(
        normalizeContentShortcutUri("UCXuqSBlHAE6Xw-yeJA0Tunw"),
        "https://www.youtube.com/channel/UCXuqSBlHAE6Xw-yeJA0Tunw",
      );
    });

    test("rejects something that only looks like a channel id", () {
      // 24 characters exactly, or it is not a channel id.
      expect(normalizeContentShortcutUri("UCtooshort"), isNull);
      expect(normalizeContentShortcutUri("UCXuqSBlHAE6Xw-yeJA0Tunwaaaa"), isNull);
    });

    test("passes a full YouTube address through unchanged", () {
      const address = "https://www.youtube.com/feed/subscriptions";
      expect(normalizeContentShortcutUri(address), address);
      expect(normalizeContentShortcutUri("https://youtu.be/dQw4w9WgXcQ"), "https://youtu.be/dQw4w9WgXcQ");
    });

    test("passes a full address that has nothing to do with YouTube through unchanged", () {
      // The only contract verified so far happens to be YouTube's (PRD 12.2),
      // and nothing here is allowed to turn that coincidence into a restriction:
      // whatever declares an intent filter for an address can be its target.
      expect(normalizeContentShortcutUri("https://example.org/a/b?c=d#e"), "https://example.org/a/b?c=d#e");
      expect(normalizeContentShortcutUri("http://192.168.1.10:8080/live"), "http://192.168.1.10:8080/live");
    });

    test("passes an application scheme through unchanged", () {
      // SmartTube's manifest declares `vnd.youtube` and `youtube` too, so a
      // scheme that is not http(s) must survive normalization.
      expect(normalizeContentShortcutUri("vnd.youtube:dQw4w9WgXcQ"), "vnd.youtube:dQw4w9WgXcQ");
      expect(normalizeContentShortcutUri("youtube://play"), "youtube://play");
    });

    test("completes an address typed without its scheme", () {
      expect(
        normalizeContentShortcutUri("youtube.com/feed/subscriptions"),
        "https://youtube.com/feed/subscriptions",
      );
      expect(normalizeContentShortcutUri("example.org"), "https://example.org");
    });

    test("rejects empty and blank input", () {
      expect(normalizeContentShortcutUri(""), isNull);
      expect(normalizeContentShortcutUri("   "), isNull);
      expect(normalizeContentShortcutUri("\t\n"), isNull);
    });

    test("rejects input that is neither a channel nor an address", () {
      expect(normalizeContentShortcutUri("@"), isNull);
      expect(normalizeContentShortcutUri("@not a handle"), isNull);
      expect(normalizeContentShortcutUri("@handle/with/slashes"), isNull);
      expect(normalizeContentShortcutUri("just some words"), isNull);
      expect(normalizeContentShortcutUri("subscriptions"), isNull);
      // A scheme with nothing after it parses fine and opens nothing.
      expect(normalizeContentShortcutUri("https:"), isNull);
      expect(normalizeContentShortcutUri("https://"), isNull);
    });

    test("rejects an address with whitespace inside it", () {
      // Trailing whitespace is trimmed, but whitespace in the middle of an
      // address means what was typed is not one.
      expect(normalizeContentShortcutUri("https://example.org/a b"), isNull);
      expect(normalizeContentShortcutUri("https://example.org/a "), "https://example.org/a");
    });
  });

  group("contentShortcutLabelSuggestion", () {
    test("suggests the handle, without its @", () {
      expect(contentShortcutLabelSuggestion("@LinusTechTips"), "LinusTechTips");
    });

    test("suggests the last part of an address", () {
      expect(contentShortcutLabelSuggestion("https://www.youtube.com/feed/subscriptions"), "subscriptions");
      expect(contentShortcutLabelSuggestion("https://www.youtube.com/@SomeChannel"), "SomeChannel");
    });

    test("suggests the host when the address has no path", () {
      expect(contentShortcutLabelSuggestion("https://example.org"), "example.org");
    });

    test("suggests nothing for an opaque channel id, which is not a name", () {
      expect(contentShortcutLabelSuggestion("UCXuqSBlHAE6Xw-yeJA0Tunw"), isNull);
    });

    test("suggests nothing for input that could not be normalized", () {
      expect(contentShortcutLabelSuggestion(""), isNull);
      expect(contentShortcutLabelSuggestion("   "), isNull);
      expect(contentShortcutLabelSuggestion("@not a handle"), isNull);
    });
  });
}
