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

import 'dart:io';

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/backup_service.dart';
import 'package:flauncher/providers/configuration_reloader.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Picks a backup file, confirms what restoring it will do, restores it, and
/// then rebuilds the whole provider tree so the restored configuration is what
/// the user actually sees.
///
/// The order of the last steps is not cosmetic:
///
///  1. show the outcome, 2. wait for the acknowledgement, 3. close the settings
///  UI, 4. only then [ConfigurationReloader.reload].
///
/// A reload destroys the widget subtree below the root — this page and the
/// settings navigator it stands in included — so calling it any earlier would
/// tear down the dialog the user is reading.
class BackupRestorePage extends StatefulWidget {
  static const String routeName = "backup_restore_panel";

  /// Lists the candidate files to pick from. Defaults to the real contents of
  /// the directory `BackupService` exports into; tests inject a plain list, the
  /// same test-seam approach `SceneImagePage.mediaPicker` and
  /// `WallpaperService.debugNow` use.
  ///
  /// Injected rather than reached for directly because `dart:io` futures do not
  /// complete inside the fake-async zone widget tests run in, so a page that
  /// touched the file system itself could not be pumped at all.
  @visibleForTesting
  final Future<List<File>?> Function() backupDirectoryLister;

  BackupRestorePage({super.key, this.backupDirectoryLister = listExportedBackupFiles});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  late final Future<_BackupListing> _listing = _listBackups();

  /// Every backup file in the export directory, newest first.
  ///
  /// Sorted by file name descending, which is a chronological sort: the name is
  /// `<prefix><yyyyMMdd-HHmmss>.json` (see [backupFileNamePrefix]), so it sorts
  /// exactly as its timestamp does — and unlike a modification time, it cannot
  /// be rewritten by a file manager copying the file around.
  ///
  /// Anything else living in the same directory is filtered out: it is the
  /// app's own external storage directory, not a folder owned by this feature.
  Future<_BackupListing> _listBackups() async {
    final files = await widget.backupDirectoryLister();
    if (files == null) {
      return const _BackupListing.storageUnavailable();
    }

    final backups = files.where((file) => _isBackupFileName(_fileNameOf(file))).toList();
    backups.sort((a, b) => _fileNameOf(b).compareTo(_fileNameOf(a)));
    return _BackupListing(files: backups);
  }

  static String _fileNameOf(FileSystemEntity entity) => entity.uri.pathSegments.last;

