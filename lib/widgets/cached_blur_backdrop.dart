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

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Replaces a live [BackdropFilter] over the (static) wallpaper with a
/// pre-blurred snapshot of the wallpaper that is blitted behind [child].
///
/// A live [BackdropFilter] re-samples and re-blurs the scene on *every*
/// composited frame, which is expensive on low-end GPUs (e.g. Android TV
/// sticks). Because the wallpaper is static, we blur it once into a [ui.Image]
/// and simply copy the region located under this widget each frame — a cheap
/// blit that naturally follows scrolling through the paint offset.
///
/// The snapshot is *screen-sized* — every consumer blits the region that
/// happens to sit behind it, so the whole screen has to be available to all of
/// them — which is why it is shared rather than built per widget: see
/// [_BlurSnapshotCache]. At 1080p one snapshot is roughly 8 MB, and the status
/// bar alone builds half a dozen of these cards.
///
/// Falls back to a live [BackdropFilter] while the snapshot is being prepared
/// or when the wallpaper is a video (which is not static).
///
/// Full-screen blurred wallpaper layer (no foreground content).
class CachedBlurLayer extends StatefulWidget {
  final double sigma;

  const CachedBlurLayer({super.key, required this.sigma});

  @override
  State<CachedBlurLayer> createState() => _CachedBlurLayerState();
}

class _CachedBlurLayerState extends _CachedBlurBackgroundState<CachedBlurLayer> {
  @override
  double get sigma => widget.sigma;

  @override
  Widget buildBlurContent(Widget blurBackground) => blurBackground;

  @override
  Widget buildLiveBlur() => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: const SizedBox.expand(),
  );
}

class CachedBlurBackdrop extends StatefulWidget {
  final double sigma;
  final Widget child;

  const CachedBlurBackdrop({super.key, required this.sigma, required this.child});

  @override
  State<CachedBlurBackdrop> createState() => _CachedBlurBackdropState();
}

class _CachedBlurBackdropState extends _CachedBlurBackgroundState<CachedBlurBackdrop> {
  @override
  double get sigma => widget.sigma;

  @override
  Widget buildBlurContent(Widget blurBackground) {
    return Stack(
      fit: StackFit.passthrough,
      children: [Positioned.fill(child: blurBackground), widget.child],
    );
  }

  @override
  Widget buildLiveBlur() => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: widget.child,
  );
}

abstract class _CachedBlurBackgroundState<T extends StatefulWidget> extends State<T> {
  /// The shared snapshot this widget is currently a consumer of, or `null`
  /// when it holds none (before the first layout, or while the wallpaper is a
  /// video and the live blur is used instead).
  ///
  /// Never disposed from here: this state owns exactly one *reference*, taken
  /// by [_BlurSnapshotCache.acquire] and given back by [_releaseSnapshot].
  /// The [ui.Image] belongs to the entry, which frees it when its last
  /// reference goes away.
  _BlurSnapshotEntry? _entry;

  @override
  void dispose() {
    _releaseSnapshot();
    super.dispose();
  }

  double get sigma;

  Widget buildBlurContent(Widget blurBackground);

  Widget buildLiveBlur();

  /// Gives back this widget's reference to the shared snapshot, if it holds
  /// one. Idempotent, so calling it from both [build] (on a key change or a
  /// switch to the live blur) and [dispose] can never release twice.
  void _releaseSnapshot() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.removeListener(_onSnapshotChanged);
    entry.release();
  }

  /// Called by the shared entry once its snapshot finished rendering, always
  /// from an asynchronous continuation (never during a build), so [setState]
  /// here is safe.
  void _onSnapshotChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WallpaperService>();
    // Video wallpapers are not static: keep the live blur, and stop holding a
    // snapshot this widget is not painting — otherwise switching to a video
    // wallpaper would pin the last static snapshot in memory for as long as
    // the launcher lives.
    if (service.wallpaperVideoFile != null) {
      _releaseSnapshot();
      return buildLiveBlur();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        if (screen.width <= 0 || screen.height <= 0) {
          // Nothing to snapshot yet.
          return buildLiveBlur();
        }

        final key = _BlurSnapshotKey(
          revision: service.wallpaperRevision,
          gradientId: service.wallpaper == null ? service.gradient.uuid : null,
          sigma: sigma,
          size: screen,
          devicePixelRatio: dpr,
        );
        if (_entry?.key != key) {
          // Anything that made the old snapshot stale — a new wallpaper
          // revision, a different gradient, a resize, a different sigma —
          // shows up as a different key here. Release first: this widget is
          // about to paint the live blur, so it no longer needs the old
          // snapshot, and whether the old image is actually freed depends on
          // whether any *other* consumer still holds it.
          _releaseSnapshot();
          _entry = _BlurSnapshotCache.acquire(key, service)..addListener(_onSnapshotChanged);
        }

        final image = _entry!.image;
        if (image == null) {
          // Snapshot not ready: fall back to the live blur for correctness.
          return buildLiveBlur();
        }
        return buildBlurContent(_BlurBlit(image: image, screenSize: screen));
      },
    );
  }
}

