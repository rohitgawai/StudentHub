import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../services/local_store_service.dart';

/// Bounded LRU cache of decoded bytes for `data:` URI images, so repeated
/// builds reuse the decoded buffer instead of re-running `base64Decode` on the
/// UI isolate (which janks frames and gets dropped on newer devices). The
/// cache is capped by both entry count and total bytes so low-end devices
/// never accumulate hundreds of megabytes of camera photos.
final Map<String, Uint8List> _dataUriBytesCache = <String, Uint8List>{};
const int _dataUriBytesCacheLimit = 48;
const int _dataUriBytesBudget = 64 * 1024 * 1024; // 64 MB
int _dataUriBytesTotal = 0;

Uint8List? _cachedDataUriBytes(String source) {
  final bytes = _dataUriBytesCache.remove(source);
  if (bytes == null) return null;
  _dataUriBytesCache[source] = bytes; // most-recently-used at the tail
  return bytes;
}

void _cacheDataUriBytes(String source, Uint8List bytes) {
  _dataUriBytesCache.remove(source);
  _dataUriBytesCache[source] = bytes;
  _dataUriBytesTotal += bytes.length;
  while ((_dataUriBytesTotal > _dataUriBytesBudget ||
          _dataUriBytesCache.length > _dataUriBytesCacheLimit) &&
      _dataUriBytesCache.isNotEmpty) {
    final oldest = _dataUriBytesCache.keys.first;
    final removed = _dataUriBytesCache.remove(oldest);
    if (removed != null) _dataUriBytesTotal -= removed.length;
  }
}

Uint8List _decodeBase64Helper(String base64) => base64Decode(base64);

/// Lightweight disk cache for network images. Unlike the OS memory cache it
/// survives app restarts, so repeat views of a gallery/cover are instant
/// (like any mainstream social app) and work while offline. No database is
/// used: the cache directory is the OS-managed app cache, keyed by URL hash.
class _DiskImageCache {
  _DiskImageCache._();

  static final _DiskImageCache instance = _DiskImageCache._();

  static const int _maxAttempts = 3;

  Directory? _dir;
  final Map<String, Future<File>> _inFlight = {};
  final Set<String> _recentFailures = {};

  Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    Directory dir;
    try {
      // Timeout-guarded: in test environments platform channels never
      // respond, so fall back to a plain temp dir instead of hanging.
      final base = await getApplicationCacheDirectory()
          .timeout(const Duration(seconds: 3));
      dir = Directory('${base.path}${Platform.pathSeparator}images');
      // Sync I/O on a small cache dir: async file ops never complete inside
      // widget-test FakeAsync zones, and sync calls are milliseconds here.
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (_) {
      // No real filesystem (e.g. web) or unreachable platform channel:
      // fall back to system temp so reads are no-ops rather than crashes.
      dir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'studenthub_images',
      );
    }
    _dir = dir;
    return dir;
  }

  String _filePathFor(String url) {
    // Deterministic FNV-1a 64-bit hash: stable across restarts (cache files
    // must keep their name) and collision-resistant enough for URL keys.
    var hash = 0xcbf29ce484222325;
    final bytes = utf8.encode(url);
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Returns the cached file for [url], downloading it (with retries) on the
  /// first request. Concurrent callers share the same download.
  Future<File> getFile(String url) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}${Platform.pathSeparator}${_filePathFor(url)}');

    if (_recentFailures.contains(url)) {
      // A previous attempt failed hard; try once more anyway (network may
      // have come back) but skip repeated spam.
      _recentFailures.remove(url);
    }
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }

    final inFlight = _inFlight[url];
    if (inFlight != null) return inFlight;

    final future = _download(url, file);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(url);
    }
  }

  Future<File> _download(String url, File file) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException(
            'GET $url -> HTTP ${res.statusCode}',
          );
        }
        if (res.bodyBytes.isEmpty) {
          throw const FormatException('Empty image response');
        }
        file.writeAsBytesSync(res.bodyBytes, flush: true);
        _recentFailures.remove(url);
        return file;
      } catch (e) {
        lastError = e;
        if (attempt < _maxAttempts - 1) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    _recentFailures.add(url);
    throw lastError!;
  }

  /// Deletes the cached file for [url] (used when a cover/gallery image is
  /// re-uploaded so the fresh bytes load everywhere).
  Future<void> removeFile(String url) async {
    _recentFailures.remove(url);
    final dir = await _cacheDir();
    final file = File('${dir.path}${Platform.pathSeparator}${_filePathFor(url)}');
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort.
    }
  }
}

/// Resolves an [ImageProvider] from a network URL, in-memory data URI, or a
/// locally stored `local://` ref returned by the device file picker. Returns
/// `null` for empty sources.
///
/// Network URLs resolve to a disk-backed, retrying provider so images survive
/// app restarts and transient network failures (no more grey boxes).
ImageProvider<Object>? resolveImageProvider(String? source) {
  if (source == null || source.isEmpty) return null;

  if (source.startsWith('data:')) {
    var bytes = _cachedDataUriBytes(source);
    if (bytes == null) {
      final comma = source.indexOf(',');
      if (comma == -1) return null;
      try {
        bytes = base64Decode(source.substring(comma + 1));
      } catch (_) {
        return null;
      }
      _cacheDataUriBytes(source, bytes);
    }
    return MemoryImage(bytes);
  }
  if (source.startsWith(LocalStoreService.localPrefix)) {
    final path = LocalStoreService.instance.resolvePathSync(source);
    if (path != null) {
      return FileImage(File(path));
    }
    return null;
  }
  return _DiskCachedNetworkImageProvider(source);
}

