import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class PickedDeviceFile {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final int size;

  PickedDeviceFile({
    required this.name,
    this.path,
    this.bytes,
    this.size = 0,
  });

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;

  /// A displayable/serializable source for the in-memory model fields:
  /// falls back to the local file path when byte data is unavailable.
  String? get source {
    if (hasBytes) {
      return 'data:${_mimeFor(name)};base64,${base64Encode(bytes!)}';
    }
    return path;
  }

  String get sizeLabel {
    if (size <= 0) return 'Size unknown';
    if (size < 1024) return '$size B';
    final kb = size / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  static String _mimeFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Opens the native OS file picker for images and returns the picked file.
Future<PickedDeviceFile?> pickImageFromDevice() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    dialogTitle: 'Choose an image from your device',
    allowMultiple: false,
    withData: true,
  );

final file = result?.files.singleOrNull;
  if (file == null) return null;

  return PickedDeviceFile(
    name: file.name,
    path: file.path,
    bytes: file.bytes,
    size: file.size,
  );
}

/// Opens the native photo gallery in multi-select mode so the user can pick
/// up to [limit] images in a single selection (Android Photo Picker /
/// iOS PHPicker). Falls back to the generic multi-select file picker on
/// platforms without native photo multi-pick support.
Future<List<PickedDeviceFile>> pickMultipleImagesFromDevice({
  int limit = 6,
}) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      limit: limit,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked.isEmpty) return [];

    final files = <PickedDeviceFile>[];
    for (final xfile in picked) {
      final bytes = await xfile.readAsBytes();
      files.add(
        PickedDeviceFile(
          name: xfile.name,
          path: xfile.path,
          bytes: bytes,
          size: bytes.length,
        ),
      );
    }
    return files;
  } catch (_) {
    // Photo Picker unavailable on this platform (e.g. desktop): fall back to
    // the generic multi-select file picker.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Choose up to $limit images from your device',
      allowMultiple: true,
      withData: true,
    );

    final files = result?.files ?? [];
    return files
        .take(limit)
        .map(
          (f) => PickedDeviceFile(
            name: f.name,
            path: f.path,
            bytes: f.bytes,
            size: f.size,
          ),
        )
        .toList();
  }
}

/// Opens the native OS file picker for PDF documents only.
Future<PickedDeviceFile?> pickPdfFromDevice() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    dialogTitle: 'Choose a PDF document from your device',
    allowMultiple: false,
    withData: true,
  );

  final file = result?.files.singleOrNull;
  if (file == null) return null;

return PickedDeviceFile(
    name: file.name,
    path: file.path,
    bytes: file.bytes,
    size: file.size,
  );
}

