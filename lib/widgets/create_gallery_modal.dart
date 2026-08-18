import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'custom_dropdown.dart';
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
  String? targetYear;
  bool _isPublishing = false;

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

    // Lock the button while the gallery is being added (prevents a double-tap
    // that would publish the same gallery twice).
    setState(() => _isPublishing = true);

    final newPost = PostModel(
      id: 'pst_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descController.text.trim(),
      category: PostCategory.gallery,
      department: department,
      targetYear: targetYear,
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
      authorAvatarUrl: dataService.currentUser.avatarUrl,
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
    final cfg = dataService.config;
    final yearOptions = ['All Academic Years', ...cfg.academicYears];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.collections_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            const Text(
              'Photo Gallery',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17.5,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            // Subtitle Banner Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.teal.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload 3 to 6 photos from campus events, fests, sports and workshops to showcase on feed.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Post Title Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gallery Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Post Title',
                      hintText: 'e.g. Annual Tech Symposium Highlights 2026',
                      prefixIcon: const Icon(Icons.title_rounded, color: Colors.green),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
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
                      hintText: 'Add a short story or caption for your photos...',
                      prefixIcon: const Icon(Icons.description_outlined, color: Colors.green),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Target Audience Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Audience',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Target Department
                  CustomDropdownField<String>(
                    value: department,
                    labelText: 'Target Department',
                    prefixIcon: Icons.school_outlined,
                    items: cfg.departments,
                    itemLabel: (d) => d,
                    onChanged: (val) {
                      if (val != null) setState(() => department = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Target Academic Year Dropdown
                  CustomDropdownField<String>(
                    value: targetYear ?? 'All Academic Years',
                    labelText: 'Target Academic Year',
                    prefixIcon: Icons.calendar_month_outlined,
                    items: yearOptions,
                    itemLabel: (y) => y,
                    onChanged: (val) {
                      setState(() {
                        targetYear = (val == 'All Academic Years') ? null : val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Photos Uploader Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gallery Photos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Glowing CTA Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isPublishing ? null : _publishGallery,
                child: _isPublishing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Publish Gallery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}