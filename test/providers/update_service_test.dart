import 'dart:io';

import 'package:flauncher/providers/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("isAbiSplitApk", () {
    test("detects ABI-split release assets", () {
      expect(isAbiSplitApk("lemonade-launcher-1.0.5-arm64-v8a.apk"), isTrue);
      expect(isAbiSplitApk("lemonade-launcher-1.0.5-armeabi-v7a.apk"), isTrue);
      expect(isAbiSplitApk("lemonade-launcher-1.0.5-x86_64.apk"), isTrue);
      expect(isAbiSplitApk("lemonade-launcher-1.0.5-x86.apk"), isTrue);
    });

    test("treats universal assets as non-split", () {
      expect(isAbiSplitApk("lemonade-launcher-1.0.5.apk"), isFalse);
      expect(isAbiSplitApk("lemonade-launcher.apk"), isFalse);
      expect(isAbiSplitApk("arc-launcher-universal-release.apk"), isFalse);
    });
  });

  group("pickReleaseApk", () {
    test("prefers universal APK over ABI splits", () {
      final picked = pickReleaseApk([
        {
          "name": "lemonade-launcher-1.0.5-arm64-v8a.apk",
          "browser_download_url": "https://example.com/arm64.apk",
        },
        {
          "name": "lemonade-launcher-1.0.5-armeabi-v7a.apk",
          "browser_download_url": "https://example.com/armeabi.apk",
        },
        {
          "name": "lemonade-launcher-1.0.5.apk",
          "browser_download_url": "https://example.com/universal.apk",
        },
      ]);

      expect(picked?.name, "lemonade-launcher-1.0.5.apk");
      expect(picked?.url, "https://example.com/universal.apk");
    });

    test("falls back to first APK when no universal exists", () {
      final picked = pickReleaseApk([
        {
          "name": "lemonade-launcher-1.0.5-arm64-v8a.apk",
          "browser_download_url": "https://example.com/arm64.apk",
        },
        {
          "name": "lemonade-launcher-1.0.5-armeabi-v7a.apk",
          "browser_download_url": "https://example.com/armeabi.apk",
        },
      ]);

      expect(picked?.name, "lemonade-launcher-1.0.5-arm64-v8a.apk");
    });
  });

  group("clearDownloadedApks", () {
    test("removes downloaded APKs but leaves other files", () async {
      final dir = await Directory.systemTemp.createTemp("update_service_clear_test");
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      await File("${dir.path}/lemonade-launcher-1.0.0.apk").writeAsString("old");
      await File("${dir.path}/lemonade-launcher-1.1.0.apk").writeAsString("older");
      await File("${dir.path}/notes.txt").writeAsString("keep me");

      await clearDownloadedApks(dir);

      final remaining =
          dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toSet();
      expect(remaining, {"notes.txt"});
    });

    test("is a no-op on a directory that does not exist", () async {
      final parent = await Directory.systemTemp.createTemp("update_service_missing_test");
      final missing = Directory("${parent.path}/does_not_exist");
      addTearDown(() async {
        if (await parent.exists()) await parent.delete(recursive: true);
      });

      await clearDownloadedApks(missing); // must not throw

      expect(await missing.exists(), isFalse);
    });
  });
}
