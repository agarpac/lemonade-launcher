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

import 'l10n/app_localizations.dart';

/// The category name `AppsService` seeds on first run for the auto-populated
/// "everything" category (PRD 13.8). Compared by equality in
/// `apps_service.dart` and pinned in a literal migration in `database.dart` —
/// never translate the stored value itself.
const String reservedAllAppsCategoryName = 'All Apps';

/// The category name the dock is located by. `flauncher.dart` finds the dock
/// row with a literal `== 'Favorites'`, `apps_service.dart` compares against
/// it, and a migration in `database.dart` writes it verbatim. Translating the
/// stored value empties the dock in silence (see AGENTS.md).
const String reservedFavoritesCategoryName = 'Favorites';

/// The label to paint for a category named [name].
///
/// Maps only the two reserved names above to their localized string; every
/// other category name — including one a user typed that happens to collide
/// with neither reserved literal — is returned unchanged. This is a
/// display-time mapping only: [name] is never rewritten, so it stays safe to
/// compare against the database, the dock lookup, and the schema migrations
/// that all still expect the literal English string.
String localizedCategoryDisplayName(AppLocalizations localizations, String name) {
  switch (name) {
    case reservedAllAppsCategoryName:
      return localizations.allApplications;
    case reservedFavoritesCategoryName:
      return localizations.favorites;
    default:
      return name;
  }
}
