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

import 'package:flauncher/category_display_name.dart';
import 'package:flauncher/l10n/app_localizations_en.dart';
import 'package:flauncher/l10n/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final es = AppLocalizationsEs();

  group("localizedCategoryDisplayName", () {
    // (a) What gets painted for the two reserved names is the localized string,
    // not the stored literal. Asserted against Spanish specifically: in English
    // the localized string and the stored value are spelled the same, which
    // would let a passthrough bug hide as a pass.
    test("translates the reserved 'All Apps' name for display", () {
      expect(localizedCategoryDisplayName(es, reservedAllAppsCategoryName), "Todas las aplicaciones");
      expect(localizedCategoryDisplayName(en, reservedAllAppsCategoryName), "All Apps");
    });

    test("translates the reserved 'Favorites' name for display", () {
      expect(localizedCategoryDisplayName(es, reservedFavoritesCategoryName), "Favoritos");
      expect(localizedCategoryDisplayName(en, reservedFavoritesCategoryName), "Favorites");
    });

    test("leaves every other category name exactly as-is", () {
      expect(localizedCategoryDisplayName(es, "Subscriptions"), "Subscriptions");
      expect(localizedCategoryDisplayName(es, "Juegos"), "Juegos");
    });

    // (b) This is exactly the spot where someone would "fix" the English text by
    // translating the constant itself. Doing that empties the dock in silence:
    // `flauncher.dart` finds the dock row with a literal `== 'Favorites'`,
    // `AppsService` compares category names the same way, and a migration in
    // `database.dart` writes 'All Apps' / 'Favorites' verbatim. None of that can
    // change just because the *display* is now localized.
    test("does not change the reserved literals that the database and dock compare against", () {
      expect(reservedAllAppsCategoryName, "All Apps");
      expect(reservedFavoritesCategoryName, "Favorites");
    });
  });
}
