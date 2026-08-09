import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'multi_image_picker_field.dart';

class CreateGalleryModal extends StatefulWidget {
  const CreateGalleryModal({super.key});

  @override
  State<CreateGalleryModal> createState() => _CreateGalleryModalState();
}

class _CreateGalleryModalState extends State<CreateGalleryModal> {
  static const int _minImages = 3;
  static const int _maxImages = 6;

  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  List<String> selectedImages = [];

  late String department;

  @override
  void initState() {
    super.initState();
    final dataService = Provider.of<MockDataService>(context, listen: false);
    department = dataService.currentUser.department;
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _publishGallery() async {
    final dataService = Provider.of<MockDataService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    if (selectedImages.length < _minImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Add at least $_minImages images (${selectedImages.length}/$_minImages added)',
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final online = await dataService.checkBackendReachable();
    if (!mounted) return;
    if (!online) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.wifi_off, color: Colors.red, size: 40),
          title: const Text('No Internet Connection'),
          content: const Text(
            'Please turn on your internet and try again. Your gallery was not published.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final newPost = PostModel(
      id: 'pst_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descController.text.trim(),
      category: PostCategory.gallery,
      department: department,
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
      timestamp: DateTime.now(),
      imageUrl: selectedImages.first,
      imageUrls: List.from(selectedImages),
    );

    dataService.addPost(newPost);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📸 Gallery published to Campus Feed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 Upload Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Post Title *',
                prefixIcon: const Icon(Icons.title_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter post title' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add a short caption for your photos...',
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            MultiImagePickerField(
              minImages: _minImages,
              maxImages: _maxImages,
              onImagesChanged: (images) {
                setState(() => selectedImages = images);
              },
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: dataService.config.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _publishGallery();
              },
              child: const Text(
                'Publish Gallery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}