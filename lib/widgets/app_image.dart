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
