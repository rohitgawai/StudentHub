import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final imageUrlController = TextEditingController();

  PostCategory category = PostCategory.announcement;
  late String department;
  String? targetYear;
  bool isUrgent = false;
  bool isPinned = false;
  bool attachPdfMock = false;

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
    imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Announcement / Post'),
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
            // Category Selector
            DropdownButtonFormField<PostCategory>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Post Category',
                border: OutlineInputBorder(),
              ),
              items: PostCategory.values
                  .where((c) => c != PostCategory.event)
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => category = val);
              },
            ),
            const SizedBox(height: 12),

            // Title
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Post Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter post title' : null,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Detailed Description *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter description' : null,
            ),
            const SizedBox(height: 12),

            // Department
            DropdownButtonFormField<String>(
              value: department,
              decoration: const InputDecoration(
                labelText: 'Target Department',
                border: OutlineInputBorder(),
              ),
              items: dataService.config.departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => department = val);
              },
            ),
            const SizedBox(height: 12),

            // Target Year
            DropdownButtonFormField<String?>(
              value: targetYear,
              decoration: const InputDecoration(
                labelText: 'Target Academic Year (Optional)',
                border: OutlineInputBorder(),
                hintText: 'All Academic Years',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Academic Years'),
                ),
                ...dataService.config.academicYears
                    .map((y) => DropdownMenuItem<String?>(value: y, child: Text(y))),
              ],
              onChanged: (val) => setState(() => targetYear = val),
            ),
            const SizedBox(height: 12),

            // Image URL (optional)
            TextFormField(
              controller: imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (Optional)',
                hintText: 'https://images.unsplash.com/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Toggles
            SwitchListTile(
              title: const Text('Mark as Urgent Post 🔥'),
              subtitle: const Text('Will be prioritized at top of student feeds'),
              value: isUrgent,
              onChanged: (val) => setState(() => isUrgent = val),
            ),
            SwitchListTile(
              title: const Text('Pin to Department Top 📌'),
              value: isPinned,
              onChanged: (val) => setState(() => isPinned = val),
            ),
            SwitchListTile(
              title: const Text('Attach Official PDF Document 📄'),
              subtitle: const Text('Simulates embedding downloadable PDF syllabus/notice'),
              value: attachPdfMock,
              onChanged: (val) => setState(() => attachPdfMock = val),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: dataService.config.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
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
                  timestamp: DateTime.now(),
                  imageUrl: imageUrlController.text.trim().isNotEmpty
                      ? imageUrlController.text.trim()
                      : null,
                  isUrgent: isUrgent,
                  isPinned: isPinned,
                  attachments: attachPdfMock
                      ? [
                          PostAttachment(
                            title: 'Official_Notice_${titleController.text.trim().replaceAll(' ', '_')}.pdf',
                            fileType: 'pdf',
                            url: 'notice.pdf',
                            fileSize: '1.2 MB',
                          )
                        ]
                      : [],
                );

                dataService.addPost(newPost);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Post published to Campus Feed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Publish Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