/// Identity of a blurred wallpaper snapshot: two consumers whose keys are
/// equal would render byte-identical images, so they share one.
///
/// These are exactly the things the per-widget implementation used to compare
/// to decide a snapshot had gone stale (`_builtRevision`, `_builtGradientId`,
/// `_builtSigma`, `_builtSize`), plus the device pixel ratio, which decides
/// the snapshot's pixel dimensions and so cannot be left out of its identity.
///
/// [gradientId] is `null` whenever there *is* a wallpaper image: the gradient
/// is then invisible behind it and must not fragment the cache. When there is
/// no image, [WallpaperService.wallpaperRevision] already changes with the
/// gradient, but the id is still part of the key so a snapshot can never
/// outlive the gradient it was rendered from.
///
/// Different sigmas do occur in practice: the full-screen app-grid layer uses
/// 10 while the dock and every status-bar card use 5, so this key keeps two
/// snapshots (one per sigma) instead of collapsing them into a wrong-looking
/// shared one.
@immutable
class _BlurSnapshotKey {
  final int revision;
  final String? gradientId;
  final double sigma;
  final Size size;
  final double devicePixelRatio;

  const _BlurSnapshotKey({
    required this.revision,
    required this.gradientId,
    required this.sigma,
    required this.size,
    required this.devicePixelRatio,
  });

  @override
  bool operator ==(Object other) =>
      other is _BlurSnapshotKey &&
      other.revision == revision &&
      other.gradientId == gradientId &&
      other.sigma == sigma &&
      other.size == size &&
      other.devicePixelRatio == devicePixelRatio;

  @override
  int get hashCode => Object.hash(revision, gradientId, sigma, size, devicePixelRatio);
}

/// The process-wide set of live blurred-wallpaper snapshots, one per distinct
/// [_BlurSnapshotKey].
///
/// Deliberately static rather than an inherited widget: the snapshots depend
/// only on the (single) [WallpaperService], the screen and a sigma, so there
/// is nothing per-subtree to scope them to, and consumers sit in completely
/// unrelated parts of the tree (the app-grid layer, the dock, every status-bar
/// card).
class _BlurSnapshotCache {
  _BlurSnapshotCache._();

  static final Map<_BlurSnapshotKey, _BlurSnapshotEntry> _entries = <_BlurSnapshotKey, _BlurSnapshotEntry>{};

  /// Takes one reference on the snapshot for [key], starting its rendering if
  /// this is the first consumer. The caller owns that reference and must give
  /// it back with [_BlurSnapshotEntry.release] exactly once.
  ///
  /// [service] is only read by the *first* caller for a given key, which is
  /// sound because everything the rendering reads from it — the wallpaper
  /// provider, the gradient — is part of the key (through the revision and
  /// the gradient id), so every caller would have produced the same pixels.
  static _BlurSnapshotEntry acquire(_BlurSnapshotKey key, WallpaperService service) {
    final existing = _entries[key];
    if (existing != null) {
      existing._retain();
      return existing;
    }
    final entry = _BlurSnapshotEntry(key);
    _entries[key] = entry;
    entry._retain();
    entry._startRender(service);
    return entry;
  }

  /// Drops [entry] from the cache once its last consumer is gone, so a later
  /// consumer with the same key renders a fresh snapshot instead of picking up
  /// a disposed image.
  static void _forget(_BlurSnapshotEntry entry) {
    if (_entries[entry.key] == entry) _entries.remove(entry.key);
  }
}

/// One shared, reference-counted blurred snapshot of the wallpaper.
///
/// Who disposes the [ui.Image], and when:
///
///  * The image is owned by this entry — never by a consumer widget. A
///    consumer only ever borrows it for the duration of a paint.
///  * Each consumer takes exactly one reference ([_BlurSnapshotCache.acquire])
///    and gives it back exactly once ([release]), from its `dispose` or when
///    its key changes.
///  * [release] disposes the image at the moment the count reaches zero — the
///    *last* consumer's release is what frees it, so it can never be freed
///    while another consumer is still blitting it — and drops the entry from
///    [_BlurSnapshotCache] in the same breath.
///  * A snapshot whose rendering finishes *after* the last consumer already
///    left is disposed immediately on arrival ([_finish]) and never published,
///    so an entry that dies mid-render leaks nothing either.
class _BlurSnapshotEntry {
  final _BlurSnapshotKey key;

  int _refCount = 0;
  ui.Image? _image;
  bool _dead = false;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  _BlurSnapshotEntry(this.key);

  /// The rendered snapshot, or `null` while it is still being prepared (or if
  /// preparing it failed — consumers keep the live blur in both cases).
  ui.Image? get image => _image;

  void _retain() {
    assert(!_dead, "A dead entry is out of the cache and must never be retained again.");
    _refCount++;
  }

