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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/backup_service.dart';
import 'package:flauncher/widgets/settings/backup_restore_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Entry point of the backup feature: two actions, "create" and "restore".
///
/// Both live behind the system settings page rather than the appearance or
/// interface ones: a backup is device housekeeping, like the brightness
/// schedule or the screensaver, and it covers *every* setting rather than
/// belonging to any single one of them.
class BackupPanelPage extends StatelessWidget {
  static const String routeName = "backup_panel";

  const BackupPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(localizations.backupAndRestore, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.save_alt),
                  title: Text(localizations.backupCreate, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => _createBackup(context),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(localizations.backupRestore, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: () => Navigator.of(context).pushNamed(BackupRestorePage.routeName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Writes a backup file and reports the outcome in a dialog.
  ///
  /// The dialog always names the file on success — the whole point of an export
  /// is being able to find it with `adb pull` or a file manager afterwards —
  /// and always lists the wallpapers whose bytes were left out, since those are
  /// the one thing a restore cannot bring back.
  Future<void> _createBackup(BuildContext context) async {
    final backupService = context.read<BackupService>();
    final result = await backupService.exportBackup();
    if (!context.mounted) {
      return;
    }
    await _showExportResultDialog(context, result);
  }

  Future<void> _showExportResultDialog(BuildContext context, BackupExportResult result) {
    final localizations = AppLocalizations.of(context)!;
    final filePath = result.filePath;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(result.succeeded ? localizations.backupCreatedTitle : localizations.backupNotCreatedTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(backupExportMessage(localizations, result.status)),
              if (filePath != null) ...[
                const SizedBox(height: 16),
                Text(localizations.backupExportFilePath(filePath)),
              ],
              if (result.wallpapersNotIncluded.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(localizations.backupExportWallpapersNotIncluded),
                const SizedBox(height: 4),
                for (final wallpaper in result.wallpapersNotIncluded) Text("• $wallpaper"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// The localized message for [status].
///
/// Every value of [BackupExportStatus] is mapped here on purpose:
/// `BackupExportResult.message` is deliberately non-localized English meant for
/// logs, so it must never reach the screen, and no status may fall through to a
/// generic "something went wrong" either.
String backupExportMessage(AppLocalizations localizations, BackupExportStatus status) {
  switch (status) {
    case BackupExportStatus.succeeded:
      return localizations.backupExportSucceeded;
    case BackupExportStatus.storageUnavailable:
      return localizations.backupExportStorageUnavailable;
    case BackupExportStatus.failed:
      return localizations.backupExportFailed;
  }
}
