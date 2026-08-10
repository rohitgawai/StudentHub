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
  int announcementWeeks = 1;

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

  void _publishUrgentAnnouncement() {
    final dataService = Provider.of<MockDataService>(context, listen: false);

    final wait = dataService.canPostAnnouncement(department);
    if (wait != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Announcement Already Active 📢'),
          content: Text(
            'An announcement for $department is already posted on the header. '
            'It expires in ${_formatWait(wait)}. '
            'Please wait and post a new one after that.',
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

    final published = dataService.postAnnouncement(
      title: titleController.text.trim(),
      description: descController.text.trim(),
      department: department,
      duration: Duration(days: announcementWeeks * 7),
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
    );

    if (!published) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement already active for this department. Please wait for it to expire.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📢 Urgent announcement live on header for ${announcementWeeks == 1 ? '1 week' : '2 weeks'}!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatWait(Duration d) {
    if (d.inDays >= 1) {
      return d.inDays == 1 ? '1 day' : '${d.inDays} days';
    }
    if (d.inHours >= 1) {
      return d.inHours == 1 ? '1 hour' : '${d.inHours} hours';
    }
    return d.inMinutes <= 1 ? 'a minute' : '${d.inMinutes} minutes';
  }

  Future<void> _publishPost() async {
    final dataService = Provider.of<MockDataService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    // Header announcements are a local, time-limited feature: no backend.
    if (category == PostCategory.urgentAnnouncement) {
      _publishUrgentAnnouncement();
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
            'Please turn on your internet and try again. Your post was not published.',
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
      category: isUrgent ? PostCategory.urgent : category,
      department: department,
      targetYear: targetYear,
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
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

    // Gallery and Event have their own dedicated upload cards. Urgent is
    // handled by the "Mark as Urgent" switch, and workshops are event posts
    // that go through the Event card (they need venue/date fields).
    final allowedCategories = PostCategory.values
        .where((c) =>
            c != PostCategory.event &&
            c != PostCategory.gallery &&
            c != PostCategory.urgent &&
            c != PostCategory.workshop)
        .toList();
    final yearOptions = ['All Academic Years', ...dataService.config.academicYears];

    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Create Campus Post'),
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
            // Requirement 1: Compact Custom Dropdown for Category
            CustomDropdownField<PostCategory>(
              value: category,
              labelText: 'Post Category',
              prefixIcon: Icons.category_outlined,
              items: allowedCategories,
              itemLabel: (c) => c == PostCategory.urgentAnnouncement
                  ? 'Campus Alert (Header Banner)'
                  : c.displayName,
              onChanged: (val) {
                if (val != null) setState(() => category = val);
              },
            ),
            if (category == PostCategory.urgentAnnouncement) ...[
              const SizedBox(height: 6),
              Text(
                'Shows as a banner on top of every page for 1-2 weeks; '
                'only one active banner per department.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),

            // Announcement Validity (only for header announcements)
            if (category == PostCategory.urgentAnnouncement) ...[
              CustomDropdownField<int>(
                value: announcementWeeks,
                labelText: 'Announcement Validity',
                prefixIcon: Icons.timer_outlined,
                items: const [1, 2],
                itemLabel: (w) => '$w Week${w > 1 ? 's' : ''}',
                onChanged: (val) {
                  if (val != null) setState(() => announcementWeeks = val);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Title
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Post Title',
                prefixIcon: const Icon(Icons.title_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter post title' : null,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: descController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Detailed Description',
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter description' : null,
            ),
            const SizedBox(height: 12),

            // Target Department Custom Dropdown
            CustomDropdownField<String>(
              value: department,
              labelText: 'Target Department',
              prefixIcon: Icons.school_outlined,
              items: dataService.config.departments,
              itemLabel: (d) => d,
              onChanged: (val) {
                if (val != null) setState(() => department = val);
              },
            ),
            const SizedBox(height: 12),

            // Target Academic Year Custom Dropdown
            CustomDropdownField<String>(
              value: targetYear ?? 'All Academic Years',
              labelText: 'Target Academic Year (Optional)',
              prefixIcon: Icons.calendar_month_outlined,
              items: yearOptions,
              itemLabel: (y) => y,
              onChanged: (val) {
                setState(() {
                  targetYear = (val == 'All Academic Years') ? null : val;
                });
              },
            ),
            const SizedBox(height: 14),

            // Requirement 10: Image Upload Picker (Replaces raw URL field)
            // Header banner alerts are plain text banners: no cover image.
            if (category != PostCategory.urgentAnnouncement)
              ImagePickerField(
                initialUrl: selectedImageUrl,
                onImageSelected: (url) {
                  setState(() => selectedImageUrl = url);
                },
              ),
            const SizedBox(height: 14),

            // Toggles & PDF Attachment (Requirement 11)
            if (category != PostCategory.urgentAnnouncement) ...[
              SwitchListTile(
                title: const Text('Mark as Urgent Post 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Will be prioritized at top of student feeds', style: TextStyle(fontSize: 11)),
                value: isUrgent,
                onChanged: (val) => setState(() => isUrgent = val),
              ),
              // Requirement 11: Switch yes button triggers PDF Upload options
              SwitchListTile(
                title: const Text('Attach Official PDF Document 📄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Upload/attach official PDF notice, syllabus, or timetable', style: TextStyle(fontSize: 11)),
                value: attachPdfMock,
                onChanged: (val) => setState(() => attachPdfMock = val),
              ),
              if (attachPdfMock) ...[
                PdfUploadField(
                  onAttachmentChanged: (attachments) {
                    attachedPdfs = attachments;
                  },
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Links & Form section (any category except header banners).
            if (category != PostCategory.urgentAnnouncement)
              LinkFormEditor(
                accent: dataService.config.primaryColor,
                initialFormLabel: titleController.text.trim().isEmpty
                    ? 'Response Form'
                    : titleController.text.trim(),
                onLinksChanged: (links) => setState(() => this.links = links),
                onFormChanged: (form) => setState(() => this.form = form),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: dataService.config.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _publishPost();
              },
              child: const Text(
                'Publish Post',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
