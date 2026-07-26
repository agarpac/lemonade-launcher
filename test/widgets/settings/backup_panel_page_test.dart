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
import 'package:flauncher/widgets/settings/backup_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    // Scale-down the font size because the font 'Ahem' used when running tests is much wider than Roboto
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("A successful export shows where the file went", (tester) async {
    final backupService = MockBackupService();
    when(backupService.exportBackup()).thenAnswer((_) async => const BackupExportResult(
          status: BackupExportStatus.succeeded,
          filePath: "/storage/emulated/0/lemonade-launcher-backup-20260101-101010.json",
          settingsCount: 3,
        ));

    await _pumpWidgetWithProviders(tester, backupService);

    await tester.tap(find.text("Create backup"));
    await tester.pumpAndSettle();

    expect(find.text("Backup created"), findsOneWidget);
    expect(
      find.text("File: /storage/emulated/0/lemonade-launcher-backup-20260101-101010.json"),
      findsOneWidget,
    );
  });

  testWidgets("A successful export lists the wallpapers whose bytes were left out", (tester) async {
    final backupService = MockBackupService();
    when(backupService.exportBackup()).thenAnswer((_) async => const BackupExportResult(
          status: BackupExportStatus.succeeded,
          filePath: "/storage/emulated/0/lemonade-launcher-backup-20260101-101010.json",
          wallpapersNotIncluded: ["wallpaper", "scene_wallpaper_cinema"],
        ));

    await _pumpWidgetWithProviders(tester, backupService);

    await tester.tap(find.text("Create backup"));
    await tester.pumpAndSettle();

    expect(
      find.text("Wallpaper images are not part of the backup."
          " You will have to choose these again after restoring:"),
      findsOneWidget,
    );
    expect(find.text("• wallpaper"), findsOneWidget);
    expect(find.text("• scene_wallpaper_cinema"), findsOneWidget);
  });

  testWidgets("A failed export shows the localized message, never the service's English one", (tester) async {
    final backupService = MockBackupService();
    when(backupService.exportBackup()).thenAnswer((_) async => const BackupExportResult(
          status: BackupExportStatus.failed,
          message: "Could not write the backup file: FileSystemException",
        ));

    await _pumpWidgetWithProviders(tester, backupService);

    await tester.tap(find.text("Create backup"));
    await tester.pumpAndSettle();

    expect(find.text("Backup not created"), findsOneWidget);
    expect(find.text("The backup file could not be written. Nothing was saved."), findsOneWidget);
    // BackupExportResult.message is for logs only: it is English whatever the
    // user's locale is, so it must never reach the screen.
    expect(find.textContaining("FileSystemException"), findsNothing);
  });

  testWidgets("An export with no reachable storage shows its own message", (tester) async {
    final backupService = MockBackupService();
    when(backupService.exportBackup()).thenAnswer((_) async => const BackupExportResult(
          status: BackupExportStatus.storageUnavailable,
        ));

    await _pumpWidgetWithProviders(tester, backupService);

    await tester.tap(find.text("Create backup"));
    await tester.pumpAndSettle();

    expect(
      find.text("This device exposes no storage where the backup could be written."),
      findsOneWidget,
    );
  });

  testWidgets("'Restore backup' opens the backup picker and exports nothing", (tester) async {
    final backupService = MockBackupService();

    await _pumpWidgetWithProviders(tester, backupService);

    await tester.tap(find.text("Restore backup"));
    await tester.pumpAndSettle();

    expect(find.byKey(Key("BackupRestorePage")), findsOneWidget);
    verifyNever(backupService.exportBackup());
  });
}

Future<void> _pumpWidgetWithProviders(WidgetTester tester, BackupService backupService) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<BackupService>.value(value: backupService),
      ],
      builder: (_, __) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          BackupRestorePage.routeName: (_) => Container(key: Key("BackupRestorePage")),
        },
        home: Scaffold(body: const BackupPanelPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
