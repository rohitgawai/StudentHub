import 'package:flutter/material.dart';
import '../services/device_file_service.dart';
import 'app_image.dart';

class ImagePickerField extends StatefulWidget {
  final String? initialUrl;
  final ValueChanged<String?> onImageSelected;
  final String? label;
  final bool showHeader;

  const ImagePickerField({
    super.key,
    this.initialUrl,
    required this.onImageSelected,
    this.label,
    this.showHeader = false,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  String? selectedUrl;
  String? selectedFileName;

  @override
  void initState() {
    super.initState();
    selectedUrl = widget.initialUrl;
    if (selectedUrl != null && selectedUrl!.isNotEmpty) {
      selectedFileName = 'Uploaded_Image.jpg';
    }
  }

  Future<void> _pickImageFromDevice() async {
    try {
      final picked = await pickImageFromDevice();
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          selectedUrl = picked.source;
          selectedFileName = picked.name;
        });
        widget.onImageSelected(selectedUrl);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not open file picker. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      selectedUrl = null;
      selectedFileName = null;
    });
    widget.onImageSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader && widget.label != null && widget.label!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_a_photo_outlined, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      widget.label!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (selectedUrl != null && selectedUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: _clearImage,
                    child: const Text(
                      'Remove Image',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Selected Image Preview
          if (selectedUrl != null && selectedUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  AppImage(
                    source: selectedUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            selectedFileName ?? 'Uploaded_Photo.jpg',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _clearImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            // Direct Device Image Upload Button (No URL link option)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _pickImageFromDevice,
                icon: const Icon(Icons.upload_file_rounded, color: Colors.blue),
                label: const Text(
                  'Upload Image',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
