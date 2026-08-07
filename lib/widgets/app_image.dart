import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/local_store_service.dart';

/// Resolves an [ImageProvider] from a network URL, in-memory data URI, or a
/// locally stored `local://` ref returned by the device file picker. Returns
/// `null` for empty sources.
ImageProvider<Object>? resolveImageProvider(String? source) {
  if (source == null || source.isEmpty) return null;

  if (source.startsWith('data:')) {
    final comma = source.indexOf(',');
    if (comma == -1) return null;
    return MemoryImage(base64Decode(source.substring(comma + 1)));
  }

  if (source.startsWith(LocalStoreService.localPrefix)) {
    final path = LocalStoreService.instance.resolvePathSync(source);
    if (path == null) return null;
    return FileImage(File(path));
  }

  return NetworkImage(source);
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

    return Image(
      image: provider,
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