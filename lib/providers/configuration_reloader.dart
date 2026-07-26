/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
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

/// Rebuilds the launcher's whole provider tree in place, so every service is
/// constructed again from the store as it is *now*.
///
/// Exists for one caller: a successful `BackupService.importBackup`. That
/// service replaces the database and the preferences underneath services that
/// each loaded their state once, at construction time (see the contract on
/// `BackupService`), and this launcher is the device's only home screen, so
/// restarting the process is not an option. Re-creating the services is.
///
/// A tiny indirection on purpose: the generation counter that does the actual
/// work lives in the root widget's [State] in `main.dart`, and a settings page
/// must be able to ask for a reload without reaching into it — nor importing
/// it. Tests supply their own instance and assert on the callback.
class ConfigurationReloader {
  final void Function() _onReload;

  const ConfigurationReloader(this._onReload);

  /// Discards every service and builds the tree again.
  ///
  /// **Destroys the widget subtree below the root**, including whatever
  /// settings page the user is standing in. Callers must therefore have
  /// already shown their result, waited for the acknowledgement and closed the
  /// settings UI before calling this.
  void reload() => _onReload();
}
