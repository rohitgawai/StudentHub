import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/form_models.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'custom_dropdown.dart';
import 'image_picker_field.dart';
import 'link_form_editor.dart';
import 'pdf_upload_field.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();

  late PostCategory category = PostCategory.announcement;
  late String department;
  String? targetYear;
  String? selectedImageUrl;
  bool isUrgent = false;
  bool attachPdfMock = false;
  bool _isPublishing = false;

  List<PostAttachment> attachedPdfs = [];
  List<PostLink> links = [];
  FormDefinition? form;

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

  Future<void> _publishPost() async {
    final dataService = Provider.of<MockDataService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    final newPost = PostModel(
      id: 'pst_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descController.text.trim(),
      category: isUrgent ? PostCategory.urgent : category,
      department: department,
      targetYear: targetYear,
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
      authorAvatarUrl: dataService.currentUser.avatarUrl,
      timestamp: DateTime.now(),
      imageUrl: selectedImageUrl,
      isUrgent: isUrgent,
      attachments: attachPdfMock ? attachedPdfs : [],
      links: links,
      form: form,
    );

    dataService.addPost(newPost);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Post published to Campus Feed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;

    final allowedCategories = PostCategory.values
        .where((c) =>
            c != PostCategory.event &&
            c != PostCategory.gallery &&
            c != PostCategory.urgent &&
            c != PostCategory.workshop)
        .toList();
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cfg.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign_rounded, color: cfg.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Create Campus Post',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
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
            // Category & Title Card
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
                    'Post Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  CustomDropdownField<PostCategory>(
                    value: category,
                    labelText: 'Post Category',
                    prefixIcon: Icons.category_outlined,
                    items: allowedCategories,
                    itemLabel: (c) => c.displayName,
                    onChanged: (val) {
                      if (val != null) setState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Post Title *',
                      hintText: 'e.g. Revised Mid-Semester Examination Schedule',
                      prefixIcon: Icon(Icons.title_rounded, color: cfg.primaryColor),
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

                  // Description
                  TextFormField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Detailed Description *',
                      hintText: 'Write all details, instructions or timetable info...',
                      prefixIcon: Icon(Icons.description_outlined, color: cfg.primaryColor),
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
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter description' : null,
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

                  // Target Academic Year Custom Dropdown (No "(Optional)")
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

            // Cover Image Card
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
                    'Post Media',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ImagePickerField(
                    initialUrl: selectedImageUrl,
                    onImageSelected: (url) {
                      setState(() => selectedImageUrl = url);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Priority & Attachments Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Mark as Urgent Post 🔥',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Pinned with priority banner on student feeds',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    value: isUrgent,
                    onChanged: (val) => setState(() => isUrgent = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Attach Official PDF Document 📄',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Attach syllabus, timetable, or official circular PDF',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    value: attachPdfMock,
                    onChanged: (val) => setState(() => attachPdfMock = val),
                  ),
                  if (attachPdfMock) ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: PdfUploadField(
                        onAttachmentChanged: (attachments) {
                          attachedPdfs = attachments;
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Links & Interactive Forms Card
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
              child: LinkFormEditor(
                accent: cfg.primaryColor,
                initialFormLabel: titleController.text.trim().isEmpty
                    ? 'Response Form'
                    : titleController.text.trim(),
                onLinksChanged: (links) => setState(() => this.links = links),
                onFormChanged: (form) => setState(() => this.form = form),
              ),
            ),

            const SizedBox(height: 24),

            // Glowing CTA Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cfg.primaryColor, cfg.primaryColor.withBlue(220)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cfg.primaryColor.withValues(alpha: 0.35),
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
                onPressed: _isPublishing ? null : _publishPost,
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
                          Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Publish Post',
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

