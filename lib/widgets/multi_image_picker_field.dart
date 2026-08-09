import 'package:flutter/material.dart';
import '../services/device_file_service.dart';
import 'app_image.dart';

/// Multi-image upload field for gallery posts: collects 3-6 images from the
/// device picker, shows thumbnails with per-image remove, and reports the
/// current selection through [onImagesChanged].
class MultiImagePickerField extends StatefulWidget {
  final List<String> initialImages;
  final ValueChanged<List<String>> onImagesChanged;
  final int minImages;
  final int maxImages;

  const MultiImagePickerField({
    super.key,
    this.initialImages = const [],
    required this.onImagesChanged,
    this.minImages = 3,
    this.maxImages = 6,
  });

  @override
  State<MultiImagePickerField> createState() => _MultiImagePickerFieldState();
}

class _MultiImagePickerFieldState extends State<MultiImagePickerField> {
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  Future<void> _pickImages() async {
    final remaining = widget.maxImages - _images.length;
    if (remaining <= 0) return;
    try {
      final picked = await pickMultipleImagesFromDevice(limit: remaining);
      if (!mounted) return;
      if (picked.isEmpty) return;
      final sources = picked
          .map((f) => f.source)
          .whereType<String>()
          .take(remaining)
          .toList();
      if (sources.isEmpty) return;
      setState(() => _images.addAll(sources));
      widget.onImagesChanged(List.from(_images));
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

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
    widget.onImagesChanged(List.from(_images));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = _images.length < widget.maxImages;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gallery Images',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${_images.length}/${widget.maxImages}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _images.length >= widget.minImages
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select ${widget.minImages}-${widget.maxImages} photos in one go (minimum ${widget.minImages} required)',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          if (_images.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AppImage(
                        source: _images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: canAdd
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: canAdd ? _pickImages : null,
              icon: const Icon(Icons.upload_file_rounded, color: Colors.green),
              label: Text(
                canAdd ? 'Upload Image' : 'Maximum images added',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: canAdd ? Colors.green : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}