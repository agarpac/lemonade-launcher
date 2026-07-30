/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
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

import 'dart:collection';

import 'app.dart';

enum LauncherSectionType
{
  Category,
  Spacer,
  Shortcut
}

enum CategorySort
{
  manual,
  alphabetical,
  lastUsed,
}

enum CategoryType
{
  row,
  grid,
}

class LauncherSection
{
  final int id;

  int order;

  LauncherSection({
    this.id = 0,
    this.order = 0
  });
}

class Category extends LauncherSection
{
  static const int          ColumnsCount  = 6;
  static const int          RowHeight     = 110;
  static const CategorySort Sort          = CategorySort.manual;
  static const CategoryType Type          = CategoryType.grid;

  int columnsCount;

  int rowHeight;

  String name;

  CategorySort sort;

  CategoryType type;

  final List<App> applications;

  Category({
    required this.name,
    int id = 0,
    int order = 0,
    this.columnsCount = Category.ColumnsCount,
    this.rowHeight = Category.RowHeight,
    this.sort = Category.Sort,
    this.type = Category.Type
  }):   applications = [],
        super(id: id, order: order);

  Category.withApplications({
    required this.name,
    required this.applications,
    int id = 0,
    int order = 0,
    this.columnsCount = Category.ColumnsCount,
    this.rowHeight = Category.RowHeight,
    this.sort = Category.Sort,
    this.type = Category.Type
  }): super(id: id, order: order);

  Category unmodifiable() {
    return Category.withApplications(
      name: name,
      id: id,
      order: order,
      columnsCount: columnsCount,
      rowHeight: rowHeight,
      sort: sort,
      type: type,
      applications: UnmodifiableListView(applications));
  }
}

class LauncherSpacer extends LauncherSection
{
  int height;

  LauncherSpacer({
    int id = 0,
    int order = 0,
    this.height = 0
  }): super(id: id, order: order);
}

/// One deep link: a label, the URI to open and the package the intent pins.
///
/// [available] is **never persisted**. It is recomputed on every state refresh
/// from what the system reports as installed, because the rule for a shortcut is
/// the opposite of the rule for an app row: an app whose package is gone is
/// deleted, a shortcut whose target is gone is only marked unavailable (see the
/// PRD, section 12.3, point 5). Persisting it would let a single refresh with a
/// silent platform channel bake "unavailable" into the database.
class ContentShortcut
{
  final int id;

  /// Id of the [ContentShortcutSection] this shortcut belongs to. Not a foreign
  /// key: a shortcut section has no row of its own, it *is* the group of
  /// shortcuts sharing this value.
  int sectionId;

  /// Position of this shortcut inside its section.
  int order;

  String label;

  String uri;

  /// The package the intent pins, so Android never shows an app chooser.
  String targetPackage;

  bool available;

  ContentShortcut({
    required this.label,
    required this.uri,
    required this.targetPackage,
    this.id = 0,
    this.sectionId = 0,
    this.order = 0,
    this.available = true
  });

  /// A shortcut with no target package can never be launched with the package
  /// pinned, and one with no URI has nothing to open. Both shapes are reachable
  /// from a hand-edited backup file, so they are treated as unavailable rather
  /// than handed to the platform channel.
  bool get launchable => uri.isNotEmpty && targetPackage.isNotEmpty;
}

/// A section made of deep links, ordered among the launcher's other sections
/// exactly like a [Category] or a [LauncherSpacer].
///
/// Its [id] is the `section_id` its shortcuts share; it owns no row of its own,
/// so a section with no shortcuts left does not exist any more (see
/// `AppsService.deleteContentShortcut`).
class ContentShortcutSection extends LauncherSection
{
  final List<ContentShortcut> shortcuts;

  ContentShortcutSection({
    int id = 0,
    int order = 0,
    List<ContentShortcut>? shortcuts
  }):   shortcuts = shortcuts ?? [],
        super(id: id, order: order);

  ContentShortcutSection unmodifiable() => ContentShortcutSection(
    id: id,
    order: order,
    shortcuts: UnmodifiableListView(shortcuts));
}