  /// Gives back one reference. See the class comment for the ownership rules.
  void release() {
    assert(_refCount > 0, "Released more times than retained.");
    _refCount--;
    if (_refCount > 0) return;
    _dead = true;
    _BlurSnapshotCache._forget(this);
    _image?.dispose();
    _image = null;
    _listeners.clear();
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Renders the snapshot off the current frame. Not awaited by anyone: the
  /// result is published through [_finish], which wakes the consumers up.
  void _startRender(WallpaperService service) {
    // A microtask rather than inline: [_BlurSnapshotCache.acquire] is reached
    // from a build/layout pass, and resolving an [ImageProvider] there has no
    // business happening in the middle of one.
    scheduleMicrotask(() => _render(service));
  }

  Future<void> _render(WallpaperService service) async {
    final pxWidth = (key.size.width * key.devicePixelRatio).round();
    final pxHeight = (key.size.height * key.devicePixelRatio).round();
    final rect = Rect.fromLTWH(0, 0, pxWidth.toDouble(), pxHeight.toDouble());

    ui.Image? source;
    try {
      final provider = service.wallpaper;
      if (provider != null) {
        source = await _resolveImage(provider);
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final blurPaint =
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: key.sigma * key.devicePixelRatio,
              sigmaY: key.sigma * key.devicePixelRatio,
              tileMode: TileMode.clamp,
            );
      canvas.saveLayer(rect, blurPaint);
      if (source != null) {
        paintImage(canvas: canvas, rect: rect, image: source, fit: BoxFit.cover, filterQuality: FilterQuality.low);
      } else {
        canvas.drawRect(rect, Paint()..shader = service.gradient.gradient.createShader(rect));
      }
      canvas.restore();

      _finish(await recorder.endRecording().toImage(pxWidth, pxHeight));
    } catch (error, stack) {
      // The wallpaper file could not be decoded. The live [BackdropFilter] is
      // already the correct fallback and stays on screen; this entry simply
      // never publishes an image. It is not retried per frame (the key is
      // unchanged, so consumers keep this entry): the next wallpaper change
      // bumps the revision and produces a new key, which retries.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: "flauncher",
          context: ErrorDescription("while rendering the blurred wallpaper snapshot"),
        ),
      );
    } finally {
      source?.dispose();
    }
  }

  /// Publishes a freshly rendered snapshot, or disposes it on the spot when
  /// the last consumer left while it was being rendered.
  void _finish(ui.Image image) {
    if (_dead) {
      image.dispose();
      return;
    }
    assert(_image == null, "An entry renders exactly once.");
    _image = image;
    // A copy: a listener may release its reference (and so mutate the list)
    // while it is being notified.
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  static Future<ui.Image> _resolveImage(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// Test-only seam: how many distinct blurred snapshots are alive right now,
/// counting those still being rendered. Follows the `debugNow` /
/// `debugTimerIsActive` precedent; the production code never reads it.
///
/// This is what proves the point of the shared cache: N frosted cards asking
/// for the same blur must add up to 1, not N.
@visibleForTesting
int get debugBlurSnapshotCount => _BlurSnapshotCache._entries.length;

/// Test-only seam: the snapshot images that are currently published, so a test
/// can hold on to one and assert on `ui.Image.debugDisposed` after a consumer
/// detaches. The production code never reads it.
@visibleForTesting
List<ui.Image> get debugBlurSnapshots => [
  for (final entry in _BlurSnapshotCache._entries.values)
    if (entry.image != null) entry.image!,
];

/// Blits the region of the pre-blurred wallpaper [image] located under this
/// render box (in screen space) using the paint offset, so it stays aligned
/// with the wallpaper while scrolling.
class _BlurBlit extends LeafRenderObjectWidget {
  final ui.Image image;
  final Size screenSize;

  const _BlurBlit({required this.image, required this.screenSize});

  @override
  RenderObject createRenderObject(BuildContext context) => _BlurBlitRender(image, screenSize);

  @override
  void updateRenderObject(BuildContext context, _BlurBlitRender renderObject) {
    renderObject
      ..image = image
      ..screenSize = screenSize;
  }
}

class _BlurBlitRender extends RenderBox {
  ui.Image _image;
  Size _screenSize;

  _BlurBlitRender(this._image, this._screenSize);

  set image(ui.Image value) {
    if (value != _image) {
      _image = value;
      markNeedsPaint();
    }
  }

  set screenSize(Size value) {
    if (value != _screenSize) {
      _screenSize = value;
      markNeedsPaint();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final scaleX = _image.width / _screenSize.width;
    final scaleY = _image.height / _screenSize.height;
    // Sample the blurred wallpaper at this box's true on-screen position so the
    // crop stays aligned with the real wallpaper (offset alone is layer-local).
    final screenPos = localToGlobal(Offset.zero);
    final src = Rect.fromLTWH(screenPos.dx * scaleX, screenPos.dy * scaleY, size.width * scaleX, size.height * scaleY);
    final dst = offset & size;
    context.canvas.drawImageRect(_image, src, dst, Paint()..filterQuality = FilterQuality.low);
  }
}
