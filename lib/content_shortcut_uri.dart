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

/// Turns what the user typed into the URI a deep link is built from.
///
/// Lives outside the widget tree on purpose: this is the one piece of the
/// content-shortcut feature with real rules in it, and rules that decide what a
/// user's input means have to be testable without pumping a settings page.
///
/// The main case is a channel (see the PRD, section 12.3, point 2): typing
/// `@handle` on a D-pad is viable, typing a whole URL is not. The full URL stays
/// as the fallback, and is *never* rejected for not being a YouTube one — the
/// only verified contract happens to be YouTube's (PRD 12.2), but nothing here
/// is allowed to turn that coincidence into a restriction.

/// Where a bare channel handle or channel id is resolved against.
const String _youTubeChannelBase = "https://www.youtube.com";

/// `@handle`. YouTube handles are 3-30 characters of letters, digits, dots,
/// dashes and underscores; the bound here is deliberately looser than that so a
/// handle YouTube accepts and this launcher has never heard of still works.
final RegExp _handlePattern = RegExp(r'^@[A-Za-z0-9._-]{1,64}$');

/// `UC…`: a channel id is always `UC` plus 22 URL-safe base64 characters.
final RegExp _channelIdPattern = RegExp(r'^UC[A-Za-z0-9_-]{22}$');

/// A URI scheme, i.e. the input is already a full address of some kind.
final RegExp _schemePattern = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');

/// A hostname with at least one dot, optionally followed by a path — the shape
/// of an address a user typed without bothering with `https://`.
final RegExp _bareHostPattern = RegExp(
    r'^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+(/.*)?$');

/// Whether [value] holds a character that can never appear unescaped in a URI:
/// a space, any other whitespace, or any control character. Catches the whole
/// family of "this is a sentence, not an address" inputs, plus control
/// characters out of a hand-edited backup or a rogue keyboard.
bool _hasForbiddenCharacter(String value) =>
    value.codeUnits.any((unit) => unit <= 0x20 || unit == 0x7F);

/// The URI to open for [input], or null when [input] is not something that can
/// be opened at all.
///
/// Accepted, in this order:
/// - `@handle` → that channel's address;
/// - `UC…` (a channel id) → that channel's address;
/// - anything with a scheme → returned **unchanged**, whatever the host and
///   whatever the scheme (`https:`, but also `youtube:` or `vnd.youtube:`,
///   which the SmartTube manifest declares too);
/// - a scheme-less hostname → the same address over `https`.
///
/// Everything else is null: empty input, a lone `@`, a handle with a space or a
/// slash in it, a scheme with nothing after it, prose.
String? normalizeContentShortcutUri(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty || _hasForbiddenCharacter(trimmed)) {
    return null;
  }

  if (trimmed.startsWith("@")) {
    return _handlePattern.hasMatch(trimmed) ? "$_youTubeChannelBase/$trimmed" : null;
  }

  if (_channelIdPattern.hasMatch(trimmed)) {
    return "$_youTubeChannelBase/channel/$trimmed";
  }

  if (_schemePattern.hasMatch(trimmed)) {
    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || parsed.scheme.isEmpty) {
      return null;
    }
    // "https:" and "https://" both parse fine and open nothing: there has to be
    // either a host or a path for the intent to point anywhere.
    if (parsed.host.isEmpty && parsed.path.isEmpty) {
      return null;
    }
    return trimmed;
  }

  if (_bareHostPattern.hasMatch(trimmed)) {
    return "https://$trimmed";
  }

  return null;
}

/// A name to offer for [input] when the user has not typed one.
///
/// Naming a shortcut is one more thing to type with a remote, so the handle or
/// the last part of the address is offered as a starting point. Returns null
/// when nothing better than the raw address could be suggested — an opaque
/// channel id is not a name, and neither is a bare hostname's TLD.
String? contentShortcutLabelSuggestion(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (_handlePattern.hasMatch(trimmed)) {
    return trimmed.substring(1);
  }
  if (_channelIdPattern.hasMatch(trimmed)) {
    return null;
  }

  final String? normalized = normalizeContentShortcutUri(trimmed);
  if (normalized == null) {
    return null;
  }
  final Uri? parsed = Uri.tryParse(normalized);
  if (parsed == null) {
    return null;
  }

  final Iterable<String> segments = parsed.pathSegments.where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) {
    return parsed.host.isEmpty ? null : parsed.host;
  }
  final String last = segments.last;
  return last.startsWith("@") && last.length > 1 ? last.substring(1) : last;
}
