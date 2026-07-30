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

// The blurred wallpaper snapshot is screen-sized (roughly 8 MB at 1080p), so
// on a 2 GB TV box the number of them that exist at once is a hard constraint,
// not a detail: the status bar alone builds half a dozen frosted cards. These
// tests pin down that the snapshot is *shared* — one per distinct
// (revision, gradient, sigma, size, dpr) — and that its lifetime is exactly
// "until the last consumer is gone", never shorter (garbage on screen) and
// never longer (the leak this cache exists to prevent).

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

void main() {
  MockWallpaperService mkWallpaperService({
    int revision = 0,
    FLauncherGradient? gradient,
    bool video = false,
  }) {
    final wallpaperService = MockWallpaperService();
    // No image: the blurred content is the static gradient, which needs no
    // asset loading inside the test's fake-async zone.
    when(wallpaperService.wallpaper).thenReturn(null);
    when(wallpaperService.wallpaperVideoFile).thenReturn(video ? File("/nonexistent/video") : null);
    when(wallpaperService.wallpaperRevision).thenReturn(revision);
    when(wallpaperService.gradient).thenReturn(gradient ?? FLauncherGradients.greatWhale);
    return wallpaperService;
  }

  Widget wrap(WallpaperService wallpaperService, Widget child) => MultiProvider(
    providers: [ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService)],
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );

  /// [count] frosted cards, all asking for the same [sigma], side by side.
  Widget cards(int count, {double sigma = 5}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index += 1)
        CachedBlurBackdrop(sigma: sigma, child: const SizedBox(width: 20, height: 20)),
    ],
  );

  /// Detaches every consumer, which must leave the cache empty again. Also
  /// keeps the process-wide cache from leaking into the next test in this file.
  Future<void> detachAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(debugBlurSnapshotCount, 0, reason: "no snapshot may outlive its last consumer");
  }

  testWidgets("many widgets asking for the same blur share a single snapshot", (tester) async {
    await tester.pumpWidget(wrap(mkWallpaperService(), cards(6)));
    await tester.pumpAndSettle();

    expect(find.byType(CachedBlurBackdrop), findsNWidgets(6));
    // The whole point: six consumers, one screen-sized image.
    expect(debugBlurSnapshotCount, 1);
    expect(debugBlurSnapshots, hasLength(1));
    // And every one of them is blitting it rather than blurring live.
    expect(find.byType(BackdropFilter), findsNothing);

    await detachAll(tester);
  });

  testWidgets("the full-screen layer and the cards share nothing, because their sigmas differ", (tester) async {
    // Reality in this codebase: `CachedBlurLayer` uses sigma 10 for the
    // app-grid backdrop while the dock and every status-bar card use 5. Those
    // must stay two snapshots — collapsing them would render one of the two at
    // the wrong blur radius.
    await tester.pumpWidget(
      wrap(
        mkWallpaperService(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [cards(3, sigma: 5), cards(2, sigma: 10)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(debugBlurSnapshotCount, 2);

    await detachAll(tester);
  });

  testWidgets("a wallpaper revision change produces a fresh snapshot", (tester) async {
    await tester.pumpWidget(wrap(mkWallpaperService(revision: 3), cards(2)));
    await tester.pumpAndSettle();
    final firstSnapshot = debugBlurSnapshots.single;

    await tester.pumpWidget(wrap(mkWallpaperService(revision: 4), cards(2)));
    await tester.pumpAndSettle();

    expect(debugBlurSnapshotCount, 1, reason: "the stale snapshot must not linger alongside the new one");
    expect(debugBlurSnapshots.single, isNot(same(firstSnapshot)));
    expect(firstSnapshot.debugDisposed, isTrue);

    await detachAll(tester);
  });

  testWidgets("a gradient change produces a fresh snapshot", (tester) async {
    await tester.pumpWidget(wrap(mkWallpaperService(gradient: FLauncherGradients.greatWhale), cards(2)));
    await tester.pumpAndSettle();
    final firstSnapshot = debugBlurSnapshots.single;

    // Same revision on purpose: the gradient id alone has to be enough.
    await tester.pumpWidget(wrap(mkWallpaperService(gradient: FLauncherGradients.viciousStance), cards(2)));
    await tester.pumpAndSettle();

    expect(debugBlurSnapshotCount, 1);
    expect(debugBlurSnapshots.single, isNot(same(firstSnapshot)));
    expect(firstSnapshot.debugDisposed, isTrue);

    await detachAll(tester);
  });

  testWidgets("a screen resize produces a fresh snapshot", (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;

    final wallpaperService = mkWallpaperService();
    await tester.pumpWidget(wrap(wallpaperService, cards(2)));
    await tester.pumpAndSettle();
    final firstSnapshot = debugBlurSnapshots.single;

    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();

    expect(debugBlurSnapshotCount, 1);
    expect(debugBlurSnapshots.single, isNot(same(firstSnapshot)));
    expect(firstSnapshot.debugDisposed, isTrue);

    await detachAll(tester);
  });

  testWidgets("the snapshot survives one consumer detaching and dies with the last", (tester) async {
    final wallpaperService = mkWallpaperService();
    await tester.pumpWidget(wrap(wallpaperService, cards(3)));
    await tester.pumpAndSettle();
    final snapshot = debugBlurSnapshots.single;
    expect(snapshot.debugDisposed, isFalse);

    // Two of the three go away. Disposing here would paint garbage in the one
    // that is still on screen.
    await tester.pumpWidget(wrap(wallpaperService, cards(1)));
    await tester.pumpAndSettle();
    expect(debugBlurSnapshotCount, 1);
    expect(debugBlurSnapshots.single, same(snapshot));
    expect(snapshot.debugDisposed, isFalse);

    // The last one goes away: now, and only now, the image is freed.
    await tester.pumpWidget(wrap(wallpaperService, cards(0)));
    await tester.pumpAndSettle();
    expect(debugBlurSnapshotCount, 0);
    expect(snapshot.debugDisposed, isTrue);

    await detachAll(tester);
  });

  testWidgets("a video wallpaper keeps the live blur and holds no snapshot", (tester) async {
    await tester.pumpWidget(wrap(mkWallpaperService(video: true), cards(3)));
    await tester.pumpAndSettle();

    // Video wallpapers are not static, so there is nothing to snapshot.
    expect(debugBlurSnapshotCount, 0);
    expect(find.byType(BackdropFilter), findsNWidgets(3));

    await detachAll(tester);
  });

  testWidgets("switching to a video wallpaper releases the snapshot that was held", (tester) async {
    await tester.pumpWidget(wrap(mkWallpaperService(), cards(2)));
    await tester.pumpAndSettle();
    final snapshot = debugBlurSnapshots.single;

    await tester.pumpWidget(wrap(mkWallpaperService(video: true), cards(2)));
    await tester.pumpAndSettle();

    expect(debugBlurSnapshotCount, 0);
    expect(snapshot.debugDisposed, isTrue);
    expect(find.byType(BackdropFilter), findsNWidgets(2));

    await detachAll(tester);
  });

  testWidgets("every consumer keeps the live blur while the snapshot is pending", (tester) async {
    // A wallpaper whose decoding never completes, so "pending" is a state the
    // test can actually observe: with the gradient, the snapshot is already
    // finished by the time the first `pumpWidget` returns, because
    // `Picture.toImage` resolves inside the same fake-async microtask flush.
    final wallpaperService = mkWallpaperService();
    when(wallpaperService.wallpaper).thenReturn(const _NeverLoadingImage());

    await tester.pumpWidget(wrap(wallpaperService, cards(2)));
    await tester.pumpAndSettle();

    // The snapshot has been asked for exactly once, and neither consumer is
    // waiting on a blank surface: both blur live until it arrives.
    expect(debugBlurSnapshotCount, 1);
    expect(debugBlurSnapshots, isEmpty);
    expect(find.byType(BackdropFilter), findsNWidgets(2));

    await detachAll(tester);
  });
}

/// An [ImageProvider] whose frames never arrive, used to hold the snapshot in
/// its "being prepared" state for as long as a test needs.
class _NeverLoadingImage extends ImageProvider<_NeverLoadingImage> {
  const _NeverLoadingImage();

  @override
  Future<_NeverLoadingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_NeverLoadingImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: Completer<ui.Codec>().future, scale: 1.0);
}
