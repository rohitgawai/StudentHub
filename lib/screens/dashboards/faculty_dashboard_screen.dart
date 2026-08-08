import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/mock_data_service.dart';

import '../../widgets/post_card.dart';
import '../../widgets/create_post_modal.dart';

class FacultyDashboardScreen extends StatelessWidget {
  const FacultyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final facultyPosts = dataService.posts
        .where((p) => p.authorRole == UserRole.faculty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 Faculty Notice Center'),
        backgroundColor: const Color(0xFF0369A1),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0369A1), Color(0xFF0288D1)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Department of ${user.department}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0369A1),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const CreatePostModal(),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Publish Academic Notice / PDF'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Published Department Announcements (${facultyPosts.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (facultyPosts.isEmpty)
            const Center(
              child: Text(
                'No academic notices published yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...facultyPosts.map(
              (p) => PostCard(
                post: p,
                config: dataService.config,
                isSaved: dataService.currentUser.savedPostIds.contains(p.id),
                isRegistered: dataService.currentUser.registeredEventIds
                    .contains(p.id),
                isCongratulated: dataService.currentUser.congratulatedPostIds
                    .contains(p.id),
                userYear: dataService.currentUser.year,
                currentUserId: dataService.currentUser.id,
              ),
            ),
        ],
      ),
    );
  }
}
