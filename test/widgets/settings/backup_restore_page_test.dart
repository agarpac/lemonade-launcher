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
import 'package:flauncher/widgets/settings/backup_restore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

const String _olderBackup = "lemonade-launcher-backup-20260101-101010.json";
const String _newerBackup = "lemonade-launcher-backup-20260202-202020.json";

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("An empty storage directory shows its own message, not a blank page", (tester) async {
    final backupService = MockBackupService();

    await _pumpWidgetWithProviders(tester, backupService, files: []);

    expect(find.text("No backup found on this device. Create one first."), findsOneWidget);
    verifyNever(backupService.previewImport(any));
  });

  testWidgets("A directory holding no backup of ours shows the same empty message", (tester) async {
    final backupService = MockBackupService();

    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile("notes.txt"), _backupFile("other-launcher-backup-20260101.json")],
    );

    expect(find.text("No backup found on this device. Create one first."), findsOneWidget);
    expect(find.text("notes.txt"), findsNothing);
    expect(find.text("other-launcher-backup-20260101.json"), findsNothing);
  });

  testWidgets("No storage directory at all shows its own message, not the empty-list one", (tester) async {
    final backupService = MockBackupService();

    await _pumpWidgetWithProviders(tester, backupService, files: null);

    expect(
      find.text("This device exposes no storage where backups could be looked for."),
      findsOneWidget,
    );
    expect(find.text("No backup found on this device. Create one first."), findsNothing);
  });

  testWidgets("Backups are listed newest first", (tester) async {
    final backupService = MockBackupService();

    // Handed over oldest-first on purpose: the ordering must be the page's, not
    // the directory listing's.
    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile(_olderBackup), _backupFile(_newerBackup)],
    );

    expect(find.text(_newerBackup), findsOneWidget);
    expect(find.text(_olderBackup), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_newerBackup)).dy,
      lessThan(tester.getTopLeft(find.text(_olderBackup)).dy),
    );
  });

  testWidgets("Choosing a backup previews it and imports nothing until it is confirmed", (tester) async {
    final backupService = MockBackupService();
    when(backupService.previewImport(any)).thenAnswer((_) async => const BackupImportResult(
          status: BackupImportStatus.succeeded,
          skippedPackageNames: ["com.example.gone"],
          wallpapersToReselect: ["wallpaper_video"],
        ));

    await _pumpWidgetWithProviders(tester, backupService, files: [_backupFile(_newerBackup)]);

    await tester.tap(find.text(_newerBackup));
    await tester.pumpAndSettle();

    expect(find.text("Restore this backup?"), findsOneWidget);
    expect(
      find.text("The current configuration is replaced by the contents of this file, not merged with it:"
          " applications, categories, sections and settings all go back to what they were when the backup"
          " was created."),
      findsOneWidget,
    );
    expect(find.text("• com.example.gone"), findsOneWidget);
    expect(find.text("• wallpaper_video"), findsOneWidget);
    verify(backupService.previewImport(argThat(_isFileNamed(_newerBackup))));
    verifyNever(backupService.importBackup(any));

    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();

    verifyNever(backupService.importBackup(any));
    expect(find.text(_newerBackup), findsOneWidget);
  });

  testWidgets("A rejected file shows its localized message, imports nothing and does not reload", (tester) async {
    final backupService = MockBackupService();
    var reloadCount = 0;
    when(backupService.previewImport(any)).thenAnswer((_) async => const BackupImportResult(
          status: BackupImportStatus.invalidFile,
          message: "The file is not valid JSON: FormatException",
        ));

    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile(_newerBackup)],
      reloader: ConfigurationReloader(() => reloadCount++),
    );

    await tester.tap(find.text(_newerBackup));
    await tester.pumpAndSettle();

    expect(find.text("Configuration not restored"), findsOneWidget);
    expect(find.text("This file is not a backup, or it is damaged. Nothing was changed."), findsOneWidget);
    // BackupImportResult.message is for logs only, never for the screen.
    expect(find.textContaining("FormatException"), findsNothing);
    expect(find.text("Restore this backup?"), findsNothing);
    verifyNever(backupService.importBackup(any));
    expect(reloadCount, 0);
  });

  testWidgets("A confirmed restore imports the chosen file and reloads the configuration exactly once",
      (tester) async {
    final backupService = MockBackupService();
    var reloadCount = 0;
    when(backupService.previewImport(any))
        .thenAnswer((_) async => const BackupImportResult(status: BackupImportStatus.succeeded));
    when(backupService.importBackup(any)).thenAnswer((_) async => const BackupImportResult(
          status: BackupImportStatus.succeeded,
          restoredApps: 4,
          restoredCategories: 2,
        ));

    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile(_newerBackup)],
      reloader: ConfigurationReloader(() => reloadCount++),
    );

    await tester.tap(find.text(_newerBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Restore"));
    await tester.pumpAndSettle();

    verify(backupService.importBackup(argThat(_isFileNamed(_newerBackup))));
    expect(find.text("Configuration restored"), findsOneWidget);
    expect(find.text("The configuration was restored."), findsOneWidget);
    // The reload waits for the acknowledgement: it would otherwise destroy the
    // dialog the user is reading.
    expect(reloadCount, 0);

    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();

    expect(reloadCount, 1);
  });

  testWidgets("A partial settings restore is reported as such and still reloads", (tester) async {
    final backupService = MockBackupService();
    var reloadCount = 0;
    when(backupService.previewImport(any))
        .thenAnswer((_) async => const BackupImportResult(status: BackupImportStatus.succeeded));
    when(backupService.importBackup(any)).thenAnswer((_) async => const BackupImportResult(
          status: BackupImportStatus.settingsRestoreIncomplete,
        ));

    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile(_newerBackup)],
      reloader: ConfigurationReloader(() => reloadCount++),
    );

    await tester.tap(find.text(_newerBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Restore"));
    await tester.pumpAndSettle();

    expect(find.text("Configuration restored"), findsOneWidget);
    expect(
      find.text("The configuration was restored, but some settings could not be written and went back to their"
          " default value. Restoring the same backup again is safe."),
      findsOneWidget,
    );

    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();

    expect(reloadCount, 1);
  });

  testWidgets("A failed import shows its message and does not reload", (tester) async {
    final backupService = MockBackupService();
    var reloadCount = 0;
    when(backupService.previewImport(any))
        .thenAnswer((_) async => const BackupImportResult(status: BackupImportStatus.succeeded));
    when(backupService.importBackup(any))
        .thenAnswer((_) async => const BackupImportResult(status: BackupImportStatus.restoreFailed));

    await _pumpWidgetWithProviders(
      tester,
      backupService,
      files: [_backupFile(_newerBackup)],
      reloader: ConfigurationReloader(() => reloadCount++),
    );

    await tester.tap(find.text(_newerBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Restore"));
    await tester.pumpAndSettle();

    expect(find.text("Configuration not restored"), findsOneWidget);
    expect(find.text("The configuration could not be restored. Nothing was changed."), findsOneWidget);

    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();

    expect(reloadCount, 0);
  });
}

Matcher _isFileNamed(String name) => isA<File>().having((file) => file.uri.pathSegments.last, "name", name);

/// A file in the fake export directory. Never created on disk: the page only
/// reads the name, and the stubbed `BackupService` is what would open it.
File _backupFile(String name) => File("/fake-external-storage/$name");

/// Pumps the page with [files] as the whole content of the export directory, or
/// `null` for a device that exposes no such directory at all.
Future<void> _pumpWidgetWithProviders(
  WidgetTester tester,
  BackupService backupService, {
  required List<File>? files,
  ConfigurationReloader? reloader,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<BackupService>.value(value: backupService),
        Provider<ConfigurationReloader>.value(
          value: reloader ?? ConfigurationReloader(() {}),
        ),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BackupRestorePage(backupDirectoryLister: () async => files),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
