import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/local_store_service.dart';

/// Cache of resolved [ImageProvider]s keyed by the source string. Creating a
/// provider (especially `base64Decode` for `data:` URIs) is skipped on every
/// rebuild once a source has been resolved.
final Map<String, ImageProvider<Object>> _providerCache = {};

/// Resolves an [ImageProvider] from a network URL, in-memory data URI, or a
/// locally stored `local://` ref returned by the device file picker. Returns
/// `null` for empty sources.
ImageProvider<Object>? resolveImageProvider(String? source) {
  if (source == null || source.isEmpty) return null;

  final cached = _providerCache[source];
  if (cached != null) return cached;

  ImageProvider<Object>? provider;
  if (source.startsWith('data:')) {
    final comma = source.indexOf(',');
    if (comma == -1) return null;
    provider = MemoryImage(base64Decode(source.substring(comma + 1)));
  } else if (source.startsWith(LocalStoreService.localPrefix)) {
    final path = LocalStoreService.instance.resolvePathSync(source);
    if (path != null) {
      provider = FileImage(File(path));
    }
  } else {
    provider = NetworkImage(source);
  }

  if (provider != null) {
    _providerCache[source] = provider;
  }
  return provider;
}

/// Renders an image from either a network URL or an in-memory data URI
/// returned by the device file picker.
class AppImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final provider = resolveImageProvider(source);
    if (provider == null) {
      return errorChild ?? Container(color: Colors.grey.shade200);
    }

    // Downscale network images so small boxes never decode full-resolution
    // bitmaps: use ~800 logical px (3x on hi-dpi screens) instead of the
    // original size. In-memory and local-file images are already decoded from
    // the exact bytes, so leave them untouched.
    final ImageProvider<Object> displayProvider;
    if (provider is NetworkImage) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = (800 * dpr).round().clamp(320, 2500);
      displayProvider = ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
    } else {
      displayProvider = provider;
    }

    return Image(
      image: displayProvider,
      height: height,
      width: width,
      fit: fit,
      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        if (frame == null) {
          return _ImageLoadingPlaceholder(
            height: height,
            width: width,
          );
        }
        return _ImageFadeIn(child: child);
      },
      errorBuilder: (ctx, err, stack) =>
          errorChild ??
          Container(
            color: Colors.grey.shade200,
            constraints: height != null || width != null
                ? BoxConstraints(
                    minHeight: height ?? 0,
                    maxHeight: height ?? double.infinity,
                    minWidth: width ?? 0,
                    maxWidth: width ?? double.infinity,
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