  static bool _isBackupFileName(String name) => name.startsWith(backupFileNamePrefix) && name.endsWith(".json");

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(localizations.backupChooseFile, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: FutureBuilder<_BackupListing>(
            future: _listing,
            builder: (context, snapshot) {
              final listing = snapshot.data;
              if (snapshot.hasError) {
                // Unreachable with the production lister, which swallows its own
                // failures — but an unhandled error must show a message rather
                // than spin on the progress indicator forever.
                return _CenteredMessage(message: localizations.backupListStorageUnavailable);
              }
              if (listing == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!listing.storageAvailable) {
                return _CenteredMessage(message: localizations.backupListStorageUnavailable);
              }
              if (listing.files.isEmpty) {
                return _CenteredMessage(message: localizations.backupListEmpty);
              }
              // A plain Column inside a scroll view, never a lazy ListView: the
              // first tile carries the autofocus, and a lazily built list is
              // free not to have built it yet when focus is handed out, which
              // leaves the page unreachable with a D-pad.
              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (final file in listing.files)
                      FocusableSettingsTile(
                        autofocus: file == listing.files.first,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(_fileNameOf(file), style: Theme.of(context).textTheme.bodyMedium),
                        onPressed: () => _restore(context, file),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Validates the file, asks for an explicit confirmation, restores, reports,
  /// and only then closes the settings UI and reloads the configuration.
  ///
  /// Nothing is written before the confirmation: [BackupService.previewImport]
  /// reads and checks the file without touching the database or the
  /// preferences, so a user who backs out at the dialog leaves with exactly the
  /// configuration they had.
  Future<void> _restore(BuildContext context, File file) async {
    final backupService = context.read<BackupService>();

    final preview = await backupService.previewImport(file);
    if (!context.mounted) {
      return;
    }
    if (preview.status != BackupImportStatus.succeeded) {
      // Rejected before anything was written: report and stay on the list, so
      // the user can pick another file.
      await _showImportResultDialog(context, preview);
      return;
    }

    final confirmed = await _showConfirmationDialog(context, preview);
    if (!confirmed || !context.mounted) {
      return;
    }

    final result = await backupService.importBackup(file);
    if (!context.mounted) {
      return;
    }
    await _showImportResultDialog(context, result);
    if (!result.succeeded || !context.mounted) {
      return;
    }

    // Read the reloader before popping: the pop makes this context defunct, and
    // the reloader lives above the subtree the reload is about to destroy.
    final reloader = context.read<ConfigurationReloader>();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
    reloader.reload();
  }

  /// States plainly that a restore replaces rather than merges, and lists what
  /// the user will not get back: the applications that are no longer installed
  /// and the wallpapers whose bytes never travelled in the file.
  Future<bool> _showConfirmationDialog(BuildContext context, BackupImportResult preview) async {
    final localizations = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.backupRestoreConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.backupRestoreConfirmBody),
              if (preview.skippedPackageNames.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(localizations.backupRestoreSkippedApps),
                const SizedBox(height: 4),
                for (final packageName in preview.skippedPackageNames) Text("• $packageName"),
              ],
              if (preview.wallpapersToReselect.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(localizations.backupRestoreWallpapersToReselect),
                const SizedBox(height: 4),
                for (final wallpaper in preview.wallpapersToReselect) Text("• $wallpaper"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            // The destructive choice is never the one under the cursor.
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.backupRestoreConfirmButton),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showImportResultDialog(BuildContext context, BackupImportResult result) {
    final localizations = AppLocalizations.of(context)!;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(result.succeeded ? localizations.backupRestoredTitle : localizations.backupNotRestoredTitle),
        content: Text(backupImportMessage(localizations, result.status)),
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

/// Every file sitting in the directory `BackupService` exports into, or `null`
/// when this device exposes no such directory at all.
///
/// Deliberately does no filtering and no ordering: [BackupRestorePage] owns
/// both, and keeping this function a thin adapter around `dart:io` is what lets
/// that page's logic be tested without a file system.
Future<List<File>?> listExportedBackupFiles() async {
  final Directory? directory;
  try {
    directory = await getExternalStorageDirectory();
  } catch (_) {
    return null;
  }
  if (directory == null) {
    return null;
  }

  try {
    if (!await directory.exists()) {
      return const [];
    }
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  } catch (_) {
    // A directory that cannot be listed holds no backup to offer, which is
    // "nothing to find" rather than "nowhere to look".
    return const [];
  }
}

/// What [_BackupRestorePageState._listBackups] found: either no reachable
/// storage at all, or the backups it holds — possibly none.
///
/// The two are told apart because they are different problems with different
/// answers: "create a backup first" versus "this device has nowhere to put
/// one". Neither may show up as an empty screen.
class _BackupListing {
  final bool storageAvailable;
  final List<File> files;

  const _BackupListing({required this.files}) : storageAvailable = true;

  const _BackupListing.storageUnavailable()
      : storageAvailable = false,
        files = const [];
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 32, color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}

/// The localized message for [status].
///
/// Every value of [BackupImportStatus] is mapped here on purpose:
/// `BackupImportResult.message` is deliberately non-localized English meant for
/// logs, so it must never reach the screen, and no status may fall through to a
/// generic "something went wrong" either.
String backupImportMessage(AppLocalizations localizations, BackupImportStatus status) {
  switch (status) {
    case BackupImportStatus.succeeded:
      return localizations.backupImportSucceeded;
    case BackupImportStatus.settingsRestoreIncomplete:
      return localizations.backupImportSettingsRestoreIncomplete;
    case BackupImportStatus.fileNotFound:
      return localizations.backupImportFileNotFound;
    case BackupImportStatus.invalidFile:
      return localizations.backupImportInvalidFile;
    case BackupImportStatus.unsupportedVersion:
      return localizations.backupImportUnsupportedVersion;
    case BackupImportStatus.installedAppsUnavailable:
      return localizations.backupImportInstalledAppsUnavailable;
    case BackupImportStatus.restoreFailed:
      return localizations.backupImportRestoreFailed;
  }
}