/// Removes every cached trace of [url] (disk file, in-memory decoded bytes and
/// the global image cache). Called when a cover/gallery image is re-uploaded
/// so every device loads the fresh bytes instead of the stale cached frame.
void clearCachedImage(String? url) {
  if (url == null || url.isEmpty) return;
  _dataUriBytesCache.remove(url);
  if (url.startsWith('http')) {
    unawaited(_DiskImageCache.instance.removeFile(url));
    PaintingBinding.instance.imageCache
        .evict(_DiskCachedNetworkImageProvider(url));
    PaintingBinding.instance.imageCache.evict(NetworkImage(url));
  }
}

/// Disk-backed network image provider: serves the file from the on-device
/// cache when available (instant repeat displays, works offline) and
/// downloads it on first request with retries, like mainstream social apps.
class _DiskCachedNetworkImageProvider
    extends ImageProvider<_DiskCachedNetworkImageProvider> {
  final String url;

  const _DiskCachedNetworkImageProvider(this.url);

  @override
  Future<_DiskCachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_DiskCachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DiskCachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('URL: $url'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _DiskCachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final file = await _DiskImageCache.instance.getFile(url);
    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) {
      PaintingBinding.instance.imageCache.evict(this);
      throw StateError('$url downloaded to an empty file and cannot be '
          'loaded as an image.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    return other is _DiskCachedNetworkImageProvider && other.url == url;
  }

  @override
  int get hashCode => Object.hash(runtimeType, url);

  @override
  String toString() =>
      '${objectRuntimeType(this, '_DiskCachedNetworkImageProvider')}("$url")';
}

/// Renders an image from a network URL, an in-memory data URI, or a local
/// `local://` file ref returned by the device file picker. Network images are
/// disk-cached and retried on failure; `data:` URIs are decoded off the UI
/// isolate so large camera photos never block frames.
class AppImage extends StatefulWidget {
  final String? source;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? errorChild;

  const AppImage({
    super.key,
    this.source,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.errorChild,
  });

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  ImageProvider<Object>? _provider;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _resolve();
  }

  Future<void> _resolve() async {
    final source = widget.source;
    if (source == null || source.isEmpty) {
      if (mounted) setState(() => _provider = null);
      return;
    }

    ImageProvider<Object>? provider;
    if (source.startsWith('data:')) {
      // Decode base64 on a background isolate: camera photos are multi-MB and
      // decoding them synchronously on the UI isolate drops frames. In widget
      // tests isolate results never arrive (FakeAsync), so decode inline.
      var bytes = _cachedDataUriBytes(source);
      if (bytes == null) {
        final comma = source.indexOf(',');
        if (comma != -1) {
          try {
            if (Platform.environment.containsKey('FLUTTER_TEST')) {
              bytes = base64Decode(source.substring(comma + 1));
            } else {
              final decoded = await compute(
                _decodeBase64Helper,
                source.substring(comma + 1),
              );
              bytes = decoded;
            }
            _cacheDataUriBytes(source, bytes);
          } catch (_) {
            bytes = null;
          }
        }
      }
      if (bytes != null) provider = MemoryImage(bytes);
    } else {
      provider = resolveImageProvider(source);
    }

    if (!mounted || widget.source != source) return;
    setState(() => _provider = provider);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return widget.errorChild ??
          Container(color: Colors.grey.shade200);
    }

    // Downscale network/file images so small boxes never decode full-resolution
    // bitmaps: use ~800 logical px (3x on hi-dpi screens) instead of the
    // original size. In-memory images are already decoded from the exact
    // bytes, so leave them untouched.
    final ImageProvider<Object> displayProvider;
    if (provider is MemoryImage) {
      displayProvider = provider;
    } else {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = (800 * dpr).round().clamp(320, 2500);
      displayProvider = ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
    }

    return Image(
      image: displayProvider,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        if (frame == null) {
          return _ImageLoadingPlaceholder(
            height: widget.height,
            width: widget.width,
          );
        }
        return _ImageFadeIn(child: child);
      },
      errorBuilder: (ctx, err, stack) =>
          widget.errorChild ??
          Container(
            color: Colors.grey.shade200,
            constraints: widget.height != null || widget.width != null
                ? BoxConstraints(
                    minHeight: widget.height ?? 0,
                    maxHeight: widget.height ?? double.infinity,
                    minWidth: widget.width ?? 0,
                    maxWidth: widget.width ?? double.infinity,
                  )
                : null,
            child: const Center(
              child: Icon(Icons.image, size: 40, color: Colors.grey),
            ),
          ),
    );
  }
}

/// Soft grey placeholder shown while the image is still decoding, so cards
/// never flash an empty void.
class _ImageLoadingPlaceholder extends StatefulWidget {
  final double? height;
  final double? width;

  const _ImageLoadingPlaceholder({this.height, this.width});

  @override
  State<_ImageLoadingPlaceholder> createState() =>
      _ImageLoadingPlaceholderState();
}

class _ImageLoadingPlaceholderState extends State<_ImageLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.85).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        height: widget.height,
        width: widget.width,
        constraints: widget.height != null || widget.width != null
            ? BoxConstraints(
                minHeight: widget.height ?? 0,
                maxHeight: widget.height ?? double.infinity,
                minWidth: widget.width ?? 0,
                maxWidth: widget.width ?? double.infinity,
              )
            : null,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 32, color: Colors.grey),
        ),
      ),
    );
  }
}

/// Fades the decoded frame in over 350ms.
class _ImageFadeIn extends StatelessWidget {
  final Widget child;

  const _ImageFadeIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (ctx, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}